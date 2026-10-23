-- Retail's spells: what they cost in retail's own resources, as Holy Power,
-- in the strip, and those with charges: "Max 2 Charges" as a part of its own
-- under the strip, the time each charge takes to come back in the strip, and
-- the time left on the next with the details. Tooltips/Spell.lua reads and
-- draws them through Retail/Tooltips/SpellExtension.lua.
local _, ns = ...
local util = ns.util
local unformat = util.unformat
local L = ns.L
local spell = {}
ns.Retail.Spell = spell

local CHARGES_COLOR = { .60, .80, 1 }

-- Retail's resources besides Forever's five, which Tooltips/Spell.lua adds to
-- its own (ns.contribute "spellPowers"): by the key the panel colors it by,
-- the game's name for it, and the lines that cost it, "3 Holy Power". The
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

-- The strip's recharge time, by the line that states it and the duration the
-- strip shows it as; Tooltips/Spell.lua adds them to its own times.
spell.TIMES = {
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_SEC, SPELL_DURATION_SEC },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_MIN, SPELL_DURATION_MIN },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_HOURS, SPELL_DURATION_HOURS },
    { "cooldown", L["Recharge"], SPELL_RECAST_TIME_CHARGES_DAYS, SPELL_DURATION_DAYS },
}

-- "Max 2 Charges", kept as the game words it.
function spell.readCharges(model, text)
    if not tonumber((unformat(text, SPELL_MAX_CHARGES))) then return false end
    model.charges = text
    return true
end

-- "Recharging: 5 sec", the time left on the next charge.
function spell.isRecharge(text)
    return unformat(text, SPELL_RECHARGE_TIME) ~= nil
end

-- The spellbook's and talent window's notes on whether a spell is on the
-- action bars, which the game adds under the spell's own lines.
local ACTION_BAR_NOTES = { "SPELLBOOK_SPELL_NOT_ON_ACTION_BAR", "TALENT_BUTTON_TOOLTIP_NOT_ON_ACTION_BAR",
    "TALENT_BUTTON_TOOLTIP_ON_INACTIVE_BONUSBAR" }

-- Whether a line the game added is one of those notes, kept with the details.
function spell.isDetail(left, right)
    if right and util.trim(right) ~= "" then return false end
    for _, name in ipairs(ACTION_BAR_NOTES) do
        local note = _G[name]
        if type(note) == "string" and unformat(left, note) == true then return true end
    end
    return false
end

-- Its charges at the head of its details, in their own style and color.
function spell.leadRows(part)
    if not part.charges then return {} end
    return { { left = part.charges, right = "", style = "spellCharges", color = CHARGES_COLOR } }
end
