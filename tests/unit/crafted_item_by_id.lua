-- A recipe nests the item it crafts under a line naming it by its id. The
-- game's lookup by name fails until the item is loaded, and the tooltip's
-- item is the recipe, so the crafted item takes its link and icon from that
-- id, and its kind, "Optional Crafting Reagent", goes under its name.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, NestedBlock = 19, ItemName = 22, ItemSpellTriggerLearn = 38 }
    local FILES = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" })
    local BLUE, WHITE, LIGHT = { r = 0, g = .44, b = .87 }, { r = 1, g = 1, b = 1 }, { r = .4, g = .73, b = 1 }
    local lines = {
        { type = LINE.ItemName, leftText = "Pattern: Snakeskin Lining", leftColor = BLUE },
        { type = LINE.NestedBlock, leftText = "", tooltipType = ITEM, tooltipID = 270898 },
        { type = LINE.ItemName, leftText = "\nSnakeskin Lining", leftColor = BLUE },
        { type = LINE.None, leftText = "Optional Crafting Reagent", leftColor = LIGHT },
        { type = LINE.ItemSpellTriggerLearn, leftText = "Use: Teaches you how to create Snakeskin Lining.",
            leftColor = WHITE },
        { type = LINE.None, leftText = "Embroidery Floss, Cursebound Globe (6)", leftColor = WHITE },
    }
    local capture = { calls = { ["C_Item.GetItemIconByID"] = { ["270898"] = { n = 1, 4549190 } } },
        enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 270900, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        line.lineIndex = index
        capture.data.lines[index] = line
        capture.lines[index] = { left = { text = line.leftText } }
    end
    local ns, world = test.load(FILES, capture)
    local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    local created = model.created or {}
    test.check("the crafted item by its id, its kind under its name",
        { name = created.name, link = created.link, icon = created.icon,
            slot = created.slot and created.slot:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") },
        { name = "Snakeskin Lining", link = 270898, icon = 4549190,
            slot = "Optional Crafting Reagent" })
end
