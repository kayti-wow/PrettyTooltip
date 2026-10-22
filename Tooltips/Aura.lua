-- Buffs and debuffs as a panel.
local _, ns = ...
local ui = ns.ui
local AURA = Enum and Enum.TooltipDataType and Enum.TooltipDataType.UnitAura
if not (ui and AURA and ui.renderView) then
    return
end

local util = ns.util
local L = ns.L
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim, readable = util.isSecret, util.safeText, util.trim, util.readable
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local BAR_HEIGHT = 4
local TIME_COLOR = { .88, .78, .60 }
local BUFF_COLOR = { .45, .75, .95 }
local DEBUFF_COLOR = { .90, .30, .25 }
local MUTED = colors.caption
local EXTRAS_RULE = { .50, .50, .54 }
-- The game's dispel colors.
local DISPELS = {
    Magic = { .20, .60, 1 },
    Curse = { .60, 0, 1 },
    Disease = { .60, .40, 0 },
    Poison = { 0, .60, 0 },
}
local PARTS = { "auraName", "auraBadges", "auraText", "auraTime", "extras" }
-- Each dispel type by the client's name for it, which the name line prints
-- on its right: "Gift" on deDE is Poison.
local DISPEL_KEYS = {}
local keptAuras = setmetatable({}, { __mode = "k" })
local auraHooks = setmetatable({}, { __mode = "k" })
ns.keptAuras = keptAuras
for key in pairs(DISPELS) do DISPEL_KEYS[ns.Locale.dispels[key] or key] = key end
-- The line saying how long the aura lasts: "5 seconds remaining".
local REMAINING = { SPELL_TIME_REMAINING_SEC, SPELL_TIME_REMAINING_MIN, SPELL_TIME_REMAINING_HOURS,
    SPELL_TIME_REMAINING_DAYS }
local function isRemaining(text)
    for _, format in pairs(REMAINING) do
        if util.unformat(text, format) then return true end
    end
    return false
end

-- The tooltip's lines lack the duration and stacks; the aura it shows has them.
-- The getter is known only while the game fills the tooltip, so the aura is
-- kept for the redraws after.
local function auraOf(tooltip, spellID, game)
    local info = util.call(tooltip.GetProcessingTooltipInfo, tooltip)
    if not info or isSecret(info) then
        local kept = keptAuras[tooltip]
        return kept and kept.spellID == spellID and kept.aura or nil
    end
    local getter, args = readable(info.getterName), readable(info.getterArgs)
    if type(getter) ~= "string" or type(args) ~= "table" then return end
    local unit, which, filter = readable(args[1]), readable(args[2]), readable(args[3])
    if type(unit) ~= "string" or which == nil then return end
    if getter:find("Buff") then filter = "HELPFUL" elseif getter:find("Debuff") then filter = "HARMFUL" end
    local aura = game.aura(unit, which, filter, getter:find("AuraInstanceID") ~= nil)
    if not aura then return end
    if not auraHooks[tooltip] then
        local function forget() keptAuras[tooltip] = nil end
        tooltip:HookScript("OnHide", forget)
        tooltip:HookScript("OnTooltipCleared", forget)
        auraHooks[tooltip] = true
    end
    keptAuras[tooltip] = { spellID = spellID, aura = aura }
    return aura
end

local function auraKey(_, data)
    if isSecret(data.id) or isSecret(data.dataInstanceID) then return end
    return data.id
end

local function completeModel(model, aura, game)
    if aura then
        model.harmful = readable(aura.isHarmful)
        if model.harmful == nil and readable(aura.isHelpful) ~= nil then model.harmful = not aura.isHelpful end
        model.stacks = util.number(aura.applications)
        model.duration = util.number(aura.duration)
        model.expires = util.number(aura.expirationTime)
        local source = readable(aura.sourceUnit)
        if type(source) == "string" then
            local name = game.unitName(source)
            if type(name) == "string" then model.caster = name end
        end
        model.dispel = model.dispel or readable(aura.dispelName)
    end
    local dispel = model.dispel and DISPELS[model.dispel]
    model.color = dispel or (model.harmful and DEBUFF_COLOR) or (model.harmful == false and BUFF_COLOR) or nil
    return model
end

