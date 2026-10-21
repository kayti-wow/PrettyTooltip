-- Retail's own code lives in this folder, which only retail's .toc
-- (PrettyTooltip_Mainline.toc) loads; this file comes first. Each file adds
-- its part to ns.Retail and loads just before the shared file that uses it.
-- Shared code reaches it only behind ns.IsRetail() (Core/Util.lua), so
-- Forever neither loads nor runs any of it.
-- Classic-only data (spell power coefficients, disenchant tables, herb, ore,
-- and skinning loot) is left out of that .toc, and what is drawn from it is
-- off. Spell schools come from retail's own table, Retail/Schools.lua.
local _, ns = ...
ns.Retail = {}
