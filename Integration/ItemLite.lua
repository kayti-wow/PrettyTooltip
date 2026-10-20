-- Native item wording for lite mode and full panels, with modifier-key restoration.
-- The game's tooltip data is left as it is: changing it would make the rest of
-- the game's tooltip code run as this addon (taint). The wording goes onto the
-- tooltip's font strings once the game has drawn them, and the item reader
-- asks for it with ns.ItemLite.wording.
local _, ns = ...
local isSecret = ns.util.isSecret
local util = ns.util
local stats = ns.Stats
local LINE = Enum and Enum.TooltipDataLineType or {}
ns.ItemLite = {}
local registered = false

local activeLinesByTooltip = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })
-- Wording already worked out, by the game's line table.
local known = setmetatable({}, { __mode = "k" })

-- The original, panel, and lite wording of a line's text; nil when the
-- rewrite leaves it as it is.
local function rewrite(text, proc, colors, markers)
    local replacements = stats.rewrite(text)
    local displayLines = replacements or { text }
    -- Lite shortens wording and keeps the game's colors, but for magic: spell
    -- power rows and what a proc deals, in their colors.
    local liteLines = {}
    local styled = false
    for displayIndex, displayText in ipairs(displayLines) do
        local display, colored = stats.styleStat(displayText, colors, markers)
        local onHit = proc or util.startsWith(displayText, ITEM_SPELL_TRIGGER_ONPROC)
        if onHit then
            local effect = stats.styleEffect(displayText, colors)
            if effect ~= displayText then display, colored = effect, effect end
        end
        local magical = onHit or stats.isMagical(displayText)
        liteLines[displayIndex] = colored and magical and colors and colored or displayText
        if colored then
            displayLines[displayIndex] = display
            styled = true
        end
    end
    if not (replacements or styled) then return end
    -- A line break gives combined bonuses two visual lines.
    return { original = text, display = table.concat(displayLines, "|n"), lite = table.concat(liteLines, "|n") }
end

-- A line of the game's item tooltip data, rewritten: { original, display,
-- lite }, or nil when it stays as the game words it.
function ns.ItemLite.wording(line)
    if not registered or isSecret(line) or type(line) ~= "table" then return end
    local text, rightText = line.leftText, line.rightText
    if isSecret(text) or type(text) ~= "string" or isSecret(rightText) or rightText then return end
    -- The game marks proc lines; the text is the fallback for clients that do not.
    local proc = LINE.ItemSpellTriggerOnProc ~= nil and not isSecret(line.type)
        and line.type == LINE.ItemSpellTriggerOnProc
    local colors, markers = ns.option("statColors"), ns.option("statMarkers")
    local kept = known[line]
    if not (kept and kept.text == text and kept.proc == proc and kept.colors == colors and kept.markers == markers) then
        kept = { text = text, proc = proc, colors = colors, markers = markers,
            wording = rewrite(text, proc, colors, markers) or false }
        known[line] = kept
    end
    return kept.wording or nil
end

-- The font strings get the wording that suits: the original while the
-- original-tooltip key is held, lite mode's shortened wording in native colors
-- but for magic, else the panel's.
local function wordingShown()
    if ns.originalKeyDown() or not ns.option("itemPanels") then return "original" end
    return ns.option("itemLite") and "lite" or "display"
end

-- Showing a shown tooltip again lays it out for its new text; a hidden one is
-- laid out when the game shows it.
local function showWording(tooltip, wording)
    if not util.canModify(tooltip) then return end
    local rows = activeLinesByTooltip[tooltip]
    if not rows then return end
    local changed = false
    for _, row in ipairs(rows) do
        if not util.canModify(row.fontString) then return end
        local text, current = row[wording] or row.original, row.fontString:GetText()
        if isSecret(current) or current ~= text then
            if not pcall(row.fontString.SetText, row.fontString, text) then return end
            changed = true
        end
    end
    if changed and util.call(tooltip.IsShown, tooltip) then tooltip:Show() end
end

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
        local wording = line.lineIndex and ns.ItemLite.wording(line)
        local fontString = wording and tooltip:GetLeftLine(line.lineIndex)
        if fontString then
            rows[#rows + 1] = {
                fontString = fontString,
                original = wording.original,
                display = wording.display,
                lite = wording.lite,
            }
        end
    end
    activeLinesByTooltip[tooltip] = #rows > 0 and rows or nil
    showWording(tooltip, wordingShown())
end

-- Called once by the entry file, before the panel's item hooks.
function ns.ItemLite.register()
    if registered then return end
    if not ns.Locale.supported or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then return end
    registered = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemShown)

    local modifierWatcher = CreateFrame("Frame")
    modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierWatcher:SetScript("OnEvent", function(_, _, key)
        if not ns.isOriginalKey(key) then return end
        local wording = wordingShown()
        for tooltip in pairs(activeLinesByTooltip) do
            if util.canModify(tooltip) and tooltip:IsShown()
                and util.call(tooltip.IsTooltipType, tooltip, Enum.TooltipDataType.Item) then
                showWording(tooltip, wording)
            end
        end
    end)
end
