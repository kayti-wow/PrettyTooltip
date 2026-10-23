-- Items as a panel: the reader, which turns the game's item lines into a
-- model, and the view, which says what to draw; Panel/Render.lua draws it.
local _, ns = ...
local ui = ns.ui
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if not (ui and ITEM) then
    return
end

-- What this file registers as the item tooltip type. A client's file loaded
-- after this one can set descriptor.extension, with any of these callbacks
-- (Retail/README.md; retail's is Retail/Tooltips/ItemExtension.lua). item is
-- the model a line goes to: the item's own or, inside a recipe, the crafted
-- item's. The contexts are described at newRead, below.
--   initModel(model) for every new model: an item's, a crafted item's inside
--     it, and the editor's samples
--   readText(left, right, line, context) -> left, right: a line's text, repaired
--   findKind(name, kinds) -> the kind a longer name holds: "Zandalari Crafting Reagent"
--   isProfession(name, professions, marked) -> whether a requirement names a
--     profession the shared list does not; marked: the game marks it a requirement
--   isSetBonus(text, line, context), isSetPiece(left, item, context) -> whether
--     a line in an item set is a bonus, or a piece, the shared reader would miss
--   readLine(item, line, context) -> true when the client takes the line itself
--   afterReadLine(item, line, context) after each line, taken or not
--   afterRead(model, context) once the item is read, a crafted item first
--   extendView(view, model, context) adds to the view before it is measured
--     and drawn; context has panel and styles
local descriptor = {}

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
local ARMOR_CLASS = Enum.ItemClass and Enum.ItemClass.Armor or 4
local ARMOR_KEYS = {}
for _, armor in ipairs(ns.Palette.ARMOR) do ARMOR_KEYS[armor.subClass] = armor.key end
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
    -- Retail's artifacts, heirlooms, and tokens, in the game's colors.
    [6] = { .90, .80, .50 },
    [7] = { 0, .80, 1 },
    [8] = { 0, .80, 1 },
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
-- Kinds of item the game names on a line of their own, as "Crafting Reagent",
-- then a client's own (ns.contribute "itemKinds"), as retail's reagent kinds.
local ITEM_KINDS = {}
for _, kind in pairs({ PROFESSIONS_USED_IN_COOKING, formats.scarce }) do ITEM_KINDS[#ITEM_KINDS + 1] = kind end
for _, extra in ipairs(ns.contributions("itemKinds")) do
    for _, kind in ipairs(extra) do ITEM_KINDS[#ITEM_KINDS + 1] = kind end
end
local ITEM_KIND_NAMES = {}
for _, kind in ipairs(ITEM_KINDS) do ITEM_KIND_NAMES[kind:lower()] = kind end
local function kindNamed(name)
    return ITEM_KIND_NAMES[name:lower()]
end

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
        -- Only an item link: a keystone's "|Hkeystone:" one is no item to the
        -- game's item calls, which give it the question mark icon.
        if ok and not isSecret(link) and type(link) == "string" and (link:find("|Hitem:", 1, true)
            or not link:find("|H", 1, true)) then
            return link
        end
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
    local grey = ns.TooltipData.isGrey(color)
    if grey == nil then return nil end
    return not grey
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

-- Every class wears a cloak, so its cloth tells nothing.
local function armorClass(itemType)
    if not itemType or itemType.classID ~= ARMOR_CLASS or itemType.equipLoc == "INVTYPE_CLOAK" then return end
    return ARMOR_KEYS[itemType.subClassID]
end

-- The armor type leads the subtitle, "Plate · Chest", in its color when the
-- setting is on. A type the player cannot wear has no armorClass, so stays red.
local function armorSlot(item)
    local color = ns.option("armorColors") and ns.Palette.armorColor(item.armorClass)
    if not color then return item.slot end
    local stop = item.slot:find(" \194\183 ", 1, true) or #item.slot + 1
    return "|cff" .. util.hex(color) .. item.slot:sub(1, stop - 1) .. "|r" .. item.slot:sub(stop)
end
-- A stack's per-item price, beside its total: a muted shade of the footer's gold.
local PRICE_DETAIL = "9E9485"

-- Can arrive color coded, or appended outside the tooltip data.
local function itemKind(left, right, color)
    if right ~= "" then return end
    local name = plainText(left):match("^%s*(.-)%s*$")
    local kind = kindNamed(name)
    -- A client can find a kind inside a longer name: "Zandalari Crafting Reagent".
    local extension = descriptor.extension
    if not kind and extension and extension.findKind then kind = extension.findKind(name, ITEM_KINDS) end
    if not kind then return end
    local shown = kindNamed(name) and kind or name
    local code = left:match("|c(%x%x%x%x%x%x%x%x)")
    if code then return kind, "|c" .. code .. shown .. "|r" end
    -- The game's line color has r, g, and b; an appended row's is a list.
    if isSecret(color) or type(color) ~= "table" then return kind, shown end
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return kind, shown
    end
    return kind, "|cff" .. util.hex({ r, g, b }) .. shown .. "|r"
end

local STAT_MARKER = ns.Stats.MARKER
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

-- Whether a name is a profession's: its own, or one a client recognizes, as
-- retail's "Midnight Blacksmithing". marked: the game marks the line as a
-- requirement.
local function isProfession(name, marked)
    if PROFESSIONS[name] then return true end
    local extension = descriptor.extension
    return extension ~= nil and extension.isProfession ~= nil and extension.isProfession(name, PROFESSIONS, marked) == true
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
    local model = {
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
        -- Gems, empty sockets, and the socket bonus, as the game lists them.
        sockets = {},
    }
    -- A client can add its own fields (retail's model.retail); shared code adds none.
    local extension = descriptor.extension
    if extension and extension.initModel then extension.initModel(model) end
    return model
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

local finishCreated

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
    if model.created then
        finishCreated(tooltip, model, game)
    elseif model.teaches then
        add(model.effects, model.teaches.left, model.teaches.right)
    end
    for _, reagent in ipairs(model.reagents or {}) do
        local link = itemByName(reagent.name, game)
        reagent.have = game.itemCount(link or reagent.name)
    end
end

-- The item inside another's tooltip, a recipe's or an artifact's pair: its link,
-- icon, and quality, and its binding where the outer item's differs.
finishCreated = function(tooltip, model, game)
    local created = model.created
    do
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
        if not link and created.id then
            -- Retail names it by its id on the line it is nested under, which
            -- gives the icon before the item loads.
            link, icon = created.id, game.itemIcon(created.id)
            local info = game.itemInfo(created.id)
            if info and type(info.quality) == "number" then quality = info.quality end
        end
        created.link, created.icon = link, icon
        -- Its kinds, "Optional Crafting Reagent", under its name, as the item's own.
        local kinds = {}
        for _, kind in ipairs(ITEM_KINDS) do kinds[#kinds + 1] = created.kinds[kind] end
        if #kinds > 0 then
            local joined = table.concat(kinds, " \194\183 ")
            created.slot = created.slot and created.slot ~= "" and (created.slot .. " \194\183 " .. joined) or joined
        end
        created.quality = type(quality) == "number" and quality or nil
        -- The crafted item's binding usually repeats the recipe's.
        local recipeBinding = model.header[1] and model.header[1].left
        local bindings = {}
        for _, row in ipairs(created.header) do
            if row.left ~= recipeBinding then bindings[#bindings + 1] = plainText(row.left) end
        end
        created.binding = #bindings > 0 and table.concat(bindings, " \194\183 ") or nil
    end
end

-- Reading ----------------------------------------------------------------------

-- Each of an item's lists of rows and how long it is, before a line is read,
-- into counts, which one read reuses from line to line: counts.lists[key] is
-- the list, counts.lengths[key] its length. A key left from another item's
-- lines is never asked for, or names another list, which addedRows tells.
local function listCounts(item, counts)
    counts = counts or { lists = {}, lengths = {} }
    local lists, lengths = counts.lists, counts.lengths
    for key, value in pairs(item) do
        if type(value) == "table" then lists[key], lengths[key] = value, #value end
    end
    return counts
end

-- The rows a line added to the item, after listCounts, into added, which one
-- read reuses: each with the name of its list, the list, and its place in
-- it, in order within a list.
local function addedRows(item, counts, added)
    added = added or {}
    for index = #added, 1, -1 do added[index] = nil end
    local lists, lengths = counts.lists, counts.lengths
    for key, value in pairs(item) do
        if type(value) == "table" then
            local from = lists[key] == value and lengths[key] or 0
            for index = from + 1, #value do
                local row = value[index]
                if type(row) == "table" and row.left ~= nil then
                    added[#added + 1] = { list = key, rows = value, row = row, at = index }
                end
            end
        end
    end
    return added
end

-- One read of an item's tooltip: the model it fills, and what it keeps from
-- line to line.
--
-- A client's callbacks (descriptor.extension) get a context. For the whole
-- read it has nativeTooltip, data, game, rootModel (the item's own model),
-- and state, a table the client keeps its own notes in. Each line the tooltip
-- shows gets a fresh one that also has the line's: lineNumber, its place in
-- data.lines; lineModel, the model the line started in; originalText, its
-- left text as the game sent it; leftText, as the panel words it; text, that
-- trimmed; rightText; and for afterReadLine, added, the rows the line added
-- (addedRows, a list reused from line to line). afterRead's has no line's
-- fields, but itemType and recipe, what the reader made of the whole item.
local function newRead(tooltip, data, game, model)
    local extension = descriptor.extension
    local read = {
        tooltip = tooltip,
        data = data,
        game = game,
        model = model,
        extension = extension,
        -- The model the lines go to: the item's or, inside a recipe's embedded
        -- tooltip, the crafted item's.
        item = model,
        -- In an item set's lines, and how many pieces it has.
        inSet = false,
        setTotal = 0,
        -- The line before taught a recipe; the lines are the game's "If you
        -- replace this item" changes; the line before was blank.
        teachesLast = false,
        inStockChanges = false,
        blankBefore = false,
        -- The models, recipe or crafted item, whose type the game does not show red.
        wearable = {},
        -- And nestedID, the item a nested block holds: a recipe's crafted item.
    }
    if extension then
        read.context = { nativeTooltip = tooltip, data = data, game = game, rootModel = model, state = {} }
        -- A line's context finds the read's fields through its metatable.
        read.lineContext = { __index = read.context }
    end
    return read
end

-- Whether text is one of the game's "If you replace this item" lines: its
-- heading, and the stat changes under it.
local function isStockChange(read, text)
    local trimmed = plainText(text):match("^%s*(.-)%s*$")
    if unformat(trimmed, STOCK_CHANGES) then
        read.inStockChanges = true
        return true
    end
    if read.inStockChanges and (trimmed == "" or lineParts(trimmed)) then
        return true
    end
    read.inStockChanges = false
    return false
end

-- Reads a line with something to say into read.item: the item's sets, weapon
-- damage, armor, stats, effects, flavor, and footer, or other addons' rows.
-- left and trimmed are its text as the panel words it, original the game's
-- when the panel words it otherwise.
local function readContent(read, line, context, left, right, trimmed, original)
    local item, model, game, extension = read.item, read.model, read.game, read.extension
    local lineType = line.type
    local setName, count, total = unformat(trimmed, ITEM_SET_NAME)
    if setName and tonumber(count) and tonumber(total) and not item.setName then
        item.setName, item.setCount = setName, count .. "/" .. total
        read.inSet, read.setTotal = true, tonumber(total)
    elseif LINE.SellPrice and lineType == LINE.SellPrice then
        item.hasSellPrice = true
    elseif unformat(trimmed, ITEM_MIN_LEVEL) and right == "" then
        item.levelRequirement = {
            text = trimmed, met = requirementOf(line, lineType, trimmed, game),
        }
    elseif isType(lineType, "UsageRequirement") or unformat(trimmed, ITEM_REQ_SKILL) then
        add(item.footerRight, left, right)
        local entry = item.footerRight[#item.footerRight]
        entry.requirement = true
        entry.met = requirementOf(line, lineType, trimmed, game)
    elseif tonumber((unformat(trimmed, DURABILITY_TEMPLATE))) then
        add(item.footerLeft, trimmed, right)
        local current, maximum = unformat(trimmed, DURABILITY_TEMPLATE)
        item.footerLeft[#item.footerLeft].durability =
            { tonumber(current), tonumber(maximum) }
    elseif unformat(trimmed, ITEM_CLASSES_ALLOWED) or unformat(trimmed, ITEM_RACES_ALLOWED)
        or unformat(trimmed, TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN)
        or unformat(trimmed, TRANSMOGRIFY_STYLE_UNCOLLECTED) or unformat(trimmed, formats.appearance) then
        add(item.footerLeft, left, right)
        if isRed(line.leftColor) then
            item.footerLeft[#item.footerLeft].color = UNUSABLE_COLOR
        elseif item ~= model then
            -- The item a recipe crafts keeps it under its stats, in the
            -- game's color: "You haven't collected this appearance".
            item.footerLeft[#item.footerLeft].color = rgb(line.leftColor)
        end
    -- A client can recognize more of a set's bonuses, as retail's active "Set: ...".
    elseif read.inSet and (unformat(trimmed, ITEM_SET_BONUS_GRAY)
        or (extension and extension.isSetBonus and extension.isSetBonus(trimmed, line, context))) then
        add(item.setBonuses, left, right)
        item.setBonuses[#item.setBonuses].active = isActive(line.leftColor)
    -- Set pieces are names alone: letters (of any alphabet), spaces,
    -- apostrophes, and hyphens. A client can allow more pieces than the
    -- set counts, as retail's appearance sets list.
    elseif read.inSet and (#item.setItems < read.setTotal
        or (extension and extension.isSetPiece and extension.isSetPiece(left, item, context)))
        and right == "" and trimmed:gsub("[%a'%- \128-\255]", "") == "" then
        add(item.setItems, trimmed, right)
        item.setItems[#item.setItems].active = isActive(line.leftColor)
    -- A wand names its school: "64 - 120 Shadow Damage".
    elseif amount(unformat(right, formats.weaponSpeed)) and (weaponDamage(trimmed, DAMAGE_TEMPLATE)
        or weaponDamage(trimmed, DAMAGE_TEMPLATE_WITH_SCHOOL)) then
        item.weaponDamage, item.weaponSpeed = left, right
    elseif weaponDamage(trimmed, PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL) then
        -- A weapon's bonus damage of a school, drawn under its base damage.
        item.weaponBonus[#item.weaponBonus + 1] = trimmed
    elseif amount(unformat(trimmed, DPS_TEMPLATE)) then
        item.weaponDps = unformat(trimmed, DPS_TEMPLATE)
    elseif amount(unformat(trimmed, ARMOR_TEMPLATE)) then
        add(item.armor, left, right)
        item.armor[#item.armor].value = (unformat(trimmed, ARMOR_TEMPLATE):gsub("%D", ""))
    elseif SHIELD_BLOCK_TEMPLATE and amount(unformat(trimmed, SHIELD_BLOCK_TEMPLATE)) then
        -- A shield's block joins its armor's line, or stands for it without one.
        if #item.armor > 0 then
            item.block, item.blockValue = trimmed, unformat(trimmed, SHIELD_BLOCK_TEMPLATE)
        else
            add(item.armor, left, right)
        end
    elseif ((LINE.ItemSpellTriggerOnProc and lineType == LINE.ItemSpellTriggerOnProc)
        or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONPROC)) and right == "" then
        -- Rewritten proc text stays an effect, rather than a stat.
        local text = original or trimmed
        add(item.equipEffects, withoutLabel(text, ITEM_SPELL_TRIGGER_ONPROC), "")
        item.equipEffects[#item.equipEffects].onHit = true
    elseif original or lineParts(trimmed) == "+" then
        -- Combined bonuses arrive as one line; each stat needs its own row.
        for piece in (left .. "|n"):gmatch("(.-)|n") do
            local stat = ns.Stats.read(plainText(piece))
            add(stat and PRIMARY_STATS[stat.key] and item.primary or item.secondary, piece, right)
            right = ""
        end
    elseif isType(lineType, "FlavorText") or trimmed:match('^".+"$') then
        add(item.flavor, left, right)
    elseif isType(lineType, "ItemEnchantmentPermanent") and right == "" then
        -- The enchant follows its label, "Enchanted:".
        local text = util.trim(plainText(left))
        for _, row in ipairs(enchantRows(text:match("^[^:]-:%s*(.+)$") or text)) do add(item.enchants, row, "") end
    elseif readCopyLine(item, left, right) then
        -- Crafter or enchant, taken into their own rows.
    elseif trimmed:match("^<.+>$") then
        add(item.effects, left, right)
    elseif (isType(lineType, "ItemSpellTriggerOnEquip") or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP))
        and right == "" then
        -- Unparsed equip effects join the stats; the list implies "Equip:".
        add(item.equipEffects, withoutLabel(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP), "")
    elseif (isType(lineType, "ItemSpellTriggerOnUse") or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE))
        and right == "" then
        -- Its gear marker stands for the words.
        add(item.effects, withoutLabel(trimmed, ITEM_SPELL_TRIGGER_ONUSE), "")
        item.effects[#item.effects].use = true
    elseif isType(lineType, "ItemSpellTriggerOnUse") or isType(lineType, "ItemSpellTriggerOnEquip")
        or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONEQUIP) or startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE) then
        add(item.effects, left, right)
    else
        addExtra(item, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
    end
end

-- Reads the text of a line the tooltip shows into read.item: first what
-- shapes the tooltip (a recipe's lines, the crafted item inside it, names and
-- levels, bindings, slots, and kinds), then, through readContent, the rest.
-- False when its text is hidden, which leaves the whole read.
local function readText(read, line, context)
    local model, game, extension = read.model, read.game, read.extension
    local left, right = safeText(line.leftText), safeText(line.rightText)
    if not left or not right then return false end
    if extension and extension.readText then left, right = extension.readText(left, right, line, context) end
    if context then context.originalText = left end
    local lineType = line.type
    model.lineIndices[line.lineIndex] = true
    -- Read as the panel words it, each stat of a combined bonus apart.
    local wording = ns.TooltipData.itemWording(line)
    local original = wording and left
    if wording then left = wording.display end
    local trimmed = left:match("^%s*(.-)%s*$")
    local item = read.item
    local startsQuest = unformat(trimmed, ITEM_STARTS_QUEST)
    if startsQuest or unformat(trimmed, ITEM_BIND_QUEST) then
        item.quest = true
    end
    if context then context.leftText, context.text, context.rightText = left, trimmed, right end

    local afterTeaches = read.teachesLast
    read.teachesLast = false
    if isStockChange(read, left) then
        addExtra(item, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
    elseif isType(lineType, "ItemSpellTriggerLearn") or unformat(trimmed, formats.recipeTeaches) then
        -- Its type marks it in every language; cooking words it apart from
        -- the other professions ("烹制", not "制作"). The recipe's own lines follow.
        model.teaches = { left = left, right = right }
        read.teachesLast = true
        if model.created then read.item = model end
    elseif afterTeaches and model.created and not model.reagents and right == ""
        and (lineType == nil or isType(lineType, "None")) and reagentList(trimmed, true) then
        model.reagents, read.item = reagentList(trimmed, true), model
    elseif item == model and startsQuest then
        model.startsQuest = trimmed
    elseif professionRequirement(trimmed, lineType) and (item == model or (model.created and not model.skill)) then
        -- A recipe's skill, before the item it creates or, as on cooking
        -- recipes, after it; once the recipe has one, the item's own.
        local name, level = professionRequirement(trimmed, lineType)
        model.skill = { name = name, level = level, text = left, met = requirementMet(trimmed, line.leftColor, game) }
    elseif model.created and not model.reagents and reagentList(trimmed) then
        model.reagents, read.item = reagentList(trimmed), model
    elseif lineType == LINE.ItemName then
        if not model.name then
            model.name, model.nameColor = left, rgb(line.leftColor)
        elseif not model.created then
            model.created = newItemModel()
            -- Its name line starts with a line break.
            model.created.name, model.created.nameColor = trimmed, rgb(line.leftColor)
            model.created.id = read.nestedID
            read.item = model.created
        end
    elseif lineType == LINE.ItemLevel then
        local level = left:match("(%d+)")
        if level then item.level, item.levelLine = tonumber(level), true end
    elseif extension and extension.readLine and extension.readLine(item, line, context) == true then
        -- The client took the line. Recipe routing, names and levels, and
        -- the sell price stay the shared reader's.
    elseif right == "" and imbueLine(plainText(trimmed)) then
        -- A weapon's temporary enchant, "Windfury Weapon (59 min)", under its enchants.
        item.imbues = item.imbues or {}
        for _, row in ipairs(enchantRows(util.trim(plainText(trimmed)))) do add(item.imbues, row, "") end
    elseif lineType == LINE.EquipSlot then
        item.equippable = true
        local slot = unusable(left, line.leftColor)
        local kind = unusable(right, line.rightColor)
        item.slot = right ~= "" and (kind .. " \194\183 " .. slot) or slot
        read.wearable[item] = right ~= "" and not isRed(line.rightColor)
    elseif lineType == LINE.ItemBinding or isBinding(trimmed) then
        add(item.header, left, right)
        if isRed(line.leftColor) then item.header[#item.header].color = UNUSABLE_COLOR end
    elseif right == "" and tonumber((unformat(trimmed, CONTAINER_SLOTS))) then
        local count, kind = unformat(trimmed, CONTAINER_SLOTS)
        item.bag = { count = tonumber(count), kind = kind }
    elseif itemKind(left, right) then
        local kind, text = itemKind(left, right, line.leftColor)
        item.kinds[kind] = text
    elseif trimmed ~= "" then
        readContent(read, line, context, left, right, trimmed, original)
    end
    -- After the shared reader, even when the client took the line; inside a
    -- recipe, the model it went to is the crafted item's.
    if extension and extension.afterReadLine then
        read.added = addedRows(context.lineModel, read.counts, read.added)
        context.added = read.added
        extension.afterReadLine(read.item, line, context)
    end
    return true
end

-- Reads one of the item's lines into read.item: what its data holds (a nested
-- item's id, the sell price) and, for a line the tooltip shows, its text.
-- False when the line cannot be read safely, which leaves the whole read.
local function readLine(read, lineNumber, line)
    if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then
        return false
    end
    local item = read.item
    local context
    if read.context and line.lineIndex then
        context = setmetatable({ lineNumber = lineNumber, lineModel = item }, read.lineContext)
        read.counts = listCounts(item, read.counts)
    end
    -- The item a nested block holds, by its id: a recipe's crafted item.
    if LINE.NestedBlock and line.type == LINE.NestedBlock and not isSecret(line.tooltipType)
        and line.tooltipType == ITEM then
        read.nestedID = number(line.tooltipID)
    end
    local effects, effectCount = item.effects, #item.effects
    -- The amount is drawn by a money frame, not as text, so take it from the data.
    if LINE.SellPrice and line.type == LINE.SellPrice then
        item.hasSellPrice = true
        local price = number(line.price)
        if price then item.sellPrice = price end
    end
    if line.lineIndex and not readText(read, line, context) then return false end
    -- An effect the game sets apart from the one before with a blank line
    -- stays apart: "Use:", "When crafting:", "Usable with:".
    if read.blankBefore and effectCount > 0 and #effects > effectCount then effects[effectCount + 1].apart = true end
    local blankLeft, blankRight = safeText(line.leftText), safeText(line.rightText)
    read.blankBefore = blankLeft ~= nil and blankLeft:match("^%s*$") ~= nil and (blankRight or "") == ""
    return true
end

-- The rows the game draws outside its data, and other addons', which follow
-- the item's lines. False when one cannot be read, which leaves the whole read.
local function readAppended(read)
    local model = read.model
    local appended = appendedRows(read.tooltip, model.lineIndices)
    if not appended then return false end
    local addAppended = ns.TooltipData.extrasAdder(model.extras)
    for _, row in ipairs(appended) do
        local trimmed = row.left:match("^%s*(.-)%s*$")
        if isStockChange(read, row.left) then
            addAppended(row)
        elseif model.created and not model.reagents and reagentList(trimmed) then
            model.reagents = reagentList(trimmed)
        elseif startsWith(trimmed, SELL_PRICE) then
            model.hasSellPrice = true
        elseif itemKind(row.left, row.right) then
            local kind, text = itemKind(row.left, row.right, row.textColor)
            model.kinds[kind] = text
        elseif readCopyLine(model, row.left, row.right) then
            -- Crafter or enchant, taken into their own rows.
        else
            addAppended(row)
        end
    end
    return true
end

-- An item inside another's tooltip that nothing teaches or crafts is its
-- pair, as an artifact's off hand. Hints after it, "<Shift Right Click to
-- View Artifact>", are the outer item's.
local function findPair(read)
    local model = read.model
    if not model.created or model.teaches or model.skill or model.reagents then return end
    model.created.paired = true
    local kept = {}
    for _, row in ipairs(model.created.effects) do
        if plainText(row.left):match("^%s*<.+>%s*$") then add(model.effects, row.left, row.right)
        else kept[#kept + 1] = row end
    end
    model.created.effects = kept
    finishCreated(read.tooltip, model, read.game)
end

-- The required level beside the binding, or with the footer's requirements
-- when something else is there.
local function placeLevelRequirement(model)
    local level = model.levelRequirement
    if not level then return end
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

-- The crafter's name, under the durability.
local function placeMadeBy(model)
    if not model.madeBy then return end
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

-- The item's kinds after its slot: what the game never says, that it is a
-- consumable and what kind, and the kinds it named on their own lines.
local function addKinds(model, itemType)
    local shown = {}
    local className, subClassName = itemType and itemType.className, itemType and itemType.subClassName
    if itemType and itemType.classID == CONSUMABLE_CLASS and type(className) == "string" and className ~= "" then
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
end

-- The sell price in the footer. The item's own price is per unit; the data
-- line's covers the stack. The coins say what the amount is. A stack leads
-- with its total, then the count and one item's price, dimmed: 2g  (20 × 10s).
local function addSellPrice(read, itemInfo)
    local model, game = read.model, read.game
    local unitPrice
    local info = model.hasSellPrice and game.itemInfo(itemInfo)
    if info and type(info.price) == "number" and info.price > 0 then unitPrice = info.price end
    local count = unitPrice and stackCount(read.data, unitPrice, model.sellPrice, game) or 1
    local price = count > 1 and unitPrice or model.sellPrice or unitPrice
    if price and price > 0 then
        local text = formatMoney(price * count)
        if count > 1 then
            text = text .. "  |cff" .. PRICE_DETAIL .. "(" .. count .. " \195\151 " .. formatMoney(price) .. ")|r"
        end
        add(model.footerRight, text, "")
        model.footerRight[#model.footerRight].sellPrice = true
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
    local read = newRead(tooltip, data, game, model)
    for lineNumber, line in ipairs(data.lines) do
        if not readLine(read, lineNumber, line) then return end
    end
    if not model.name or model.name == "" then return end
    if not readAppended(read) then return end
    findPair(read)
    -- Crafted gear can need a profession too; only a recipe teaches.
    local recipe = (model.created and not model.created.paired) or (model.skill and model.teaches)
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
    local itemType = game.itemType(itemInfo)
    local classID = itemType and itemType.classID
    if read.wearable[model] then model.armorClass = armorClass(itemType) end
    if model.created and read.wearable[model.created] then
        model.created.armorClass = armorClass(game.itemType(model.created.link))
    end
    if ns.hasData("disenchant") and classID and not recipe then
        local itemLevel = game.itemLevel(itemInfo) or model.level
        model.disenchant = ns.disenchantFor(classID, model.quality, tonumber(itemLevel), itemType.equipLoc,
            itemType.id, game)
    end
    placeLevelRequirement(model)
    placeMadeBy(model)
    addKinds(model, itemType)
    withBagSlots(model)
    if model.created then withBagSlots(model.created) end
    addSellPrice(read, itemInfo)
    model.quest = model.quest or classID == QUEST_CLASS
    model.comparison = isComparison(tooltip)
    model.equippedWith = model.comparison and game.isEquipped(model.link) == false or nil
    local extension = read.extension
    if extension and extension.afterRead then
        -- What the game says the item is, and whether it is a recipe, which
        -- the reader has already worked out.
        read.context.itemType, read.context.recipe = itemType, recipe and true or false
        if model.created then extension.afterRead(model.created, read.context) end
        extension.afterRead(model, read.context)
    end
    return model
end
readModel = probe("read item", readModel)

-- Native details need identity and disenchant metadata, never the item's
-- stats, effects, appended native lines, or the Pretty presentation model.
local function readDetails(tooltip, data, game)
    if isSecret(data) or type(data) ~= "table" then return end
    local itemInfo = getItemInfo(tooltip, data)
    local id = number(data.id)
    local shownID = type(itemInfo) == "string" and tonumber(itemInfo:match("item:(%d+)")) or number(itemInfo)
    -- GetItem can name a recipe's crafted item. Details belong to the recipe.
    if id and id ~= shownID then itemInfo = id end
    local model = { link = itemInfo }
    if ns.option("disenchant") and ns.hasData("disenchant") then
        local itemType = game.itemType(itemInfo)
        if itemType and itemType.classID then
            model.disenchant = ns.disenchantFor(itemType.classID, getQuality(itemInfo, data, game),
                getLevel(itemInfo, game), itemType.equipLoc, itemType.id, game)
        end
    end
    return model
end
readDetails = probe("read item details", readDetails)

-- The game can send quality icons at 20 px; a line's icon is its text's height.
local function fitAtlases(text, size)
    if type(text) ~= "string" then return text end
    size = math.floor((size or 12) + .5)
    return (text:gsub("|A:([^:|]+)[^|]*|a", function(atlas)
        return "|A:" .. atlas .. ":" .. size .. ":" .. size .. ":0:0|a"
    end))
end
ui.fitAtlases = fitAtlases

-- Copies of rows with their quality icons at the style's size.
local function fittedRows(rows, style)
    local fitted = {}
    for index, row in ipairs(rows or {}) do
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        copy.left = fitAtlases(row.left, style.size)
        fitted[index] = copy
    end
    return fitted
end

-- A style that leaves an inactive row in its own color, the game's grey or
-- red, even under a color set in the editor.
local function inactiveStyle(style)
    return setmetatable({ color = false }, { __index = style })
end

-- Rows each in turn, an inactive one in its own color.
local function drawRows(panel, rows, y, style, color)
    local inactive = inactiveStyle(style)
    for _, row in ipairs(rows) do
        y = drawRow(panel, row, y, row.inactive and inactive or style, color)
    end
    return y
end

-- A socket's icon is a little larger than its text, and drawn apart from it:
-- an icon in the text sits on its baseline and hangs below, leaving the text
-- high. Apart, it is centered on the line, and the text starts after it.
local SOCKET_ICON_GAP = 4
local GEM_COLOR = { .90, .85, .74 }

-- A border (frame, an atlas, as an essence slot's) is half as wide again as
-- it is tall, as the game draws it at 18 by 12; an icon inside it takes 10 of
-- those 12.
local FRAME_ASPECT, FRAMED_ICON = 18 / 12, 10 / 12

local function socketIconSize(style)
    return math.floor((style.size or 12) * 1.25 + .5)
end

-- The width a socket's art takes: its border, else its icon; 0 with neither.
local function socketArtWidth(row, style)
    if row.frame then return math.floor(socketIconSize(style) * FRAME_ASPECT + .5) end
    if row.icon then return socketIconSize(style) end
    return 0
end

-- Where a socket's text starts: past its art, when it has some.
local function socketIndent(row, style)
    local indent = row.indent or 0
    local art = socketArtWidth(row, style)
    if art > 0 then indent = indent + art + SOCKET_ICON_GAP end
    return indent
end

-- One texture of a socket's art, centered on the line at x.
local function socketTexture(panel, y, x, width, height, style, sublevel, row)
    -- The line is the text's size and 2 tall (Panel/Layout.lua's textAt).
    local top = y + (style.size + 2 - height) / 2
    local texture = acquireTexture(panel, nil, sublevel)
    texture:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -ui.snap(panel, top))
    texture:SetSize(width, height)
    if row.desaturated then texture:SetDesaturated(true) end
    return texture
end

local function socketsWidth(panel, sockets, style)
    local need = 0
    for _, row in ipairs(sockets) do
        need = math.max(need, rowWidth(panel, row, style) + socketIndent(row, style))
    end
    return need
end

local function drawSockets(panel, sockets, y, style)
    for _, row in ipairs(sockets) do
        local x, size = pad() + (row.indent or 0), socketIconSize(style)
        local width = socketArtWidth(row, style)
        if row.icon then
            -- Inside its border, when it has one.
            local iconSize = row.frame and math.floor(size * FRAMED_ICON + .5) or size
            local icon = socketTexture(panel, y, x + (width - iconSize) / 2, iconSize, iconSize, style, 1, row)
            icon:SetTexture(row.icon)
            local coords = row.iconCoords
            if coords then icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
        end
        if row.frame then
            socketTexture(panel, y, x, width, size, style, 2, row):SetAtlas(row.frame)
        end
        y = drawRow(panel, row, y, style, GEM_COLOR, socketIndent(row, style), 3)
    end
    return y
end

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
        local text, rowStyle, rowColor = row.left, style, color
        if row.inactive then
            text, rowStyle, rowColor = util.uncolored(text), inactiveStyle(style), row.color
        elseif numbers then
            text = ns.Stats.styleEffect(text, ns.option("statColors"))
        end
        local stands = row.onHit and MARKED.onHit or row.use and MARKED.use
        if row.note then
            -- A note on the effects, under their text, in its own color.
            if not row.inactive then text, rowColor = row.left, row.color or color end
        elseif hang > 0 then
            local shown = stands and stands[1] or marker
            if row.inactive then shown = ns.Stats.tintedMarker(shown, row.color) end
            styledAt(panel, shown, pad(), y, hang, rowStyle, rowColor)
        elseif stands then
            -- Without its marker, the line keeps its words.
            text = (stands[2] or "") .. text
        end
        y = y + styledAt(panel, text, pad() + hang, y, width, rowStyle, rowColor) + 3
    end
    return y
end

-- Use effects are led by the gear; the group's other rows, such as
-- "<Right Click to Open>", are drawn as they come, with space where the game
-- left a blank line between them.
local function drawEffects(panel, list, y, style, color)
    for index, row in ipairs(list) do
        -- Set apart by the game, as enchants and gems are from the rows around them.
        if row.apart and index > 1 then y = y + APART_SPACE end
        if row.use or row.note then
            y = drawMarked(panel, { row }, y, style, color, nil, true)
        elseif row.inactive then
            y = drawRow(panel, row, y, inactiveStyle(style), color)
        else
            y = drawRow(panel, row, y, style, color, row.indent)
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

local function createdUnmet(created)
    return created.levelRequirement and not created.levelRequirement.met
end

-- An unmet level draws the whole line red, its armor type too.
local function createdSubtitle(created)
    local parts = {}
    if created.slot and created.slot ~= "" then
        parts[#parts + 1] = createdUnmet(created) and created.slot or armorSlot(created)
    end
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

-- Secondary stats in their own style where a client offers one (retail's
-- secondaryStats), else as the primary ones.
local function secondaryStyle(styles)
    return styles.secondaryStats or styles.stats
end

-- Gems and sockets in their own style where a client offers one (retail's
-- gems), else as enchants.
local function socketStyle(styles)
    return styles.gems or styles.enchants
end

-- Enchants with their quality icons sized to the text.
local function enchantRowsOf(model, styles)
    return fittedRows(model.enchants, styles.enchants)
end

-- Whether an item has gems or sockets.
local function hasSockets(model)
    return #model.sockets > 0
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
    if hasSockets(model) then need = math.max(need, socketsWidth(panel, model.sockets, socketStyle(styles))) end
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
    y = drawRows(panel, model.primary, y, styles.stats, { .90, .85, .74 })
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
        y = drawSockets(panel, model.sockets, y, socketStyle(styles))
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
        y = y + styledAt(panel, subtitle, pad() + indent, y, inner - indent, styles.subtitle,
            createdUnmet(created) and UNUSABLE_COLOR or { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 2
    end
    y = math.max(y, top + CREATED_ICON + 2) + 8
    local stats = hasStats(created)
    if stats then y = drawStats(panel, created, styles, y) end
    if created.setName then y = drawSet(panel, created, styles, divider(panel, y, GOLD_RULE, stats and 11 or 0)) end
    -- Its footer's lines, as whose classes may use it or an appearance not yet
    -- collected, under the rest: the recipe's footer is its own.
    local footer = {}
    for _, row in ipairs(created.footerLeft) do
        if not row.durability then footer[#footer + 1] = row end
    end
    if #footer > 0 then y = drawGroup(panel, footer, y + 4, styles.footer, { .82, .78, .71 }) end
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
    local quality = QUALITY[model.quality] or model.nameColor or QUALITY[1]
    local accent = model.quest and colors.quest or quality
    local header = { { id = "title", text = model.name, style = styles.title, color = quality, gap = 4 } }
    if model.slot and model.slot ~= "" then
        header[#header + 1] = { id = "slot", text = armorSlot(model), style = styles.subtitle,
            color = { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }, gap = 4 }
    end
    header[#header + 1] = { id = "binding", rows = model.header, style = styles.header, color = { .78, .72, .63 }, gap = 3 }

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
        -- A pair stands under a divider; what a recipe crafts, under "Creates".
        local separator = model.created.paired and { divider = GOLD_RULE, before = sectioned and DIVIDER_AFTER or 0 }
            or { caption = L["Creates"], style = styles.caption, before = sectioned and 6 or 0 }
        section({ separator = separator,
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
    local view = {
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
    -- Compose additions before the shared renderer measures width and height.
    -- This outer-item seam also runs for previews; it does not draw directly.
    local extension = descriptor.extension
    if extension and extension.extendView then extension.extendView(view, model, { panel = panel, styles = styles }) end
    return view
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

descriptor.read = readModel
descriptor.render = render
descriptor.key = getItemInfo
descriptor.option = "itemPanels"
descriptor.readDetails = readDetails
descriptor.details = details
descriptor.detailKeys = { "disenchant", "showIDs" }
ns.TooltipTypes[ITEM] = descriptor
