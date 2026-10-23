-- Retail's item data, which Tooltips/Item.lua adds to its own lists: the kinds
-- of reagent retail names on a line of their own, as "Finishing Crafting
-- Reagent" (ns.contribute "itemKinds"), which join the item's slot under its
-- name. Reading and drawing retail's lines is in Retail/Tooltips/ItemExtension.lua.
local _, ns = ...

local kinds = {}
for _, kind in pairs({ PROFESSIONS_MODIFIED_CRAFTING_REAGENT_FINISHING, PROFESSIONS_MODIFIED_CRAFTING_REAGENT }) do
    if type(kind) == "string" then kinds[#kinds + 1] = kind end
end
ns.contribute("itemKinds", kinds)
