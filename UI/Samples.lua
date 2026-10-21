-- The style editor's sample tooltips, as data: each type's samples are the
-- fields of its model, which its own tooltip file completes. What comes from
-- the game or the settings is written as a marker and filled in on each draw:
-- { item = ID } or { spell = ID } an icon, { itemName = ID, english } or
-- { spellName = ID, english } or { questName = ID, english } the name the client gives,
-- { money = copper } coins (with
-- each and count, a stack), a stat list's strings the stat rows the settings
-- style, enchant an "Enchanted:" line's rows, disenchant the results for
-- { quality, class, level, slot }, expiresIn an aura's end, and after fields
-- set once the model is complete.
local _, ns = ...
local ui = ns.ui
if not ui then return end

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local L, fill, formats, skill = ns.L, ns.util.fill, ns.Locale.formats, ns.Locale.skillName
local DOT = " \194\183 "
local PALE = { .95, .93, .88 }

-- A stat line as the game prints one: "+13 Stamina".
local function statLine(key, amount, sign)
    return ns.Stats.text({ key = key, sign = sign or "+", amount = tostring(amount), percent = key == "CRIT_CHANCE" })
end

-- An item's, spell's, or quest's name on this client, asked on each draw.
-- Quest fallbacks are translated while the client loads their titles.
local function itemName(id, english) return { itemName = id, english } end
local function spellName(id, english) return { spellName = id, english } end
local function questName(id, english) return { questName = id, english } end

local function quoted(text) return '"' .. text .. '"' end

