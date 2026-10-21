-- An optional reagent names what it does as "Provides the following property:
-- ..." and its "+15 Recipe Difficulty" in green. In each client language both
-- go with its crafting lines: the property as an effect without the lead-in,
-- the difficulty as it is, and neither among its stats or extras.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 1 }
    local LANGUAGE_FILES = { enUS = false, deDE = "deDE", frFR = "frFR", esES = "esES", esMX = "esMX",
        ptBR = "Portuguese", ruRU = "ruRU", koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW" }
    local locales = {}
    for locale in pairs(LANGUAGE_FILES) do locales[#locales + 1] = locale end
    table.sort(locales)
    local WHITE, GREEN, GOLD = { r = 1, g = 1, b = 1 }, { r = .1, g = 1, b = .1 }, { r = 1, g = .82, b = 0 }
    local EFFECT = "Your spells have a chance to fire 5 Big Booms."

    for _, locale in ipairs(locales) do
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3003, lines = {} }, lines = {} }
        local files = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
            "Panel/Render.lua", "Tooltips/Item.lua" })
        if LANGUAGE_FILES[locale] then
            local at
            for index, file in ipairs(files) do if file == "Locale/English.lua" then at = index end end
            table.insert(files, at + 1, "Locale/" .. LANGUAGE_FILES[locale] .. ".lua")
        end
        local ns, world = test.load(files, capture)

        -- The game's own wording in this language, read once it is loaded.
        local difficulty = "|cff19ff19+15 " .. OPTIONAL_REAGENT_TOOLTIP_DIFFICULTY_ADJUST:gsub("[:：]$", "") .. "|r"
        local property = PROFESSIONS_MODIFIED_CRAFTING_REAGENT_DESCRIPTION:gsub("%%1?%$?s", function()
            return "|n" .. EFFECT
        end)
        local lines = { { "B0P", WHITE }, { difficulty, GOLD }, { " ", GOLD }, { property, GREEN } }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = index == 1 and LINE.ItemName or LINE.None, lineIndex = index,
                leftText = line[1], leftColor = line[2] }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
        local effects = {}
        for _, row in ipairs(model.effects) do effects[#effects + 1] = row.left end
        test.check(locale .. ": the difficulty and the property with the crafting lines",
            { effects = effects, secondary = #model.secondary, extras = #model.extras },
            { effects = { difficulty, EFFECT }, secondary = 0, extras = 0 })
    end
end