local function readAura(tooltip, data, game)
    if not util.canModify(tooltip) then return end
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local spellID = readable(data.id)
    local model = { description = {}, extras = {}, lineIndices = {}, icon = game.spellIcon(spellID) }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            local text = trim(left)
            if not model.name then
                model.name = text
                model.dispel = DISPEL_KEYS[trim(right)]
            elseif text ~= "" or right ~= "" then
                if isRemaining(text) then
                    model.remaining = text
                elseif text ~= "" and not model.text then
                    model.text = text
                else
                    tooltipData.add(model.extras, left, right)
                    local row = model.extras[#model.extras]
                    row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
                end
            end
        end
    end
    if not model.name or model.name == "" then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    tooltipData.addExtras(model.extras, appended)
    return completeModel(model, auraOf(tooltip, spellID, game), game)
end

local function badges(model)
    local list = {}
    if model.harmful ~= nil then
        list[#list + 1] = model.harmful and { L["Debuff"], DEBUFF_COLOR } or { L["Buff"], BUFF_COLOR }
    end
    if model.dispel and DISPELS[model.dispel] then
        list[#list + 1] = { ns.Locale.dispels[model.dispel] or model.dispel, DISPELS[model.dispel] }
    end
    if type(model.stacks) == "number" and model.stacks > 1 then
        list[#list + 1] = { util.fill(L["%s stacks"], model.stacks), MUTED }
    end
    return list
end

local function sentencesOf(model)
    local list = {}
    if model.text then
        for _, sentence in ipairs(util.splitSentences(model.text)) do list[#list + 1] = sentence end
    end
    return list
end

local function timeRow(model)
    local left = model.remaining
    if not left and type(model.duration) == "number" and model.duration == 0 then left = L["No time limit"] end
    if not left and not model.caster then return end
    return { left = left or "", right = model.caster and util.fill(L["by %s"], model.caster) or "" }
end

local function hasBar(model)
    return type(model.duration) == "number" and model.duration > 0 and type(model.expires) == "number"
end

-- The time left as a bar that drains, kept live.
local function drawBarFill(bar)
    local left = math.max(0, bar.expires - GetTime())
    local ratio = math.max(0, math.min(1, left / bar.duration))
    bar.fill:SetWidth(math.max(1, bar.width * ratio))
    bar.fill:SetShown(ratio > 0)
end

local function timeBar(model, color)
    return function(panel, y)
        local bar = { width = panel.width - 2 * ui.pad(), duration = model.duration, expires = model.expires }
        bar.fill = ui.drawTrack(panel, y, BAR_HEIGHT)
        bar.fill:SetVertexColor(color[1], color[2], color[3], 1)
        drawBarFill(bar)
        ui.setLive(panel, function() drawBarFill(bar) end)
        -- The bar ends its section: a rule after it counts in the space below it.
        panel.rowTail = 8
        return y + BAR_HEIGHT + 8
    end
end

-- The time left and its bar, added to sections: from model.remaining, the
-- time left as text, and model.duration and model.expires, for the bar.
local function timeSections(sections, model, color)
    local time = timeRow(model)
    if not (time or hasBar(model)) then return end
    local separator = #sections > 0 and { rule = { color[1] * .7, color[2] * .7, color[3] * .7 } }
        or { divider = ui.GOLD_RULE }
    if time then
        time.rightColor = MUTED
        sections[#sections + 1] = { separator = separator, kind = "rows", rows = { time },
            style = ui.styleOf("auraTime"), color = TIME_COLOR, gap = 3 }
        separator = nil
    end
    if hasBar(model) then
        sections[#sections + 1] = { separator = separator, kind = "custom", draw = timeBar(model, color) }
    end
end

-- What the panel shows, for Panel/Render.lua to draw.
local function auraView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local color = model.color or colors.neutral
    local sections = {}
    local sentences = sentencesOf(model)
    if #sentences > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "prose", sentences = sentences,
            style = styles.auraText, color = colors.description, numbers = ns.Palette.numberCode(color), gap = 5 }
    end
    timeSections(sections, model, color)
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "aura",
        color = color,
        tint = model.color,
        strength = TINT_STRENGTH,
        icon = ns.option("iconAuras") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = {
            { text = model.name, style = styles.auraName, color = colors.title, gap = 4 },
            { badges = badges(model), style = styles.auraBadges, before = 1, gap = 4 },
        },
        sections = sections,
    }
end

local function renderAura(panel, tooltip, model)
    ui.renderView(panel, tooltip, auraView(model))
end

ui.timeSections = timeSections
ui.auraModel = function(fields)
    fields.extras = fields.extras or {}
    return completeModel(fields, nil, ns.Game)
end
ui.defineTooltipType(AURA, { read = readAura, render = renderAura, key = auraKey, option = "auraPanels" })
