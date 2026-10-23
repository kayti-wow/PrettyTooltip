-- Spell tooltips as a panel: a strip for cost, cast time, cooldown, and range,
-- then the description one sentence per line, tinted by school or resource.
local _, ns = ...
local ui = ns.ui
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if not (ui and SPELL and ui.renderView) then
    return
end

-- A client file loaded after this one can set descriptor.extension: readStat,
-- isCooldown, leadRows, isDetail. Retail's is Retail/Tooltips/SpellExtension.lua.
local descriptor = {}

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local unformat, startsWith = util.unformat, util.startsWith
local formats = ns.Locale.formats
local L = ns.L
local add = tooltipData.add
local LINE = Enum.TooltipDataLineType or {}
local styledAt, measureStyled = ui.styledAt, ui.measureStyled
local pad = ui.pad
-- The style parts a spell draws with; a client adds its own (descriptor.parts).
local PARTS = { "spellTitle", "spellBadges", "spellValues", "spellCaptions", "spellDetails",
    "spellText", "extras" }
descriptor.parts = PARTS
local TITLE_COLOR = colors.title
local DETAIL_COLOR = colors.detail
local CAPTION_OFFSET = 17
local RANK_BADGE = { .60, .56, .50 }
local REMAINING_COLOR = { 1, .60, .25 }
local UNMET_COLOR = colors.unmet
local STRIP_HEIGHT = 34
-- Spells have one title line, so a smaller icon keeps the header short.
local ICON_SIZE = 38
-- Spells are tinted a little less than items; the school is only a hint.
local SPELL_TINT = .7
local EXTRAS_RULE = { .50, .50, .54 }
-- Each power by the key the panel colors it by, its name, and the lines that
-- cost it: "73 Mana".
local POWERS = {
    { key = "Mana", name = MANA, costs = { MANA_COST, MANA_COST_LARGE }, color = { .25, .55, 1 } },
    { key = "Rage", name = RAGE, costs = { RAGE_COST }, color = { .90, .22, .20 } },
    { key = "Energy", name = ENERGY, costs = { ENERGY_COST }, color = { 1, .86, .25 } },
    { key = "Focus", name = FOCUS, costs = { FOCUS_COST }, color = { 1, .55, .25 } },
    { key = "Runic Power", name = RUNIC_POWER, costs = { RUNIC_POWER_COST }, color = { 0, .82, 1 } },
}
-- A client's own resources, after these, as retail's Holy Power and Fury
-- (Retail/Tooltips/Spell.lua); one the client has no name for is left out.
for _, extra in ipairs(ns.contributions("spellPowers")) do
    for _, power in ipairs(extra) do
        if type(power.name) == "string" then POWERS[#POWERS + 1] = power end
    end
end
local POWER_COLORS = {}
for _, power in ipairs(POWERS) do POWER_COLORS[power.key] = power.color end

-- The strip's times, by the line that states one and the duration the strip
-- shows it as: "2.5 sec cast" as "2.5 sec", "Wirken in 1,5 Sek." as "1,5 Sek.".
local TIMES = {
    { "cast", L["Cast"], SPELL_CAST_TIME_SEC, SPELL_DURATION_SEC },
    { "cast", L["Cast"], SPELL_CAST_TIME_MIN, SPELL_DURATION_MIN },
    { "cooldown", L["Cooldown"], SPELL_RECAST_TIME_SEC, SPELL_DURATION_SEC },
    { "cooldown", L["Cooldown"], SPELL_RECAST_TIME_MIN, SPELL_DURATION_MIN },
    { "cooldown", L["Cooldown"], SPELL_RECAST_TIME_HOURS, SPELL_DURATION_HOURS },
    { "cooldown", L["Cooldown"], SPELL_RECAST_TIME_DAYS, SPELL_DURATION_DAYS },
}
-- A client adds its own times when it loads, as retail's charges' recharge.
descriptor.times = TIMES
-- Casts the strip shows as the game words them.
local CASTS = { SPELL_CAST_TIME_INSTANT, SPELL_CAST_TIME_INSTANT_NO_MANA, SPELL_CAST_CHANNELED, SPELL_ON_NEXT_SWING }

-- A spell's requirements: "Requires Shields", "Requires Cat Form". English
-- words them all alike; other languages do not.
local REQUIREMENTS = { ITEM_REQ_SKILL, ITEM_MIN_LEVEL, ITEM_MIN_SKILL, SPELL_EQUIPPED_ITEM, SPELL_REQUIRED_FORM,
    TOOLTIP_TALENT_PREREQ, TOOLTIP_TALENT_TIER_POINTS }
local function isRequirement(text)
    for _, format in pairs(REQUIREMENTS) do
        if unformat(text, format) then return true end
    end
    return false
end

local function isAmount(text)
    return util.parseNumber(text, LARGE_NUMBER_SEPERATOR) ~= nil
end

local function spellKey(_, data)
    if isSecret(data.id) then return end
    return data.id
end

local function readStat(model, text)
    for _, power in ipairs(POWERS) do
        for _, cost in pairs(power.costs) do
            local amount = unformat(text, cost)
            if isAmount(amount) then
                model.cost, model.power = { amount, power.name }, power.key
                return true
            end
        end
    end
    local percent = unformat(text, formats.baseManaCost)
    if percent then
        model.cost, model.power = { percent .. "%", L["Base Mana"] }, "Mana"
        return true
    end
    for _, time in ipairs(TIMES) do
        local amount = unformat(text, time[3])
        -- One time of each kind: Russian words the time left on a charge as a
        -- cooldown, below the recharge it is part of.
        if isAmount(amount) and not model[time[1]] then
            model[time[1]] = { util.fill(time[4], amount), time[2] }
            return true
        end
    end
    for _, cast in pairs(CASTS) do
        if unformat(text, cast) then
            model.cast = { text, L["Cast"] }
            return true
        end
    end
    if unformat(text, SPELL_PASSIVE) then
        model.passive = text
        return true
    end
    -- A client's own strip lines, as retail's "Max 2 Charges".
    local extension = descriptor.extension
    if extension and extension.readStat and extension.readStat(model, text) == true then return true end
    local range = unformat(text, SPELL_RANGE)
    if range then
        model.range = { util.fill(L["%s yd"], range), L["Range"] }
        return true
    end
    if unformat(text, MELEE_RANGE) then
        model.range = { MELEE, L["Range"] }
        return true
    end
end

-- The game can fill a line's right side only in the tooltip text, as it may
-- for a cooldown beside the cast time.
local function nativeRight(tooltip, lineIndex)
    local font = tooltip.GetRightLine and tooltip:GetRightLine(lineIndex)
    if not font then
        local name = tooltip:GetName()
        font = name and _G[name .. "TextRight" .. lineIndex]
    end
    local text = font and font:IsShown() and safeText(font:GetText())
    return text or ""
end

local colorNumbers = util.colorNumbers

local function badges(model, school)
    local list = {}
    if school then list[#list + 1] = { ns.Palette.schoolName(school), ns.Palette.school(school) } end
    if model.rank ~= "" then list[#list + 1] = { model.rank, RANK_BADGE } end
    if model.passive then list[#list + 1] = { model.passive, RANK_BADGE } end
    if model.talent then
        list[#list + 1] = { TOOLTIP_TALENT_RANK:format(model.talent.rank, model.talent.max), RANK_BADGE }
    end
    -- Set by the types that show a spell: a macro's name, a pet ability's autocast.
    for _, tag in ipairs(model.tags or {}) do list[#list + 1] = { tag[1], tag[2] or RANK_BADGE } end
    return list
end

-- Descriptions come in the game's gold; without a readable color, a long
-- line with nothing on the right is taken as one.
local function isDescription(line, text, right)
    local color = line.leftColor
    if not isSecret(color) and type(color) == "table" then
        local r, g, b = color.r, color.g, color.b
        if not isSecret(r) and not isSecret(g) and not isSecret(b)
            and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r > .9 and g > .65 and g < .9 and b < .3
        end
    end
    return right == "" and util.width(text) >= 40
end

local function newModel(icon)
    return { cells = {}, details = {}, requirements = {}, description = {}, extras = {}, rank = "",
        icon = icon }
end

-- A line that is only a pointer to another spell's description, which the
-- game left unfilled: "$@382021" on Earthliving Weapon's imbue, the
-- "spelldesc" missing from it. The other spell's description, or "" while
-- the game has not loaded it, so the pointer is never shown; nil for any
-- other line.
local function pointedDescription(text, game)
    local id = tonumber(text:match("^%$@%a*(%d+)$"))
    if not id then return end
    local target = game.spellDescription(id)
    if not target or target:find("^%$@") then return "" end
    return target
end

-- A description can open with its own requirement, on a line of its own.
local function readDescription(model, text)
    local rest = {}
    for paragraph in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do
        local stripped = trim(paragraph)
        if #rest == 0 and isRequirement(stripped) then
            add(model.requirements, stripped, "")
        elseif stripped ~= "" then
            rest[#rest + 1] = stripped
        end
    end
    if #rest > 0 then model.description[#model.description + 1] = table.concat(rest, "\n") end
end

-- A recipe spell's "Reagents: |nPeacebloom, Silverleaf (2)", each the game
-- colors red while the player lacks it. Nil for a list it cannot read.
local function readReagents(text)
    -- The label as startsWith matched it: without its line break.
    local label = trim((SPELL_REAGENTS:gsub("|n", "")))
    local at = text:find(label, 1, true)
    if label == "" or not at then return end
    local list = trim((text:sub(at + #label):gsub("^%s*|n", "")))
    for _, separator in ipairs(ns.Locale.listSeparators) do
        local following = type(separator) == "table" and separator[2] or ""
        separator = type(separator) == "table" and separator[1] or separator
        list = list:gsub(((separator .. following):gsub("%p", "%%%0")), "\031" .. following)
    end
    local reagents = {}
    for piece in (list .. "\031"):gmatch("(.-)\031") do
        local plain = trim(util.plainText(piece))
        if plain == "" then return end
        local name, count = plain:match("^(.-)%s*%((%d+)%)$")
        name = name or plain
        reagents[#reagents + 1] = { name = name, count = tonumber(count) or 1,
            missing = piece:find("|cffff2020", 1, true) ~= nil }
    end
    if #reagents > 0 then return reagents end
end

local function readLine(model, line, left, right, game)
    local text, rightText = trim(left), trim(right)
    if text == "" and rightText == "" then return end
    local pointed = rightText == "" and pointedDescription(text, game)
    if pointed then
        if pointed ~= "" then readDescription(model, pointed) end
        return
    end
    if LINE.UsageRequirement and line.type == LINE.UsageRequirement then
        add(model.requirements, text, rightText)
        local usable = line.usable
        if isSecret(usable) then usable = nil end
        if usable == false or not tooltipData.requirementMet(text, line.leftColor, game) then
            model.requirements[#model.requirements].color = UNMET_COLOR
        end
        return
    end
    -- "Passive" by its type, where the line has one; readStat knows the word.
    if LINE.SpellPassive and line.type == LINE.SpellPassive and rightText == "" then
        model.passive = text
        return
    end
    if rightText ~= "" and readStat(model, rightText) then rightText = "" end
    -- A cost in two resources is one line with a break: "30 Energy" over "1 to
    -- 5 Combo Points". The first is the strip's cost, the rest are details.
    local first, rest = (text:gsub("|n", "\n")):match("^([^\n]*)\n(.+)$")
    if first and readStat(model, trim(first)) then
        for part in rest:gmatch("[^\n]+") do
            if trim(part) ~= "" then add(model.details, util.resolvePlurals(trim(part)), "") end
        end
        if rightText ~= "" then add(model.details, rightText, "") end
        return
    end
    if text ~= "" and readStat(model, text) then
        if rightText ~= "" then add(model.details, rightText, "") end
    elseif unformat(text, ITEM_COOLDOWN_TIME)
        or (descriptor.extension and descriptor.extension.isCooldown and descriptor.extension.isCooldown(text)) then
        add(model.details, text, rightText)
        model.details[#model.details].color = REMAINING_COLOR
    elseif isRequirement(text) then
        add(model.requirements, text, rightText)
        local row = model.requirements[#model.requirements]
        row.color = not tooltipData.requirementMet(text, line.leftColor, game) and UNMET_COLOR or nil
    elseif startsWith(text, SPELL_REAGENTS) or startsWith(text, SPELL_TOTEMS) then
        local reagents = not model.reagents and startsWith(text, SPELL_REAGENTS) and readReagents(text)
        if reagents then model.reagents = reagents else add(model.details, text, rightText) end
    elseif text ~= "" and ((LINE.SpellDescription and line.type == LINE.SpellDescription)
        or isDescription(line, text, rightText)) then
        readDescription(model, text)
    else
        -- A right side already read, as the range, is not shown again.
        add(model.extras, left, rightText == "" and "" or right)
        local row = model.extras[#model.extras]
        row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
    end
end

-- The talent window writes a talent's rank above the tooltip's data, and,
-- below it, another rank and the points still to spend. After "Next Rank:"
-- that rank is the next one. Without the label, a second "Passive" starts it,
-- and then it is the current rank while the data holds the next.
-- Rows it does not claim are other addons' rows. Nil when not a talent.
local function readTalent(model, rows)
    local talent, extras, block, unlabeled
    for _, row in ipairs(rows) do
        local plain = trim(util.plainText(row.left))
        local rank, max = unformat(plain, TOOLTIP_TALENT_RANK)
        if tonumber(rank) and tonumber(max) and not talent then
            talent = { rank = tonumber(rank), max = tonumber(max), description = {}, details = {} }
            extras = {}
        elseif not talent then
            return
        elseif unformat(plain, NEXT_RANK_COLON) or unformat(plain, TOOLTIP_TALENT_NEXT_RANK) then
            block = talent
        elseif not block and unformat(plain, SPELL_PASSIVE) then
            block, unlabeled = talent, true
        elseif unformat(plain, formats.talentPoints) or isRequirement(plain) then
            local color = row.textColor
            local unmet = row.left:find("|cffff2020", 1, true) or (color and color[1] > .9 and color[2] < .3)
            add(model.requirements, plain, "")
            model.requirements[#model.requirements].color = unmet and UNMET_COLOR or nil
        elseif block and row.left:find("^|c%x%x%x%x%x%x%x%x") then
            -- The game's own lines bring no color of their own; this is another
            -- addon's, as Forever's "Press F6" line, which can follow the next rank.
            extras[#extras + 1] = row
        elseif block and unformat(plain, SPELL_PASSIVE) then
            -- The rank after the data repeats it.
        elseif block then
            local color = row.textColor
            local gold = color and color[1] > .9 and color[2] > .7 and color[2] < .9 and color[3] < .2
            if gold then
                block.description[#block.description + 1] = plain
            else
                add(block.details, plain, trim(row.right or ""))
            end
        else
            extras[#extras + 1] = row
        end
    end
    if not talent then return end
    if unlabeled and #talent.description > 0 then
        model.description, talent.description = talent.description, model.description
    end
    model.talent = talent
    return extras
end

local function readSpell(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = newModel(game.spellIcon(data.id))
    model.spellID = not isSecret(data.id) and data.id or nil
    model.lineIndices = {}
    local current = model
    for index, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) or isSecret(line.type) then return end
        -- The game can send a line's index twice, the second time empty.
        local repeated = line.lineIndex and model.lineIndices[line.lineIndex]
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        local nestsItem = LINE.NestedBlock and line.type == LINE.NestedBlock and not isSecret(line.tooltipType)
            and line.tooltipType == ITEM
        if nestsItem then
            -- The item a recipe crafts, as a trainer shows it: every line after
            -- the block is the item's own. Unread, they stay the spell's rows.
            local created = ui.createdItem and ui.createdItem.read(tooltip, tooltipData.nested(data), game)
            if created then
                model.created = created
                for after = index + 1, #data.lines do
                    local itemLine = data.lines[after]
                    local itemIndex = not isSecret(itemLine) and type(itemLine) == "table" and itemLine.lineIndex
                    if itemIndex and not isSecret(itemIndex) then model.lineIndices[itemIndex] = true end
                end
                break
            end
            current = model
        elseif LINE.NestedBlock and line.type == LINE.NestedBlock then
            -- Another spell inside this one: another form's version, or a recipe's result.
            local id = line.tooltipID
            if isSecret(id) then id = nil end
            model.nested = newModel(game.spellIcon(id))
            model.nested.spellID = id
            current = model.nested
        elseif line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            local isName = (LINE.SpellName and line.type == LINE.SpellName)
                or (current == model and line.lineIndex == 1)
            if not left or not right then
                -- In combat the game hides some lines, as the cooldown left. The
                -- panel shows such a text without reading it, but cannot go
                -- without the spell's name.
                if isName and not current.name then return end
                if isSecret(line.leftText) then
                    current.hidden = current.hidden or {}
                    current.hidden[#current.hidden + 1] = line.leftText
                end
            else
                if right == "" and not repeated then right = nativeRight(tooltip, line.lineIndex) end
                if isName and not current.name then
                    current.name, current.rank = trim(left), trim(right)
                else
                    readLine(current, line, left, right, game)
                end
            end
        end
    end
    -- Talents, and spells with another nested in them, leave their name out of
    -- the data; the game writes it on the tooltip's first line.
    if not model.name or model.name == "" then
        local font = tooltip:GetLeftLine(1)
        model.name = game.spellName(data.id) or trim(font and safeText(font:GetText()) or "")
        model.lineIndices[1] = true
    end
    if model.name == "" then return end

    -- The game hides every line it draws once any is hidden, and other addons'
    -- rows with them; the panel goes without those.
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices) or {}
    -- A client's own lines the game adds after the data, as retail's "You
    -- haven't added this to your action bars", go with the details rather
    -- than other addons' rows.
    local extension = descriptor.extension
    if extension and extension.isDetail then
        local kept = {}
        for _, row in ipairs(appended) do
            if extension.isDetail(row.left, row.right) then
                -- In the game's color, muted as other added rows are.
                add(model.details, trim(row.left), trim(row.right or ""))
                model.details[#model.details].color = row.color
            else
                kept[#kept + 1] = row
            end
        end
        appended = kept
    end
    local rows = {}
    for _, row in ipairs(appended) do
        if not tooltipData.isBlank(row) then rows[#rows + 1] = row end
    end
    -- A talent's rows are read without their blank lines; anything else keeps them as gaps.
    local talentExtras = readTalent(model, rows)
    tooltipData.addExtras(model.extras, talentExtras or appended)
    for _, part in ipairs({ model, model.nested }) do
        for _, field in ipairs({ "cost", "cast", "cooldown", "range" }) do
            if part[field] then part.cells[#part.cells + 1] = part[field] end
        end
    end
    return model
end

local function sentencesOf(model)
    local list = {}
    for _, text in ipairs(model.description) do
        for _, sentence in ipairs(util.splitSentences(text)) do list[#list + 1] = sentence end
    end
    return list
end

-- A nested spell's name, a step smaller than the panel's own.
local function nestedTitleStyle(title)
    local style = {}
    for field, value in pairs(title) do style[field] = value end
    style.size = math.max(10, title.size - 4)
    return style
end

-- The strip's cells, always all four and in this order. One the tooltip left
-- out shows what its absence means, dimmed; a spell with none, as a passive,
-- has no strip.
local STRIP = {
    { "cost", L["Free"], L["Cost"] },
    { "cast", SPELL_CAST_TIME_INSTANT, L["Cast"] },
    { "cooldown", L["None"], L["Cooldown"] },
    { "range", L["Self"], L["Range"] },
}

local function stripCells(part)
    if #part.cells == 0 then return part.cells end
    local cells = {}
    for index, cell in ipairs(STRIP) do
        cells[index] = part[cell[1]] or { cell[2], cell[3], implied = true }
    end
    return cells
end

-- A client's rows at the head of a spell's details, as retail's charges: each
-- a row with style, the name of its style part, and color.
local function leadRows(part)
    local extension = descriptor.extension
    return extension and extension.leadRows and extension.leadRows(part) or {}
end

-- The widest thing in one spell's body: its strip, rows, and sentences.
local function bodyWidth(panel, part, body, styles)
    local need = 0
    local function consider(width) if width > need then need = width end end
    local cells = stripCells(part)
    if #cells > 0 then
        local widest = 0
        for _, cell in ipairs(cells) do
            widest = math.max(widest, measureStyled(panel, cell[1], styles.spellValues),
                measureStyled(panel, util.upper(cell[2]), styles.spellCaptions))
        end
        consider((widest + 16) * #cells)
    end
    for _, rows in ipairs({ part.details, part.requirements }) do
        for _, row in ipairs(rows) do consider(ui.rowWidth(panel, row, styles.spellDetails)) end
    end
    for _, row in ipairs(leadRows(part)) do consider(ui.rowWidth(panel, row, styles[row.style])) end
    for _, sentence in ipairs(body.sentences) do
        consider(math.min(measureStyled(panel, sentence, styles.spellText), ui.PROSE_WIDTH))
    end
    for _, row in ipairs(body.powerRows or {}) do
        consider(ui.rowWidth(panel, row, styles.spellDetails))
    end
    local next = part.talent
    if next then
        for _, row in ipairs(next.details) do consider(ui.rowWidth(panel, row, styles.spellDetails)) end
        for _, sentence in ipairs(body.nextSentences) do
            consider(math.min(measureStyled(panel, sentence, styles.spellText), ui.PROSE_WIDTH))
        end
    end
    return need
end

local function drawStrip(panel, model, y, color, styles)
    local values, captions = styles.spellValues, styles.spellCaptions
    local cells = stripCells(model)
    local cellWidth = (panel.width - 2 * pad()) / #cells
    local captionOffset = math.max(CAPTION_OFFSET, values.size + 4)
    local height = math.max(STRIP_HEIGHT, captionOffset + captions.size + 8)
    for index, cell in ipairs(cells) do
        local x = pad() + (index - 1) * cellWidth
        local valueColor = cell.implied and colors.caption or TITLE_COLOR
        local power = cell == model.cost and POWER_COLORS[model.power]
        if power then
            valueColor = { power[1] * .45 + .55, power[2] * .45 + .55, power[3] * .45 + .55 }
        end
        styledAt(panel, cell[1], x, y, cellWidth, values, valueColor, "CENTER")
        styledAt(panel, util.upper(cell[2]), x, y + captionOffset, cellWidth, captions,
            colors.caption, "CENTER")
        if index > 1 then
            local separator = ui.acquireTexture(panel)
            separator:SetPoint("TOPLEFT", panel, "TOPLEFT", ui.snap(panel, x), -ui.snap(panel, y + 2))
            separator:SetSize(ui.pixel(panel), height - 8)
            separator:SetVertexColor(color[1] * .6, color[2] * .6, color[3] * .6, .5)
        end
    end
    -- What the strip leaves under its captions, for a rule after it.
    panel.rowTail = height - captionOffset - captions.size
    return y + height
end

local function hasBody(part, body)
    return #part.cells > 0 or #part.details > 0 or #part.requirements > 0 or #body.sentences > 0 or #leadRows(part) > 0
        or (part.hidden and #part.hidden > 0)
        or body.powerRows ~= nil or (body.nextSentences and #body.nextSentences > 0)
end

-- A rule after the block above, as far below its letters as the next block
-- starts below it.
local function ruleAfter(panel, y, color)
    return ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, ui.RULE_SPACE - (panel.rowTail or 0))
end

-- The strip, requirements, and description of the spell or the one nested in
-- it; body holds its sentences and spell power rows.
local function drawBody(panel, part, body, y, color, styles, numberCode)
    if #part.cells > 0 then
        y = drawStrip(panel, part, y, color, styles) + 2
        panel.rowTail = panel.rowTail + 2
    end
    local hidden = part.hidden or {}
    local lead = leadRows(part)
    local detailed = #part.details > 0 or #part.requirements > 0 or #hidden > 0 or #lead > 0
    if detailed then
        -- Under the strip, a little apart from it; first, where anything would start.
        if #part.cells > 0 then y = y + 2 end
        for _, row in ipairs(lead) do y = ui.drawRow(panel, row, y, styles[row.style], row.color, 0, 2) end
        y = ui.drawGroup(panel, part.requirements, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
        y = ui.drawGroup(panel, part.details, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
        -- Hidden lines are the cooldown left, in combat: in its color, as out of it.
        for _, text in ipairs(hidden) do
            local style = styles.spellDetails
            y = y + ui.hiddenTextAt(panel, text, pad(), y, panel.width - 2 * pad(), style, REMAINING_COLOR) + 2
            panel.rowTail = math.floor(style.size * 1.15 + .5) - style.size + 2
        end
    end
    if #body.sentences > 0 then
        if #part.cells > 0 or detailed then
            y = ruleAfter(panel, y, color)
        end
        for _, sentence in ipairs(body.sentences) do
            y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                y, styles.spellText, colors.description, 0, 5)
        end
    end
    if body.powerRows then
        if #part.cells > 0 or detailed or #body.sentences > 0 then
            y = ruleAfter(panel, y, color)
        end
        y = ui.drawGroup(panel, body.powerRows, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
    end
    -- A talent's next rank, a step dimmer, under its caption.
    local talent = part.talent
    if talent and (#body.nextSentences > 0 or #talent.details > 0) then
        y = ui.caption(panel, y + 4, util.upper(L["Next Rank"]), styles.spellCaptions, colors.caption)
        y = ui.drawGroup(panel, talent.details, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
        for _, sentence in ipairs(body.nextSentences) do
            y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                y, styles.spellText, DETAIL_COLOR, 0, 5)
        end
    end
    return y
end

-- The spell power breakdown and the rates under it, each by its option.
local function powerRows(part, numberCode, panel)
    local showPower, showRates = ns.showsDetail("spellPower", panel), ns.showsDetail("spellRates", panel)
    if not (showPower or showRates) or not ns.Locale.features.coefficients then return end
    local rows, rates
    if ns.spellPowerRows then
        rows, rates = ns.spellPowerRows(part, numberCode, ns.Game)
    elseif showRates and ns.SpellAmounts then
        -- Without coefficients (Data/Coefficients.lua, which retail's .toc leaves
        -- out), the rates come from the text alone.
        rates = ns.SpellAmounts.rateRowsOf(part, ns.Game)
    end
    local list = showPower and rows or {}
    for _, row in ipairs(showRates and rates or {}) do list[#list + 1] = row end
    if #list > 0 then return list end
end

-- What the panel shows, for Panel/Render.lua to draw. Each spell's body,
-- its own and a nested one's, is drawn here as one custom section. more,
-- when given, adds sections of another type's (sections, color) before the
-- other addons' rows: an imbue's time left.
local function spellView(panel, model, more)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local school = ns.Palette.detectSchool(model.description, model.name, model.spellID)
    local numberCode = ns.Palette.numberCode(ns.Palette.school(school))
    local power = model.power and POWER_COLORS[model.power]
    local accent = ns.Palette.school(school) or power
    local color = accent or colors.neutral
    local function bodyOf(part)
        local nextSentences = {}
        if part.talent then
            for _, text in ipairs(part.talent.description) do
                for _, sentence in ipairs(util.splitSentences(text)) do nextSentences[#nextSentences + 1] = sentence end
            end
        end
        return { sentences = sentencesOf(part), powerRows = powerRows(part, numberCode, panel),
            nextSentences = nextSentences }
    end

    local sections = {}
    local body = bodyOf(model)
    if hasBody(model, body) then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "custom",
            measure = function(p) return bodyWidth(p, model, body, styles) end,
            draw = function(p, y) return drawBody(p, model, body, y, color, styles, numberCode) end }
    end
    local nested = model.nested
    if nested and nested.name then
        local nestedBody = bodyOf(nested)
        local titleStyle = nestedTitleStyle(styles.spellTitle)
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE },
            kind = "custom",
            measure = function(p)
                return math.max(measureStyled(p, nested.name, titleStyle), bodyWidth(p, nested, nestedBody, styles))
            end,
            draw = function(p, y)
                y = y + styledAt(p, nested.name, pad(), y, p.width - 2 * pad(), titleStyle, TITLE_COLOR) + 6
                return drawBody(p, nested, nestedBody, y, color, styles, numberCode)
            end }
    end
    if model.created then sections[#sections + 1] = ui.createdItem.section(model.created, #sections > 0 and 6 or 0) end
    for _, part in ipairs({ model, nested }) do
        if part.reagents then
            local rows = {}
            for index, reagent in ipairs(part.reagents) do
                rows[index] = { left = reagent.name, right = reagent.count > 1 and tostring(reagent.count) or "",
                    color = reagent.missing and UNMET_COLOR or nil }
            end
            sections[#sections + 1] = { separator = { caption = util.upper(L["Reagents"]), style = styles.spellCaptions,
                before = 4 },
                kind = "rows", rows = rows, style = styles.spellDetails, color = DETAIL_COLOR, gap = 2 }
        end
    end
    if more then more(sections, color) end
    local extras = ui.withID(panel, model.extras, L["Spell ID: %s"], model.spellID)
    if #extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 12 },
            kind = "rows", rows = extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local header = {
        { text = model.name, style = styles.spellTitle, color = TITLE_COLOR, gap = 4 },
        { badges = badges(model, school), style = styles.spellBadges, before = 1, gap = 4 },
    }
    return {
        tooltipType = "spell",
        color = color,
        tint = accent,
        gradient = ns.Palette.gradient(school),
        strength = SPELL_TINT,
        icon = ns.option("iconSpells") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
    }
end

local function renderSpell(panel, tooltip, model)
    ui.renderView(panel, tooltip, spellView(panel, model))
end
ui.spellView = spellView

-- A spell model from given fields: the editor's samples.
ui.spellModel = function(fields)
    local model = newModel(fields.icon)
    for key, value in pairs(fields) do model[key] = value end
    for _, field in ipairs({ "cost", "cast", "cooldown", "range" }) do
        if model[field] then model.cells[#model.cells + 1] = model[field] end
    end
    return model
end

local function details(model, context)
    local school = ns.Palette.detectSchool(model.description, model.name, model.spellID)
    local numberCode = ns.Palette.numberCode(ns.Palette.school(school))
    local rows = {}
    for _, row in ipairs(powerRows(model, numberCode, context) or {}) do rows[#rows + 1] = row end
    local nested = model.nested
    local nestedRows = nested and nested.name and powerRows(nested, numberCode, context)
    if nestedRows then
        rows[#rows + 1] = { left = nested.name, right = "", color = TITLE_COLOR }
        for _, row in ipairs(nestedRows) do rows[#rows + 1] = row end
    end
    rows[#rows + 1] = ui.idRow(context, L["Spell ID: %s"], model.spellID)
    return rows
end

descriptor.read, descriptor.render, descriptor.key, descriptor.option = readSpell, renderSpell, spellKey, "spellPanels"
descriptor.details, descriptor.detailKeys = details, { "spellPower", "spellRates", "showIDs" }
ui.defineTooltipType(SPELL, descriptor)
