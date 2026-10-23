-- Retail's item lines, read and drawn through the callbacks Tooltips/Item.lua
-- offers a client (descriptor.extension): where an item comes from (Heroic,
-- Mythic) and whether it is cosmetic, under its name; its upgrade level,
-- crafted quality, and transmogrification; its gems and sockets, and the Heart
-- of Azeroth's essence slots; a Mythic keystone's lines; notes on its effects
-- ("Legacy Item", charges, "You are in the wrong zone."); effects and primary
-- stats the character will not get, greyed; and Housing Decor's kind and
-- placement cost. It loads just after Tooltips/Item.lua.
local _, ns = ...
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
local descriptor = ns.TooltipTypes and ns.TooltipTypes[ITEM]
if not descriptor then return end
local util = ns.util
local isSecret, safeText, plainText, unformat = util.isSecret, util.safeText, util.plainText, util.unformat
local tooltipData = ns.TooltipData
local add, colorOf = tooltipData.add, tooltipData.colorOf
local fitAtlases = ns.ui.fitAtlases
local LINE = Enum.TooltipDataLineType or {}
local colors = ns.Retail.Palette.parts

-- A crafting reagent's quality icon, against its line's text.
local REAGENT_QUALITY_SCALE = 1.6
-- A gem's own enchantment, as the game draws it: indented, in gold.
local GEM_ENCHANT_COLOR = { 1, .82, 0 }
local GEM_ENCHANT_INDENT = 20
-- A primary stat another specialization uses, as retail's tooltip greys it,
-- under a grey marker where stats have one.
local INACTIVE_STAT_COLOR = { .50, .50, .50 }
local INACTIVE_MARKER = ns.Stats.tintedMarker(ns.Stats.MARKER, INACTIVE_STAT_COLOR) .. "  "
-- "Already Known" on an appearance or spell the character has, in the game's
-- red when it sends none.
local KNOWN_COLOR = { 1, .125, .125 }
-- A Warbound item's binding, in the game's light blue when it sends none.
local WARBOUND_COLOR = { 0, .80, 1 }
-- A Mythic keystone's lines, in the game's colors: its levels in gold, its
-- dungeon's modifiers in green under a gold heading, indented as the game does.
local KEYSTONE_LEVEL_COLOR = { 1, .82, 0 }
local KEYSTONE_HEADING_COLOR = { 1, 1, 1 }
local KEYSTONE_MODIFIER_COLOR = { 0, 1, 0 }
local KEYSTONE_MODIFIER_INDENT = 12
local DURATION_LINES = { "ITEM_DURATION_DAYS", "ITEM_DURATION_HOURS", "ITEM_DURATION_MIN", "ITEM_DURATION_SEC" }
-- An effect's charges, "3 Charges", in the game's white.
local CHARGES_COLOR = { 1, 1, 1 }
-- "Legacy Item: Effects are inactive", in the game's blue.
local LEGACY_COLOR = { 0, .80, 1 }
-- A reagent's "Usable with:", in the game's gold.
local USABLE_WITH_COLOR = { 1, .82, 0 }
-- How the game binds an item (its TooltipDataItemBinding enum, as documented,
-- where the client has none): the kinds that bind to the Warband.
local BINDING = Enum.TooltipDataItemBinding or { Account = 1, BnetAccount = 2, BindToAccount = 4,
    BindToBnetAccount = 5, AccountUntilEquipped = 9, BindToAccountUntilEquipped = 10 }
local WARBOUND = {}
for _, name in ipairs({ "Account", "BnetAccount", "BindToAccount", "BindToBnetAccount", "AccountUntilEquipped",
    "BindToAccountUntilEquipped" }) do
    if BINDING[name] then WARBOUND[BINDING[name]] = true end
end

