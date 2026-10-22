-- Retail's item lines: where an item comes from (Heroic, Mythic), its upgrade
-- level, crafted quality, and transmogrification, its gems and sockets, and
-- the primary stats another specialization greys. Tooltips/Item.lua reads
-- and draws them through the callbacks Retail/Tooltips/ItemExtension.lua gives it.
local _, ns = ...
local util = ns.util
local isSecret, safeText, plainText, unformat = util.isSecret, util.safeText, util.plainText, util.unformat
local add, colorOf = ns.TooltipData.add, ns.TooltipData.colorOf
local LINE = Enum and Enum.TooltipDataLineType or {}
local item = {}
ns.Retail.Item = item

-- Each line in the game's color unless the editor sets one.
local SOURCE_COLOR = { .12, 1, .12 }
local UPGRADE_COLOR = { .90, .80, .55 }
local TRANSMOG_COLOR = { 1, .50, 1 }
local CRAFTED_COLOR = { .90, .85, .74 }
-- A crafting reagent's quality icon, against its line's text.
local REAGENT_QUALITY_SCALE = 1.6
-- A gem's own enchantment, as the game draws it: indented, in gold.
local GEM_ENCHANT_COLOR = { 1, .82, 0 }
local GEM_ENCHANT_INDENT = 20
-- A primary stat another specialization uses, as retail's tooltip greys it.
local INACTIVE_STAT_COLOR = { .50, .50, .50 }
-- "Cosmetic" under the name, and "Already Known" on an appearance or spell the
-- character has, in the game's colors when it sends none.
local COSMETIC_COLOR = { 1, .50, 1 }
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
local BINDING = Enum and Enum.TooltipDataItemBinding or { Account = 1, BnetAccount = 2, BindToAccount = 4,
    BindToBnetAccount = 5, AccountUntilEquipped = 9, BindToAccountUntilEquipped = 10 }
local WARBOUND = {}
for _, name in ipairs({ "Account", "BnetAccount", "BindToAccount", "BindToBnetAccount", "AccountUntilEquipped",
    "BindToAccountUntilEquipped" }) do
    if BINDING[name] then WARBOUND[BINDING[name]] = true end
end

-- Reading ----------------------------------------------------------------------

-- Retail's own fields on an item (model.retail), each false until a line
-- gives it: fields sets some, as the editor's samples do.
function item.newFields(fields)
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

-- Quality icons at a size: Tooltips/Item.lua's, read when drawn.
local function fitAtlases(text, size) return ns.ui.fitAtlases(text, size) end

-- A line's color as the game sends it, exactly, or fallback.
local function gameColor(color, fallback)
    if isSecret(color) or type(color) ~= "table" then return fallback end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return fallback
    end
    return { r, g, b }
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

