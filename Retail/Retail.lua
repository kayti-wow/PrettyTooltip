-- Retail's own code lives in the Retail/ folder, which only retail's .toc
-- (PrettyTooltip_Mainline.toc) loads; this file comes first. Each file adds
-- its part to ns.Retail, sits at the same path as the shared file that uses
-- it (Retail/Tooltips/Item.lua for Tooltips/Item.lua), and loads just before it.
-- Retail/Tooltips/ItemExtension.lua loads just after Tooltips/Item.lua instead:
-- it hands that file retail's callbacks (descriptor.extension).
-- Otherwise shared code reaches it only behind ns.IsRetail() (Core/Util.lua), so
-- Forever neither loads nor runs any of it.
-- Classic-only data (spell power coefficients, disenchant tables, herb, ore,
-- and skinning loot) is left out of that .toc, and what is drawn from it is
-- off. Spell schools come from retail's own table, Retail/Data/Schools.lua.
local _, ns = ...
ns.Retail = {}