-- Retail's own fields on an item (model.retail), each false until a line
-- gives it: fields sets some, as the editor's samples do.
local function newFields(fields)
    local retail = {
        -- Where it comes from, between the name and level: "Heroic", "Mythic+",
        -- and its color.
        source = false, sourceColor = false,
        -- "Cosmetic", under the name, and its color.
        cosmetic = false, cosmeticColor = false,
        -- Its upgrade track and level, "Myth 2/6", and crafted quality, with its icon.
        upgrade = false, craftingQuality = false,
        -- The appearance it is transmogrified to, and its weapon illusion.
        transmog = false, illusion = false,
        -- Whether it is a Mythic keystone.
        keystone = false,
        -- Decor's kind, "Housing Decor", and placement cost.
        decorKind = false, decorCost = false,
    }
    for key, value in pairs(fields or {}) do
        assert(retail[key] ~= nil, "no retail item field " .. tostring(key))
        retail[key] = value
    end
    return retail
end
-- For the editor's samples (Retail/UI/Samples.lua).
ns.Retail.Item = { newFields = newFields }

-- Reading: helpers --------------------------------------------------------------

-- A line's color as the game sends it, exactly, or fallback.
local function gameColor(color, fallback)
    return util.rgb(color) or fallback
end

-- The color a line's text opens with, as a panel color; nil without one.
local function openingColor(text)
    local color = util.openingColor(text)
    return color and colorOf({ r = color[1], g = color[2], b = color[3] })
end

-- Whether text is one of the game's strings, as it words them or in any case.
local function isString(text, ...)
    text = util.trim(text):lower()
    for index = 1, select("#", ...) do
        local wording = select(index, ...)
        if type(wording) == "string" and text == util.trim(wording):lower() then return true end
    end
    return false
end

-- An optional reagent's "+15 Recipe Difficulty": the game's wording, with a
-- signed number before or after it, and nothing else.
local function isDifficulty(plain)
    local wording = OPTIONAL_REAGENT_TOOLTIP_DIFFICULTY_ADJUST
    if type(wording) ~= "string" then return false end
    wording = util.trim(wording):gsub("[:：]$", "")
    if wording == "" then return false end
    local text = util.trim(plain)
    local first, last = text:find(wording, 1, true)
    if not first then return false end
    local rest = util.trim(text:sub(1, first - 1) .. " " .. text:sub(last + 1)):gsub("[:：]", "")
    return util.trim(rest):match("^[+-]%d+$") ~= nil
end

-- A profession's tool or accessory names itself so: "Alchemy Tool".
local function isProfessionGear(plain)
    for _, format in ipairs({ PROFESSION_TOOL_TOOLTIP_LINE, PROFESSION_ACCESSORY_TOOLTIP_LINE }) do
        if type(format) == "string" and unformat(util.trim(plain), format) then return true end
    end
    return false
end

-- A Warbound item's binding line: by the game's binding kind, or else its words.
local function isWarbound(line, text)
    local bonding = line.bonding
    if not isSecret(bonding) and type(bonding) == "number" then return WARBOUND[bonding] == true end
    return isString(plainText(text), ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND, ITEM_ACCOUNTBOUND_UNTIL_EQUIP,
        ITEM_BIND_TO_ACCOUNT, ITEM_BIND_TO_BNETACCOUNT, ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP)
end

-- Retail writes some colors with spaces for zeros, as "|cFF 0FF 0Mythic+":
-- read as the color it means, not as text.
local function repairedColors(text)
    return (text:gsub("|c([%x ][%x ][%x ][%x ][%x ][%x ][%x ][%x ])", function(code)
        return "|c" .. code:gsub(" ", "0")
    end))
end

