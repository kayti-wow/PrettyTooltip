-- Every question the addon asks the game about items, spells, units, auras,
-- quests, the player, and other addons, as ns.Game. Answers the game hides
-- come back as nil, and a missing API answers nothing. Readers receive this
-- table as an argument, so a test can pass its own.
-- Last, ns.Processor, through which the addon's stages hook the game's
-- tooltip processor.
local _, ns = ...
local util = ns.util
local isSecret, readable, call, number, rgb = util.isSecret, util.readable, util.call, util.number, util.rgb
local game = {}
ns.Game = game

function game.mailAttachments(index)
    if not (GetInboxItem and GetInboxItemLink) then return {} end
    local items = {}
    for slot = 1, ATTACHMENTS_MAX_RECEIVE or 12 do
        local ok, name, id, icon, count = pcall(GetInboxItem, index, slot)
        if not ok then return end
        if isSecret(name) or isSecret(id) or isSecret(icon) or isSecret(count) then return end
        local linked, link = pcall(GetInboxItemLink, index, slot)
        if not linked or isSecret(link) then return end
        link = util.safeText(link)
        if link == "" then link = nil end
        name, id, icon, count = util.safeText(name), number(id), readable(icon), number(count)
        if name and name ~= "" and (link or id) then
            items[#items + 1] = { name = name, id = id or tonumber(link:match("item:(%d+)")),
                link = link, icon = icon, count = count }
        end
    end
    return items
end

-- Items -----------------------------------------------------------------------

-- An item's name, link, quality, icon, and unit sell price, by ID, link, or
-- name; fields the client has not loaded are nil.
function game.itemInfo(item)
    if isSecret(item) then return end
    if not (item and C_Item and C_Item.GetItemInfo) then return end
    local ok, name, link, quality, _, _, _, _, _, _, icon, price = pcall(C_Item.GetItemInfo, item)
    if not ok then return end
    return { name = readable(name), link = readable(link), quality = readable(quality), icon = readable(icon),
        price = readable(price) }
end

-- The item's id, type and subtype names, equip slot, and class and subclass
-- IDs, from data the client always has; nil when any is hidden.
function game.itemType(item)
    if isSecret(item) then return end
    if not (item and C_Item and C_Item.GetItemInfoInstant) then return end
    local ok, id, className, subClassName, equipLoc, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, item)
    if not ok or isSecret(id) or isSecret(className) or isSecret(subClassName) or isSecret(equipLoc)
        or isSecret(classID) or isSecret(subClassID) then return end
    return { id = id, className = className, subClassName = subClassName, equipLoc = equipLoc, classID = classID,
        subClassID = subClassID }
end

-- Asks the client to load an item it has not seen, for a later hover.
function game.loadItem(itemID)
    if isSecret(itemID) then return end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
end

function game.itemName(itemID)
    if not (C_Item and C_Item.GetItemNameByID) then return end
    local name = call(C_Item.GetItemNameByID, itemID)
    if type(name) == "string" then return name end
end

function game.itemIcon(item)
    if not (item and C_Item and C_Item.GetItemIconByID) then return end
    return (call(C_Item.GetItemIconByID, item))
end

function game.itemLevel(item)
    if not (item and C_Item and C_Item.GetDetailedItemLevelInfo) then return end
    return number((call(C_Item.GetDetailedItemLevelInfo, item)))
end

-- How many the player carries.
function game.itemCount(item)
    if not (C_Item and C_Item.GetItemCount) then return end
    return number((call(C_Item.GetItemCount, item)))
end

-- How many the stack in a bag slot holds, by the item's GUID.
function game.stackCount(guid)
    if isSecret(guid) or type(guid) ~= "string" or not (C_Item and C_Item.GetItemLocation and C_Item.GetStackCount) then
        return
    end
    local ok, count = pcall(function() return C_Item.GetStackCount(C_Item.GetItemLocation(guid)) end)
    count = ok and number(count)
    if count and count > 0 then return count end
end

-- true or false; nil when the game cannot tell.
function game.isEquipped(link)
    if isSecret(link) then return end
    if not (link and C_Item and C_Item.IsEquippedItem) then return end
    local ok, equipped = pcall(C_Item.IsEquippedItem, link)
    if ok and not isSecret(equipped) then return equipped == true end
end

-- Auctionator's last seen price, in copper.
function game.auctionPrice(itemID)
    if isSecret(itemID) then return end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "PrettyTooltip", itemID)
    price = ok and number(price)
    if price and price > 0 then return price end
