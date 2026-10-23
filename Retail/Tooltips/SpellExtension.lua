-- Retail's part in reading and drawing spells, through the callbacks Tooltips/Spell.lua
-- offers a client (descriptor.extension). It loads just after that file;
-- Retail/Tooltips/Spell.lua, before it, holds what these use.
local _, ns = ...
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
local descriptor = ns.TooltipTypes and ns.TooltipTypes[SPELL]
if not descriptor then return end
local spell = ns.Retail.Spell

-- A spell with charges states the time each takes to come back instead.
for _, time in ipairs(spell.TIMES) do descriptor.times[#descriptor.times + 1] = time end
-- Charges are drawn in their own style.
descriptor.parts[#descriptor.parts + 1] = "spellCharges"

descriptor.extension = {
    -- "Max 2 Charges".
    readStat = spell.readCharges,
    -- "Recharging: 5 sec", with the cooldown left.
    isCooldown = spell.isRecharge,
    -- "Max 2 Charges", first among its details.
    leadRows = spell.leadRows,
    -- "You haven't added this to your action bars", with the details.
    isDetail = spell.isDetail,
}
