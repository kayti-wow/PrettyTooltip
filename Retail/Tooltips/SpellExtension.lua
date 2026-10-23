-- Retail's spells with charges, through the callbacks Tooltips/Spell.lua
-- offers a client (descriptor.extension): "Max 2 Charges" as a part of its
-- own under the strip, and the time left on the next charge with the details.
-- The game's notes on whether a spell is on the action bars stay with the
-- details too. It loads just after that file; the recharge time in the strip
-- is Retail/Tooltips/Spell.lua's.
local _, ns = ...
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
local descriptor = ns.TooltipTypes and ns.TooltipTypes[SPELL]
if not descriptor then return end
local util = ns.util
local unformat = util.unformat
local CHARGES_COLOR = ns.Retail.Palette.parts.spellCharges

-- The spellbook's and talent window's notes on whether a spell is on the
-- action bars, which the game adds under the spell's own lines.
local ACTION_BAR_NOTES = { "SPELLBOOK_SPELL_NOT_ON_ACTION_BAR", "TALENT_BUTTON_TOOLTIP_NOT_ON_ACTION_BAR",
    "TALENT_BUTTON_TOOLTIP_ON_INACTIVE_BONUSBAR" }

descriptor.extension = {
    -- "Max 2 Charges", kept as the game words it.
    readStat = function(model, text)
        if not tonumber((unformat(text, SPELL_MAX_CHARGES))) then return false end
        model.charges = text
        return true
    end,

    -- "Recharging: 5 sec", the time left on the next charge, with the cooldown left.
    isCooldown = function(text)
        return unformat(text, SPELL_RECHARGE_TIME) ~= nil
    end,

    -- Its charges at the head of its details, in their own style and color.
    leadRows = function(part)
        if not part.charges then return {} end
        return { { left = part.charges, right = "", style = "spellCharges", color = CHARGES_COLOR } }
    end,

    -- "You haven't added this to your action bars", with the details.
    isDetail = function(left, right)
        if right and util.trim(right) ~= "" then return false end
        for _, name in ipairs(ACTION_BAR_NOTES) do
            local note = _G[name]
            if type(note) == "string" and unformat(left, note) == true then return true end
        end
        return false
    end,
}
