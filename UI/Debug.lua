-- Debug commands: /ptip anchors, /ptip perf, /ptip pixel, and /ptip trace. Each shows its
-- findings in the report window, to copy into a bug report.
local addonName, ns = ...
local ui = ns.ui
if not ui then return end

local isSecret = ns.util.isSecret
local util = ns.util
local panels, perf = ui.panels, ui.perf

-- /ptip anchors: where each shown panel sits, left to right, and how its
-- hidden tooltip is anchored.
function ns.dumpAnchors()
    local shown = {}
    for tooltip, panel in pairs(panels) do
        if util.canModify(tooltip) and panel:IsShown() then
            local left, right = util.number(panel:GetLeft()), util.number(panel:GetRight())
            local nativeLeft, nativeRight = util.number(tooltip:GetLeft()), util.number(tooltip:GetRight())
            if left and right and nativeLeft and nativeRight then
                shown[#shown + 1] = {
                    tooltip = tooltip,
                    panel = panel,
                    left = left,
                    right = right,
                    nativeLeft = nativeLeft,
                    nativeRight = nativeRight
                }
            end
        end
    end
    table.sort(shown, function(a, b) return a.left < b.left end)
    local function nameOf(frame)
        if not frame then return "nil" end
        if not util.canModify(frame) then return "<restricted>" end
        for tooltip, panel in pairs(panels) do
            if frame == panel then return (tooltip:GetName() or "?") .. "'s panel" end
        end
        return frame:GetName() or tostring(frame)
    end
    if #shown == 0 then
        print("PrettyTooltip: no panel is shown.")
        return
    end
    local lines = {}
    for index, entry in ipairs(shown) do
        local tooltip, panel = entry.tooltip, entry.panel
        local line = ("%s: panel %.1f to %.1f (pinned %s), hidden %.1f to %.1f"):format(tooltip:GetName() or "?",
            entry.left, entry.right, tostring(panel.side), entry.nativeLeft, entry.nativeRight)
        if index > 1 then
            line = line .. (", gap %.1f"):format(entry.left - shown[index - 1].right)
        end
        lines[#lines + 1] = line
        for _, point in ipairs(util.framePoints(tooltip) or {}) do
            lines[#lines + 1] = ("    %s to %s %s, offset %s, %s"):format(point[1], nameOf(point[2]),
                point[3], tostring(point[4]), tostring(point[5]))
        end
    end
    ns.showReport("anchors", lines)
end

-- /ptip pixel: whether lines are snapped by the game's PixelUtil or the
-- addon's own math, and what one screen pixel is at the current scale.
function ns.dumpPixel()
    local native = PixelUtil and PixelUtil.GetNearestPixelSize and PixelUtil.GetPixelToUIUnitFactor
    local width, height = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    width, height, scale = util.number(width), util.number(height), util.number(scale)
    if not (width and height and scale) then
        ns.showReport("pixel", { "Screen geometry is restricted." }); return
    end
    ns.showReport("pixel", { ("Snapping with %s; screen %dx%d, UI scale %.3f, one pixel = %.4f units."):format(
        native and "the game's PixelUtil" or "the addon's own math", width, height, scale, ui.pixel(UIParent)) })
end

-- The addon's own memory in KB, as the game counts it; nil where it cannot.
local function addonMemory()
    local getter = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    if not (UpdateAddOnMemoryUsage and getter) then return end
    local ok, usage = pcall(function()
        UpdateAddOnMemoryUsage()
        return getter(addonName)
    end)
    if ok and not isSecret(usage) and type(usage) == "number" then return usage end
end

function ns.perfCapture(seconds)
    perf.calls, perf.time, perf.on = {}, {}, true
    local memory = collectgarbage("count")
    local own = addonMemory()
    print("PrettyTooltip: measuring for " .. seconds .. " seconds; keep the tooltip open.")
    C_Timer.After(seconds, function()
        perf.on = false
        local names, counts = {}, {}
        for name, calls in pairs(perf.calls) do
            if perf.time[name] then
                names[#names + 1] = name
            else
                counts[#counts + 1] = name .. " " .. calls
            end
        end
        table.sort(names, function(a, b) return perf.time[a] > perf.time[b] end)
        table.sort(counts)
        local lines = { string.format("PrettyTooltip perf over %d s:", seconds) }
        local ownNow = addonMemory()
        if own and ownNow then
            lines[#lines + 1] = string.format("  memory: %.0f KB, %+.0f KB over the run", ownNow, ownNow - own)
        end
        lines[#lines + 1] = string.format("  all addons' Lua memory: %+.0f KB over the run",
            collectgarbage("count") - memory)
        if #counts > 0 then lines[#lines + 1] = "  counts: " .. table.concat(counts, ", ") end
        for _, name in ipairs(names) do
            lines[#lines + 1] = string.format("  %s: %d calls (%.0f/s), %.1f ms", name, perf.calls[name],
                perf.calls[name] / seconds, perf.time[name] or 0)
        end
        ns.showReport("perf", lines)
    end)
end

-- /ptip trace: every frame for a few seconds, each game tooltip's and its
-- panel's visibility, opacity, size, and anchors, written when they change,
-- and the calls that move, show, hide, or fade a game tooltip, with the line
-- that made each. Values the game hides read "secret".
local TRACED = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local MAX_LINES = 4000
local tracing, traceLines, traceStart, traceFrame
local hookedForTrace = {}

local function shown(value)
    if isSecret(value) then return "secret" end
    if type(value) == "number" then return ("%.1f"):format(value) end
    return tostring(value)
end

local function traceLine(text)
    if #traceLines >= MAX_LINES then
        tracing = false
        return
    end
    traceLines[#traceLines + 1] = ("%7.3f  %s"):format(debugprofilestop() / 1000 - traceStart, text)
end

local function nameOf(frame)
    if isSecret(frame) then return "secret" end
    if not frame then return "nil" end
    for tooltip, panel in pairs(panels) do
        if frame == panel then return (util.call(tooltip.GetName, tooltip) or "?") .. ".panel" end
    end
    return util.call(frame.GetName, frame) or tostring(frame)
end

local function anchorsOf(frame)
    local count = util.call(frame.GetNumPoints, frame)
    if not count then return "points secret" end
    local parts = {}
    for index = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        parts[#parts + 1] = ("%s>%s.%s(%s,%s)"):format(shown(point), nameOf(relativeTo), shown(relativePoint),
            shown(x), shown(y))
    end
    return #parts > 0 and table.concat(parts, " ") or "no points"
end

local function stateOf(frame, isTooltip)
    if not frame then return "missing" end
    if not util.canModify(frame) then return "restricted" end
    local parts = { frame:IsShown() and "shown" or "hidden" }
    if not frame:IsShown() then return parts[1] end
    parts[#parts + 1] = "alpha " .. shown(frame:GetAlpha())
    if frame.GetEffectiveAlpha then parts[#parts + 1] = "eff " .. shown(frame:GetEffectiveAlpha()) end
    parts[#parts + 1] = "size " .. shown(frame:GetWidth()) .. "x" .. shown(frame:GetHeight())
    parts[#parts + 1] = "pos " .. shown(frame:GetLeft()) .. "," .. shown(frame:GetTop())
    parts[#parts + 1] = "scale " .. shown(frame:GetScale())
    if isTooltip and frame.GetPadding then
        local right, bottom, left, top = frame:GetPadding()
        parts[#parts + 1] = ("pad %s/%s/%s/%s"):format(shown(right), shown(bottom), shown(left), shown(top))
    end
    if isTooltip and frame.IsClampedToScreen then parts[#parts + 1] = "clamped " .. shown(frame:IsClampedToScreen()) end
    parts[#parts + 1] = anchorsOf(frame)
    return table.concat(parts, "  ")
end

local function hookForTrace(tooltip, name)
    if hookedForTrace[tooltip] then return end
    hookedForTrace[tooltip] = true
    -- The first line of the stack that is neither the game's C nor this file.
    local function caller()
        for line in (debugstack(2, 12, 0) or ""):gmatch("[^\n]+") do
            if not line:find("^%s*%[C%]") and not line:find("UI/Debug.lua", 1, true) then
                return (line:gsub("^%s+", ""):gsub("Interface/AddOns/", ""):gsub("^%[string \"@?", ""))
            end
        end
        return "the game"
    end
    local function record(method, describe)
        if not tooltip[method] then return end
        hooksecurefunc(tooltip, method, function(_, ...)
            if not tracing then return end
            traceLine(("%s:%s(%s)  from %s"):format(name, method, describe and describe(...) or "", caller()))
        end)
    end
    local function first(value) return shown(value) end
    record("SetAlpha", first)
    record("Show")
    -- Wrapping Hide makes the game's GameTooltip_Hide fail on the 1.60 beta
    -- client ("attempt to call a nil value") for the rest of the session.
    tooltip:HookScript("OnHide", function()
        if tracing then traceLine(("%s OnHide  from %s"):format(name, caller())) end
    end)
    record("SetShown", first)
    record("FadeOut")
    record("ClearAllPoints")
    record("SetPoint", function(point, relativeTo, relativePoint, x, y)
        return ("%s, %s, %s, %s, %s"):format(shown(point), nameOf(relativeTo), shown(relativePoint), shown(x), shown(y))
    end)
    record("SetOwner", function(owner, anchor) return nameOf(owner) .. ", " .. shown(anchor) end)
    record("SetPadding", function(...)
        local values = {}
        for index = 1, select("#", ...) do values[index] = shown((select(index, ...))) end
        return table.concat(values, ", ")
    end)
    record("SetScale", first)
end

function ns.traceTooltips(seconds)
    if tracing then
        print("PrettyTooltip: a trace is already running.")
        return
    end
    traceLines, traceStart, tracing = {}, debugprofilestop() / 1000, true
    local previous, combat = {}, nil
    for _, name in ipairs(TRACED) do
        local tooltip = _G[name]
        if tooltip and util.canModify(tooltip) then hookForTrace(tooltip, name) end
    end
    traceFrame = traceFrame or CreateFrame("Frame")
    local frameCount = 0
    -- The two faults to catch: the game's tooltip showing under a shown panel,
    -- and a panel shown while its tooltip is hidden.
    local visible, visibleInCombat, orphaned, flagged = 0, 0, 0, 0
    local function check(name, tooltip, panel, inCombat)
        if not (panel and panel:IsShown() and util.canModify(tooltip)) then return end
        if not tooltip:IsShown() then
            orphaned = orphaned + 1
            if flagged < 40 then
                flagged = flagged + 1
                traceLine(("!! frame %d  %s.panel shown without its tooltip, at %s,%s"):format(frameCount, name,
                    shown(panel:GetLeft()), shown(panel:GetTop())))
            end
            return
        end
        -- A tooltip moved off the screen while it fades is out of sight, whatever its alpha.
        local right, top = util.number(tooltip:GetRight()), util.number(tooltip:GetTop())
        if right and top and (right < 0 or top < 0) then return end
        local alpha = tooltip.GetEffectiveAlpha and tooltip:GetEffectiveAlpha() or tooltip:GetAlpha()
        if isSecret(alpha) or alpha > .01 then
            visible = visible + 1
            if inCombat then visibleInCombat = visibleInCombat + 1 end
            if flagged < 40 then
                flagged = flagged + 1
                traceLine(("!! frame %d  %s VISIBLE under its panel, alpha %s, %s by %s"):format(frameCount, name,
                    shown(alpha), shown(tooltip:GetWidth()) .. "x" .. shown(tooltip:GetHeight()),
                    shown(panel:GetWidth()) .. "x" .. shown(panel:GetHeight())))
            end
        end
    end
    traceFrame:SetScript("OnUpdate", function()
        if not tracing then return end
        frameCount = frameCount + 1
        local inCombat = InCombatLockdown() and true or false
        if inCombat ~= combat then
            combat = inCombat
            traceLine(inCombat and "-- in combat" or "-- out of combat")
        end
        for _, name in ipairs(TRACED) do
            local tooltip = _G[name]
            local panel = tooltip and panels[tooltip]
            pcall(check, name, tooltip, panel, inCombat)
            for _, entry in ipairs({ { name, tooltip, true }, { name .. ".panel", panel, false } }) do
                local ok, state = pcall(stateOf, entry[2], entry[3])
                state = ok and state or ("unreadable: " .. tostring(state))
                if previous[entry[1]] ~= state then
                    previous[entry[1]] = state
                    traceLine(("frame %d  %s  %s"):format(frameCount, entry[1], state))
                end
            end
        end
    end)
    print("PrettyTooltip: tracing tooltips for " .. seconds .. " seconds; hover what shows the problem now.")
    C_Timer.After(seconds, function()
        tracing = false
        traceFrame:SetScript("OnUpdate", nil)
        local lines = { ("PrettyTooltip trace over %d s, %d frames%s:"):format(seconds, frameCount,
            #traceLines >= MAX_LINES and " (cut short at " .. MAX_LINES .. " lines)" or ""),
            ("  the game's tooltip visible under a panel: %d frames, %d of them in combat"):format(visible,
                visibleInCombat),
            ("  a panel shown without its tooltip: %d frames"):format(orphaned) }
        for _, line in ipairs(traceLines) do lines[#lines + 1] = line end
        ns.showReport("trace", lines)
    end)
end
