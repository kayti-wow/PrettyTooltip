-- In combat the game hides a spell's cooldown line and every line it draws.
-- In each client language the panel stays up and shows the hidden line unread.
return function(test)
    local SPELL, NAME, DESCRIPTION = 1, 13, 34
    local LANGUAGE_FILES = { enUS = false, deDE = "deDE", frFR = "frFR", esES = "esES", esMX = "esMX",
        ptBR = "Portuguese", ruRU = "ruRU", koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW" }
    local locales = {}
    for locale in pairs(LANGUAGE_FILES) do locales[#locales + 1] = locale end
    table.sort(locales)

    for _, locale in ipairs(locales) do
        local hidden = { __secret = true }
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = 0, Spell = SPELL },
                TooltipDataLineType = { None = 0, SpellName = NAME, SpellDescription = DESCRIPTION } },
            data = { type = SPELL, id = 1259799, lines = {
                { type = NAME, lineIndex = 1, leftText = "Spell", rightText = "" },
                { type = 0, lineIndex = 2, leftText = hidden, leftColor = { __secret = true } },
                { type = DESCRIPTION, lineIndex = 3, leftText = "A description." },
            } },
            lines = {} }
        for index = 1, 3 do
            capture.lines[index] = { left = { text = { __secret = true }, color = { { __secret = true },
                { __secret = true }, { __secret = true } } } }
        end
        local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua",
            "Tooltips/Spell.lua", "Integration/Native.lua", "Integration/Placement.lua" }
        if LANGUAGE_FILES[locale] then table.insert(files, 6, "Locale/" .. LANGUAGE_FILES[locale] .. ".lua") end
        local ns, world = test.load(files, capture)
        local model = ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game)
        local panel = ns.ui.getPanel(world.main)
        local drawn = false
        if model then
            ns.TooltipTypes[SPELL].render(panel, world.main, model)
            local font = panel.hiddenPool and panel.hiddenPool[1]
            drawn = font ~= nil and font._shown == true and issecretvalue(font._text)
        end
        test.check(locale .. ": the panel stays and shows the hidden line", {
            read = model ~= nil, name = model and model.name, hidden = model and model.hidden and #model.hidden,
            drawn = drawn, description = model and model.description[1],
        }, { read = true, name = "Spell", hidden = 1, drawn = true, description = "A description." })
    end
end
