-- Retail names an expansion's reagents after it: "Zandalari Crafting Reagent".
-- The line joins the item's kinds under its name, in its own words and the
-- game's color, as "Crafting Reagent" does; a sentence naming one does not.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 1 }
    local FILES = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" })
    local BLUE, GREEN = { r = .4, g = .733, b = 1 }, { r = .1, g = 1, b = .1 }
    local function read(lines, files)
        local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3002, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = index == 1 and LINE.ItemName or 0, lineIndex = index,
                leftText = line[1], leftColor = line[2] }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local ns, world = test.load(files or FILES, capture)
        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    end
    local WHITE = { r = 1, g = 1, b = 1 }

    local model = read({ { "Deep Sea Satin", WHITE }, { "Zandalari Crafting Reagent", BLUE } })
    test.check("an expansion's reagent under the name, in its words and color", { model.slot, #model.extras },
        { "|cff66BBFFZandalari Crafting Reagent|r", 0 })
    model = read({ { "Ingenious Identifier", WHITE }, { "Kul Tiran Finishing Crafting Reagent", BLUE } })
    test.check("the longest kind it names", model.slot, "|cff66BBFFKul Tiran Finishing Crafting Reagent|r")
    model = read({ { "Odd Bauble", WHITE }, { "Use: Turns a Crafting Reagent into dust.", GREEN },
        { "Gives a Crafting Reagent to a friend.", GREEN } })
    test.check("a sentence naming one is not a kind", model.slot, nil)

    -- Forever keeps its exact kinds.
    local forever = {}
    for _, file in ipairs(FILES) do if not file:match("^Retail/") then forever[#forever + 1] = file end end
    model = read({ { "Deep Sea Satin", WHITE }, { "Zandalari Crafting Reagent", BLUE } }, forever)
    test.check("Forever reads it as before", { model.slot, #model.extras }, { nil, 1 })
end
