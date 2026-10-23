-- Retail's spell data, which Tooltips/Spell.lua adds to its own lists:
-- retail's resources (ns.contribute "spellPowers") and the time a charge
-- takes to come back (ns.contribute "spellTimes"). Reading and drawing
-- charges is in Retail/Tooltips/SpellExtension.lua.
local _, ns = ...
local L = ns.L
local spell = {}
ns.Retail.Spell = spell

-- Retail's resources besides Forever's five: by the key the panel colors it
-- by, the game's name for it, and the lines that cost it, "3 Holy Power". The
-- colors are the game's power bar colors, lifted where they read too dark on
-- the panel (Insanity, Soul Shards, Arcane Charges).
spell.POWERS = {
    { key = "Holy Power", name = HOLY_POWER, costs = { HOLY_POWER_COST }, color = { .95, .90, .60 } },
    { key = "Fury", name = FURY, costs = { FURY_COST }, color = { .79, .26, .99 } },
    { key = "Pain", name = PAIN, costs = { PAIN_COST, PAIN_COST_LARGE }, color = { 1, .61, 0 } },
    { key = "Insanity", name = INSANITY, costs = { INSANITY_COST, INSANITY_COST_LARGE }, color = { .60, .30, .95 } },
    { key = "Maelstrom", name = MAELSTROM, costs = { MAELSTROM_COST, MAELSTROM_COST_LARGE }, color = { 0, .50, 1 } },
    { key = "Astral Power", name = LUNAR_POWER, costs = { LUNAR_POWER_COST, LUNAR_POWER_COST_LARGE },
        color = { .30, .52, .90 } },
    { key = "Chi", name = CHI_POWER, costs = { CHI_COST }, color = { .71, 1, .92 } },
    { key = "Soul Shards", name = SOUL_SHARDS_POWER, costs = { SOUL_SHARDS_COST }, color = { .65, .45, .75 } },
    { key = "Arcane Charges", name = POWER_TYPE_ARCANE_CHARGES, costs = { ARCANE_CHARGES_COST },
        color = { .40, .55, 1 } },
    { key = "Combo Points", name = COMBO_POINTS_POWER, costs = { COMBO_POINTS_COST }, color = { 1, .96, .41 } },
    { key = "Essence", name = POWER_TYPE_ESSENCE, costs = { ESSENCE_COST }, color = { .40, .80, 1 } },
    { key = "Runes", name = RUNES, costs = { RUNE_COST }, color = { .50, .50, .50 } },
    { key = "Health", name = HEALTH, costs = { HEALTH_COST }, color = { 0, 1, 0 } },
}
ns.contribute("spellPowers", spell.POWERS)

-- A spell with charges states the time each takes to come back instead of a
-- cooldown: by the line that states it and the duration the strip shows it as.
spell.TIMES = {
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_SEC, SPELL_DURATION_SEC },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_MIN, SPELL_DURATION_MIN },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_HOURS, SPELL_DURATION_HOURS },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_DAYS, SPELL_DURATION_DAYS },
}
ns.contribute("spellTimes", spell.TIMES)
