-- Slash-command parsing and dispatch, registered by the entry file.
local _, ns = ...
local util = ns.util

-- Prints the shown tooltip's raw data, to see what a type of tooltip carries.
local function dumpTooltip()
    -- A clicked chat link opens in its own tooltip.
    local tooltip = util.canModify(GameTooltip) and GameTooltip:IsShown() and GameTooltip or ItemRefTooltip
    if not (util.canModify(tooltip) and tooltip:IsShown()) then
        print(ns.L["PrettyTooltip: hover something first; there is no tooltip to dump."])
        return
    end
    -- Who filled it, to tell which frame or addon a lines-only tooltip is from.
    local owner = util.call(tooltip.GetOwner, tooltip)
    local ownerName = util.canModify(owner) and util.call(owner.GetDebugName, owner)
    local lines = { "Owned by " .. (util.safeText(ownerName) or "<restricted>") }
    local data = util.call(tooltip.GetTooltipData, tooltip)
    if type(data) ~= "table" then
        -- Filled by an addon with lines alone, as Questie's quest links.
        lines[#lines + 1] = "No tooltip data; the lines shown:"
        for index = 1, tooltip:NumLines() do
            local left = tooltip:GetLeftLine(index)
            local name = util.call(tooltip.GetName, tooltip)
            local right = tooltip.GetRightLine and tooltip:GetRightLine(index)
                or (name and _G[name .. "TextRight" .. index])
            local leftText, rightText = "", ""
            if left then leftText = util.safeText(left:GetText()) or "<restricted>" end
            if right then rightText = util.safeText(right:GetText()) or "<restricted>" end
            local text = leftText .. (rightText ~= "" and "  |  " .. rightText or "")
            lines[#lines + 1] = index .. ". " .. text
        end
        ns.showReport("dump", lines)
        return
    end
    local function names(enum)
        local found = {}
        for name, value in pairs(enum or {}) do found[value] = name end
        return found
    end
    local types, lineTypes = names(Enum.TooltipDataType), names(Enum.TooltipDataLineType)
    local function show(value)
        if util.isSecret(value) then return "<restricted>" end
        if type(value) == "table" and value.GenerateHexColor then
            local hex = util.call(value.GenerateHexColor, value)
            return type(hex) == "string" and ("#" .. hex) or "<restricted>"
        end
        if type(value) == "table" then return "{...}" end
        return tostring(value)
    end
    local fields = {}
    for key, value in pairs(data) do
        if not util.isSecret(key) and type(key) == "string" and key ~= "lines" then
            fields[#fields + 1] = key .. "=" .. show(value)
        end
    end
    local dataType = util.readable(data.type)
    lines[#lines + 1] = show(types[dataType] or dataType) .. "  " .. table.concat(fields, "  ")
    local dataLines = util.readable(data.lines)
    if type(dataLines) ~= "table" then dataLines = {} end
    for index, line in ipairs(dataLines) do
        local parts = {}
        if not util.isSecret(line) and type(line) == "table" then
            for key, value in pairs(line) do
                if not util.isSecret(key) and type(key) == "string" and key ~= "type" then
                    parts[#parts + 1] = key .. "=" .. show(value)
                end
            end
            local lineType = util.readable(line.type)
            table.sort(parts)
            lines[#lines + 1] = index .. ". " .. show(lineTypes[lineType] or lineType) .. "  " .. table.concat(parts, "  ")
        else
            lines[#lines + 1] = index .. ". <restricted>"
        end
    end
    ns.showReport("dump", lines)
end

local function handleCommand(message)
    local wanted = (message or ""):match("^%s*(.-)%s*$"):lower()
    if wanted == "placement" or wanted:match("^placement%s") then
        print("PrettyTooltip: Pretty panels use frame anchors. Select Blizzard layout in the options to use Blizzard tooltips.")
        return
    end
    local perfSeconds = wanted:match("^perf%s*(%d*)$")
    if perfSeconds then
        if ns.perfCapture then ns.perfCapture(math.min(30, math.max(1, tonumber(perfSeconds) or 5))) end
        return
    end
    -- /ptip trace [seconds]: what the tooltips do while the player hovers.
    local traceSeconds = wanted:match("^trace%s*(%d*)$")
    if traceSeconds then
        if ns.traceTooltips then ns.traceTooltips(math.min(10, math.max(1, tonumber(traceSeconds) or 4))) end
        return
    end
    if wanted == "anchors" then
        if ns.dumpAnchors then pcall(ns.dumpAnchors) end
        return
    end
    if wanted == "pixel" then
        if ns.dumpPixel then pcall(ns.dumpPixel) end
        return
    end
    -- /ptip capture <name>, list, or clear: tooltips saved as test fixtures.
    local command, argument = wanted:match("^(%S+)%s*(.-)$")
    if command == "capture" and ns.capture then
        if argument == "list" then
            ns.listCaptures()
        elseif argument == "clear" then
            ns.clearCaptures()
        else
            ns.capture(argument)
        end
        return
    end
    if wanted == "dump" then
        -- Secret values cannot be printed in some situations.
        local ok, problem = pcall(dumpTooltip)
        if not ok then print(ns.util.fill(ns.L["PrettyTooltip: this tooltip cannot be read right now (%s)."],
            util.safeText(problem) or "<restricted>")) end
        return
    end
    if wanted ~= "options" and ns.openEditor then
        ns.openEditor()
    else
        ns.openSettings()
    end
end

ns.Commands = {}
local commandsRegistered = false
function ns.Commands.register()
    if commandsRegistered then return end
    commandsRegistered = true
    SLASH_PRETTYTOOLTIP1 = "/prettytooltip"
    SLASH_PRETTYTOOLTIP2 = "/ptip"
    SlashCmdList.PRETTYTOOLTIP = handleCommand
end
