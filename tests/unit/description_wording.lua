-- Spell descriptions are read by the phrases a language file gives
-- (ns.Locale.descriptions, schoolWords): a German client with German phrases
-- reads a German description as the English one reads its own.
return function(test)
    -- A language file's phrases, loaded where one loads: after English.lua.
    local function german(_, ns)
        local words = ns.Locale.descriptions
        words.range, words.school = "%d bis %d", { "%sschaden", "%szauber" }
        ns.Locale.schoolWords = { Fire = "Feuer", Frost = "Frost", Shadow = "Schatten", Holy = "Heilig",
            Nature = "Natur", Arcane = "Arkan" }
    end
    local function load(locale, language)
        local files = { "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua", language,
            "Game/Game.lua", "Data/Schools.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua" }
        if not language then table.remove(files, 5) end
        return test.load(files, { client = { locale = locale } })
    end
    local game = { spellDamage = function() return 30 end, spellHealing = function() return 300 end }
    local function rows(ns, cast, text)
        local found = ns.spellPowerRows({ name = "?", cast = { cast, "Cast" }, description = { text }, spellID = 2136 },
            "FFFFFF", game)
        return found and found[1].left .. " | " .. found[1].right:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    local ns = load("deDE", german)
    test.check("deDE: a school in the language's words",
        ns.Palette.detectSchool({ "\195\156berzieht den Feind mit 39 bis 48 Punkt(en) Feuerschaden." }), "Fire")
    test.check("deDE: not inside another word", ns.Palette.detectSchool({ "Ruft einen Steinfeuerschaden herbei." }),
        nil)
    test.check("deDE: a name that opens with a school", ns.Palette.detectSchool({}, "Frost Nova"), "Frost")
    test.check("deDE: an amount from the language's range", rows(ns, "Spontan",
        "\195\156berzieht den Feind mit 39 bis 48 Punkt(en) Feuerschaden."),
        "Spell Power Coefficient | 42,9% \194\183 27 to 36 + 12")

    ns = load("enUS")
    test.check("enUS: the same spell in English", rows(ns, "Instant", "Blasts the enemy for 39 to 48 Fire damage."),
        "Spell Power Coefficient | 42.9% \194\183 27 to 36 + 12")
    test.check("enUS: health is not healing", ns.spellPowerRows({ name = "?", cast = { "Instant", "Cast" },
        description = { "Summons a totem with 5 health for 45 sec." } }, "FFFFFF", game), nil)
end
