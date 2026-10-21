-- Items as a panel: the reader, which turns the game's item lines into a
-- model, and the view, which says what to draw; Panel/Render.lua draws it.
local _, ns = ...
local ui = ns.ui
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if not (ui and ITEM) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, safeText, number = util.isSecret, util.safeText, util.number
local plainText, rgb, unformat, startsWith = util.plainText, util.rgb, util.unformat, util.startsWith
local formats = ns.Locale.formats
local L = ns.L
local LINE = Enum.TooltipDataLineType
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
local pad, PROSE_WIDTH, COLUMN_GAP = ui.pad, ui.PROSE_WIDTH, ui.COLUMN_GAP
local ICON_SIZE, EXTRA_COLOR, GOLD_RULE, FLAVOR_GOLD, probe, bodyFont = ui.ICON_SIZE, ui.EXTRA_COLOR, ui.GOLD_RULE, ui.FLAVOR_GOLD, ui.probe, ui.bodyFont
local isComparison = ui.isComparison
local isRed, add, colorOf = ns.TooltipData.isRed, ns.TooltipData.add, ns.TooltipData.colorOf
local appendedRows, requirementMet = ns.TooltipData.appendedRows, ns.TooltipData.requirementMet
local formatMoney, enchantRows, styleOf, styledAt, measureStyled = ui.formatMoney, ui.enchantRows, ui.styleOf, ui.styledAt, ui.measureStyled
local rowWidth, drawRow, acquireTexture, divider, drawGroup = ui.rowWidth, ui.drawRow, ui.acquireTexture, ui.divider, ui.drawGroup

local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
local DURABILITY_BAR = 54
-- Added to a row's own gap of 3: enchants and gems are 8 from the rows around them.
local APART_SPACE = 5
local EXTRAS_RULE = { .50, .50, .54 }
-- The space a divider or the rule over other addons' rows adds after rows,
-- which end with their own gap: a divider then shows as much space above its
-- line as below, 13 px, and the rule 9 px.
local DIVIDER_AFTER, RULE_AFTER = 3, 5
local QUALITY = {
    [0] = { .62, .62, .62 },
    [1] = { .77, .77, .77 },
    [2] = { .30, .82, .30 },
    [3] = { .32, .59, .98 },
    [4] = { .72, .40, .94 },
    [5] = { 1.00, .57, .22 },
}
-- The line naming a weapon's temporary enchant and its time left.
local IMBUE_LINES = { ITEM_ENCHANT_TIME_LEFT_SEC, ITEM_ENCHANT_TIME_LEFT_MIN, ITEM_ENCHANT_TIME_LEFT_HOURS,
    ITEM_ENCHANT_TIME_LEFT_DAYS }
local function imbueLine(text)
    for _, format in pairs(IMBUE_LINES) do
        local name, left = unformat(text, format)
        if name and name ~= "" and tonumber(left) then return true end
    end
    return false
end

local PRIMARY_STATS = { STRENGTH = true, AGILITY = true, STAMINA = true, INTELLECT = true, SPIRIT = true,
    ALL_STATS = true }
