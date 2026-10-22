-- Debug commands: /ptip anchors, /ptip perf, /ptip pixel, and /ptip trace. Each shows its
-- findings in the report window, to copy into a bug report.
local addonName, ns = ...
local ui = ns.ui
if not ui then return end
local placement = ns.Placement

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
    local lines = { "Placement: " .. placement.strategy }
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

local perfFrame
function ns.perfCapture(seconds)
    if perf.on then print("PrettyTooltip: a performance capture is already running."); return end
    seconds = math.min(30, math.max(1, tonumber(seconds) or 5))
    perf.calls, perf.time, perf.max = {}, {}, {}
    perf.depth, perf.total = 0, 0
    local memory = collectgarbage("count")
    local own = addonMemory()
    local mode = ns.option("layout")
    local strategy = mode == "blizzard" and "Blizzard frames" or placement.strategy
    local started, frames = debugprofilestop(), 0
    perfFrame = perfFrame or CreateFrame("Frame")
    perfFrame:SetScript("OnUpdate", function() frames = frames + 1 end)
    perf.on = true
    print("PrettyTooltip: measuring for " .. seconds .. " seconds; keep the tooltip open.")
    C_Timer.After(seconds, function()
        local elapsed = math.max(.001, (debugprofilestop() - started) / 1000)
        perf.on = false
        perfFrame:SetScript("OnUpdate", nil)
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
        local lines = { string.format("PrettyTooltip perf over %.3f s (requested %g s), layout %s:", elapsed, seconds, mode),
            "  placement strategy: " .. strategy,
            string.format("  %d frames, %.1f frames/s", frames, frames / elapsed),
            string.format("  instrumented work: %.3f ms total, %.3f ms/frame (nested calls counted once)",
                perf.total, frames > 0 and perf.total / frames or 0),
            "  Times are inclusive and overlap; do not add rows. Profiling adds overhead." }
        local endMode = ns.option("layout")
        if endMode ~= mode then lines[#lines + 1] = "  Layout changed during capture; repeat this run." end
        local ownNow = addonMemory()
        if own and ownNow then
            lines[#lines + 1] = string.format("  memory: %.0f KB, %+.0f KB over the run", ownNow, ownNow - own)
        end
        lines[#lines + 1] = string.format("  all addons' Lua memory: %+.0f KB over the run",
            collectgarbage("count") - memory)
        if #counts > 0 then lines[#lines + 1] = "  counts: " .. table.concat(counts, ", ") end
        for _, name in ipairs(names) do
            lines[#lines + 1] = string.format("  %s: %d calls (%.1f/s), %.3f ms total, %.2f us/call, %.2f us max, %.3f ms/frame",
                name, perf.calls[name], perf.calls[name] / elapsed, perf.time[name],
                perf.time[name] * 1000 / perf.calls[name], (perf.max[name] or 0) * 1000,
                frames > 0 and perf.time[name] / frames or 0)
        end
        ns.showReport("perf", lines)
    end)
end

-- /ptip trace: every frame for a few seconds, each game tooltip's and its
-- panel's visibility, opacity, size, and anchors, written when they change,
-- and the calls that move, show, hide, or fade a game tooltip, with the line
-- that made each. Values the game hides read "secret".
local TRACED = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
local MAX_EVENTS = 4000
local tracing, traceLines, traceStart, traceFrame
local hookedForTrace = {}
local hookedManagers = setmetatable({}, { __mode = "k" })
local lastAlpha, suppressed, eventCount, omittedEvents

local function shown(value)
    if isSecret(value) then return "secret" end
    if type(value) == "number" then return ("%.1f"):format(value) end
    return tostring(value)
end

local function traceLine(text)
    traceLines[#traceLines + 1] = ("%7.3f  %s"):format(debugprofilestop() / 1000 - traceStart, text)
end

-- Bound noisy method logs while retaining samples and lifecycle events.
local function takeEvent(essential)
    if not tracing then return false end
    if essential then return true end
    if eventCount >= MAX_EVENTS then
        omittedEvents = omittedEvents + 1
        return false
    end
    eventCount = eventCount + 1
    return true
end

local function pendingOf(panel)
    if not panel then return "no panel" end
    local flags = {}
    for _, flag in ipairs({ "restorePending", "contentPending", "comparisonPending", "comparisonFitPending",
        "comparisonAnchorPending" }) do
        if panel[flag] then flags[#flags + 1] = flag end
    end
    return "pending " .. (#flags > 0 and table.concat(flags, ",") or "none")
end

local function nameOf(frame)
    if isSecret(frame) then return "secret" end
    if not frame then return "nil" end
    if type(frame) ~= "table" and type(frame) ~= "userdata" then return shown(frame) end
    for tooltip, panel in pairs(panels) do
        if frame == panel then return (util.call(tooltip.GetName, tooltip) or "?") .. ".panel" end
        if frame == panel.close then return (util.call(tooltip.GetName, tooltip) or "?") .. ".panel.close" end
    end
    return util.call(frame.GetName, frame) or util.call(frame.GetDebugName, frame) or tostring(frame)
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
    if frame.IsMouseOver then parts[#parts + 1] = "hover " .. shown(util.call(frame.IsMouseOver, frame)) end
    if isTooltip and frame.GetPadding then
        local right, bottom, left, top = frame:GetPadding()
        parts[#parts + 1] = ("pad %s/%s/%s/%s"):format(shown(right), shown(bottom), shown(left), shown(top))
    end
    if isTooltip and frame.IsClampedToScreen then parts[#parts + 1] = "clamped " .. shown(frame:IsClampedToScreen()) end
    parts[#parts + 1] = anchorsOf(frame)
    return table.concat(parts, "  ")
end

-- An invisible native child can receive mouse motion over the visible panel.
-- Log its identity, parent and bounds when focus changes, including alpha 0.
local function mouseState()
    local foci
    if type(GetMouseFoci) == "function" then
        foci = util.call(GetMouseFoci)
        if type(foci) ~= "table" then return "focus restricted" end
    elseif type(GetMouseFocus) == "function" then
        foci = { util.call(GetMouseFocus) }
    else
        return "focus API unavailable"
    end
    local parts = {}
    for index, frame in ipairs(foci) do
        if index > 6 then break end
        if util.canModify(frame) then
            local parent = util.call(frame.GetParent, frame)
            parts[#parts + 1] = nameOf(frame) .. " parent " .. nameOf(parent) .. " {" .. stateOf(frame, false) .. "}"
        else
            parts[#parts + 1] = "restricted"
        end
    end
    return #parts > 0 and table.concat(parts, " | ") or "no focus"
end

local function mousePosition()
    local x, y = util.call(GetCursorPosition)
    return "cursor " .. shown(x) .. "," .. shown(y)
end

local function hookForTrace(tooltip, name, isPanel)
    if hookedForTrace[tooltip] then return end
    hookedForTrace[tooltip] = true
    -- The first line of the stack that is neither the game's C nor this file.
    local function caller()
        for line in ((debugstack(2, 12, 0) or ""):gsub("\\", "/")):gmatch("[^\n]+") do
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
            if method == "SetAlpha" then
                local alpha = ...
                if not isSecret(alpha) and alpha == 0 and lastAlpha[tooltip] == 0 then
                    suppressed = suppressed + 1
                    return
                end
                lastAlpha[tooltip] = util.number(alpha)
            end
            if not takeEvent() then return end
            local panel = isPanel and tooltip or panels[tooltip]
            if not isPanel and panel then hookForTrace(panel, name .. ".panel", true) end
            traceLine(("%s:%s(%s)  from %s  [%s]"):format(name, method, describe and describe(...) or "", caller(),
                pendingOf(panel)))
        end)
    end
    local function first(value) return shown(value) end
    record("SetAlpha", first)
    record("Show")
    -- Wrapping Hide makes the game's GameTooltip_Hide fail on the 1.60 beta
    -- client ("attempt to call a nil value") for the rest of the session.
    local events = isPanel and { "OnHide", "OnShow" } or { "OnHide", "OnShow", "OnTooltipCleared" }
    if util.call(tooltip.IsMouseEnabled, tooltip) == true then
        events[#events + 1], events[#events + 2] = "OnEnter", "OnLeave"
    end
    for _, event in ipairs(events) do
        tooltip:HookScript(event, function()
            if takeEvent(true) then
                local mouse = ""
                if event == "OnEnter" or event == "OnLeave" then
                    local ok, state = pcall(mouseState)
                    mouse = "  " .. mousePosition() .. "  " .. (ok and state or "focus unreadable")
                end
                traceLine(("%s %s  from %s  [%s]%s"):format(name, event, caller(),
                    pendingOf(isPanel and tooltip or panels[tooltip]), mouse))
            end
        end)
    end
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

local function hookComparisonTrace()
    local manager = TooltipComparisonManager
    if isSecret(manager) or type(manager) ~= "table" then return end
    local hooked = hookedManagers[manager]
    if not hooked then hooked = {}; hookedManagers[manager] = hooked end
    for _, method in ipairs({ "Initialize", "SetItemTooltip", "AnchorShoppingTooltips", "Clear" }) do
        if not hooked[method] and type(manager[method]) == "function" then
            hooked[method] = true
            hooksecurefunc(manager, method, function(self, first, second)
                if isSecret(self) or not takeEvent(true) then return end
                traceLine(("TooltipComparisonManager:%s(%s, %s)  owner %s"):format(method,
                    shown(first), shown(second), nameOf(self.tooltip)))
            end)
        end
    end
end

function ns.traceTooltips(seconds)
    if tracing then
        print("PrettyTooltip: a trace is already running.")
        return
    end
    traceLines, traceStart, tracing = {}, debugprofilestop() / 1000, true
    traceLine("layout: " .. ns.option("layout"))
    traceLine("placement strategy: " .. placement.strategy)
    lastAlpha, suppressed = {}, 0
    eventCount, omittedEvents = 0, 0
    local previous, combat, previousMouse = {}, nil, nil
    for _, name in ipairs(TRACED) do
        local tooltip = _G[name]
        if tooltip and util.canModify(tooltip) then
            hookForTrace(tooltip, name)
            if panels[tooltip] then hookForTrace(panels[tooltip], name .. ".panel", true) end
        end
    end
    hookComparisonTrace()
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
        -- Frames, panels and the comparison manager can appear after tracing starts.
        hookComparisonTrace()
        local inCombat = InCombatLockdown() and true or false
        if inCombat ~= combat then
            combat = inCombat
            traceLine(inCombat and "-- in combat" or "-- out of combat")
        end
        local mouseOK, mouse = pcall(mouseState)
        mouse = mouseOK and mouse or "focus unreadable"
        if mouse ~= previousMouse then
            previousMouse = mouse
            traceLine(("frame %d  mouse %s  %s"):format(frameCount, mousePosition(), mouse))
        end
        for _, name in ipairs(TRACED) do
            local tooltip = _G[name]
            local panel = tooltip and panels[tooltip]
            if tooltip and not hookedForTrace[tooltip] and util.canModify(tooltip) then
                hookForTrace(tooltip, name)
            end
            if panel and not hookedForTrace[panel] then hookForTrace(panel, name .. ".panel", true) end
            pcall(check, name, tooltip, panel, inCombat)
            for _, entry in ipairs({ { name, tooltip, true }, { name .. ".panel", panel, false } }) do
                local ok, state = pcall(stateOf, entry[2], entry[3])
                state = ok and state or ("unreadable: " .. tostring(state))
                if not entry[3] and entry[2] then state = state .. "  [" .. pendingOf(entry[2]) .. "]" end
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
            omittedEvents > 0 and " (event log capped at " .. MAX_EVENTS .. " calls)" or ""),
            ("  the game's tooltip visible under a panel: %d frames, %d of them in combat"):format(visible,
                visibleInCombat),
            ("  a panel shown without its tooltip: %d frames"):format(orphaned),
            ("  redundant zero-alpha calls omitted: %d"):format(suppressed),
            ("  calls omitted after the event limit: %d; frame samples and lifecycle events cover the full duration")
                :format(omittedEvents) }
        for _, line in ipairs(traceLines) do lines[#lines + 1] = line end
        ns.showReport("trace", lines)
    end)
end
