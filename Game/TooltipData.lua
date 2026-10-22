-- What every tooltip type's reader shares in reading the game's tooltips: rows,
-- their colors, requirements, and the rows other addons append to a tooltip.
local _, ns = ...
local util = ns.util
local isSecret, safeText = util.isSecret, util.safeText
local EXTRA_COLOR = ns.Palette.roles.extras
local tooltipData = {}
ns.TooltipData = tooltipData

local function add(list, left, right)
    list[#list + 1] = { left = left, right = right }
end

local function quietColor(r, g, b)
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or (r > .9 and g > .9 and b > .9) then
        return EXTRA_COLOR
    end
    return { r * .85, g * .85, b * .85 }
end

local function colorOf(color)
    if isSecret(color) or type(color) ~= "table" then return EXTRA_COLOR end
    return quietColor(color.r, color.g, color.b)
end

-- The game colors whatever the character cannot use red. Nil when unreadable.
local function isRed(color)
    if isSecret(color) or type(color) ~= "table" then return nil end
    local r, g = color.r, color.g
    if isSecret(r) or isSecret(g) or type(r) ~= "number" or type(g) ~= "number" then
        return nil
    end
    return r > .9 and g < .3
end

local function requirementMet(text, color, game)
    local level = tonumber((util.unformat(text, ITEM_MIN_LEVEL)))
    if level then
        local playerLevel = game.playerLevel()
        if playerLevel then return playerLevel >= tonumber(level) end
    end
    return isRed(color) == false
end

local function appendedRows(tooltip, lineIndices)
    local rows = {}
    local name = tooltip:GetName()
    for index = 1, tooltip:NumLines() do
        if not lineIndices[index] then
            local leftFont = tooltip:GetLeftLine(index)
            local rightFont = tooltip.GetRightLine and tooltip:GetRightLine(index)
                or (name and _G[name .. "TextRight" .. index])
            if (leftFont and not util.canModify(leftFont)) or (rightFont and not util.canModify(rightFont)) then return end
            local left, right = "", ""
            if leftFont then left = safeText(leftFont:GetText()) end
            if rightFont then right = safeText(rightFont:GetText()) end
            if not left or not right then return end
            rows[#rows + 1] = {
                left = left,
                right = right,
                color = leftFont and quietColor(leftFont:GetTextColor()) or EXTRA_COLOR,
                textColor = leftFont and { leftFont:GetTextColor() },
                rightColor = rightFont and quietColor(rightFont:GetTextColor()),
            }
        end
    end
    return rows
end

-- An empty line, as other addons add between their sections.
local function isBlank(row)
    return util.trim(util.plainText(row.left or "")) == "" and util.trim(util.plainText(row.right or "")) == ""
end

-- Adds other addons' rows to extras, one at a time: adder(row). A blank row
-- separates an addon's sections, so it is kept as a gap, but only between two
-- rows, and never two together.
local function extrasAdder(extras)
    local gap = false
    return function(row)
        if isBlank(row) then
            gap = #extras > 0
            return
        end
        if gap and not extras[#extras].blank then extras[#extras + 1] = { left = "", right = "", blank = true } end
        gap = false
        extras[#extras + 1] = row
    end
end

local function addExtras(extras, rows)
    local adder = extrasAdder(extras)
    for _, row in ipairs(rows) do adder(row) end
end

-- The spell or item a tooltip shows in full, as a #showtooltip macro's or a
-- pet ability's: a nested block naming it, then its own lines. Data for that
-- type's reader, or nil.
local function nested(data)
    local block = Enum.TooltipDataLineType and Enum.TooltipDataLineType.NestedBlock
    if not block then return end
    local types = Enum.TooltipDataType
    for index, line in ipairs(data.lines) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.type) then return end
        if line.type == block then
            local id, kind = line.tooltipID, line.tooltipType
            if isSecret(id) or isSecret(kind) or type(id) ~= "number"
                or (kind ~= types.Spell and kind ~= types.Item) then
                return
            end
            local lines = {}
            for after = index + 1, #data.lines do lines[#lines + 1] = data.lines[after] end
            return { type = kind, id = id, lines = lines }
        end
    end
end

tooltipData.add = add

-- The line's own color when the game marks it as one the character will not
-- get, as { r, g, b }; nil otherwise. Forever marks none; a client that does
-- replaces this (retail's Retail/Game/TooltipDataExtension.lua).
function tooltipData.inactiveColor(_color) end
-- An item line's shortened wordings (Data/Stats.lua's itemWording), from the
-- game's own data, which stays as it is. Nil for a line that reads the same,
-- has a right side, or is hidden.
-- Repeated comparison handovers need fresh font bindings, but their wording
-- depends only on readable text, proc status and the current style settings.
-- Keep negative results too; ordinary lines otherwise repeat every stat rule.
-- Returned wording tables are shared; callers must treat them as read-only.
local wordings, wordingCount, wordingVersion, wordingColors, wordingMarkers = {}, 0
local WORDING_LIMIT = 512
local function itemWording(line)
    if isSecret(line) or type(line) ~= "table" then return end
    local text, right = line.leftText, line.rightText
    if isSecret(text) or type(text) ~= "string" or isSecret(right) or right or isSecret(line.type) then return end
    -- The game marks proc lines; the text is the fallback for clients that do not.
    local procType = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemSpellTriggerOnProc
    local proc = procType ~= nil and line.type == procType
    local version, colors, markers = ns.settingsVersion or 0, ns.option("statColors"), ns.option("statMarkers")
    if version ~= wordingVersion or colors ~= wordingColors or markers ~= wordingMarkers then
        wordings, wordingCount = {}, 0
        wordingVersion, wordingColors, wordingMarkers = version, colors, markers
    end
    -- A line the game marks inactive (greyed or reddened, on retail) keeps the
    -- game's color, without stat colors in it.
    local inactive = tooltipData.inactiveColor(line.leftColor) ~= nil
    local key = ((proc and 1 or 0) + (inactive and 2 or 0)) .. text
    local cached = wordings[key]
    if cached ~= nil then return cached or nil end
    local wording = ns.Stats.itemWording(text, proc, colors and not inactive, markers)
    if wordingCount >= WORDING_LIMIT then wordings, wordingCount = {}, 0 end
    wordings[key], wordingCount = wording or false, wordingCount + 1
    return wording
end

tooltipData.colorOf = colorOf
tooltipData.itemWording = itemWording
tooltipData.isRed = isRed
tooltipData.requirementMet = requirementMet
tooltipData.appendedRows = appendedRows
tooltipData.nested = nested
tooltipData.isBlank = isBlank
tooltipData.extrasAdder = extrasAdder
tooltipData.addExtras = addExtras
