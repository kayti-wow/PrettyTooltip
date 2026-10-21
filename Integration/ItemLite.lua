-- Native item wording, only when the item is not presented by a Pretty
-- panel. Apply to font strings after the fill; keep Blizzard's data intact.
local _, ns = ...
local isSecret = ns.util.isSecret
local util = ns.util
local itemWording = ns.TooltipData.itemWording
ns.ItemLite = {}
local registered = false

local activeLinesByTooltip = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })

local function wordingShown()
    if ns.originalKeyDown() then return "original" end
    return ns.option("liteWording") and "lite" or "original"
end

local function showWording(tooltip, wording, relayout)
    if not util.canModify(tooltip) then return end
    local rows = activeLinesByTooltip[tooltip]
    if not rows then return end
    for _, row in ipairs(rows) do
        if not util.canModify(row.fontString) then return end
        local ok = pcall(row.fontString.SetText, row.fontString, row[wording] or row.original)
        if not ok then return end
        -- Combined bonuses take a line each.
        if row.lines > 1 and row.fontString.SetWordWrap then pcall(row.fontString.SetWordWrap, row.fontString, true) end
    end
    if relayout then tooltip:Show() end
end

-- Runs before the game's own Show at the end of the fill, which lays the
-- reworded lines out.
local function onItemShown(tooltip, data)
    if not util.canModify(tooltip) then return end
    if isSecret(data) or type(data) ~= "table" then return end
    local lines = data.lines
    if isSecret(lines) or type(lines) ~= "table" then return end

    if not hookedTooltips[tooltip] then
        local function forget(cleared) activeLinesByTooltip[cleared] = nil end
        tooltip:HookScript("OnHide", forget)
        tooltip:HookScript("OnTooltipCleared", forget)
        hookedTooltips[tooltip] = true
    end

    local info = util.call(tooltip.GetProcessingTooltipInfo, tooltip)
    local append = type(info) == "table" and util.readable(info.append)
    local rows = (append and activeLinesByTooltip[tooltip]) or {}
    for _, line in ipairs(lines) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.lineIndex) then return end
        if line.lineIndex ~= nil and type(line.lineIndex) ~= "number" then return end
        local wording = line.lineIndex and itemWording(line)
        local fontString = wording and tooltip:GetLeftLine(line.lineIndex)
        if fontString then
            rows[#rows + 1] = { fontString = fontString, original = line.leftText,
                lite = wording.lite, lines = wording.lines }
        end
    end
    activeLinesByTooltip[tooltip] = #rows > 0 and rows or nil
    showWording(tooltip, wordingShown(), false)
end

-- Called once by the entry file.
function ns.ItemLite.register()
    if registered then return end
    if not ns.Locale.supported or not (ns.Processor.available()
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then return end
    registered = true
    ns.Processor.onData("wording", Enum.TooltipDataType.Item, function(tooltip, data)
        -- Choose before any line traversal. The Pretty reader transforms
        -- original data itself, and cached panels need no wording pass.
        if ns.restyles("itemPanels") then
            if not isSecret(tooltip) and (type(tooltip) == "table" or type(tooltip) == "userdata") then
                activeLinesByTooltip[tooltip] = nil
            end
            return
        end
        onItemShown(tooltip, data)
    end)
    ns.Processor.onKey("wording", function(key)
        if ns.restyles("itemPanels") or not ns.isOriginalKey(key) then return end
        local wording = wordingShown()
        for tooltip in pairs(activeLinesByTooltip) do
            if util.canModify(tooltip) and tooltip:IsShown()
                and util.call(tooltip.IsTooltipType, tooltip, Enum.TooltipDataType.Item) then
                showWording(tooltip, wording, true)
            end
        end
    end)
end