end

-- Spells ----------------------------------------------------------------------

function game.spellIcon(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if not getter then return end
    local ok, icon = pcall(getter, spellID)
    if ok and not isSecret(icon) and icon then return icon end
end

function game.spellName(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    if not getter then return end
    local ok, name = pcall(getter, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
end

-- A spell's description as the game fills it in; nil while the game has not
-- loaded the spell, or where it hides it.
function game.spellDescription(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
    if not getter then return end
    local ok, text = pcall(getter, spellID)
    if ok and not isSecret(text) and type(text) == "string" and text ~= "" then return text end
end

-- A spell's name on this client, for one the addon's data names in English,
-- as the English client's own tables do: an English client is not asked.
function game.localSpellName(spellID, english)
    if GetLocale() == "enUS" then return english end
    return game.spellName(spellID) or english
end

-- A spell's own tooltip, filled in a hidden tooltip no panel covers: the
-- tooltip and its data, for the spell reader. Nil where the game hides it.
local scanner
function game.spellTooltip(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PrettyTooltipSpellScanner", UIParent, "GameTooltipTemplate")
        scanner.prettyTooltipScanner = true
    end
    local ok, data = pcall(function()
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
        scanner:SetSpellByID(spellID)
        return scanner:GetTooltipData()
    end)
    if ok and not isSecret(data) and type(data) == "table" then return scanner, data end
end

-- Weapons ---------------------------------------------------------------------

-- The weapon slots a temporary enchant can be on, in GetWeaponEnchantInfo's order.
local WEAPON_SLOTS = { [16] = 1, [17] = 2, [18] = 3 }

-- Every enchant on a weapon from Forever's C_Item.GetWeaponEnchantInfo, which
-- lists a weapon's temporary enchant (a poison, an oil) and its class imbue
-- (Windfury, Rockbiter) apart; the other APIs miss the class imbue. Nil when
-- the API is missing or unreadable.
local function weaponEnchants(slot)
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return end
    -- Enum.WeaponSlot counts from 0: main hand, off hand, ranged.
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, WEAPON_SLOTS[slot] - 1)
    if not ok or isSecret(enchants) or type(enchants) ~= "table" then return end
    local list = {}
    for _, enchant in ipairs(enchants) do
        if not isSecret(enchant) and type(enchant) == "table" and readable(enchant.hasEnchant) then
            local id, left = number(enchant.enchantID), number(enchant.timeLeft)
            if id then
                list[#list + 1] = { enchantID = id, remaining = left and left / 1000,
                    charges = number(enchant.charges) }
            end
        end
    end
    return list
end

-- Every temporary enchant on a weapon slot, each as game.weaponImbue gives
-- one. On Forever a weapon can hold two at once, a temporary enchant and a
-- class imbue; elsewhere one at most.
function game.weaponImbues(slot)
    if isSecret(slot) or not WEAPON_SLOTS[slot] then return {} end
    return weaponEnchants(slot) or { game.weaponImbue(slot) }
end

-- A weapon slot's one temporary enchant, from the APIs that give a slot one:
-- its enchant ID, the seconds it has left, and its charges; nil without one.
function game.weaponImbue(slot)
    if isSecret(slot) or not WEAPON_SLOTS[slot] then return end
    local id, left, charges
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
        if not ok or isSecret(info) or type(info) ~= "table" then return end
        id, left, charges = number(info.enchantID), number(info.remainingTimeMs), number(info.chargesRemaining)
    elseif GetWeaponEnchantInfo then
        local values = util.pack(pcall(GetWeaponEnchantInfo))
        if not values[1] then return end
        -- Four values a weapon, after pcall's own: whether it has one, the time
        -- left in milliseconds, the charges, and the enchant ID.
        local first = 2 + (WEAPON_SLOTS[slot] - 1) * 4
        if not readable(values[first]) then return end
        left, charges, id = number(values[first + 1]), number(values[first + 2]), number(values[first + 3])
    end
    if not id then return end
    return { enchantID = id, remaining = left and left / 1000, charges = charges }
end

-- The icon of the item in one of the player's slots.
function game.slotIcon(slot)
    if isSecret(slot) or not GetInventoryItemTexture then return end
    local ok, icon = pcall(GetInventoryItemTexture, "player", slot)
    if ok and not isSecret(icon) and icon then return icon end
end

-- Macros ----------------------------------------------------------------------

function game.macro(name)
    if isSecret(name) or not GetMacroInfo or type(name) ~= "string" then return end
    local _, icon, body = call(GetMacroInfo, name)
    if type(body) ~= "string" then return end
    return { icon = icon, body = body }
end

-- The name of the macro whose #showtooltip shows this spell or item now; the
-- first, if several do. Character macros are numbered after the account's slots.
function game.macroShowing(dataType, id)
    if isSecret(dataType) or isSecret(id) then return end
    local isItem = dataType == Enum.TooltipDataType.Item
    local shows = isItem and GetMacroItem or GetMacroSpell
    if not (GetNumMacros and shows and GetMacroInfo) or type(id) ~= "number" then return end
    local account, character = call(GetNumMacros)
    local indices = {}
    for index = 1, number(account) or 0 do indices[#indices + 1] = index end
    local offset = MAX_ACCOUNT_MACROS or 120
    for index = offset + 1, offset + (number(character) or 0) do indices[#indices + 1] = index end
    for _, index in ipairs(indices) do
        local found
        if isItem then
            local _, link = call(shows, index)
            found = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        else
            found = number((call(shows, index)))
        end
        if found == id then
            local name, _, body = call(GetMacroInfo, index)
            if type(body) == "string" and body:lower():match("^%s*#showtooltip") then return name end
        end
    end
end

-- The pet bar -----------------------------------------------------------------

-- The pet bar slot showing this name: its icon, whether it is the active
-- command or stance, and autocast (nil when the action has none). Commands
-- and stances are named by global strings, as PET_ACTION_ATTACK.
function game.petAction(name)
    if isSecret(name) or not GetPetActionInfo or type(name) ~= "string" then return end
    for slot = 1, NUM_PET_ACTION_SLOTS or 10 do
        local ok, slotName, icon, isToken, isActive, autocastAllowed, autocastEnabled = pcall(GetPetActionInfo, slot)
        slotName, icon, isToken = readable(slotName), readable(icon), readable(isToken)
        if ok and type(slotName) == "string" then
            if isToken then slotName, icon = _G[slotName] or slotName, _G[icon] or icon end
            if slotName == name then
                local autocast
                if readable(autocastAllowed) then autocast = readable(autocastEnabled) == true end
                return { icon = icon, active = readable(isActive) == true, autocast = autocast }
            end
        end
    end
end

-- The player ------------------------------------------------------------------

function game.playerLevel()
    if not UnitLevel then return end
    return number((call(UnitLevel, "player")))
end

-- The player's bonus damage for a school, by the game's school index.
function game.spellDamage(school)
    if not GetSpellBonusDamage then return end
    return number((call(GetSpellBonusDamage, school)))
end

function game.spellHealing()
    if not GetSpellBonusHealing then return end
    return number((call(GetSpellBonusHealing)))
end

-- The mana a spell costs the player: none here, as Forever's tooltips give the
-- mana itself. A client whose tooltips give a share of base mana replaces it
-- (retail's Retail/Game/GameExtension.lua).
function game.spellManaCost(_spellID) end

-- The seconds an instant cast holds the player's other spells: Forever's is
-- 1.5 sec. Retail's shrinks with haste, and it replaces this.
function game.globalCooldown()
    return 1.5
end

-- The player's rank in a skill or profession, by the addon's name for it
-- ("Skinning"), which the client knows by its own (ns.Locale.skills). Older
-- clients list skills; newer ones, like Forever's, only list professions.
function game.skill(key)
    if isSecret(key) then return end
    local names = {}
    for _, name in ipairs(ns.Locale.skillNames(key)) do names[name] = true end
    if GetNumSkillLines and GetSkillLineInfo then
        for index = 1, number((call(GetNumSkillLines))) or 0 do
            local skillName, isHeader, _, rank = call(GetSkillLineInfo, index)
            if not isHeader and names[skillName] and type(rank) == "number" then return rank end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local found = util.pack(pcall(GetProfessions))
        for position = 2, found[1] and found.n or 1 do
            local index = found[position]
            if not isSecret(index) and index ~= nil then
                local skillName, _, rank = call(GetProfessionInfo, index)
                if names[skillName] and type(rank) == "number" then return rank end
            end
        end
    end
end

-- Units -----------------------------------------------------------------------

function game.unitExists(unit) return call(UnitExists, unit) end
function game.unitGUID(unit) return call(UnitGUID, unit) end
function game.unitToken(guid) return UnitTokenFromGUID and call(UnitTokenFromGUID, guid) or nil end
function game.unitName(unit) return (call(UnitName, unit)) end
function game.unitIsUnit(unit, other) return call(UnitIsUnit, unit, other) end
function game.unitIsPlayer(unit) return call(UnitIsPlayer, unit) end
function game.unitLevel(unit) return call(UnitEffectiveLevel or UnitLevel, unit) end
-- The localized class name, then the class file name.
function game.unitClass(unit) return call(UnitClass, unit) end
function game.unitRace(unit) return call(UnitRace, unit) end
-- The guild's name, then the unit's rank in it.
function game.unitGuild(unit) return call(GetGuildInfo, unit) end
function game.unitFaction(unit) return call(UnitFactionGroup, unit) end
function game.unitIsAFK(unit) return call(UnitIsAFK, unit) end
function game.unitIsDND(unit) return call(UnitIsDND, unit) end
function game.unitCreatureType(unit) return call(UnitCreatureType, unit) end
function game.unitClassification(unit) return call(UnitClassification, unit) end
function game.unitIsPVP(unit) return call(UnitIsPVP, unit) end
function game.unitIsDead(unit) return call(UnitIsDeadOrGhost, unit) end
function game.unitReaction(unit, other) return call(UnitReaction, unit, other) end
function game.unitIsTapDenied(unit) return call(UnitIsTapDenied, unit) end
-- The names of a class's specializations, by class ID: Forever has none.
-- Retail's client does, and it replaces this.
function game.classSpecs(_classID) end

-- A class's color, by its file name, as { r, g, b }.
-- The units a nearby player may be: the group, target, focus, mouseover, and
-- everyone with a nameplate.
local NEARBY = { "target", "focus", "mouseover" }
for index = 1, 4 do NEARBY[#NEARBY + 1] = "party" .. index end
for index = 1, 40 do NEARBY[#NEARBY + 1] = "raid" .. index end
for index = 1, 40 do NEARBY[#NEARBY + 1] = "nameplate" .. index end
game.NEARBY_UNITS = NEARBY

-- A player's class name and file, by the player's name, from those units.
function game.playerClass(name)
    if isSecret(name) or type(name) ~= "string" then return end
    for _, unit in ipairs(NEARBY) do
        if game.unitName(unit) == name and game.unitIsPlayer(unit) then
            local className, classFile = game.unitClass(unit)
            if type(classFile) == "string" then return className, classFile end
        end
    end
end

function game.classColor(classFile)
    if not isSecret(classFile) and classFile and RAID_CLASS_COLORS then return rgb(RAID_CLASS_COLORS[classFile]) end
end

-- A class-color addon's color for the class, from the CUSTOM_CLASS_COLORS
-- table those addons share; nil without one, or one without the class.
local watching
function game.customClassColor(classFile)
    local colors = CUSTOM_CLASS_COLORS
    if isSecret(classFile) or not classFile or isSecret(colors) or type(colors) ~= "table" then return end
    -- Its colors can change while panels are cached; a change draws them again.
    if not watching and type(colors.RegisterCallback) == "function" then
        watching = pcall(colors.RegisterCallback, colors, function()
            ns.settingsVersion = (ns.settingsVersion or 0) + 1
        end)
    end
    local ok, color = pcall(function() return rgb(colors[classFile]) end)
    if ok then return color end
end

-- The color the game gives a level, relative to the player's, as { r, g, b }.
function game.difficultyColor(level)
    if isSecret(level) or type(level) ~= "number" or not GetQuestDifficultyColor then return end
    return rgb((call(GetQuestDifficultyColor, level)))
end

-- Auras -----------------------------------------------------------------------

-- An aura on a unit, by its instance ID or by its index under a filter.
function game.aura(unit, which, filter, byInstance)
    if isSecret(unit) or isSecret(which) or isSecret(filter) or isSecret(byInstance) then return end
    if not C_UnitAuras then return end
    local ok, aura
    if byInstance and C_UnitAuras.GetAuraDataByAuraInstanceID then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, which)
    elseif C_UnitAuras.GetAuraDataByIndex then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, which, filter)
    end
    if ok and not isSecret(aura) and type(aura) == "table" then return aura end
end

-- Quests ----------------------------------------------------------------------

-- A quest's localized title. Request uncached data for the editor's next draw.
function game.questName(questID)
    if isSecret(questID) then return end
    if not (C_QuestLog and (C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo)) then return end
    local name = call(C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo, questID)
    if type(name) == "string" and name ~= "" then return name end
    if C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
end

-- true or false; nil without a quest log to ask.
function game.questCompleted(questID)
    if C_QuestLog then return call(C_QuestLog.IsQuestFlaggedCompleted, questID) == true end
end

function game.onQuest(questID)
    if C_QuestLog then return call(C_QuestLog.IsOnQuest, questID) == true end
end

-- A quest's level while it is in the quest log; nil otherwise.
function game.questLevel(questID)
    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo) then return end
    local index = call(C_QuestLog.GetLogIndexForQuestID, questID)
    if type(index) ~= "number" then return end
    local info = call(C_QuestLog.GetInfo, index)
    if type(info) == "table" then
        local level = number(info.level)
        if level and level > 0 then return level end
    end
end

-- Art -------------------------------------------------------------------------

-- An atlas's file, texture coordinates, and size; nil where the client lacks it.
function game.atlasInfo(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return end
    local info = call(C_Texture.GetAtlasInfo, name)
    if type(info) ~= "table" then return end
    local safe = {}
    for _, key in ipairs({ "file", "width", "height", "leftTexCoord", "rightTexCoord", "topTexCoord", "bottomTexCoord" }) do
        local value = readable(info[key])
        if value == nil then return end
        if key ~= "file" and type(value) ~= "number" then return end
        if key == "file" and type(value) ~= "number" and type(value) ~= "string" then return end
        safe[key] = value
    end
    if safe.width > 0 and safe.height > 0 then return safe end
end

-- Other addons ----------------------------------------------------------------

-- Installed, whether enabled or not.
function game.addonInstalled(addon)
    if isSecret(addon) then return false end
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and not isSecret(name) and not isSecret(reason) and name ~= nil and reason ~= "MISSING"
end

-- One of Questie's phrases as its tooltips print it, in the language Questie
-- is set to, which need not be the client's; the English phrase without it.
-- Its modules are read directly, since ImportModule creates a missing one.
function game.questieText(phrase)
    local modules = QuestieLoader and QuestieLoader._modules
    local l10n = type(modules) == "table" and modules.l10n
    if l10n then
        local ok, text = pcall(l10n, phrase)
        if ok and not isSecret(text) and type(text) == "string" then return text end
    end
    return phrase
end

-- The tooltip processor --------------------------------------------------------

-- The addon's one hand in the game's tooltip processor: a single post-call for
-- each tooltip data type and one modifier-key watcher, which run the stages in
-- a fixed order, whatever order they were added in. Every stage only reads the
-- tooltip data; the addon registers no pre-call, as the game reads the data
-- after those, and anything an addon wrote there would taint its fill.
local processor = {}
ns.Processor = processor

-- Native item wording or the Pretty panel, selected by the current settings;
-- then native details where no panel covers the tooltip, and follow cursor.
local ORDER = { "wording", "panel", "details", "cursor" }
local RANK = {}
for rank, stage in ipairs(ORDER) do RANK[stage] = rank end

local byType = {}
local onKeys = {}
local watcher

-- Each stage apart, as with a post-call of its own: one that fails is
-- reported, and the rest still run.
local function run(handler, ...)
    local ok, failure = pcall(handler, ...)
    if ok then return end
    local report = geterrorhandler and geterrorhandler()
    if report then report(failure) else error(failure, 0) end
end

local function insert(list, stage, handler)
    assert(RANK[stage], "unknown stage " .. tostring(stage))
    list[#list + 1] = { stage = stage, rank = RANK[stage], handler = handler }
    table.sort(list, function(a, b) return a.rank < b.rank end)
end

function processor.available()
    return TooltipDataProcessor ~= nil and TooltipDataProcessor.AddTooltipPostCall ~= nil
end

-- handler(tooltip, data), once the game has filled a tooltip of dataType.
function processor.onData(stage, dataType, handler)
    local list = byType[dataType]
    if not list then
        list = {}
        byType[dataType] = list
        TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
            for _, entry in ipairs(list) do run(entry.handler, tooltip, data) end
        end)
    end
    insert(list, stage, handler)
end

-- handler(key), as MODIFIER_STATE_CHANGED names it.
function processor.onKey(stage, handler)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
        watcher:SetScript("OnEvent", function(_, _, key)
            for _, entry in ipairs(onKeys) do run(entry.handler, key) end
        end)
    end
    insert(onKeys, stage, handler)
end

-- The stages a data type runs, in order.
function processor.stages(dataType)
    local names = {}
    for index, entry in ipairs(byType[dataType] or {}) do names[index] = entry.stage end
    return names
end
