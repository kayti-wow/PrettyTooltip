-- Retail's part in reading units, through the callbacks Tooltips/Unit.lua
-- offers a client (descriptor.extension). It loads just after that file;
-- Retail/Tooltips/Unit.lua, before it, holds what these use.
local _, ns = ...
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
local descriptor = ns.TooltipTypes and ns.TooltipTypes[UNIT]
if not descriptor then return end
local unit = ns.Retail.Unit

descriptor.extension = {
    -- A player's specialization, named with the class.
    afterRead = function(model, context)
        if model.isPlayer then unit.readSpec(model, context.game) end
    end,
}