-- Retail's reagent kinds, named on a line of their own, as Tooltips/Item.lua
-- names "Crafting Reagent": they join the item's slot under its name.
function item.kinds()
    local list = {}
    for _, kind in pairs({ PROFESSIONS_MODIFIED_CRAFTING_REAGENT_FINISHING, PROFESSIONS_MODIFIED_CRAFTING_REAGENT }) do
        if type(kind) == "string" then list[#list + 1] = kind end
    end
    return list
end

-- The kind a reagent's line names with an expansion's name added, as
-- "Zandalari Crafting Reagent": the longest kind in it, on a short label line
-- (no colon or closing period, as an effect's sentence has). Nil otherwise.
function item.kindWithin(name, kinds)
    if name == "" or name:find(":", 1, true) or name:find("：", 1, true) or name:find("[%.。]$") then return end
    local found
    for _, kind in ipairs(kinds) do
        if #name <= #kind + 40 and name:find(kind, 1, true) and (not found or #kind > #found) then found = kind end
    end
    return found
end

-- Decor's placement cost, beside its name: the budget icon and a number.
function item.readNameRight(model, right)
    if type(right) == "string" and right:find("|A:", 1, true)
        and tonumber(util.trim(plainText((right:gsub("|A:.-|a", ""))))) then
        model.retail.decorCost = util.trim(right)
    end
end

-- Decor names its class and subclass on a line of its own, in the game's
-- blue: "Housing Decor". It joins the item's kinds under its name.
function item.readClassLine(model, itemType)
    local housing = Enum and Enum.ItemClass and Enum.ItemClass.Housing
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

-- Decor's kind and placement cost, its icon at the slot line's size.
function item.addKinds(shown, model)
    if not model.retail then return end
    local kind = model.retail.decorKind
    if model.retail.decorCost then
        local cost = fitAtlases(model.retail.decorCost, ns.style("subtitle").size)
        kind = kind and (kind .. "  " .. cost) or cost
    end
    if kind then shown[#shown + 1] = kind end
end

-- A Warbound item's binding line: by the game's binding kind, or else its words.
function item.isWarbound(line, text)
    local bonding = line.bonding
    if not isSecret(bonding) and type(bonding) == "number" then return WARBOUND[bonding] == true end
    return isString(plainText(text), ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND, ITEM_ACCOUNTBOUND_UNTIL_EQUIP,
        ITEM_BIND_TO_ACCOUNT, ITEM_BIND_TO_BNETACCOUNT, ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP)
end

-- A binding row in the game's light blue when it binds to the Warband.
function item.colorBinding(row, line, text)
    if item.isWarbound(line, text) then row.color = gameColor(line.leftColor, WARBOUND_COLOR) end
end

-- Retail writes some colors with spaces for zeros, as "|cFF 0FF 0Mythic+":
-- read as the color it means, not as text.
function item.repairedColors(text)
    return (text:gsub("|c([%x ][%x ][%x ][%x ][%x ][%x ][%x ][%x ])", function(code)
        return "|c" .. code:gsub(" ", "0")
    end))
end

-- Whether a profession's name is in a requirement's, as a word: retail's for
-- one expansion's part of it, "Midnight Blacksmithing". professions holds the
-- client's names, as keys.
function item.isExpansionProfession(name, professions)
    for profession in pairs(professions) do
        local start, stop = name:find(profession, 1, true)
        if start and not name:sub(start - 1, start - 1):match("%a") and not name:sub(stop + 1, stop + 1):match("%a") then
            return true
        end
    end
    return false
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

-- The color a line's text opens with, as a panel color; nil without one.
local function openingColor(text)
    local code = text:match("^%s*|c%x%x(%x%x%x%x%x%x)")
    if not code then return end
    local r, g, b = tonumber(code:sub(1, 2), 16), tonumber(code:sub(3, 4), 16), tonumber(code:sub(5, 6), 16)
    return colorOf({ r = r / 255, g = g / 255, b = b / 255 })
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
    return left ~= nil and right == "" and transmogOf(util.trim(item.repairedColors(left))) == ""
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
    local code, inner = util.trim(text):match("^|c%x%x(%x%x%x%x%x%x)(.-)|r$")
    if not code or inner == "" or inner:find("|c", 1, true) then return false end
    local r, g, b = tonumber(code:sub(1, 2), 16), tonumber(code:sub(3, 4), 16), tonumber(code:sub(5, 6), 16)
    return g > 200 and r < 100 and b < 100
end

local function addSocket(m, text, right)
    add(m.sockets, text, right)
    return m.sockets[#m.sockets]
end

-- Reads a line of retail's into m, the item or the one a recipe creates: its
-- upgrade level, a socket, gem, socket bonus, or essence slot, its crafted quality, or its
-- transmogrification. Whether the line was one. left and trimmed are the
-- line's text as the panel words it, original as the game did, if it differs.
function item.readLine(m, line, data, lineNumber, left, right, trimmed, original)
    local lineType = line.type
    local plain = plainText(trimmed)
    if afterTransmogHeader(data.lines, lineNumber) and trimmed ~= "" and right == "" then
        m.retail.transmog = util.trim(plain)
    elseif (LINE.ItemUpgradeLevel and lineType == LINE.ItemUpgradeLevel) or upgradeOf(plain) then
        m.retail.upgrade = upgradeOf(plain) or trimmed
    elseif LINE.GemSocket and lineType == LINE.GemSocket then
        -- A gem's stat in its stat color, without the stat marker; an empty
        -- socket as the game words it.
        local text = ns.Stats.styleStat(util.trim(original or left), ns.option("statColors"), false)
        local row = addSocket(m, text, right)
        row.icon, row.color = socketIcon(line), colorOf(line.leftColor)
    elseif LINE.AzeriteEssenceSlot and lineType == LINE.AzeriteEssenceSlot then
        -- "Essence Slot Available", or the essence in it, with the sockets.
        local row = addSocket(m, util.trim(left), right)
        row.color = colorOf(line.leftColor)
        essenceSlot(row, line)
    elseif LINE.GemSocketEnchantment and lineType == LINE.GemSocketEnchantment then
        local row = addSocket(m, left, right)
        row.indent, row.color = GEM_ENCHANT_INDENT, GEM_ENCHANT_COLOR
    elseif right == "" and type(ITEM_SOCKETABLE) == "string" and util.trim(plain) == ITEM_SOCKETABLE then
        -- "<Shift Right Click to Socket>", with the sockets, unless turned off.
        if ns.option("socketHint") then addSocket(m, left, "").color = colorOf(line.leftColor) end
    elseif right == "" and unformat(plain, ITEM_SOCKET_BONUS) then
        -- Green while every socket matches, grey before.
        addSocket(m, original or left, "").color = colorOf(line.leftColor)
    elseif (LINE.ProfessionCraftingQuality and lineType == LINE.ProfessionCraftingQuality)
        or (right == "" and unformat(plain, PROFESSIONS_CRAFTING_QUALITY)) then
        m.retail.craftingQuality = trimmed
    elseif right == "" and transmogOf(trimmed) then
        -- Without the appearance, the next line names it.
        local appearance = transmogOf(trimmed)
        if appearance ~= "" then m.retail.transmog = appearance end
    elseif right == "" and unformat(plain, TRANSMOGRIFIED_ENCHANT) then
        m.retail.illusion = util.trim(plain)
    elseif right == "" and type(PROFESSIONS_FINISHING_CRAFTING_REAGENT_DESCRIPTION) == "string"
        and unformat(plain, PROFESSIONS_FINISHING_CRAFTING_REAGENT_DESCRIPTION) then
        -- A finishing reagent's effect, "When crafting: ...", with the item's effects.
        add(m.effects, trimmed, "")
    elseif right == "" and type(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION) == "string"
        and unformat(plain, PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION) then
        -- An optional reagent's effect, "Provides the following property: ...",
        -- with the item's effects, worded without the lead-in, as "Use:" is.
        local effect = unformat(plain, PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION)
        effect = util.trim((tostring(effect):gsub("^%s*|n", "")))
        add(m.effects, effect ~= "" and effect or trimmed, "")
    elseif right == "" and isDifficulty(plain) then
        -- "+15 Recipe Difficulty" goes with the reagent's crafting lines, not its stats.
        add(m.effects, trimmed, "")
    elseif right == "" and type(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_USABLE_WITH) == "string"
        and unformat(plain, util.uncolored(PROFESSIONS_MODIFIED_CRAFTING_REAGENT_USABLE_WITH)) then
        -- The recipes a reagent goes into, under its effect, in the game's colors.
        add(m.effects, trimmed, "")
        m.effects[#m.effects].color = gameColor(line.leftColor, USABLE_WITH_COLOR)
    elseif right == "" and not m.slot and isProfessionGear(plain) then
        -- "Alchemy Tool", "Alchemy Accessory": its kind, under the name.
        m.slot = util.trim(plain)
    elseif right == "" and isString(plain, ITEM_COSMETIC) then
        -- "Cosmetic", under the name, in the game's pink.
        m.retail.cosmetic, m.retail.cosmeticColor = util.trim(plain), gameColor(line.leftColor, COSMETIC_COLOR)
    elseif right == "" and isString(plain, ERR_COSMETIC_KNOWN, ITEM_SPELL_KNOWN) then
        -- "Already Known", in the game's red, under the effect it makes moot.
        add(m.effects, util.trim(plain), "")
        m.effects[#m.effects].color, m.effects[#m.effects].inactive = gameColor(line.leftColor, KNOWN_COLOR), true
    else
        return false
    end
    return true
end

-- A Mythic keystone sends no name line: its first line, "Keystone: Ruby Life
-- Pools", names the dungeon, which becomes the item's name. Its other lines:
-- "Mythic Level 15" and "Resilient Level 14" under the name, its "Dungeon
-- Modifiers:" with the effects, and its duration in the footer. Whether the
-- line was one.
function item.readKeystone(m, line, lineNumber, left, right, trimmed)
    if right ~= "" then return false end
    local plain = util.trim(plainText(trimmed))
    if lineNumber == 1 then
        if m.name or type(CHALLENGE_MODE_KEYSTONE_NAME) ~= "string" then return false end
        local dungeon = unformat(plain, CHALLENGE_MODE_KEYSTONE_NAME)
        if type(dungeon) ~= "string" or util.trim(dungeon) == "" then return false end
        m.name, m.nameColor, m.retail.keystone = util.trim(dungeon), gameColor(line.leftColor), true
        -- The game's item info has no link to go by; the line has its quality.
        if not isSecret(line.quality) and type(line.quality) == "number" then m.quality = line.quality end
        -- Its kind, "Keystone", the line's own word for it.
        local kind = util.trim((CHALLENGE_MODE_KEYSTONE_NAME:gsub("%%s", "")))
        kind = util.trim((kind:gsub("^[:：]+", ""):gsub("[:：]+$", "")))
        if kind ~= "" then m.slot = kind end
        return true
    end
    if not m.retail.keystone or plain == "" then return false end
    if unformat(plain, CHALLENGE_MODE_ITEM_POWER_LEVEL) or unformat(plain, RESILIENT_KEY_LEVEL) then
        add(m.header, plain, "")
        m.header[#m.header].color = gameColor(line.leftColor, KEYSTONE_LEVEL_COLOR)
    elseif isString(plain, CHALLENGE_MODE_DUNGEON_MODIFIERS) then
        add(m.effects, plain, "")
        m.effects[#m.effects].color = gameColor(line.leftColor, KEYSTONE_HEADING_COLOR)
    elseif left:match("^%s") and #m.effects > 0 then
        -- A modifier, indented under the heading.
        add(m.effects, plain, "")
        local row = m.effects[#m.effects]
        row.color, row.indent = gameColor(line.leftColor, KEYSTONE_MODIFIER_COLOR), KEYSTONE_MODIFIER_INDENT
    else
        for _, name in ipairs(DURATION_LINES) do
            local format = _G[name]
            if type(format) == "string" and unformat(plain, format) then
                add(m.footerLeft, util.resolvePlurals(plain), "")
                return true
            end
        end
        return false
    end
    return true
end

-- A note on the item's effects, kept beside them: "Legacy Item: Effects are
-- inactive" waits for the effect after it, and an effect's charges or an error
-- the game reddens under it, "You are in the wrong zone.", follow that one. notes holds
-- the list the last effect went into and the note waiting. Whether the line
-- was one.
function item.readEffectNote(notes, line, right, trimmed)
    if right ~= "" then return false end
    local plain = util.trim(plainText(trimmed))
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
-- Mythic. Whether the line was that.
function item.readSource(m, line, data, lineNumber, right, trimmed)
    local lineType = line.type
    if right ~= "" or trimmed == "" or not (lineType == nil or (LINE.None ~= nil and lineType == LINE.None)) then
        return false
    end
    local before = lineBefore(data.lines, lineNumber)
    -- Before its level, or, on an item with none, all in green: "The War Within Season 3".
    if not (before and before.type == LINE.ItemName
        and (levelFollows(data.lines, lineNumber) or wholeGreen(trimmed))) then
        return false
    end
    m.retail.source = util.trim(plainText(trimmed))
    m.retail.sourceColor = openingColor(trimmed) or colorOf(line.leftColor) or false
    return true
end

-- A primary stat another specialization uses, grey, as the game draws it.
function item.markInactiveStat(row)
    row.left = ns.Retail.Stats.inactiveStat(row.left, ns.option("statMarkers"))
    row.color, row.inactive = INACTIVE_STAT_COLOR, true
end

-- Drawing ----------------------------------------------------------------------

-- The header's lines: where the item comes from, and whether it is cosmetic,
-- under its name.
function item.addSource(header, model, styles)
    if not model.retail then return end
    if model.retail.source then
        header[#header + 1] = { text = model.retail.source, style = styles.itemSource,
            color = model.retail.sourceColor or SOURCE_COLOR, gap = 4 }
    end
    if model.retail.cosmetic then
        header[#header + 1] = { text = model.retail.cosmetic, style = styles.itemCosmetic,
            color = model.retail.cosmeticColor or COSMETIC_COLOR, gap = 4 }
    end
end

-- Its upgrade level and crafted quality, under its slot.
function item.addUpgrade(header, model, styles)
    if not model.retail then return end
    if model.retail.upgrade then
        header[#header + 1] = { text = model.retail.upgrade, style = styles.itemUpgrade, color = UPGRADE_COLOR, gap = 4 }
    end
    if model.retail.craftingQuality then
        -- Gear's icon sits in its line at the text's height; a reagent's
        -- quality is what its line is for, so its icon is larger.
        local size = styles.craftingQuality.size * (model.equippable and 1 or REAGENT_QUALITY_SCALE)
        header[#header + 1] = { text = fitAtlases(model.retail.craftingQuality, size),
            style = styles.craftingQuality, color = CRAFTED_COLOR,
            gap = 4 }
    end
end

-- What it is transmogrified to, under its binding and level.
function item.addLooks(header, model, styles)
    if not model.retail then return end
    local looks = {}
    if model.retail.transmog then looks[#looks + 1] = { left = util.trim(TRANSMOGRIFIED_HEADER) .. " " .. model.retail.transmog, right = "" } end
    if model.retail.illusion then looks[#looks + 1] = { left = model.retail.illusion, right = "" } end
    if #looks > 0 then
        header[#header + 1] = { rows = looks, style = styles.itemTransmog, color = TRANSMOG_COLOR, gap = 3 }
    end
end
