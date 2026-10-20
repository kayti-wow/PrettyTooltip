-- Retail names a recipe's profession by its expansion: "Requires Midnight
-- Blacksmithing (50)", on a line the game marks as a requirement. A reagent
-- whose name holds a profession's ("Elixir of Mining") is no profession.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 22, UsageRequirement = 43 }
    local function read(lines)
        local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = line[2], lineIndex = index, leftText = line[1],
                leftColor = { r = 1, g = 1, b = 1 } }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local ns, world = test.load({ "Core/Retail.lua", "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }, capture)
        PrettyTooltipDB = {}
        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    end
    local model = read({ { "Plans: Murder Row Fishhook", LINE.ItemName },
        { "Requires Khaz Algar Blacksmithing (25)", LINE.UsageRequirement } })
    test.check("an expansion's profession, on a requirement line",
        { model.skill and model.skill.name, model.skill and model.skill.level }, { "Khaz Algar Blacksmithing", 25 })
    model = read({ { "Recipe: Mining Tonic", LINE.ItemName }, { "Requires Elixir of Mining (2)", LINE.None } })
    test.check("a reagent named for a profession is not one", model.skill, nil)
    model = read({ { "Plans: Copper Chain Belt", LINE.ItemName }, { "Requires Blacksmithing (35)", LINE.None } })
    test.check("a profession's own name, on any line", model.skill and model.skill.name, "Blacksmithing")
end