-- The types in the editor's order; dataType names the game's tooltip type and
-- model the completer the tooltip file shares.
local TYPES = {
    {
        key = "item", label = "Items", dataType = "Item", model = "itemModel", first = "title", noun = "item",
        samples = {
            {
                label = "Weapon",
                fields = {
                    name = itemName(12784, "Arcanite Reaper"), quality = 4, icon = { item = 12784 }, level = 63,
                    equippable = true,
                    slot = L["Axe"] .. DOT .. INVTYPE_2HWEAPON,
                    header = { { left = ITEM_BIND_ON_EQUIP, right = fill(ITEM_MIN_LEVEL, 58), rightColor = PALE } },
                    weaponDps = "53.8",
                    weaponDamage = fill(DAMAGE_TEMPLATE, 153, 256), weaponSpeed = fill(formats.weaponSpeed, "3.80"),
                    primary = { statLine("STAMINA", 13) },
                    secondary = { statLine("ATTACK_POWER", 62) },
                    equipEffects = {
                        { left = L["Your attacks have a chance to cleave a nearby enemy."], right = "" },
                        { left = L["Wounds the target for 40 to 60 damage."], right = "", onHit = true },
                    },
                    enchant = statLine("AGILITY", 25),
                    flavor = { { left = quoted(L["Sample flavor text sits here, in gold."]), right = "" } },
                    footerLeft = {
                        { left = fill(DURABILITY_TEMPLATE, 61, 120), right = "", durability = { 61, 120 } },
                        { left = fill(L["Made by %s"], "Lorelei"), right = "", color = ui.FLAVOR_GOLD },
                    },
                    footerRight = { { left = { money = 64218 }, right = "", sellPrice = true } },
                    disenchant = { 2, 4, 63, "INVTYPE_2HWEAPON" },
                },
            },
            {
                label = "Set piece",
                fields = {
                    name = itemName(22425, "Redemption Tunic"), quality = 4, icon = { item = 22416 }, level = 88,
                    equippable = true,
                    slot = L["Plate"] .. DOT .. INVTYPE_CHEST,
                    header = { { left = ITEM_BIND_ON_PICKUP, right = fill(ITEM_MIN_LEVEL, 60), rightColor = PALE } },
                    armor = { { left = fill(ARMOR_TEMPLATE, 1027), right = "", value = "1027" } },
                    primary = { statLine("INTELLECT", 31), statLine("STAMINA", 25) },
                    secondary = { statLine("CRIT_CHANCE", 1), statLine("HEALING_POWER", 59), statLine("MANA_REGEN", 10) },
                    enchant = statLine("ALL_STATS", 4),
                    setName = L["Redemption Armor"], setCount = "3/9",
                    setItems = {
                        { left = itemName(22425, "Redemption Tunic"), right = "", active = true },
                        { left = itemName(22427, "Redemption Legguards"), right = "", active = true },
                        { left = itemName(22426, "Redemption Handguards"), right = "", active = true },
                        { left = itemName(22428, "Redemption Headpiece"), right = "", active = false },
                        { left = itemName(22429, "Redemption Spaulders"), right = "", active = false },
                    },
                    setBonuses = {
                        { left = fill(ITEM_SET_BONUS_GRAY, 2, L["Increases the amount healed by your Judgement of Light by 20."]),
                            right = "", active = true },
                        { left = fill(ITEM_SET_BONUS_GRAY, 4, L["Reduces cooldown on your Lay on Hands by 12 min."]),
                            right = "", active = false },
                    },
                    extras = { { left = fill(L["Dropped by: %s"], L["Kel'Thuzad"]), right = "", color = { .17, .51, .77 } } },
                    footerLeft = { { left = fill(DURABILITY_TEMPLATE, 165, 165), right = "", durability = { 165, 165 } } },
                    footerRight = {
                        { left = fill(ITEM_REQ_REPUTATION, L["Argent Dawn"], FACTION_STANDING_LABEL7), right = "",
                            requirement = true, met = false },
                        { left = { money = 123767 }, right = "", sellPrice = true },
                    },
                },
            },
            {
                label = "Equipped",
                fields = {
                    name = itemName(12583, "Blackhand Doomsaw"), quality = 3, icon = { item = 12583 }, level = 63,
                    equippable = true, comparison = true,
                    slot = L["Polearm"] .. DOT .. INVTYPE_2HWEAPON,
                    header = { { left = ITEM_SOULBOUND, right = fill(ITEM_MIN_LEVEL, 55), rightColor = PALE } },
                    weaponDps = "45.1",
                    weaponDamage = fill(DAMAGE_TEMPLATE, 131, 197), weaponSpeed = fill(formats.weaponSpeed, "3.60"),
                    primary = { statLine("STRENGTH", 15) },
                    extras = {
                        { left = ITEM_DELTA_DESCRIPTION, right = "", color = { .85, .70, 0 } },
                        { left = statLine("STRENGTH", 15, "-"), right = "", color = { .85, .13, .13 } },
                        { left = statLine("STAMINA", 13), right = "", color = { .09, .85, .09 } },
                        { left = statLine("ATTACK_POWER", 62), right = "", color = { .09, .85, .09 } },
                    },
                    footerLeft = { { left = fill(DURABILITY_TEMPLATE, 100, 100), right = "", durability = { 100, 100 } } },
                    footerRight = { { left = { money = 41250 }, right = "", sellPrice = true } },
                },
            },
            {
                label = "Potion",
                fields = {
                    name = itemName(13446, "Major Healing Potion"), quality = 1, icon = { item = 13446 }, level = 55,
                    slot = L["Consumable"] .. DOT .. L["Potion"],
                    header = { { left = "", right = fill(ITEM_MIN_LEVEL, 45), rightColor = PALE } },
                    effects = { { left = L["Restores 1050 to 1750 health."] .. " " .. fill(ITEM_COOLDOWN_TOTAL_MIN, 2),
                        right = "", use = true } },
                    footerRight = { { left = { money = 5000, each = 1000, count = 5 }, right = "", sellPrice = true } },
                },
            },
            {
                label = "Recipe",
                fields = {
                    name = itemName(251360, "Plans: Veteran's Gloves"), quality = 2, icon = "Interface\\Icons\\INV_Scroll_03",
                    slot = L["Plans"] .. DOT .. skill("Blacksmithing"),
                    header = { { left = ITEM_BIND_ON_PICKUP, right = fill(L["Requires %s %s"], skill("Blacksmithing"), 80),
                        rightColor = PALE } },
                    created = {
                        name = itemName(250508, "Veteran's Gloves"), quality = 2, icon = "Interface\\Icons\\INV_Gauntlets_05",
                        slot = L["Mail"] .. DOT .. INVTYPE_HAND,
                        levelRequirement = { text = fill(ITEM_MIN_LEVEL, 15), met = true },
                        armor = { { left = fill(ARMOR_TEMPLATE, 115), right = "", value = "115" } },
                        primary = { statLine("STRENGTH", 5), statLine("AGILITY", 3), statLine("STAMINA", 5) },
                    },
                    reagents = {
                        { name = itemName(2841, "Bronze Bar"), count = 10, have = 4, icon = { item = 2841 } },
                        { name = itemName(3470, "Rough Grinding Stone"), count = 4, have = 4, icon = { item = 3470 } },
                        { name = itemName(5498, "Small Lustrous Pearl"), count = 3, have = 1, icon = { item = 5498 } },
                    },
                    footerRight = { { left = { money = 400 }, right = "", sellPrice = true } },
                },
            },
            {
                label = "Quest item",
                fields = {
                    name = itemName(1307, "Gold Pickup Schedule"), quality = 1, icon = { item = 1307 },
                    quest = true, slot = ITEM_BIND_QUEST, startsQuest = ITEM_STARTS_QUEST,
                    header = { { left = ITEM_SOULBOUND, right = "" } },
                    flavor = { { left = quoted(L["A schedule of gold pickups."]), right = "" } },
                },
            },
        },
    },
    {
        key = "spell", label = "Spells", dataType = "Spell", model = "spellModel", first = "spellTitle", noun = "spell",
        samples = {
            {
                label = "Fireball",
                fields = {
                    name = spellName(133, "Fireball"), rank = fill(L["Rank %s"], 1), icon = { spell = 133 },
                    cost = { "30", MANA }, power = "Mana", cast = { fill(SPELL_DURATION_SEC, "1.5"), L["Cast"] },
                    range = { fill(L["%s yd"], 35), L["Range"] },
                    spellPower = 10,
                    description = { L["Hurls a fiery ball that causes 16 to 25 Fire damage and an "
                        .. "additional 2 Fire damage over 4 sec."] },
                },
            },
            {
                label = "Ability",
                fields = {
                    name = spellName(72, "Shield Bash"), rank = fill(L["Rank %s"], 1), icon = { spell = 72 },
                    cost = { "10", RAGE }, power = "Rage", cast = { SPELL_CAST_TIME_INSTANT, L["Cast"] },
                    cooldown = { fill(SPELL_DURATION_SEC, 12), L["Cooldown"] }, range = { MELEE, L["Range"] },
                    requirements = { { left = fill(SPELL_EQUIPPED_ITEM, L["Shields"]), right = "", color = { 1, .34, .28 } } },
                    details = { { left = fill(ITEM_COOLDOWN_TIME_SEC, 8), right = "", color = { 1, .60, .25 } } },
                    description = { L["Bashes the target with your shield for 8 damage. It also "
                        .. "interrupts spellcasting and prevents any spell in that school from being "
                        .. "cast for 6 sec."] },
                },
            },
            {
                label = "Heal",
                fields = {
                    name = spellName(635, "Holy Light"), rank = fill(L["Rank %s"], 1), icon = { spell = 635 },
                    cost = { "35", MANA }, power = "Mana", cast = { fill(SPELL_DURATION_SEC, "2.5"), L["Cast"] },
                    range = { fill(L["%s yd"], 40), L["Range"] },
                    spellPower = 10,
                    description = { L["Heals a friendly target for 42 to 51."] },
                    extras = { { left = fill(L["Spell ID: %s"], 635), right = "", color = { .60, .60, .63 } } },
                },
            },
        },
    },
    {
        key = "object", label = "Objects", dataType = "Object", model = "objectModel", first = "objectTitle",
        noun = "object", noLookup = true,
        samples = {
            {
                label = "Herb",
                fields = { name = L["Bruiseweed"], skill = "Herbalism", skillColor = { 1, .5, .25 } },
                -- Completing the model asks the game for them.
                after = { prices = { { SELL_PRICE, { money = 40 } }, { L["Auction"], { money = 1250 } } } },
            },
            {
                label = "Ore",
                fields = {
                    name = L["Mithril Deposit"], skill = "Mining", skillMet = false,
                    details = { { left = fill(LOCKED_WITH_SPELL, skill("Mining")), right = "", requirement = true, met = false } },
                    extras = { { left = fill(L["Gathered here %s times"], 12), right = "", color = { .17, .51, .77 } } },
                },
            },
            {
                label = "Chest",
                fields = {
                    name = L["Battered Chest"], skill = "Lockpicking",
                    details = {
                        { left = LOCKED, right = "" },
                        { left = fill(ITEM_MIN_SKILL, skill("Lockpicking"), 25), right = "", requirement = true, met = true },
                    },
                },
            },
            {
                label = "Quest",
                fields = {
                    name = L["Sealed Supply Crate"],
                    quests = {
                        { left = L["Heavy Supplies"], right = "", title = true },
                        { left = "- " .. L["Supply Crate: 2/5"], right = "" },
                        { left = "- " .. L["Report to the quartermaster"], right = "", completed = true },
                    },
                },
            },
        },
    },
    {
        key = "unit", label = "Units", dataType = "Unit", model = "unitModel", first = "unitName", noun = "unit",
        noLookup = true,
        samples = {
            {
                label = "Player",
                fields = {
                    name = "Somniferie", iconPath = "Interface\\Icons\\INV_Misc_Head_Human_02",
                    isPlayer = true, level = 60, race = L["Human"],
                    className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.WARRIOR or "Warrior",
                    classFile = "WARRIOR", guild = "Dawnbreakers", guildRealm = "Argent Dawn", faction = "Alliance", pvp = true, healthShare = 1,
                    target = L["Ragnaros"], targetColor = { 1, .27, .22 },
                    extras = { { left = fill(ITEM_LEVEL, 61), right = "", color = { .60, .60, .63 } } },
                },
            },
            {
                label = "Enemy",
                fields = {
                    name = L["Defias Pillager"], iconPath = "Interface\\Icons\\INV_Misc_Head_Human_01",
                    level = 15, creature = L["Humanoid"], classification = "elite", reaction = 2, healthShare = .64,
                    target = "Somniferie", targetIsYou = true,
                    quests = {
                        { left = L["The Defias Brotherhood"], right = "", title = true },
                        { left = "- " .. L["Defias Pillager slain: 4/10"], right = "" },
                    },
                },
            },
            {
                label = "Vendor",
                fields = {
                    name = L["Innkeeper Farley"], iconPath = "Interface\\Icons\\INV_Misc_Head_Dwarf_01",
                    tag = "<" .. L["Innkeeper"] .. ">", level = 30, creature = L["Humanoid"], reaction = 5, healthShare = 1,
                },
            },
            {
                label = "Rare",
                fields = {
                    name = L["Mother Fang"], iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
                    level = 10, creature = L["Beast"], classification = "rare", reaction = 2, healthShare = .38,
                },
            },
            {
                label = "Rare elite",
                fields = {
                    name = L["Foe Reaper 4000"], iconPath = "Interface\\Icons\\INV_Misc_Gear_01",
                    level = 20, creature = L["Mechanical"], classification = "rareelite", reaction = 2, healthShare = .82,
                },
            },
            {
                label = "Boss",
                fields = {
                    name = L["Azuregos"], iconPath = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
                    level = -1, creature = L["Dragonkin"], classification = "worldboss", reaction = 2, healthShare = .91,
                },
            },
        },
    },
    {
        key = "aura", label = "Buffs", dataType = "UnitAura", model = "auraModel", first = "auraName", noun = "aura",
        noLookup = true,
        samples = {
            {
                label = "Buff",
                fields = {
                    name = spellName(1245, "Power Word: Fortitude"), icon = { spell = 1245 }, dispel = "Magic",
                    harmful = false, text = L["Increases Stamina by 26."], remaining = fill(SPELL_TIME_REMAINING_MIN, 17),
                    duration = 1800, expiresIn = 1020, caster = "Somniferie",
                },
            },
            {
                label = "Curse",
                fields = {
                    name = spellName(980, "Curse of Agony"), icon = { spell = 980 }, dispel = "Curse", harmful = true,
                    text = L["Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, "
                        .. "and builds up as the Curse reaches its full duration."],
                    remaining = fill(SPELL_TIME_REMAINING_SEC, 16), duration = 24, expiresIn = 16,
                },
            },
            {
                label = "Poison",
                fields = {
                    name = spellName(2818, "Deadly Poison"), icon = { spell = 2818 }, dispel = "Poison", harmful = true,
                    stacks = 3, text = L["Inflicts 9 Nature damage every 3 sec."],
                    remaining = fill(SPELL_TIME_REMAINING_SEC, 9), duration = 12, expiresIn = 9,
                },
            },
        },
    },
    {
        key = "quest", label = "Quests", dataType = "Quest", model = "questModel", first = "questTitle", noun = "quest",
        noLookup = true,
        samples = {
            {
                label = "Active",
                fields = {
                    name = questName(378, "The Fury Runs Deep"), level = 27, tags = { LFG_TYPE_DUNGEON }, zone = L["The Stockade"],
                    active = true,
                    description = { L["Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr."] },
                    objectives = { { left = itemName(3640, "Head of Deepfury"), right = "0/1", completed = false } },
                },
            },
            {
                label = "Ready",
                fields = {
                    name = questName(33, "Wolves Across the Border"), level = 6, active = true, ready = true,
                    description = { L["Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner."] },
                    objectives = { { left = itemName(750, "Tough Wolf Meat"), right = "8/8", completed = true } },
                    extras = { { left = L["Ended by"], right = L["Eagan Peltskinner"] } },
                },
            },
            {
                label = "New",
                fields = {
                    name = questName(1014, "Arugal Must Die"), level = 27, tags = { LFG_TYPE_DUNGEON }, zone = L["Shadowfang Keep"],
                    description = { L["Dalar Dawnweaver wants Arugal dead and his head brought to him."] },
                    objectives = { { left = itemName(5442, "Head of Arugal") } },
                    extras = { { left = L["Started by"], right = L["Dalar Dawnweaver"] },
                        { left = L["Found in"], right = L["Silverpine Forest"] } },
                },
            },
        },
    },
    {
        key = "macro", label = "Macros", dataType = "Macro", model = "macroModel", first = "macroName", noun = "macro",
        noLookup = true,
        samples = {
            {
                label = "Cast",
                fields = {
                    name = L["Heal"], icon = { spell = 19750 },
                    body = { "#showtooltip", "/cast [@mouseover,help,nodead][] Flash of Light" },
                },
            },
            {
                label = "Targeting",
                fields = {
                    name = L["Rares"], icon = 132212,
                    body = { "/targetexact Mor'Ladim", "/targetexact Sewer Beast", "/run SetRaidTarget(\"target\", 8)" },
                },
            },
        },
    },
}
-- Retail's own parts in the samples (Retail/Samples.lua).
if ns.IsRetail() then
    ns.Retail.Samples.extend(TYPES, { statLine = statLine, itemName = itemName, spellName = spellName })
