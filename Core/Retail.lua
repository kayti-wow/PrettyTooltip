-- Loaded first, by the retail .toc alone. Classic-only data (spell power
-- coefficients, disenchant tables, herb, ore, and skinning loot) is left out of
-- that .toc; this flag turns off what is drawn from it and hides its settings.
-- Spell schools come from retail's own table, Data/SchoolsRetail.lua.
local _, ns = ...
ns.retail = true