-- "Upgrade Level: Myth 2/6" as "Myth 2/6", in the game's own short wording.
local function upgradeOf(text)
    local track, level, most = unformat(text, ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
    if track and tonumber(level) and tonumber(most) then
        return util.fill(ITEM_UPGRADE_DROPDOWN_LEVEL_FORMAT_STRING, track, level, most)
    end
    level, most = unformat(text, ITEM_UPGRADE_TOOLTIP_FORMAT)
    if tonumber(level) and tonumber(most) then return util.fill(ITEM_UPGRADE_DROPDOWN_LEVEL_FORMAT, level, most) end
end

-- What an item is transmogrified to: "Transmogrified to:" and the appearance,
-- on the line after it or the same one; "" when the next line names it.
local function transmogOf(text)
    local header = type(TRANSMOGRIFIED_HEADER) == "string" and util.trim(TRANSMOGRIFIED_HEADER) or ""
    local plain = util.trim(plainText(text))
    if header == "" or plain:sub(1, #header) ~= header then return end
    local rest = plain:sub(#header + 1):gsub("|n", "\n")
    return util.trim((rest:gsub("%s+", " ")))
end

-- A socket's icon: the gem in it, else the game's empty socket of its kind.
local function socketIcon(line)
    local gem = not isSecret(line.gemIcon) and line.gemIcon or nil
    if type(gem) == "number" or type(gem) == "string" then return gem end
    local kind = not isSecret(line.socketType) and line.socketType or nil
    if type(kind) == "string" and kind ~= "" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. kind end
end

-- An essence slot on the Heart of Azeroth, drawn as a socket: the game's border
-- for its kind (major or minor), the essence's icon inside it when one is set,
-- and both greyed while the slot is disabled.
local function essenceSlot(row, line)
    local kind = not isSecret(line.slotType) and line.slotType or nil
    if type(kind) == "string" and kind ~= "" then row.frame = "tooltip-heartofazerothessence-" .. kind end
    local essence = not isSecret(line.essenceIcon) and line.essenceIcon or nil
    if type(essence) == "number" or type(essence) == "string" then
        -- The game crops the essence's icon to its round face.
        row.icon, row.iconCoords = essence, { .171875, .828125, .171875, .828125 }
    end
    row.desaturated = not isSecret(line.disabled) and line.disabled == true or nil
end

-- The line the reader took before this one: the one before it with a line index.
local function lineBefore(lines, index)
    for at = index - 1, 1, -1 do
        local line = lines[at]
        if isSecret(line) or type(line) ~= "table" or isSecret(line.lineIndex) then return end
        if line.lineIndex then return line end
    end
end

-- Whether the line before this one is "Transmogrified to:" alone, so this
-- one names the appearance.
local function afterTransmogHeader(lines, index)
    local before = lineBefore(lines, index)
    if not before then return false end
    local left, right = safeText(before.leftText), safeText(before.rightText)
    return left ~= nil and right == "" and transmogOf(util.trim(repairedColors(left))) == ""
end

-- Whether the line after this one is the item level, as under a source.
local function levelFollows(lines, index)
    local after = lines[index + 1]
    return LINE.ItemLevel ~= nil and not isSecret(after) and type(after) == "table" and not isSecret(after.type)
        and after.type == LINE.ItemLevel
end

-- A line the game colors whole in its source green with its own code:
-- "|cFF19FF19The War Within Season 3|r". "Housing Decor" is blue.
local function wholeGreen(text)
    local hex, inner = util.trim(text):match("^|c%x%x(%x%x%x%x%x%x)(.-)|r$")
    if not hex or inner == "" or inner:find("|c", 1, true) then return false end
    local color = util.fromHex(hex)
    return color[2] > 200 / 255 and color[1] < 100 / 255 and color[3] < 100 / 255
end

local function addSocket(item, text, right)
    add(item.sockets, text, right)
    return item.sockets[#item.sockets]
end

-- Reading: the lines ----------------------------------------------------------
-- Each takes the model the line goes to, the line, and its context
-- (Tooltips/Item.lua's newRead), and says whether the line was one of its own.

-- Retail's upgrade level, a socket, gem, socket bonus, or essence slot, its
-- crafted quality, transmogrification, and a reagent's or profession tool's lines.
local function readRetailLine(item, line, context)
    local left, right, trimmed, original = context.leftText, context.rightText, context.text, context.originalText
    local lineType = line.type
    local plain = plainText(trimmed)
    if afterTransmogHeader(context.data.lines, context.lineNumber) and trimmed ~= "" and right == "" then
        item.retail.transmog = util.trim(plain)
    elseif (LINE.ItemUpgradeLevel and lineType == LINE.ItemUpgradeLevel) or upgradeOf(plain) then
        item.retail.upgrade = upgradeOf(plain) or trimmed
    elseif LINE.GemSocket and lineType == LINE.GemSocket then
        -- A gem's stat in its stat color, without the stat marker; an empty
        -- socket as the game words it.
        local text = ns.Stats.styleStat(util.trim(original or left), ns.option("statColors"), false)
        local row = addSocket(item, text, right)
        row.icon, row.color = socketIcon(line), colorOf(line.leftColor)
    elseif LINE.AzeriteEssenceSlot and lineType == LINE.AzeriteEssenceSlot then
        -- "Essence Slot Available", or the essence in it, with the sockets.
        local row = addSocket(item, util.trim(left), right)
        row.color = colorOf(line.leftColor)
        essenceSlot(row, line)
    elseif LINE.GemSocketEnchantment and lineType == LINE.GemSocketEnchantment then
        local row = addSocket(item, left, right)
        row.indent, row.color = GEM_ENCHANT_INDENT, GEM_ENCHANT_COLOR
    elseif right == "" and type(ITEM_SOCKETABLE) == "string" and util.trim(plain) == ITEM_SOCKETABLE then
        -- "<Shift Right Click to Socket>", with the sockets, unless turned off.
        if ns.option("socketHint") then addSocket(item, left, "").color = colorOf(line.leftColor) end
    elseif right == "" and unformat(plain, ITEM_SOCKET_BONUS) then
        -- Green while every socket matches, grey before.
        addSocket(item, original or left, "").color = colorOf(line.leftColor)
    elseif (LINE.ProfessionCraftingQuality and lineType == LINE.ProfessionCraftingQuality)
        or (right == "" and unformat(plain, PROFESSIONS_CRAFTING_QUALITY)) then
        item.retail.craftingQuality = trimmed
    elseif right == "" and transmogOf(trimmed) then
        -- Without the appearance, the next line names it.
        local appearance = transmogOf(trimmed)
        if appearance ~= "" then item.retail.transmog = appearance end
    elseif right == "" and unformat(plain, TRANSMOGRIFIED_ENCHANT) then
        item.retail.illusion = util.trim(plain)
    elseif right == "" and type(PROFESSIONS_FINISHING_CRAFTING_REAGENT_DESCRIPTION) == "string"
        and unformat(plain, PROFESSIONS_FINISHING_CRAFTING_REAGENT_DESCRIPTION) then
        -- A finishing reagent's effect, "When crafting: ...", with the item's effects.
        add(item.effects, trimmed, "")
    elseif right == "" and type(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION) == "string"
        and unformat(plain, PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION) then
        -- An optional reagent's effect, "Provides the following property: ...",
        -- with the item's effects, worded without the lead-in, as "Use:" is.
        local effect = unformat(plain, PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION)
        effect = util.trim((tostring(effect):gsub("^%s*|n", "")))
        add(item.effects, effect ~= "" and effect or trimmed, "")
    elseif right == "" and isDifficulty(plain) then
        -- "+15 Recipe Difficulty" goes with the reagent's crafting lines, not its stats.
        add(item.effects, trimmed, "")
    elseif right == "" and type(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_USABLE_WITH) == "string"
        and unformat(plain, util.uncolored(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_USABLE_WITH)) then
        -- The recipes a reagent goes into, under its effect, in the game's colors.
        add(item.effects, trimmed, "")
        item.effects[#item.effects].color = gameColor(line.leftColor, USABLE_WITH_COLOR)
    elseif right == "" and not item.slot and isProfessionGear(plain) then
        -- "Alchemy Tool", "Alchemy Accessory": its kind, under the name.
        item.slot = util.trim(plain)
    elseif right == "" and isString(plain, ITEM_COSMETIC) then
        -- "Cosmetic", under the name, in the game's pink.
        item.retail.cosmetic = util.trim(plain)
        item.retail.cosmeticColor = gameColor(line.leftColor, colors.itemCosmetic)
    elseif right == "" and isString(plain, ERR_COSMETIC_KNOWN, ITEM_SPELL_KNOWN) then
        -- "Already Known", in the game's red, under the effect it makes moot.
        add(item.effects, util.trim(plain), "")
        local row = item.effects[#item.effects]
        row.color, row.inactive = gameColor(line.leftColor, KNOWN_COLOR), true
    else
        return false
    end
    return true
end

-- A Mythic keystone sends no name line: its first line, "Keystone: Ruby Life
-- Pools", names the dungeon, which becomes the item's name. Its other lines:
-- "Mythic Level 15" and "Resilient Level 14" under the name, its "Dungeon
-- Modifiers:" with the effects, and its duration in the footer.
local function readKeystone(item, line, context)
    local left, trimmed = context.leftText, context.text
    if context.rightText ~= "" then return false end
    local plain = util.trim(plainText(trimmed))
    if context.lineNumber == 1 then
        if item.name or type(CHALLENGE_MODE_KEYSTONE_NAME) ~= "string" then return false end
        local dungeon = unformat(plain, CHALLENGE_MODE_KEYSTONE_NAME)
        if type(dungeon) ~= "string" or util.trim(dungeon) == "" then return false end
        item.name, item.nameColor, item.retail.keystone = util.trim(dungeon), gameColor(line.leftColor), true
        -- The game's item info has no link to go by; the line has its quality.
        if not isSecret(line.quality) and type(line.quality) == "number" then item.quality = line.quality end
        -- Its kind, "Keystone", the line's own word for it.
        local kind = util.trim((CHALLENGE_MODE_KEYSTONE_NAME:gsub("%%s", "")))
        kind = util.trim((kind:gsub("^[:：]+", ""):gsub("[:：]+$", "")))
        if kind ~= "" then item.slot = kind end
        return true
    end
    if not item.retail.keystone or plain == "" then return false end
    if unformat(plain, CHALLENGE_MODE_ITEM_POWER_LEVEL) or unformat(plain, RESILIENT_KEY_LEVEL) then
        add(item.header, plain, "")
        item.header[#item.header].color = gameColor(line.leftColor, KEYSTONE_LEVEL_COLOR)
    elseif isString(plain, CHALLENGE_MODE_DUNGEON_MODIFIERS) then
        add(item.effects, plain, "")
        item.effects[#item.effects].color = gameColor(line.leftColor, KEYSTONE_HEADING_COLOR)
    elseif left:match("^%s") and #item.effects > 0 then
        -- A modifier, indented under the heading.
        add(item.effects, plain, "")
        local row = item.effects[#item.effects]
        row.color, row.indent = gameColor(line.leftColor, KEYSTONE_MODIFIER_COLOR), KEYSTONE_MODIFIER_INDENT
    else
        for _, name in ipairs(DURATION_LINES) do
            local format = _G[name]
            if type(format) == "string" and unformat(plain, format) then
                add(item.footerLeft, util.resolvePlurals(plain), "")
                return true
            end
        end
        return false
    end
    return true
end

-- A note on the item's effects, kept beside them: "Legacy Item: Effects are
-- inactive" waits for the effect after it, and an effect's charges or an error
-- the game reddens under it, "You are in the wrong zone.", follow that one.
-- notes holds the list the last effect went into and the note waiting.
local function readEffectNote(notes, line, context)
    if context.rightText ~= "" then return false end
    local plain = util.trim(plainText(context.text))
    if plain == "" then return false end
    if isString(plain, ITEM_LEGACY_INACTIVE_EFFECTS) then
        notes.pending = { left = plain, right = "", color = gameColor(line.leftColor, LEGACY_COLOR), note = true }
        return true
    end
    if notes.last and (isString(plain, ITEM_SPELL_CHARGES_NONE)
        or (type(ITEM_SPELL_CHARGES) == "string" and unformat(plain, ITEM_SPELL_CHARGES))) then
        -- "3 Charges" under the use effect they count, in the game's white.
        add(notes.last, util.resolvePlurals(plain), "")
        local row = notes.last[#notes.last]
        row.color, row.note = gameColor(line.leftColor, CHARGES_COLOR), true
        return true
    end
    if notes.last and LINE.ErrorLine and line.type == LINE.ErrorLine then
        add(notes.last, plain, "")
        local row = notes.last[#notes.last]
        row.color, row.inactive, row.note = gameColor(line.leftColor, KNOWN_COLOR), true, true
        return true
    end
    return false
end

-- Retail names where an item comes from between its name and level: Heroic,
-- Mythic.
local function readSource(item, line, context)
    local trimmed, lines, lineNumber = context.text, context.data.lines, context.lineNumber
    local lineType = line.type
    if context.rightText ~= "" or trimmed == "" or not (lineType == nil or (LINE.None ~= nil and lineType == LINE.None)) then
        return false
    end
    local before = lineBefore(lines, lineNumber)
    -- Before its level, or, on an item with none, all in green: "The War Within Season 3".
    if not (before and before.type == LINE.ItemName and (levelFollows(lines, lineNumber) or wholeGreen(trimmed))) then
        return false
    end
    item.retail.source = util.trim(plainText(trimmed))
    item.retail.sourceColor = openingColor(trimmed) or colorOf(line.leftColor) or false
    return true
end

-- Reading: after the shared reader -----------------------------------------------

-- A primary stat another specialization uses, grey, as the game draws it:
-- without its colors, under a grey marker where stats have one.
local function markInactiveStat(row)
    local plain = util.uncolored(row.left):gsub("^|T.-|t%s*", "")
    row.left = (ns.option("statMarkers") and INACTIVE_MARKER or "") .. plain
    row.color, row.inactive = INACTIVE_STAT_COLOR, true
end

-- A Warbound binding in the game's light blue.
local function colorBinding(row, line, text)
    if isWarbound(line, text) then row.color = gameColor(line.leftColor, WARBOUND_COLOR) end
end

-- Decor's placement cost, beside its name: the budget icon and a number.
local function readNameRight(model, right)
    if type(right) == "string" and right:find("|A:", 1, true)
        and tonumber(util.trim(plainText((right:gsub("|A:.-|a", ""))))) then
        model.retail.decorCost = util.trim(right)
    end
end

-- Decor names its class and subclass on a line of its own, in the game's
-- blue: "Housing Decor". It joins the item's kinds under its name.
local function readClassLine(model, itemType)
    local housing = Enum.ItemClass and Enum.ItemClass.Housing
    if not housing or itemType.classID ~= housing then return end
    local class, subclass = itemType.className, itemType.subClassName
    if type(class) ~= "string" or class == "" then return end
    for index, row in ipairs(model.extras) do
        local text = util.trim(plainText(row.left))
        if row.right == "" and text:find(class, 1, true)
            and (type(subclass) ~= "string" or subclass == "" or text:find(subclass, 1, true)) then
            table.remove(model.extras, index)
            local code = row.left:match("|c(%x%x%x%x%x%x%x%x)")
            model.retail.decorKind = code and ("|c" .. code .. text .. "|r") or text
            return
        end
    end
end

-- Decor's kind and placement cost after its slot, the cost's icon at the slot
-- line's size.
local function addDecorKinds(model)
    local kind = model.retail.decorKind
    if model.retail.decorCost then
        local cost = fitAtlases(model.retail.decorCost, ns.style("subtitle").size)
        kind = kind and (kind .. "  " .. cost) or cost
    end
    if kind then
        model.slot = model.slot and model.slot ~= "" and (model.slot .. " \194\183 " .. kind) or kind
    end
end

-- Drawing ----------------------------------------------------------------------

-- Where the item comes from, and whether it is cosmetic, for under its name.
local function sourceLines(model, styles)
    local lines = {}
    if model.retail.source then
        lines[#lines + 1] = { text = model.retail.source, style = styles.itemSource,
            color = model.retail.sourceColor or colors.itemSource, gap = 4 }
    end
    if model.retail.cosmetic then
        lines[#lines + 1] = { text = model.retail.cosmetic, style = styles.itemCosmetic,
            color = model.retail.cosmeticColor or colors.itemCosmetic, gap = 4 }
    end
    return lines
end

-- Its upgrade level and crafted quality, for under its slot.
local function upgradeLines(model, styles)
    local lines = {}
    if model.retail.upgrade then
        lines[#lines + 1] = { text = model.retail.upgrade, style = styles.itemUpgrade, color = colors.itemUpgrade,
            gap = 4 }
    end
    if model.retail.craftingQuality then
        -- Gear's icon sits in its line at the text's height; a reagent's
        -- quality is what its line is for, so its icon is larger.
        local size = styles.craftingQuality.size * (model.equippable and 1 or REAGENT_QUALITY_SCALE)
        lines[#lines + 1] = { text = fitAtlases(model.retail.craftingQuality, size), style = styles.craftingQuality,
            color = colors.craftingQuality, gap = 4 }
    end
    return lines
end

-- What it is transmogrified to, for under its binding and level.
local function looksLine(model, styles)
    local looks = {}
    if model.retail.transmog then
        looks[#looks + 1] = { left = util.trim(TRANSMOGRIFIED_HEADER) .. " " .. model.retail.transmog, right = "" }
    end
    if model.retail.illusion then looks[#looks + 1] = { left = model.retail.illusion, right = "" } end
    if #looks > 0 then return { rows = looks, style = styles.itemTransmog, color = colors.itemTransmog, gap = 3 } end
end

-- The place of the header entry with this id (Tooltips/Item.lua's itemView).
local function headerAt(view, id)
    for index, entry in ipairs(view.header) do
        if entry.id == id then return index end
    end
end

-- The callbacks -----------------------------------------------------------------

-- What one read keeps from line to line, in its context's state: claimed,
-- whether retail took the line; model, the item its notes on effects are for;
-- last, the list the last effect went into; pending, a note waiting for the
-- effect it comes before; named, whether the name line has been read.
local function stateOf(context)
    local state = context.state
    if state.model == nil then state.model = context.rootModel end
    return state
end

descriptor.extension = {
    -- Retail's own fields on every item, a recipe's crafted item, and the
    -- editor's samples.
    initModel = function(model)
        model.retail = newFields()
    end,

    -- Retail writes some colors with spaces for zeros: read as the color meant.
    readText = function(left, right)
        return repairedColors(left), repairedColors(right)
    end,

    -- An expansion's reagents, "Zandalari Crafting Reagent": the longest kind
    -- in the name, on a short label line (no colon or closing period, as an
    -- effect's sentence has).
    findKind = function(name, kinds)
        if name == "" or name:find(":", 1, true) or name:find("：", 1, true) or name:find("[%.。]$") then return end
        local found
        for _, kind in ipairs(kinds) do
            if #name <= #kind + 40 and name:find(kind, 1, true) and (not found or #kind > #found) then found = kind end
        end
        return found
    end,

    -- One expansion's part of a profession, "Midnight Blacksmithing", as a
    -- word in a line the game marks as a requirement; a reagent's name can
    -- hold one too ("Elixir of Mining"), so other lines need the name exactly.
    isProfession = function(name, professions, marked)
        if not marked then return false end
        for profession in pairs(professions) do
            local start, stop = name:find(profession, 1, true)
            if start and not name:sub(start - 1, start - 1):match("%a") and not name:sub(stop + 1, stop + 1):match("%a") then
                return true
            end
        end
        return false
    end,

    -- Retail keeps an active bonus in the set, worded "Set: ...".
    isSetBonus = function(text)
        return unformat(text, ITEM_SET_BONUS) ~= nil
    end,

    -- Retail's appearance sets can list more pieces than they count ("(0/3)"
    -- over five), each indented.
    isSetPiece = function(left)
        return left:match("^%s%s%S") ~= nil
    end,

    readLine = function(item, line, context)
        local state = stateOf(context)
        state.claimed = readKeystone(item, line, context)
            -- "Legacy Item: Effects are inactive", "You are in the wrong zone.":
            -- beside the effects they speak of.
            or readEffectNote(state, line, context)
            or readRetailLine(item, line, context)
            or readSource(item, line, context)
        return state.claimed
    end,

    afterReadLine = function(item, line, context)
        local state = stateOf(context)
        local model = context.rootModel
        local read = not state.claimed
        state.claimed = nil
        -- What the reader made of a line retail did not take: an effect the
        -- character will not get, greyed or reddened, keeps that color; so does
        -- a primary stat another specialization uses, grey.
        local inactive = read and not context.text:match("^<.+>$") and tooltipData.inactiveColor(line.leftColor)
        local grey = read and tooltipData.isGrey(line.leftColor) == true
        local effectsAt, equipsAt
        for _, entry in ipairs(context.added) do
            local list, row = entry.list, entry.row
            if list == "header" and read then
                colorBinding(row, line, context.text)
            elseif list == "effects" or list == "equipEffects" then
                if inactive then row.color, row.inactive = inactive, true end
                if list == "effects" then effectsAt = math.min(effectsAt or entry.at, entry.at)
                else equipsAt = math.min(equipsAt or entry.at, entry.at) end
            elseif list == "primary" and grey then
                markInactiveStat(row)
            end
        end
        -- A waiting note goes before the effect it speaks of.
        local lineModel = context.lineModel
        local grown = (effectsAt and lineModel.effects) or (equipsAt and lineModel.equipEffects) or nil
        if state.pending and grown then
            table.insert(grown, (effectsAt or equipsAt), state.pending)
            state.pending = nil
        end
        -- A note after an effect follows it, past blank lines only.
        local blank = context.text == "" and context.rightText == ""
        if grown then state.last = grown elseif not blank then state.last = nil end
        -- Decor names its placement cost beside its name.
        if LINE.ItemName and line.type == LINE.ItemName and not state.named then
            state.named = true
            if model.name then readNameRight(model, context.rightText) end
        end
        -- Notes stay with the item they were read for.
        if state.model ~= item then state.model, state.last = item, nil end
    end,

    afterRead = function(model, context)
        if model ~= context.rootModel then return end
        -- A note with no effect after it stays with the effects.
        local state = stateOf(context)
        if state.pending then table.insert((state.model or model).effects, state.pending) end
        state.pending = nil
        -- Decor names its class, "Housing Decor", on a line of its own; with its
        -- placement cost, it joins the kinds under its name.
        if context.itemType and not context.recipe then readClassLine(model, context.itemType) end
        addDecorKinds(model)
    end,

    extendView = function(view, model, context)
        if not model.retail then return end
        local styles = context.styles
        -- Where it comes from and whether it is cosmetic, under its name.
        local title = headerAt(view, "title")
        for index, entry in ipairs(sourceLines(model, styles)) do table.insert(view.header, title + index, entry) end
        -- Its upgrade level and crafted quality, under its slot: just before the binding.
        local binding = headerAt(view, "binding")
        for index, entry in ipairs(upgradeLines(model, styles)) do
            table.insert(view.header, binding + index - 1, entry)
        end
        -- What it is transmogrified to, under its binding and level.
        view.header[#view.header + 1] = looksLine(model, styles)
    end,
}
