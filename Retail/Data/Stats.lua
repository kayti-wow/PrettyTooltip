-- Retail's stats: its secondary stats and the minor ones under them, which
-- Data/Stats.lua adds to its own (ns.contribute "stats"), and the grey of a
-- stat that does not count for the player's specialization.
local _, ns = ...
local util = ns.util
local L = ns.L
local stats = {}
ns.Retail.Stats = stats

-- Retail's secondary stats each in a color of its own, and its minor stats
-- (Leech, Avoidance, Speed, and a profession tool's) in one; the style editor
-- offers them on retail.
stats.CATEGORIES = {
    { key = "CriticalStrike", label = L["Critical Strike"], value = "F7A38E", name = "F5C8BC" },
    { key = "Haste", label = L["Haste"], value = "F2D57C", name = "F3E2B0" },
    { key = "Mastery", label = L["Mastery"], value = "C3A6F7", name = "D8CAF5" },
    { key = "Versatility", label = L["Versatility"], value = "86D4CC", name = "BDE6E1" },
    { key = "Minor", label = L["Leech, Avoidance, and Speed"], value = "D2C4A8", name = "E3DACA" },
}

local function mod(name) return _G["ITEM_MOD_" .. name] end

-- Retail's ratings, as its items print them: "+120 Haste".
stats.STATS = {
    CRITICAL_STRIKE = { category = "CriticalStrike", name = mod("CRIT_RATING_SHORT") },
    HASTE = { category = "Haste", name = mod("HASTE_RATING_SHORT") },
    MASTERY = { category = "Mastery", name = mod("MASTERY_RATING_SHORT") },
    VERSATILITY = { category = "Versatility", name = mod("VERSATILITY") },
    LEECH = { category = "Minor", name = mod("CR_LIFESTEAL_SHORT") },
    AVOIDANCE = { category = "Minor", name = mod("CR_AVOIDANCE_SHORT") },
    SPEED = { category = "Minor", name = mod("CR_SPEED_SHORT") },
    -- A profession tool's or accessory's stats, with the minor ones.
    INGENUITY = { category = "Minor", name = mod("INGENUITY_SHORT") },
    MULTICRAFT = { category = "Minor", name = mod("MULTICRAFT_SHORT") },
    RESOURCEFULNESS = { category = "Minor", name = mod("RESOURCEFULNESS_SHORT") },
    CRAFTING_SPEED = { category = "Minor", name = mod("CRAFTING_SPEED_SHORT") },
    PERCEPTION = { category = "Minor", name = mod("PERCEPTION_SHORT") },
    DEFTNESS = { category = "Minor", name = mod("DEFTNESS_SHORT") },
    FINESSE = { category = "Minor", name = mod("FINESSE_SHORT") },
    -- A recipe's crafted gear before its secondary stats are chosen: "+32 Random Stat 1".
    RANDOM_STAT_1 = { category = "Minor", name = mod("MODIFIED_CRAFTING_STAT_1") },
    RANDOM_STAT_2 = { category = "Minor", name = mod("MODIFIED_CRAFTING_STAT_2") },
}

-- The marker greyed, as the 32 px art tinted.
local INACTIVE_MARKER = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2:32:32:0:32:0:32:128:128:128|t  "

-- A stat that does not count, as retail's primary stats for another
-- specialization: without its colors, under a grey marker where stats have one.
function stats.inactiveStat(text, markers)
    local plain = util.uncolored(text):gsub("^|T.-|t%s*", "")
    return (markers and INACTIVE_MARKER or "") .. plain
end

ns.contribute("stats", { label = "Secondary stat colors", categories = stats.CATEGORIES, stats = stats.STATS })
