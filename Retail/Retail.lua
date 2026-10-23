-- Retail's own code lives in the Retail/ folder, which only retail's .toc
-- (PrettyTooltip_Mainline.toc) loads; this file comes first. Shared code never
-- names retail: retail reaches it in two ways, so Forever neither loads nor
-- runs any of it.
-- - Before a shared file: Retail/<path>.lua, at the same path as the shared
--   file it serves (Retail/Data/Stats.lua for Data/Stats.lua), adds its part to
--   ns.Retail, and what it adds to that file's lists through ns.contribute
--   (Core/Util.lua).
-- - After a shared file: Retail/<path>Extension.lua puts retail's callbacks in
--   a tooltip type's descriptor.extension (Retail/Tooltips/ItemExtension.lua),
--   or its answers in place of the shared ones (Retail/Game/GameExtension.lua).
-- Classic-only data (spell power coefficients, disenchant tables, herb, ore,
-- and skinning loot) is left out of that .toc, and what is drawn from it is
-- off. Spell schools come from retail's own table, Retail/Data/Schools.lua.
local _, ns = ...
ns.Retail = {}
