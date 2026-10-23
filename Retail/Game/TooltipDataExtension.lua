-- Retail's answers in place of Forever's (Game/TooltipData.lua): the color of
-- a line the game greys or reds. It loads just after that file;
-- Retail/Game/TooltipData.lua, before it, holds them.
local _, ns = ...
for name, answer in pairs(ns.Retail.TooltipData) do
    assert(ns.TooltipData[name], "retail answers what Game/TooltipData.lua does not ask: " .. name)
    ns.TooltipData[name] = answer
end