local lineParts = ns.Stats.lineParts
local QUEST_MARK = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t "
-- Kinds of item the game names on a line of their own, as "Crafting Reagent".
local ITEM_KINDS = {}
for _, kind in pairs({ PROFESSIONS_USED_IN_COOKING, formats.scarce }) do ITEM_KINDS[#ITEM_KINDS + 1] = kind end
local ITEM_KIND_NAMES = {}
for _, kind in ipairs(ITEM_KINDS) do ITEM_KIND_NAMES[kind:lower()] = kind end

-- The lines naming how an item binds or how many one may have: "Binds when
-- picked up", "Soulbound", "Unique (2)".
local BINDINGS = { ITEM_BIND_ON_PICKUP, ITEM_BIND_ON_EQUIP, ITEM_BIND_ON_USE, ITEM_BIND_TO_ACCOUNT,
    ITEM_BIND_TO_BNETACCOUNT, ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP, ITEM_SOULBOUND, ITEM_UNIQUE, ITEM_UNIQUE_EQUIPPABLE,
    ITEM_UNIQUE_MULTIPLE, ITEM_LIMIT_CATEGORY, ITEM_LIMIT_CATEGORY_MULTIPLE }
local function isBinding(text)
    for _, binding in pairs(BINDINGS) do
        if unformat(text, binding) then return true end
    end
    return false
end

-- An amount as a weapon or armor line holds it: digits and separators.
local function amount(text)
    return text and text:match("^[%d%.,]+$")
end

-- Whether the text is a weapon's damage printed from format: "41 - 77 Damage".
local function weaponDamage(text, format)
    local low, high = unformat(text, format)
    return amount(low) ~= nil and amount(high) ~= nil
end

local function getItemInfo(tooltip, data)
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and not isSecret(link) and link then return link end
    end
    if not isSecret(data.hyperlink) and data.hyperlink then return data.hyperlink end
    if not isSecret(data.id) then return data.id end
end

-- A bag's "16 Slot Soul Bag" line, in its subtitle: the kind of bag, in place
-- of a plainer slot it ends with, then the slots.
local function withBagSlots(item)
    local bag = item.bag
    if not bag then return end
    local slot, kind = item.slot or "", bag.kind
    if slot == "" or kind:sub(-#slot) == slot then
        slot = kind
    elseif slot ~= kind then
        slot = slot .. " \194\183 " .. kind
    end
    item.slot = slot .. " \194\183 " .. util.fill(bag.count == 1 and L["%s Slot"] or L["%s Slots"], bag.count)
end

local function getQuality(itemInfo, data, game)
    local info = game.itemInfo(itemInfo)
    if info and type(info.quality) == "number" then return info.quality end
    return number(data.quality) or 1
end

local function getLevel(itemInfo, game)
    local level = game.itemLevel(itemInfo)
    if level and level > 0 then return level end
end

-- The game greys set pieces you lack and bonuses that are not active yet.
local function isActive(color)
    if isSecret(color) or type(color) ~= "table" then return nil end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    return not (r < .7 and math.abs(r - g) < .06 and math.abs(g - b) < .06)
end

local function addExtra(model, left, right, leftColor, rightColor)
    add(model.extras, left, right)
    local row = model.extras[#model.extras]
    row.color, row.rightColor = leftColor, rightColor
end

local UNUSABLE_COLOR = colors.unmet

local function unusable(text, color)
    if isRed(color) then return "|cffFF5747" .. text .. "|r" end
    return text
end

-- A stack's per-item price, beside its total: a muted shade of the footer's gold.
local PRICE_DETAIL = "9E9485"

-- Can arrive color coded, or appended outside the tooltip data.
local function itemKind(left, right, color)
    if right ~= "" then return end
    local kind = ITEM_KIND_NAMES[plainText(left):match("^%s*(.-)%s*$"):lower()]
    if not kind then return end
    local code = left:match("|c(%x%x%x%x%x%x%x%x)")
    if code then return kind, "|c" .. code .. kind .. "|r" end
    if isSecret(color) or type(color) ~= "table" then return kind, kind end
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return kind, kind
    end
    return kind, string.format("|cff%02X%02X%02X%s|r", math.floor(r * 255 + .5),
        math.floor(g * 255 + .5), math.floor(b * 255 + .5), kind)
end

-- Must match STAT_MARKER in Data/Stats.lua, minus its trailing spaces.
local STAT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2|t"
local EQUIP_EFFECT_COLOR = { .48, .88, .48 }
-- A sword marks a chance on hit, a sparkle an enchant, and a gear a use
-- effect: white art from art/make_markers.py, tinted here. Every row's text
-- starts after a 9 px marker, the size of the diamond in a stat's text. These
-- three are drawn apart from their text, two pixels larger and shifted one
-- left, so they center where the diamond does.
local MARKER_SIZE = 9
local ON_HIT_MARKER = "|T" .. ART .. "marker-sword:11:11:-1:-2:32:32:0:32:0:32:200:210:225|t"
local ENCHANT_MARKER = "|T" .. ART .. "marker-sparkle:11:11:-1:-2:32:32:0:32:0:32:90:230:60|t"
local USE_MARKER = "|T" .. ART .. "marker-gear:11:11:-1:-2:32:32:0:32:0:32:240:200:90|t"
-- Markers that stand in for a line's opening words, which come back while
-- markers are off.
local MARKED = {
    onHit = { ON_HIT_MARKER, ITEM_SPELL_TRIGGER_ONPROC and ITEM_SPELL_TRIGGER_ONPROC .. " " },
    use = { USE_MARKER, ITEM_SPELL_TRIGGER_ONUSE and ITEM_SPELL_TRIGGER_ONUSE .. " " },
}

-- Whether a line is of a type the client names. Its text is the fallback,
-- for clients and lines without one.
local function isType(lineType, name)
    return LINE ~= nil and LINE[name] ~= nil and lineType == LINE[name]
end

-- A requirement is met by the line's own usable flag where it has one, else
-- by its wording and color.
local function requirementOf(line, lineType, text, game)
    local usable = line.usable
    if isType(lineType, "UsageRequirement") and not isSecret(usable) and type(usable) == "boolean" then
        return usable
    end
    return requirementMet(text, line.leftColor, game)
end

-- The text after a label the game puts first, as "Use:".
local function withoutLabel(text, label)
    if label and text:sub(1, #label) == label then return (text:sub(#label + 1):gsub("^%s+", "")) end
    return text
end

local function readCopyLine(model, left, right)
    if right ~= "" then return false end
    local text = plainText(left):match("^%s*(.-)%s*$")
    local maker = unformat(text, ITEM_CREATED_BY)
    if maker then
        model.madeBy = maker
        return true
    end
    local enchant = unformat(text, ENCHANTED_TOOLTIP_LINE)
    if enchant then
        for _, row in ipairs(enchantRows(enchant)) do add(model.enchants, row, "") end
        return true
    end
    return false
end

-- A large line's value bright and its words a steel grey: the DPS, armor, and
-- block. Their text without its own colors takes LARGE_COLOR.
local VALUE_COLOR, LABEL_COLOR, LARGE_COLOR = "E6ECF2", "AEB9C7", { .90, .93, .95 }

local function valueLabel(value, label)
    return "|cff" .. VALUE_COLOR .. value .. "|r |cff" .. LABEL_COLOR .. label .. "|r"
end

-- The game's "If you replace this item" lines are kept as rows from another
-- source; their "+5 Stamina" lines must not be read as the item's own stats.
local STOCK_CHANGES = ITEM_DELTA_DESCRIPTION

-- The professions a recipe or crafted item can require, by the client's names.
local PROFESSIONS = {}
for _, key in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Cooking", "First Aid", "Fishing", "Mining", "Herbalism", "Skinning", "Jewelcrafting", "Inscription" }) do
    for _, name in ipairs(ns.Locale.skillNames(key)) do PROFESSIONS[name] = true end
end

-- Whether a name is a profession's: its own, or, on retail and a line the game
-- marks as a requirement, one expansion's part of it, "Midnight Blacksmithing".
-- A reagent's name can hold one too ("Elixir of Mining"), so other lines need
-- the name exactly.
local function isProfession(name, marked)
    if PROFESSIONS[name] then return true end
    return marked and ns.IsRetail() and ns.Retail.Item.isExpansionProfession(name, PROFESSIONS) or false
end

-- "Requires Blacksmithing (80)": the profession and level a recipe needs.
local function professionRequirement(text, lineType)
    local name, level = unformat(text, ITEM_MIN_SKILL)
    local marked = LINE.UsageRequirement ~= nil and lineType == LINE.UsageRequirement
    if name and tonumber(level) and isProfession(name, marked) then return name, tonumber(level) end
end

-- "Requires Bronze Bar (10), Sulfuric Acid (2)": a recipe's reagents.
-- placed: the line stands where a recipe lists its reagents, right after
-- "Teaches you how to make", where Forever words them without "Requires"
-- and a single one without a count: "Heavy Leather, Magenta Dye".
local function reagentList(text, placed)
    text = plainText(text)
    -- "Requires Cooking (80)" has the same shape, but names a skill; so does a
    -- crafted item's "Unique-Equipped: Embellished (2)", which is its own.
    if professionRequirement(text) or isBinding(text) then return end
    text = unformat(text, ITEM_REQ_SKILL) or text
    if not placed and not text:find("%(%d+%)") then return end
    local list = {}
    for piece in (text .. ","):gmatch("%s*(.-)%s*,") do
        if piece == "" then return end
        local name, count = piece:match("^(.-)%s*%((%d+)%)$")
        list[#list + 1] = { name = name or piece, count = tonumber(count) or 1 }
    end
    return list
end

-- Only items the client has seen resolve by name.
local function itemByName(name, game)
    local info = game.itemInfo(name)
    if info and info.link then return info.link, info.quality, info.icon end
end

local function newItemModel()
    return {
        header = {},
        armor = {},
        primary = {},
        secondary = {},
        equipEffects = {},
        enchants = {},
        effects = {},
        flavor = {},
        setItems = {},
        setBonuses = {},
        extras = {},
        footerLeft = {},
        footerRight = {},
        kinds = {},
        weaponBonus = {},
    }
end

-- An item model from given fields, each list it lacks empty: the editor's samples.
ui.itemModel = function(fields)
    local model = newItemModel()
    for key, value in pairs(fields) do model[key] = value end
    return model
end

-- How many the shown stack holds: its bag slot knows, else the data line's
-- price, which covers the stack, gives it away.
local function stackCount(data, unitPrice, linePrice, game)
    local count = game.stackCount(data.guid)
    if count then return count end
    if linePrice and linePrice > unitPrice and linePrice % unitPrice == 0 then
        return linePrice / unitPrice
    end
    return 1
end

-- A recipe's lines hold the crafted item's whole tooltip, from its name line
-- to the reagents; those go into model.created.
local function finishRecipe(tooltip, model, data, game)
    local recipeID = not isSecret(data.id) and data.id or nil
    if recipeID then
        model.link, model.icon = recipeID, game.itemIcon(recipeID) or model.icon
        model.quality, model.level = getQuality(recipeID, data, game), getLevel(recipeID, game)
    end
    model.levelLine = nil
    if model.skill then
        local text = util.fill(L["Requires %s %s"], model.skill.name, model.skill.level)
        if model.levelRequirement then
            add(model.footerRight, text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, model.skill.met
        else
            model.levelRequirement = { text = text, met = model.skill.met }
        end
        model.slot = (model.name:match("^([^:%s]+):") or L["Recipe"]) .. " \194\183 " .. model.skill.name
    end
    local created = model.created
    if created then
        local link, quality, icon = itemByName(created.name, game)
        if not link and tooltip.GetItem then
            -- The game reports the crafted item as the tooltip's item, under the
            -- recipe's name; its link names it, and gives the icon before it loads.
            local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
            if ok and not isSecret(itemLink) and type(itemLink) == "string"
                and itemLink:match("%[(.-)%]") == created.name then
                link, icon = itemLink, game.itemIcon(itemLink)
                local loaded = itemByName(itemLink, game)
                if loaded then quality = getQuality(itemLink, {}, game) end
            end
        end
        created.link, created.icon = link, icon
        created.quality = type(quality) == "number" and quality or nil
        -- The crafted item's binding usually repeats the recipe's.
        local recipeBinding = model.header[1] and model.header[1].left
        local bindings = {}
        for _, row in ipairs(created.header) do
            if row.left ~= recipeBinding then bindings[#bindings + 1] = plainText(row.left) end
        end
        created.binding = #bindings > 0 and table.concat(bindings, " \194\183 ") or nil
    elseif model.teaches then
        add(model.effects, model.teaches.left, model.teaches.right)
    end
    for _, reagent in ipairs(model.reagents or {}) do
        local link = itemByName(reagent.name, game)
        reagent.have = game.itemCount(link or reagent.name)
    end
end

local function readModel(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local itemInfo = getItemInfo(tooltip, data)
    local model = newItemModel()
    model.link = itemInfo
    model.quality = getQuality(itemInfo, data, game)
    model.icon = game.itemIcon(itemInfo)
    model.level = getLevel(itemInfo, game)
    model.lineIndices = {}
    -- Lines go to the recipe or, inside its embedded tooltip, the crafted item.
    local m = model
    local inSet, setTotal = false, 0
    local teachesLast = false
    local inStockChanges = false
    local function isStockChange(text)
        local trimmed = plainText(text):match("^%s*(.-)%s*$")
        if unformat(trimmed, STOCK_CHANGES) then
            inStockChanges = true
            return true
        end
        if inStockChanges and (trimmed == "" or lineParts(trimmed)) then
            return true
        end
        inStockChanges = false
        return false
    end

    for lineNumber, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then
            return
        end
        -- The amount is drawn by a money frame, not as text, so take it from the data.
        if LINE.SellPrice and line.type == LINE.SellPrice then
            m.hasSellPrice = true
            local price = number(line.price)
            if price then m.sellPrice = price end
        end
        if line.lineIndex then
        local left, right = safeText(line.leftText), safeText(line.rightText)
        if not left or not right then return end
        if ns.IsRetail() then
            left, right = ns.Retail.Item.repairedColors(left), ns.Retail.Item.repairedColors(right)
        end
        local lineType = line.type
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        -- Read as the panel words it, each stat of a combined bonus apart.
        local wording = ns.TooltipData.itemWording(line)
        local original = wording and left
        if wording then left = wording.display end
        local trimmed = left:match("^%s*(.-)%s*$")
        local startsQuest = unformat(trimmed, ITEM_STARTS_QUEST)
        if startsQuest or unformat(trimmed, ITEM_BIND_QUEST) then
            m.quest = true
        end
        local displayed = left

        local afterTeaches = teachesLast
        teachesLast = false
        if isStockChange(left) then
            addExtra(m, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
        elseif isType(lineType, "ItemSpellTriggerLearn") or unformat(trimmed, formats.recipeTeaches) then
            -- Its type marks it in every language; cooking words it apart from
            -- the other professions ("烹制", not "制作"). The recipe's own lines follow.
            model.teaches = { left = left, right = right }
            teachesLast = true
            if model.created then m = model end
        elseif afterTeaches and model.created and not model.reagents and right == ""
            and (lineType == nil or isType(lineType, "None")) and reagentList(trimmed, true) then
            model.reagents, m = reagentList(trimmed, true), model
        elseif m == model and startsQuest then
            model.startsQuest = trimmed
        elseif professionRequirement(trimmed, lineType) and (m == model or (model.created and not model.skill)) then
            -- A recipe's skill, before the item it creates or, as on cooking
            -- recipes, after it; once the recipe has one, the item's own.
            local name, level = professionRequirement(trimmed, lineType)
            model.skill = { name = name, level = level, text = left, met = requirementMet(trimmed, line.leftColor, game) }
        elseif model.created and not model.reagents and reagentList(trimmed) then
            model.reagents, m = reagentList(trimmed), model
        elseif lineType == LINE.ItemName then
            if not model.name then
                model.name, model.nameColor = left, rgb(line.leftColor)
            elseif not model.created then
                model.created = newItemModel()
                -- Its name line starts with a line break.
                model.created.name, model.created.nameColor = trimmed, rgb(line.leftColor)
                m = model.created
            end
        elseif lineType == LINE.ItemLevel then
            local level = left:match("(%d+)")
            if level then m.level, m.levelLine = tonumber(level), true end
        elseif ns.IsRetail() and ns.Retail.Item.readLine(m, line, data, lineNumber, left, right, trimmed, original) then
            -- Retail's upgrade level, sockets, crafted quality, and transmogrification.
        elseif right == "" and imbueLine(plainText(trimmed)) then
            -- A weapon's temporary enchant, "Windfury Weapon (59 min)", under its enchants.
            m.imbues = m.imbues or {}
            for _, row in ipairs(enchantRows(util.trim(plainText(trimmed)))) do add(m.imbues, row, "") end
        elseif lineType == LINE.EquipSlot then
            m.equippable = true
            local slot = unusable(left, line.leftColor)
            local kind = unusable(right, line.rightColor)
            m.slot = right ~= "" and (kind .. " \194\183 " .. slot) or slot
        elseif lineType == LINE.ItemBinding or isBinding(trimmed) then
            add(m.header, left, right)
            if isRed(line.leftColor) then m.header[#m.header].color = UNUSABLE_COLOR end
        elseif right == "" and tonumber((unformat(trimmed, CONTAINER_SLOTS))) then
            local count, kind = unformat(trimmed, CONTAINER_SLOTS)
            m.bag = { count = tonumber(count), kind = kind }
        elseif itemKind(left, right) then
            local kind, text = itemKind(left, right, line.leftColor)
            m.kinds[kind] = text
        elseif ns.IsRetail() and ns.Retail.Item.readSource(m, line, data, lineNumber, right, trimmed) then
            -- Retail's source between the name and level: Heroic, Mythic.
        elseif trimmed ~= "" then
            local setName, count, total = unformat(trimmed, ITEM_SET_NAME)
            if setName and tonumber(count) and tonumber(total) and not m.setName then
                m.setName, m.setCount = setName, count .. "/" .. total
                inSet, setTotal = true, tonumber(total)
            elseif LINE.SellPrice and lineType == LINE.SellPrice then
                m.hasSellPrice = true
            elseif unformat(trimmed, ITEM_MIN_LEVEL) and right == "" then
                m.levelRequirement = {
                    text = trimmed, met = requirementOf(line, lineType, trimmed, game),
                }
            elseif isType(lineType, "UsageRequirement") or unformat(trimmed, ITEM_REQ_SKILL) then
                add(m.footerRight, left, right)
                local entry = m.footerRight[#m.footerRight]
                entry.requirement = true
                entry.met = requirementOf(line, lineType, trimmed, game)
            elseif tonumber((unformat(trimmed, DURABILITY_TEMPLATE))) then
                add(m.footerLeft, trimmed, right)
                local current, maximum = unformat(trimmed, DURABILITY_TEMPLATE)
                m.footerLeft[#m.footerLeft].durability =
                    { tonumber(current), tonumber(maximum) }
            elseif unformat(trimmed, ITEM_CLASSES_ALLOWED) or unformat(trimmed, ITEM_RACES_ALLOWED)
                or unformat(trimmed, TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN)
                or unformat(trimmed, TRANSMOGRIFY_STYLE_UNCOLLECTED) or unformat(trimmed, formats.appearance) then
                add(m.footerLeft, left, right)
                if isRed(line.leftColor) then
                    m.footerLeft[#m.footerLeft].color = UNUSABLE_COLOR
                end
            -- Retail keeps an active bonus in the set, worded "Set: ...".
            elseif inSet and (unformat(trimmed, ITEM_SET_BONUS_GRAY)
                or (ns.IsRetail() and unformat(trimmed, ITEM_SET_BONUS))) then
                add(m.setBonuses, left, right)
                m.setBonuses[#m.setBonuses].active = isActive(line.leftColor)
            -- Set pieces are names alone: letters (of any alphabet), spaces,
            -- apostrophes, and hyphens.
            elseif inSet and #m.setItems < setTotal
                and right == "" and trimmed:gsub("[%a'%- \128-\255]", "") == "" then
                add(m.setItems, trimmed, right)
                m.setItems[#m.setItems].active = isActive(line.leftColor)
            -- A wand names its school: "64 - 120 Shadow Damage".
            elseif amount(unformat(right, formats.weaponSpeed)) and (weaponDamage(trimmed, DAMAGE_TEMPLATE)
                or weaponDamage(trimmed, DAMAGE_TEMPLATE_WITH_SCHOOL)) then
                m.weaponDamage, m.weaponSpeed = left, right
            elseif weaponDamage(trimmed, PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL) then
                -- A weapon's bonus damage of a school, drawn under its base damage.
                m.weaponBonus[#m.weaponBonus + 1] = trimmed
            elseif amount(unformat(trimmed, DPS_TEMPLATE)) then
                m.weaponDps = unformat(trimmed, DPS_TEMPLATE)
            elseif amount(unformat(trimmed, ARMOR_TEMPLATE)) then
                add(m.armor, left, right)
                m.armor[#m.armor].value = (unformat(trimmed, ARMOR_TEMPLATE):gsub("%D", ""))
            elseif SHIELD_BLOCK_TEMPLATE and amount(unformat(trimmed, SHIELD_BLOCK_TEMPLATE)) then
                -- A shield's block joins its armor's line, or stands for it without one.
                if #m.armor > 0 then
                    m.block, m.blockValue = trimmed, unformat(trimmed, SHIELD_BLOCK_TEMPLATE)
                else
                    add(m.armor, left, right)
                end
            elseif ((LINE.ItemSpellTriggerOnProc and lineType == LINE.ItemSpellTriggerOnProc)
                or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONPROC)) and right == "" then
                -- Rewritten proc text stays an effect, rather than a stat.
                local text = original or trimmed
                add(m.equipEffects, withoutLabel(text, ITEM_SPELL_TRIGGER_ONPROC), "")
                m.equipEffects[#m.equipEffects].onHit = true
            elseif original or lineParts(trimmed) == "+" then
                -- Retail greys the primary stats another specialization uses.
                local inactive = ns.IsRetail() and isActive(line.leftColor) == false
                -- Combined bonuses arrive as one line; each stat needs its own row.
                for piece in (displayed .. "|n"):gmatch("(.-)|n") do
                    local stat = ns.Stats.read(plainText(piece))
                    local primary = stat and PRIMARY_STATS[stat.key]
                    if primary and inactive then
                        ns.Retail.Item.addInactiveStat(m.primary, piece, right)
                    else
                        add(primary and m.primary or m.secondary, piece, right)
                    end
                    right = ""
                end
            elseif isType(lineType, "FlavorText") or trimmed:match('^".+"$') then
                add(m.flavor, left, right)
            elseif isType(lineType, "ItemEnchantmentPermanent") and right == "" then
                -- The enchant follows its label, "Enchanted:".
                local text = util.trim(plainText(left))
                for _, row in ipairs(enchantRows(text:match("^[^:]-:%s*(.+)$") or text)) do add(m.enchants, row, "") end
            elseif readCopyLine(m, left, right) then
                -- Crafter or enchant, taken into their own rows.
            elseif trimmed:match("^<.+>$") then
                add(m.effects, left, right)
            elseif (isType(lineType, "ItemSpellTriggerOnEquip") or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP))
                and right == "" then
                -- Unparsed equip effects join the stats; the list implies "Equip:".
                add(m.equipEffects, withoutLabel(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP), "")
            elseif (isType(lineType, "ItemSpellTriggerOnUse") or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE))
                and right == "" then
                -- Its gear marker stands for the words.
                add(m.effects, withoutLabel(trimmed, ITEM_SPELL_TRIGGER_ONUSE), "")
                m.effects[#m.effects].use = true
            elseif isType(lineType, "ItemSpellTriggerOnUse") or isType(lineType, "ItemSpellTriggerOnEquip")
                or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP) or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE) then
                add(m.effects, left, right)
            else
                addExtra(m, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
            end
        end
        end
    end

    if not model.name or model.name == "" then return end
    local appended = appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do
        local trimmed = row.left:match("^%s*(.-)%s*$")
        if isStockChange(row.left) then
            model.extras[#model.extras + 1] = row
        elseif model.created and not model.reagents and reagentList(trimmed) then
            model.reagents = reagentList(trimmed)
        elseif startsWith(trimmed, SELL_PRICE) then
            model.hasSellPrice = true
        elseif itemKind(row.left, row.right) then
            local kind, text = itemKind(row.left, row.right, row.textColor)
            model.kinds[kind] = text
        elseif readCopyLine(model, row.left, row.right) then
            -- Crafter or enchant, taken into their own rows.
        elseif trimmed ~= "" or row.right ~= "" then
            model.extras[#model.extras + 1] = row
        end
    end
    -- Crafted gear can need a profession too; only a recipe teaches.
    local recipe = model.created or (model.skill and model.teaches)
    if recipe then
        finishRecipe(tooltip, model, data, game)
        itemInfo = model.link
    else
        if model.skill then
            add(model.footerRight, model.skill.text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, model.skill.met
        end
        if model.teaches then add(model.effects, model.teaches.left, model.teaches.right) end
    end
    local classID, className, subClassName, equipLoc, itemID
    local itemType = game.itemType(itemInfo)
    if itemType then
        classID, className, subClassName = itemType.classID, itemType.className, itemType.subClassName
        equipLoc, itemID = itemType.equipLoc, itemType.id
    end
    if ns.disenchantFor and classID and not recipe then
        local itemLevel = game.itemLevel(itemInfo) or model.level
        model.disenchant = ns.disenchantFor(classID, model.quality, tonumber(itemLevel), equipLoc, itemID, game)
    end
    local level = model.levelRequirement
    if level then
        if #model.header == 0 then add(model.header, "", "") end
        local row = model.header[1]
        if row.right == "" then
            row.right = level.text
            row.rightColor = level.met and { .95, .93, .88 } or UNUSABLE_COLOR
        else
            add(model.footerRight, level.text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, level.met
        end
    end
    if model.madeBy then
        local at = 1
        for index, entry in ipairs(model.footerLeft) do
            if entry.durability then at = index + 1 end
        end
        table.insert(model.footerLeft, at, {
            left = util.fill(L["Made by %s"], model.madeBy),
            right = "",
            color = FLAVOR_GOLD,
        })
    end
    local shown = {}
    -- The game's tooltip never says an item is a consumable, or what kind.
    if classID == CONSUMABLE_CLASS and type(className) == "string" and className ~= "" then
        shown[1] = className
        if type(subClassName) == "string" and subClassName ~= "" and subClassName ~= className then
            shown[1] = className .. " \194\183 " .. subClassName
        end
    end
    for _, kind in ipairs(ITEM_KINDS) do shown[#shown + 1] = model.kinds[kind] end
    if #shown > 0 then
        local kinds = table.concat(shown, " \194\183 ")
        model.slot = model.slot and model.slot ~= "" and (model.slot .. " \194\183 " .. kinds) or kinds
    end
    withBagSlots(model)
    if model.created then withBagSlots(model.created) end

    -- The item's own price is per unit; the data line's covers the stack.
    local unitPrice
    local info = model.hasSellPrice and game.itemInfo(itemInfo)
    if info and type(info.price) == "number" and info.price > 0 then unitPrice = info.price end
    -- The coins say what the amount is. A stack leads with its total, then the
    -- count and one item's price, dimmed: 2g  (20 × 10s).
    local count = unitPrice and stackCount(data, unitPrice, model.sellPrice, game) or 1
    local price = count > 1 and unitPrice or model.sellPrice or unitPrice
    if price and price > 0 then
        local text = formatMoney(price * count)
        if count > 1 then
            text = text .. "  |cff" .. PRICE_DETAIL .. "(" .. count .. " \195\151 " .. formatMoney(price) .. ")|r"
        end
        add(model.footerRight, text, "")
        model.footerRight[#model.footerRight].sellPrice = true
    end
    model.quest = model.quest or classID == QUEST_CLASS
    model.comparison = isComparison(tooltip)
    model.equippedWith = model.comparison and game.isEquipped(model.link) == false or nil
    return model
end
readModel = probe("read item", readModel)

-- Where an effect's or enchant's text starts: after a marker and two spaces,
-- as a stat's does.
local function markerIndent(panel, style)
    if not ns.option("statMarkers") then return 0 end
    return MARKER_SIZE + measureStyled(panel, "a  a", style) - measureStyled(panel, "aa", style)
end

-- Equip effects, enchants, and use effects, each led by a marker (a chance on
-- hit by the sword) drawn apart from the text, so wrapped lines hang under it.
-- numbers: an effect's numbers are highlighted, in its school's tint when it
-- names one; enchants read as stats and keep theirs.
local function drawMarked(panel, list, y, style, color, marker, numbers)
    local hang = markerIndent(panel, style)
    local width = panel.width - 2 * pad() - hang
    for _, row in ipairs(list) do
        local text = row.left
        if numbers then text = ns.Stats.styleEffect(text, ns.option("statColors")) end
        local stands = row.onHit and MARKED.onHit or row.use and MARKED.use
        if hang > 0 then
            styledAt(panel, stands and stands[1] or marker, pad(), y, hang, style, color)
        elseif stands then
            -- Without its marker, the line keeps its words.
            text = (stands[2] or "") .. text
        end
        y = y + styledAt(panel, text, pad() + hang, y, width, style, color) + 3
    end
    return y
end

-- Use effects are led by the gear; the group's other rows, such as
-- "<Right Click to Open>", are drawn as they come.
local function drawEffects(panel, list, y, style, color)
    for _, row in ipairs(list) do
        if row.use then
            y = drawMarked(panel, { row }, y, style, color, nil, true)
        else
            y = drawRow(panel, row, y, style, color)
        end
    end
    return y
end

local function footerText(row)
    if row.right ~= "" then return row.left .. " " .. row.right end
    return row.left
end

-- Read at draw time, so the editor's samples follow the setting too.
local function shownFooterRight(model)
    if ns.option("sellPrice") then return model.footerRight end
    local rows = {}
    for _, row in ipairs(model.footerRight) do
        if not row.sellPrice then rows[#rows + 1] = row end
    end
    return rows
end

-- Damage of a school in its stat colors, from Data/Stats.lua.
local function damageText(text)
    return ns.Stats.styleDamage(text, ns.option("statColors"))
end

local function weaponText(model)
    local text = damageText(model.weaponDamage)
    if model.weaponSpeed then text = text .. "  \194\183  " .. model.weaponSpeed end
    return text
end

-- Swap Damage Stats puts the damage on the large line, and the DPS and speed
-- on the small one under it.
local function swapsDamage(model)
    return ns.option("swapDamage") and model.weaponDamage ~= nil and model.weaponDps ~= nil
end

-- A large line's value, from first to last, bright and its words dim, as
-- valueLabel colors them. Its words can come first, as Russian's "Урон: 153-256".
local function valueWords(text, first, last)
    local before, gap = text:sub(1, first - 1):match("^(.-)(%s*)$")
    local space, after = text:sub(last + 1):match("^(%s*)(.*)$")
    local function dim(words) return words ~= "" and "|cff" .. LABEL_COLOR .. words .. "|r" or "" end
    return dim(before) .. gap .. "|cff" .. VALUE_COLOR .. text:sub(first, last) .. "|r" .. space .. dim(after)
end

-- A school's damage keeps its stat colors.
local function leadDamage(model)
    local text = damageText(model.weaponDamage)
    if text ~= model.weaponDamage then return text end
    local low, high = unformat(util.trim(text), DAMAGE_TEMPLATE_WITH_SCHOOL)
    if not low then low, high = unformat(util.trim(text), DAMAGE_TEMPLATE) end
    if not (low and high and tostring(high):match("^%d[%d%.,]*$")) then return text end
    local first = text:find(low, 1, true)
    local _, last = text:find(high, first and first + #low or 1, true)
    if not (first and last) then return text end
    return valueWords(text, first, last)
end

-- The small line under them a tenth darker than their words, its numbers a
-- little brighter than its own.
local SMALL_COLOR, SMALL_NUMBER = { .62, .65, .70 }, "BBC2CB"

-- The text with its number, as the game filled it in, in that brighter grey.
local function brightened(text, value)
    local first, last
    if value then first, last = text:find(value, 1, true) end
    if not first then return text end
    return text:sub(1, first - 1) .. "|cff" .. SMALL_NUMBER .. value .. "|r" .. text:sub(last + 1)
end

local function rateText(model)
    local text = "|cff" .. SMALL_NUMBER .. model.weaponDps .. "|r " .. DAMAGE_PER_SECOND
    if not model.weaponSpeed then return text end
    return text .. "  \194\183  " .. brightened(model.weaponSpeed, unformat(model.weaponSpeed, formats.weaponSpeed))
end

-- A shield's block follows its armor on the same line: "547 Armor · 11 Block".
local function armorText(model, row, index)
    local text = row.value and valueLabel(row.value, ARMOR) or row.left
    if index ~= 1 or not model.block then return text end
    local first, last = model.block:find(model.blockValue, 1, true)
    local block = first and valueWords(model.block, first, last) or model.block
    return text .. "  \194\183  " .. block
end

local function setCountStyle(setName)
    local style = {}
    for field, value in pairs(setName) do style[field] = value end
    style.size = math.max(8, setName.size - 3)
    if not setName.customFont then style.font = bodyFont() end
    return style
end

local DISENCHANT_GREY = { .55, .53, .50 }
local DISENCHANT_TEXT = { .88, .84, .76 }

local function disenchantHeading(result)
    local row = { left = ROLL_DISENCHANT,
        right = util.fill(L["Requires %s %s"], ns.Locale.skillName("Enchanting"), result.skill) }
    if not result.player then
        row.rightColor = DISENCHANT_GREY
    elseif result.player < result.skill then
        row.rightColor = UNUSABLE_COLOR
    end
    return row
end

local function disenchantRows(result)
    local rows = {}
    for _, entry in ipairs(result.rows) do
        local count = entry.count[1] == entry.count[2] and (entry.count[1] > 1 and entry.count[1] .. " " or "")
            or (entry.count[1] .. "\226\128\147" .. entry.count[2] .. " ")
        local icon = entry.icon and ("|T" .. entry.icon .. ":0|t ") or ""
        rows[#rows + 1] = {
            left = icon .. count .. (entry.name or "?"),
            right = string.format("%g%%", math.floor(entry.chance * 10 + .5) / 10),
        }
    end
    if result.value then
        rows[#rows + 1] = { left = L["Expected value"], right = formatMoney(result.value), color = DISENCHANT_GREY }
    end
    return rows
end

local CREATED_ICON = 26

local function reagentRows(model)
    local rows = {}
    for _, reagent in ipairs(model.reagents or {}) do
        -- No icons: the client knows one by name only once it has loaded the item.
        local row = { left = reagent.name, right = tostring(reagent.count) }
        if reagent.have then
            row.right = reagent.have .. " / " .. reagent.count
            if reagent.have < reagent.count then row.rightColor = UNUSABLE_COLOR end
        end
        rows[#rows + 1] = row
    end
    return rows
end

local function createdSubtitle(created)
    local parts = {}
    if created.slot and created.slot ~= "" then parts[#parts + 1] = created.slot end
    if created.binding then parts[#parts + 1] = created.binding end
    if created.levelRequirement then parts[#parts + 1] = created.levelRequirement.text end
    if #parts > 0 then return table.concat(parts, " \194\183 ") end
end

-- The item level plate under the icon is as wide as the icon's border, with
-- its text padded 5 on each side; a larger text grows the icon rather than
-- the plate, sized for a two-digit level so every item's icon is the same size.
local function itemIconSize(panel, badge, style)
    if not badge then return ICON_SIZE end
    return math.max(ICON_SIZE, math.ceil(measureStyled(panel, util.fill(L["iLvl %s"], 88), style)) + 8)
end

-- The widest of a list's rows, each plus extra; prose rows wrap.
local function listWidth(panel, list, style, extra, prose)
    local need = 0
    for _, row in ipairs(list) do
        local width = rowWidth(panel, row, style)
        if prose and (not row.right or row.right == "") then width = math.min(width, PROSE_WIDTH) end
        need = math.max(need, width + extra)
    end
    return need
end

-- Retail styles its secondary stats apart from the primary ones.
local function secondaryStyle(styles)
    return ns.IsRetail() and styles.secondaryStats or styles.stats
end

-- Retail's enchants with their quality icons sized to the text.
local function enchantRowsOf(model, styles)
    if ns.IsRetail() then return ns.Retail.Item.fittedRows(model.enchants, styles.enchants) end
    return model.enchants
end

-- Whether a retail item has gems or sockets.
local function hasSockets(model)
    return ns.IsRetail() and model.sockets ~= nil and #model.sockets > 0
end

-- Whether an item has stats, effects, gems, or flavor, drawn under the first divider.
local function hasStats(model)
    return model.weaponDps or model.weaponDamage or #model.weaponBonus > 0 or #model.armor > 0
        or #model.primary > 0 or #model.secondary > 0 or #model.equipEffects > 0 or #model.enchants > 0
        or #model.effects > 0 or #model.flavor > 0 or hasSockets(model) or model.imbues ~= nil
end

local function statsWidth(panel, model, styles)
    local need = math.max(
        listWidth(panel, model.armor, styles.armor, 0),
        listWidth(panel, model.primary, styles.stats, 0),
        listWidth(panel, model.secondary, secondaryStyle(styles), 0),
        listWidth(panel, enchantRowsOf(model, styles), styles.enchants, markerIndent(panel, styles.enchants)),
        listWidth(panel, model.imbues or {}, styles.enchants, markerIndent(panel, styles.enchants)),
        listWidth(panel, model.flavor, styles.flavor, 0, true))
    if hasSockets(model) then need = math.max(need, ns.Retail.Item.socketsWidth(panel, model.sockets, styles.gems)) end
    for _, row in ipairs(model.equipEffects) do
        need = math.max(need, math.min(measureStyled(panel, row.left, styles.equipEffects), PROSE_WIDTH)
            + markerIndent(panel, styles.equipEffects))
    end
    -- Use effects are indented past their gear.
    for _, row in ipairs(model.effects) do
        need = math.max(need, listWidth(panel, { row }, styles.effects,
            row.use and markerIndent(panel, styles.effects) or 0, true))
    end
    local swapped = swapsDamage(model)
    if model.weaponDps then
        need = math.max(need, measureStyled(panel, swapped and leadDamage(model)
            or valueLabel(model.weaponDps, DAMAGE_PER_SECOND), styles.dps))
    end
    if model.weaponDamage then
        need = math.max(need, measureStyled(panel, swapped and rateText(model) or weaponText(model), styles.damage) + 7)
    end
    for _, bonus in ipairs(model.weaponBonus) do
        need = math.max(need, measureStyled(panel, damageText(bonus), styles.damage) + 7)
    end
    if model.block then need = math.max(need, measureStyled(panel, armorText(model, model.armor[1], 1), styles.armor)) end
    return need
end

local function setWidth(panel, model, styles)
    local countWidth = measureStyled(panel, model.setCount or "", setCountStyle(styles.setName))
    return math.max(measureStyled(panel, model.setName, styles.setName) + math.max(45, countWidth + COLUMN_GAP),
        listWidth(panel, model.setItems, styles.setItems, 20),
        listWidth(panel, model.setBonuses, styles.setBonuses, 3, true))
end

local function createdWidth(panel, created, styles)
    local need = math.max(measureStyled(panel, created.name, styles.createdName) + CREATED_ICON + 8,
        statsWidth(panel, created, styles), created.setName and setWidth(panel, created, styles) or 0)
    local subtitle = createdSubtitle(created)
    if subtitle then
        need = math.max(need, math.min(measureStyled(panel, subtitle, styles.subtitle), PROSE_WIDTH) + CREATED_ICON + 8)
    end
    return need
end

local function footerWidth(panel, model, footerRight, style)
    local need = 0
    for index = 1, math.max(#model.footerLeft, #footerRight) do
        local left, right = model.footerLeft[index], footerRight[index]
        local leftWidth = 0
        if left and left.durability then
            leftWidth = DURABILITY_BAR + 7 + measureStyled(panel, left.durability[1] .. " / " .. left.durability[2], style)
        elseif left then
            leftWidth = measureStyled(panel, left.left, style)
        end
        need = math.max(need, leftWidth + COLUMN_GAP + (right and measureStyled(panel, footerText(right), style) or 0))
    end
    return need
end

local function durabilityColor(current, maximum)
    local ratio = maximum > 0 and current / maximum or 0
    if current == 0 then return { 1, .34, .28 } end
    if ratio < .25 then return { 1, .52, .25 } end
    if ratio < .5 then return { .95, .76, .30 } end
    return { .45, .80, .40 }
end

local function drawDurability(panel, durability, y, style)
    local current, maximum = durability[1], durability[2]
    local color = durabilityColor(current, maximum)
    local track = acquireTexture(panel, nil, 0)
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -(y + math.floor(style.size / 2)))
    track:SetSize(DURABILITY_BAR, 4)
    track:SetVertexColor(.16, .14, .13, 1)
    local fill = acquireTexture(panel, nil, 1)
    local width = maximum > 0 and DURABILITY_BAR * current / maximum or 0
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetSize(math.max(width, 1), 4)
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    if width < 1 then fill:Hide() end
    local healthy = maximum > 0 and current / maximum >= .5
    return styledAt(panel, current .. " / " .. maximum, pad() + DURABILITY_BAR + 7, y,
        math.max(90, style.size * 8), style, healthy and { .82, .78, .71 } or color)
end

-- Weapon damage, armor, stats, and effects.
local function drawStats(panel, model, styles, y)
    local inner = panel.width - 2 * pad()
    local top = y
    local swapped = swapsDamage(model)
    if model.weaponDps then
        y = drawRow(panel, {
            left = swapped and leadDamage(model) or valueLabel(model.weaponDps, DAMAGE_PER_SECOND),
            right = "",
        }, y, styles.dps, LARGE_COLOR) + 2
    end
    if model.weaponDamage or #model.weaponBonus > 0 then
        if model.weaponDamage then
            y = y + styledAt(panel, swapped and rateText(model) or weaponText(model), pad() + 7, y, inner - 7,
                styles.damage, SMALL_COLOR)
        end
        for _, bonus in ipairs(model.weaponBonus) do
            y = y + 2 + styledAt(panel, damageText(bonus), pad() + 7, y + 2, inner - 7, styles.damage,
                SMALL_COLOR)
        end
        y = y + 7
    end
    for index, row in ipairs(model.armor) do
        y = drawRow(panel, {
            left = armorText(model, row, index),
            right = row.right, rightColor = row.rightColor,
        }, y, styles.armor, LARGE_COLOR)
    end
    if #model.armor > 0 then y = y + 5 end
    if ns.IsRetail() then
        y = ns.Retail.Item.drawPrimary(panel, model.primary, y, styles.stats, { .90, .85, .74 })
    else
        y = drawGroup(panel, model.primary, y, styles.stats, { .90, .85, .74 })
    end
    -- The rest of the stats sit under a divider, whatever comes above them:
    -- a wand often has its damage and no primary stats.
    local above = #model.primary > 0 or #model.armor > 0 or model.weaponDps or model.weaponDamage
        or #model.weaponBonus > 0
    local underDivider
    if (#model.secondary > 0 or #model.equipEffects > 0) and above then
        y = divider(panel, y, GOLD_RULE, DIVIDER_AFTER)
        underDivider = y
    end
    y = drawGroup(panel, model.secondary, y, secondaryStyle(styles), { .90, .85, .74 })
    -- Enchants and gems stand apart from the rows around them, once between
    -- two of them; first under the divider, they start where anything would.
    local apartAt
    local function standApart()
        if y > top and y ~= underDivider and y ~= apartAt then
            y = y + APART_SPACE
            apartAt = y
        end
    end
    local enchanted = #model.enchants > 0 or (model.imbues ~= nil and #model.imbues > 0)
    local socketed = hasSockets(model)
    if enchanted then standApart() end
    y = drawMarked(panel, enchantRowsOf(model, styles), y, styles.enchants, { .90, .85, .74 }, ENCHANT_MARKER)
    -- Temporary enchants under the permanent ones.
    if model.imbues then y = drawMarked(panel, model.imbues, y, styles.enchants, { .90, .85, .74 }, ENCHANT_MARKER) end
    -- Use effects and flavor add their own space after them.
    if enchanted and (socketed or #model.equipEffects > 0) then standApart() end
    if socketed then
        standApart()
        y = ns.Retail.Item.drawSockets(panel, model.sockets, y, styles.gems)
        if #model.equipEffects > 0 then standApart() end
    end
    -- Equip effects after what is added to the item: its enchants and gems.
    y = drawMarked(panel, model.equipEffects, y, styles.equipEffects, EQUIP_EFFECT_COLOR, STAT_MARKER, true)
    -- Use effects and flavor stand apart from the stats above them; first under
    -- the divider, they start where anything would.
    if #model.effects > 0 and y > top then y = y + 5 end
    y = drawEffects(panel, model.effects, y, styles.effects, { .48, .88, .48 })
    if #model.flavor > 0 then
        y = drawGroup(panel, model.flavor, y > top and y + 5 or y, styles.flavor, FLAVOR_GOLD)
    end
    return y
end

-- The set's name and count, its pieces, and its bonuses.
local function drawSet(panel, model, styles, y)
    local inner = panel.width - 2 * pad()
    local countStyle = setCountStyle(styles.setName)
    local count = model.setCount or ""
    local countWidth = math.max(42, measureStyled(panel, count, countStyle) + 2)
    local titleHeight = styledAt(panel, model.setName, pad(), y, inner - countWidth - 3,
        styles.setName, { 1, .76, .18 })
    local countHeight = styledAt(panel, count, panel.width - pad() - countWidth, y, countWidth,
        countStyle, { 1, .76, .18 }, "RIGHT")
    y = y + math.max(24, titleHeight + 7, countHeight + 7)
    for _, row in ipairs(model.setItems) do
        local bullet, color = "|cff756C60-  |r", { .61, .58, .54 }
        if row.active == true then
            bullet, color = "|cffD9B36A-  |r", { .94, .89, .77 }
        elseif row.active == false then
            bullet, color = "|cff4A4540-  |r", { .44, .42, .40 }
        end
        y = drawRow(panel, { left = bullet .. row.left, right = row.right },
            y, styles.setItems, color, 5)
    end
    if #model.setBonuses > 0 then y = y + 7 end
    for _, row in ipairs(model.setBonuses) do
        local color = { .68, .65, .57 }
        if row.active == true then
            color = { .48, .88, .48 }
        elseif row.active == false then
            color = { .44, .42, .40 }
        end
        y = drawRow(panel, row, y, styles.setBonuses, color, 3)
    end
    return y
end

-- The item a recipe crafts: a small header, then its own stats and effects.
local function drawCreated(panel, created, styles, y)
    local inner = panel.width - 2 * pad()
    local quality = QUALITY[created.quality] or created.nameColor or QUALITY[1]
    local indent = 0
    local top = y
    if created.icon then
        local px = ui.pixel(panel)
        local border = acquireTexture(panel, nil, 0)
        border:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -ui.snap(panel, y))
        border:SetSize(CREATED_ICON + 2 * px, CREATED_ICON + 2 * px)
        border:SetVertexColor(quality[1] * .8, quality[2] * .8, quality[3] * .8, 1)
        local icon = acquireTexture(panel, created.icon, 1)
        icon:SetPoint("TOPLEFT", border, "TOPLEFT", px, -px)
        icon:SetSize(CREATED_ICON, CREATED_ICON)
        icon:SetTexCoord(.08, .92, .08, .92)
        indent = CREATED_ICON + 10
    end
    y = y + styledAt(panel, created.name, pad() + indent, y, inner - indent, styles.createdName, quality) + 2
    local subtitle = createdSubtitle(created)
    if subtitle then
        local unmet = created.levelRequirement and not created.levelRequirement.met
        y = y + styledAt(panel, subtitle, pad() + indent, y, inner - indent, styles.subtitle,
            unmet and UNUSABLE_COLOR or { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 2
    end
    y = math.max(y, top + CREATED_ICON + 2) + 8
    local stats = hasStats(created)
    if stats then y = drawStats(panel, created, styles, y) end
    if created.setName then y = drawSet(panel, created, styles, divider(panel, y, GOLD_RULE, stats and 11 or 0)) end
    return y
end

-- Durability and requirements on the left, prices on the right.
local function drawFooter(panel, model, footerRight, footer, y)
    local inner = panel.width - 2 * pad()
    for index = 1, math.max(#model.footerLeft, #footerRight) do
        local left = model.footerLeft[index]
        local right = footerRight[index]
        local h1, h2 = 0, 0
        local rightWidth = 0
        if right then
            local content = footerText(right)
            local color = { .88, .78, .60 }
            if right.requirement then
                color = right.met and { 1, 1, 1 } or { 1, .34, .28 }
            end
            rightWidth = math.min(measureStyled(panel, content, footer) + 2, inner * .6)
            h2 = styledAt(panel, content, panel.width - pad() - rightWidth, y,
                rightWidth, footer, color, "RIGHT")
        end
        if left and left.durability then
            h1 = drawDurability(panel, left.durability, y, footer)
        elseif left then
            h1 = styledAt(panel, left.left, pad(), y, inner - rightWidth - COLUMN_GAP,
                footer, left.color or { .82, .78, .71 })
        end
        y = y + math.max(h1, h2, footer.size + 2) + 4
    end
    return y
end

local function itemStyles()
    local styles = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if not element.tooltipType or element.tooltipType == "shared" then
            styles[element.key] = styleOf(element.key)
        end
    end
    return styles
end

-- A recipe's model keeps its ID; others keep the item's link.
local function itemID(model)
    if type(model.link) == "number" then return model.link end
    if type(model.link) == "string" then return tonumber(model.link:match("item:(%d+)")) end
end

local function itemView(panel, model)
    local styles = itemStyles()
    local icon = ns.option("iconItems") and model.icon or nil
    local badge = icon and ns.option("itemLevelBadge") and model.level
        and (model.equippable or model.levelLine) and util.fill(L["iLvl %s"], model.level) or nil
    local quality = QUALITY[model.quality] or QUALITY[1]
    local accent = model.quest and colors.quest or quality
    local header = { { text = model.name, style = styles.title, color = quality, gap = 4 } }
    if ns.IsRetail() then ns.Retail.Item.addSource(header, model, styles) end
    if model.slot and model.slot ~= "" then
        header[#header + 1] = { text = model.slot, style = styles.subtitle,
            color = { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }, gap = 4 }
    end
    if ns.IsRetail() then ns.Retail.Item.addUpgrade(header, model, styles) end
    header[#header + 1] = { rows = model.header, style = styles.header, color = { .78, .72, .63 }, gap = 3 }
    if ns.IsRetail() then ns.Retail.Item.addLooks(header, model, styles) end

    local sections, sectioned = {}, false
    local function section(entry) sections[#sections + 1] = entry end
    -- A quest the item begins comes first, as the game's quest givers mark it.
    if model.startsQuest then
        section({ separator = { space = 2 }, kind = "rows", rows = { { left = QUEST_MARK .. model.startsQuest, right = "" } },
            style = styles.effects, color = colors.quest, gap = 5 })
    end
    if hasStats(model) then
        section({ separator = { divider = GOLD_RULE }, kind = "custom",
            measure = function(p) return statsWidth(p, model, styles) end,
            draw = function(p, y) return drawStats(p, model, styles, y) end })
        sectioned = true
    end
    if model.setName then
        -- A divider after a section's rows sits as far below the last as above the
        -- next, as the one inside the stats does: the rows end with their gap.
        section({ separator = { divider = GOLD_RULE, before = sectioned and DIVIDER_AFTER or 0 }, kind = "custom",
            measure = function(p) return setWidth(p, model, styles) end,
            draw = function(p, y) return drawSet(p, model, styles, y) end })
        sectioned = true
    end
    if model.created then
        section({ separator = { caption = L["Creates"], style = styles.caption, before = sectioned and 6 or 0 },
            kind = "custom",
            measure = function(p) return createdWidth(p, model.created, styles) end,
            draw = function(p, y) return drawCreated(p, model.created, styles, y) end })
        sectioned = true
    end
    if model.reagents then
        section({ separator = { caption = L["Reagents"], style = styles.caption, before = 4 }, kind = "rows",
            rows = reagentRows(model), style = styles.reagents, color = { .90, .85, .74 }, gap = 3 })
        sectioned = true
    end
    if model.disenchant and ns.showsDetail("disenchant", panel) then
        section({ separator = { divider = GOLD_RULE, before = sectioned and DIVIDER_AFTER or 0 }, kind = "rows",
            rows = { disenchantHeading(model.disenchant) }, style = styles.disenchant, color = FLAVOR_GOLD, gap = 4 })
        section({ kind = "rows", rows = disenchantRows(model.disenchant), style = styles.disenchant,
            color = DISENCHANT_TEXT, gap = 2 })
        sectioned = true
    end
    local extras = ui.withID(panel, model.extras, L["Item ID: %s"], itemID(model))
    if #extras > 0 then
        section({ separator = sectioned and { rule = EXTRAS_RULE, before = RULE_AFTER } or { space = 12 }, kind = "rows",
            rows = extras, style = styles.extras, color = EXTRA_COLOR, gap = 2, wrap = true })
    end

    local footerRight = shownFooterRight(model)
    local footer
    if #model.footerLeft > 0 or #footerRight > 0 then
        footer = {
            measure = function(p) return footerWidth(p, model, footerRight, styles.footer) end,
            draw = function(p, y) return drawFooter(p, model, footerRight, styles.footer, y) end,
        }
    end
    return {
        tooltipType = "item",
        questItem = model.quest,
        color = accent,
        tint = (model.quest or model.quality >= 2) and accent or nil,
        icon = icon,
        iconSize = itemIconSize(panel, badge, styles.badge),
        badge = badge,
        -- A shield or off-hand is also compared against the one-hander from the
        -- bags it would be worn with; Blizzard heads that one "Equipped With".
        tag = model.comparison and util.upper(model.equippedWith and L["Equipped With"] or L["Equipped"]) or nil,
        header = header,
        sections = sections,
        footer = footer,
    }
end

local function render(panel, tooltip, model)
    ui.renderView(panel, tooltip, itemView(panel, model))
end
render = probe("render item", render)

-- An item nested in another tooltip, as the item a trainer's recipe spell
-- crafts: read from its own lines, and drawn as a recipe draws the item it creates.
ui.createdItem = {
    read = function(tooltip, data, game)
        local ok, item = pcall(readModel, tooltip, data, game)
        if not ok or not item or not item.name then return end
        -- Its name line starts with a line break; other addons' rows are the outer tooltip's.
        item.name, item.extras = util.trim(item.name), {}
        if item.skill and not item.levelRequirement then
            item.levelRequirement = { text = item.skill.text, met = item.skill.met }
        end
        return item
    end,
    section = function(created, before)
        local styles = itemStyles()
        return { separator = { caption = L["Creates"], style = styles.caption, before = before }, kind = "custom",
            measure = function(p) return createdWidth(p, created, styles) end,
            draw = function(p, y) return drawCreated(p, created, styles, y) end }
    end,
}

local function details(model, context)
    local rows = {}
    if model.disenchant and ns.showsDetail("disenchant", context) then
        local heading = disenchantHeading(model.disenchant)
        heading.color = FLAVOR_GOLD
        rows[1] = heading
        for _, row in ipairs(disenchantRows(model.disenchant)) do
            row.color = row.color or DISENCHANT_TEXT
            rows[#rows + 1] = row
        end
    end
    rows[#rows + 1] = ui.idRow(context, L["Item ID: %s"], itemID(model))
    return rows
end

ns.TooltipTypes[ITEM] = { read = readModel, render = render, key = getItemInfo, option = "itemPanels",
    details = details, detailKeys = { "disenchant", "showIDs" } }
