-- Macros as a panel: the name, then the macro's lines, in the color of the
-- spell it casts. One with #showtooltip is the spell's panel instead, with the
-- macro named in its subtitle.
local _, ns = ...
local ui = ns.ui
local MACRO = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Macro
if not (ui and MACRO and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local EXTRAS_RULE = { .50, .50, .54 }
local COMMAND = util.hex(colors.quest)
local MUTED = util.hex(colors.caption)
local PARTS = { "macroName", "macroBadges", "macroText", "extras" }
-- The commands that name what a macro casts, each by every name the client
-- takes for it: "/cast", "/spell", and in German also "/wirken".
local CASTS = { ["#showtooltip"] = true, ["/cast"] = true, ["/use"] = true }
for _, command in pairs({ SLASH_CAST1, SLASH_CAST2, SLASH_CAST3, SLASH_CAST4, SLASH_USE1, SLASH_USE2 }) do
    CASTS[command:lower()] = true
end
local SPELL = Enum.TooltipDataType.Spell

local function macroKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local shown = tooltipData.nested(data)
    if shown then return shown.type .. ":" .. shown.id end
    local line = data.lines[1]
    if isSecret(line) or type(line) ~= "table" then return end
    return safeText(line.leftText)
end

-- The spell a macro shows or casts: its first option, without conditions or rank.
local function spellOf(body)
    for _, line in ipairs(body) do
        local command, rest = line:match("^([/#]%S+)%s+(.+)$")
        if command and CASTS[command:lower()] then
            local spell = trim((rest:gsub("%b[]", ""):match("^%s*([^;]*)") or ""):gsub("%(.-%)", ""))
            if spell ~= "" then return spell end
        end
    end
end

local function completeModel(model)
    model.extras = model.extras or {}
    model.body = model.body or {}
    model.spell = model.spell or spellOf(model.body)
    return model
end

local function readMacro(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    -- With #showtooltip, the game fills the tooltip with the spell or item it
    -- shows; the macro is named in that panel's subtitle.
    local nested = tooltipData.nested(data)
    if nested then
        local tooltipType = ns.TooltipTypes[nested.type]
        local shown = tooltipType and tooltipType.read(tooltip, nested, game)
        if not shown then return end
        local name = game.macroShowing(nested.type, nested.id)
        local label = name and util.fill(ns.L["Macro: %s"], name) or ns.L["Macro"]
        if nested.type == SPELL then
            shown.tags = { { label } }
        else
            shown.slot = (shown.slot and shown.slot ~= "" and (shown.slot .. " \194\183 ") or "") .. label
        end
        return { shows = shown, showsType = nested.type }
    end
    local model = { extras = {}, lineIndices = {}, body = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            if not model.name then
                model.name = trim(left)
            elseif trim(left) ~= "" or right ~= "" then
                tooltipData.add(model.extras, left, right)
                local row = model.extras[#model.extras]
                row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
            end
        end
    end
    if not model.name or model.name == "" then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    tooltipData.addExtras(model.extras, appended)
    -- The tooltip has only the name; the macro itself has its icon and lines.
    local macro = game.macro(model.name)
    if macro then
        model.icon = macro.icon
        for line in (macro.body .. "\n"):gmatch("(.-)\n") do
            line = trim(line)
            if line ~= "" then model.body[#model.body + 1] = line end
        end
    end
    return completeModel(model)
end

-- Commands in gold; directives such as #showtooltip and [conditions] muted.
local function styleLine(line)
    line = line:gsub("|", "||")
    local command, rest = line:match("^([/#]%S+)(.*)$")
    if not command then return line end
    rest = rest:gsub("%b[]", function(condition) return "|cff" .. MUTED .. condition .. "|r" end)
    return "|cff" .. (command:sub(1, 1) == "#" and MUTED or COMMAND) .. command .. "|r" .. rest
end

local function macroView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local school = ns.spellSchool and ns.spellSchool(model.spell)
    local accent = ns.Palette.school(school)
    local color = accent or colors.neutral
    local sections = {}
    if #model.body > 0 then
        local rows = {}
        for index, line in ipairs(model.body) do rows[index] = { left = styleLine(line), right = "" } end
        sections[1] = { separator = { divider = ui.GOLD_RULE }, kind = "rows", rows = rows,
            style = styles.macroText, color = colors.detail, gap = 2, wrap = true }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "macro",
        color = color,
        tint = accent,
        strength = TINT_STRENGTH,
        icon = ns.option("iconMacros") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = {
            { text = model.name, style = styles.macroName, color = colors.title, gap = 4 },
            { badges = { { ns.L["Macro"], colors.caption } }, style = styles.macroBadges, before = 1, gap = 4 },
        },
        sections = sections,
    }
end

local function renderMacro(panel, tooltip, model)
    if model.shows then
        ns.TooltipTypes[model.showsType].render(panel, tooltip, model.shows)
    else
        ui.renderView(panel, tooltip, macroView(model))
    end
end

ui.macroModel = completeModel
ui.defineTooltipType(MACRO, { read = readMacro, render = renderMacro, key = macroKey, option = "macroPanels" })