end

-- Markers ----------------------------------------------------------------------

local function icon(getter, id)
    if getter then
        local ok, found = pcall(getter, id)
        if ok and found then return found end
    end
    return QUESTION_MARK
end

local function money(marker)
    local text = ui.formatMoney(marker.money)
    if not marker.each then return text end
    return text .. "  |cff9E9485(" .. marker.count .. " \195\151 " .. ui.formatMoney(marker.each) .. ")|r"
end

-- A copy with each marker filled in.
local function resolve(value)
    if type(value) ~= "table" then return value end
    if value.item and next(value, next(value)) == nil then
        return icon(C_Item and C_Item.GetItemIconByID, value.item)
    end
    if value.spell and next(value, next(value)) == nil then
        return icon(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, value.spell)
    end
    if value.itemName then return ns.Game.itemName(value.itemName) or value[1] end
    if value.spellName then return ns.Game.spellName(value.spellName) or value[1] end
    if value.questName then return ns.Game.questName(value.questName) or L[value[1]] end
    if value.money then return money(value) end
    local copy = {}
    for key, item in pairs(value) do copy[key] = resolve(item) end
    return copy
end

local function stat(text)
    return { left = ns.Stats.styleStat(text, ns.option("statColors"), ns.option("statMarkers")), right = "" }
