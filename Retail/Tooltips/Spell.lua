-- Retail's spells with charges: "Max 2 Charges" as a part of its own under
-- the strip, the time each charge takes to come back in the strip, and the
-- time left on the next with the details. Tooltips/Spell.lua uses these on retail.
local _, ns = ...
local util = ns.util
local unformat = util.unformat
local L = ns.L
local spell = {}
ns.Retail.Spell = spell

local CHARGES_COLOR = { .60, .80, 1 }

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

local function chargesRow(part) return { left = part.charges, right = "" } end

function spell.chargesWidth(panel, part, styles)
    return ns.ui.rowWidth(panel, chargesRow(part), styles.spellCharges)
end

function spell.drawCharges(panel, part, y, styles)
    return ns.ui.drawRow(panel, chargesRow(part), y, styles.spellCharges, CHARGES_COLOR, 0, 2)
end
