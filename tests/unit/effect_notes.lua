-- Retail notes why an effect is inactive: "Legacy Item: Effects are inactive"
-- before it, an error in red, "You are in the wrong zone.", under it; and an
-- effect's charges under it. Each stays beside its effect; one under no effect
-- stays where it was, and Forever reads them as before.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 1, ErrorLine = 41 }
    local FILES = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" })
    local WHITE, GREEN, GREY = { r = 1, g = 1, b = 1 }, { r = 0, g = 1, b = 0 }, { r = .5, g = .5, b = .5 }
    local RED, BLUE = { r = 1, g = .125, b = .125 }, { r = 0, g = .8, b = 1 }
    local function read(lines, files)
        local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3004, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = line[3] or (index == 1 and LINE.ItemName or LINE.None),
                lineIndex = index, leftText = line[1], leftColor = line[2] }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local ns, world = test.load(files or FILES, capture)
        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    end
    local function rows(list)
        local out = {}
        for _, row in ipairs(list) do out[#out + 1] = { row.left, row.note or false } end
        return out
    end

    local model = read({ { "Belt", WHITE }, { "Equip: Fire.", GREY }, { "You are in the wrong zone.", RED, LINE.ErrorLine },
        { "Use: Hide.", GREEN } })
    test.check("an error under its equip effect", rows(model.equipEffects),
        { { "Fire.", false }, { "You are in the wrong zone.", true } })
    test.check("its use effect apart", rows(model.effects), { { "Hide.", false } })

    model = read({ { "Belt", WHITE }, { "+5 Stamina", WHITE }, { "You are in the wrong zone.", RED, LINE.ErrorLine } })
    test.check("an error under no effect stays an extra", { #model.equipEffects, #model.effects, #model.extras },
        { 0, 0, 1 })

    model = read({ { "Fist", WHITE }, { "Legacy Item: Effects are inactive", BLUE } })
    test.check("a legacy note with no effect after it stays with the effects", rows(model.effects),
        { { "Legacy Item: Effects are inactive", true } })

    -- An effect's charges, worded, under it; with no effect before, where they were.
    model = read({ { "Lens", WHITE }, { "Use: Beam.", GREEN }, { "1 |4Charge:Charges;", WHITE } })
    test.check("one charge under its use effect", rows(model.effects), { { "Beam.", false }, { "1 Charge", true } })
    model = read({ { "Lens", WHITE }, { "Use: Beam.", GREEN }, { "No charges", WHITE } })
    test.check("no charges under its use effect", rows(model.effects), { { "Beam.", false }, { "No charges", true } })
    model = read({ { "Lens", WHITE }, { "3 |4Charge:Charges;", WHITE } })
    test.check("charges under no effect stay an extra", { #model.effects, #model.extras }, { 0, 1 })

    local forever = {}
    for _, file in ipairs(FILES) do if not file:match("^Retail/") then forever[#forever + 1] = file end end
    model = read({ { "Belt", WHITE }, { "Equip: Fire.", GREY }, { "You are in the wrong zone.", RED, LINE.ErrorLine } },
        forever)
    test.check("Forever reads the error as before", { #model.equipEffects, #model.extras }, { 1, 1 })
end
