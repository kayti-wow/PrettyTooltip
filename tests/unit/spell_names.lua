-- The data names class spells by ID, with their English names: a client in
-- another language is asked for its own names, and an English one is not.
return function(test)
    local function load(locale, calls)
        return test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
        "Game/Game.lua", "Data/Schools.lua",
            "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua" }, { client = { locale = locale }, calls = calls })
    end
    local game = { spellDamage = function() return 0 end, spellHealing = function() return 0 end }
    local function rank(ns, name)
        local rows = ns.spellPowerRows({ name = name, rank = "Rang 3", cast = { "Instant", "Cast" },
            description = { "Verursacht 62 bis 68 Frost damage." } }, "FFFFFF", game)
        return rows and rows[1].right:match("(%d+[%.,]%d)%%")
    end

    local ns = load("deDE", { ["C_Spell.GetSpellName"] = {
        ["116"] = { n = 1, "Frostblitz" }, ["139"] = { n = 1, "Erneuerung" } } })
    test.check("deDE: a school by the client's name", { ns.spellSchool("Frostblitz"), ns.spellSchool("Erneuerung") },
        { "Frost", "Holy" })
    test.check("deDE: not by the English one", ns.spellSchool("Frostbolt"), nil)
    test.check("deDE: a name the client does not give stays English", ns.spellSchool("Fireball"), "Fire")
    test.check("deDE: a rank by the client's name", rank(ns, "Frostblitz"), "59,7")
    -- Unknown by name, it is no class spell, and has no rank to read.
    test.check("deDE: not a rank by the English name", rank(ns, "Frostbolt"), nil)

    ns = load("enUS", {})
    test.check("enUS: the English names, without asking", ns.spellSchool("Frostbolt"), "Frost")
    test.check("enUS: a rank by name", rank(ns, "Frostbolt"), "59.7")
end