end

-- An item's stat strings as the rows the settings style, its enchant as rows,
-- and its disenchant results; the crafted item of a recipe likewise.
local function prepareItem(fields)
    for _, list in ipairs({ "primary", "secondary" }) do
        for index, text in ipairs(fields[list] or {}) do
            if type(text) == "string" then fields[list][index] = stat(text) end
        end
    end
    if fields.enchant then
        fields.enchants = {}
        for _, row in ipairs(ui.enchantRows(fields.enchant)) do fields.enchants[#fields.enchants + 1] = { left = row, right = "" } end
        fields.enchant = nil
    end
    if fields.disenchant then
        local spec = fields.disenchant
        fields.disenchant = ns.disenchantFor and ns.disenchantFor(spec[1], spec[2], spec[3], spec[4], nil, ns.Game)
    end
    if fields.created then fields.created = ui.itemModel(prepareItem(fields.created)) end
    return fields
end

-- A sample's model, built fresh on every draw.
local function build(sampleType, sample)
    local fields = resolve(sample.fields)
    if fields.expiresIn then fields.expires, fields.expiresIn = GetTime() + fields.expiresIn, nil end
    if sampleType.key == "item" then prepareItem(fields) end
    local model = ui[sampleType.model](fields)
    for key, value in pairs(resolve(sample.after or {})) do model[key] = value end
    return model
end

-- The types this client has, each with its samples' builders, in order.
function ns.editorSampleTypes()
    local types = {}
    for _, sampleType in ipairs(TYPES) do
        local dataType = Enum.TooltipDataType[sampleType.dataType]
        if dataType and ui[sampleType.model] then
            local samples = {}
            for index, sample in ipairs(sampleType.samples) do
                samples[index] = { label = sample.label, build = function() return build(sampleType, sample) end,
                    questID = type(sample.fields.name) == "table" and sample.fields.name.questName or nil }
            end
            types[#types + 1] = { key = sampleType.key, label = sampleType.label, dataType = dataType,
                samples = samples, first = sampleType.first, noun = sampleType.noun, noLookup = sampleType.noLookup }
        end
    end
    return types
end
