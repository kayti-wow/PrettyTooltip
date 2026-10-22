-- Retail's answers in place of Forever's (Game/Game.lua): a spell's mana cost,
-- the global cooldown after haste, and a class's specializations. It loads
-- just after that file; Retail/Game/Game.lua, before it, holds them.
local _, ns = ...
for name, answer in pairs(ns.Retail.Game) do
    assert(ns.Game[name], "retail answers what Game/Game.lua does not ask: " .. name)
    ns.Game[name] = answer
end
