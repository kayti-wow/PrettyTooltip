-- Retail's classes, which Forever has none of: Core/Palette.lua adds them to
-- its own (ns.contribute "classes"), each after the one its after names, so
-- the style editor offers their colors in the game's order.
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
