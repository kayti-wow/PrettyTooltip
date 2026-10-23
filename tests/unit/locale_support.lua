-- The addon reads a client's tooltips only where its language is supported,
-- and shows a feature that reads more than the game's strings only where the
-- language turns it on.
return function(test)
    local SPELL = 1
    local function load(locale, language)
        local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", language, "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
            "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" }
        if not language then table.remove(files, 6) end
        return test.load(files, { client = { locale = locale }, enums = { TooltipDataType = { Item = 0, Spell = SPELL } } })
    end

    local ns = load("ruRU")
    test.check("a language without its file: no panels", { ns.Locale.supported, ns.ui == nil }, { false, true })

    -- A Fireball sample's drawn text holds its spell power rows where the
    -- language has them.
    local function powerRows(loaded)
        local model = loaded.ui.spellModel({ name = "Fireball", rank = "Rank 1", cast = { "1.5 sec", "Cast" },
            cost = { "30", "Mana" }, power = "Mana", spellPower = 10,
            description = { "Hurls a fiery ball that causes 16 to 25 Fire damage." } })
        local panel = loaded.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, SPELL)
        for _, font in ipairs(panel.pool) do
            if font._shown and (font._text or ""):find("Coefficient", 1, true) then return true end
        end
        return false
    end
    ns = load("enUS")
    test.check("enUS: supported, with the spell power rows", { ns.Locale.supported, powerRows(ns) }, { true, true })
    ns = load("enUS", function(_, loaded) loaded.Locale.features.coefficients = false end)
    test.check("a language without them shows none", powerRows(ns), false)
end
