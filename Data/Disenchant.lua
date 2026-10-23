-- What an item disenchants into, from Classic's tables (Warcraft Wiki's
-- "Disenchanting tables"); the game has no API for them.
-- Forever only: retail's .toc leaves this file out.
local _, ns = ...
ns.provideData("disenchant")

local ARMOR, WEAPON = 4, 2
local UNCOMMON, RARE, EPIC = 2, 3, 4
local NEXUS = 20725
local NAMES = {
    [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust", [11176] = "Dream Dust",
    [16204] = "Illusion Dust",
    [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence",
    [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence",
    [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence",
    [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence",
    [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard",
    [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
    [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard",
    [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard",
    [NEXUS] = "Nexus Crystal",
}
-- For /ptip capture, which records each material's name and icon.
ns.disenchantMaterials = NAMES
-- Uncommon: { low, high, dust, dust count, essence, essence count, shard,
-- the main yield's chance, the other's, the shard's }. Armor mostly gives
-- dust and weapons essence; weapons from 51 on take 22 and 3.
local GREEN = {
    { 5, 15, 10940, { 1, 2 }, 10938, { 1, 2 }, nil, 80, 20, 0 },
    { 16, 20, 10940, { 2, 3 }, 10939, { 1, 2 }, 10978, 75, 20, 5 },
    { 21, 25, 10940, { 4, 6 }, 10998, { 1, 2 }, 10978, 75, 15, 10 },
    { 26, 30, 11083, { 1, 2 }, 11082, { 1, 2 }, 11084, 75, 20, 5 },
    { 31, 35, 11083, { 2, 5 }, 11134, { 1, 2 }, 11138, 75, 20, 5 },
    { 36, 40, 11137, { 1, 2 }, 11135, { 1, 2 }, 11139, 75, 20, 5 },
    { 41, 45, 11137, { 2, 5 }, 11174, { 1, 2 }, 11177, 75, 20, 5 },
    { 46, 50, 11176, { 1, 2 }, 11175, { 1, 2 }, 11178, 75, 20, 5 },
    { 51, 55, 11176, { 2, 5 }, 16202, { 1, 2 }, 14343, 75, 20, 5 },
    { 56, 60, 16204, { 1, 2 }, 16203, { 1, 2 }, 14344, 75, 20, 5 },
    { 61, 999, 16204, { 2, 5 }, 16203, { 2, 3 }, 14344, 75, 20, 5 },
}
local BLUE = {
    { 1, 25, 10978 }, { 26, 30, 11084 }, { 31, 35, 11138 }, { 36, 40, 11139 },
    { 41, 45, 11177 }, { 46, 50, 11178 }, { 51, 55, 14343 }, { 56, 999, 14344 },
}
local PURPLE = {
    { 40, 45, 11177, { 2, 4 } }, { 46, 50, 11178, { 2, 4 } }, { 51, 55, 14343, { 2, 4 } },
    { 56, 60, NEXUS, { 1, 1 } }, { 61, 999, NEXUS, { 1, 2 } },
}
local NOT_DISENCHANTABLE = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
-- Wands enchanters make.
local CRAFTED_WANDS = { [11287] = true, [11288] = true, [11289] = true, [11290] = true }

local function band(list, level)
    for _, entry in ipairs(list) do
        if level >= entry[1] and level <= entry[2] then return entry end
    end
end

-- Classic's Enchanting needed by item level.
local function skillFor(level, quality)
    if level <= 20 then return quality == RARE and 25 or 1 end
    if level <= 60 then return 25 + math.floor((level - 21) / 5) * 25 end
    return 225
end

local function yields(classID, quality, level)
    if quality == UNCOMMON then
        local entry = band(GREEN, level)
        if not entry then return end
        local dust = { id = entry[3], count = entry[4] }
        local essence = { id = entry[5], count = entry[6] }
        local main, other = dust, essence
        if classID == WEAPON then main, other = essence, dust end
        main.chance, other.chance = entry[8], entry[9]
        local shard = entry[10]
        if classID == WEAPON and level >= 51 then other.chance, shard = 22, 3 end
        local list = { main, other }
        if entry[7] then list[3] = { id = entry[7], count = { 1, 1 }, chance = shard } end
        return list
    elseif quality == RARE then
        local entry = band(BLUE, level)
        if not entry then return end
        if entry[3] == 14344 then
            return { { id = 14344, count = { 1, 1 }, chance = 99.5 }, { id = NEXUS, count = { 1, 1 }, chance = .5 } }
        end
        return { { id = entry[3], count = { 1, 1 }, chance = 100 } }
    elseif quality == EPIC then
        local entry = band(PURPLE, level)
        if entry then return { { id = entry[3], count = entry[4], chance = 100 } } end
    end
end

-- { skill, player, value, rows = { { id, name, icon, count, chance } } }, or
-- nil for an item that cannot be disenchanted. game answers the player's
-- Enchanting, the results' names and icons, and their auction prices.
function ns.disenchantFor(classID, quality, level, equipLoc, itemID, game)
    if classID ~= ARMOR and classID ~= WEAPON or CRAFTED_WANDS[itemID] then return end
    if type(quality) ~= "number" or type(level) ~= "number" or NOT_DISENCHANTABLE[equipLoc] then return end
    local list = yields(classID, quality, level)
    if not list then return end
    local result = { skill = skillFor(level, quality), player = game.skill("Enchanting"), rows = {} }
    local value, priced = 0, true
    for _, entry in ipairs(list) do
        local name = game.itemName(entry.id)
        local icon = game.itemIcon(entry.id)
        result.rows[#result.rows + 1] = {
            id = entry.id, name = name or NAMES[entry.id], icon = icon,
            count = entry.count, chance = entry.chance,
        }
        local price = game.auctionPrice(entry.id)
        if price then
            value = value + entry.chance / 100 * (entry.count[1] + entry.count[2]) / 2 * price
        elseif entry.chance >= 5 then
            priced = false
        end
    end
    if priced and value > 0 then result.value = math.floor(value) end
    return result
end
