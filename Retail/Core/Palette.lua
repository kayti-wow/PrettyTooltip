-- Retail's colors: its four classes, which Forever has none of, and the colors
-- of retail's own lines. Core/Palette.lua adds the classes to its own
-- (ns.contribute "classes"), each after the one its after names, so the style
-- editor offers their colors in the game's order.
local _, ns = ...
local palette = {}
ns.Retail.Palette = palette

palette.CLASSES = {
    { after = "PRIEST", key = "DEATHKNIGHT", label = "Death Knight" },
    { after = "WARLOCK", key = "MONK", label = "Monk" },
    { after = "DRUID", key = "DEMONHUNTER", label = "Demon Hunter" },
    { after = "DEMONHUNTER", key = "EVOKER", label = "Evoker" },
}
ns.contribute("classes", palette.CLASSES)

-- Retail's own lines in the game's colors, by the style part each is drawn
-- with: Retail/Core/Settings.lua's parts start from them in the editor, and
-- the panel draws them so unless the editor sets one.
palette.parts = {
    itemSource = { .12, 1, .12 },
    itemCosmetic = { 1, .50, 1 },
    itemUpgrade = { .90, .80, .55 },
    craftingQuality = { .90, .85, .74 },
    itemTransmog = { 1, .50, 1 },
    secondaryStats = { .90, .85, .74 },
    gems = { .90, .85, .74 },
    spellCharges = { .60, .80, 1 },
}
