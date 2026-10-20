-- A French client loads Locale\frFR.lua and reads its own tooltips: an item,
-- a spell, a herb node, and a boss, each worded as the French client words it.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/frFR.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    -- A model from lines, the first the name: each a left text, or { left, right }.
    local function read(kind, lines, nameType)
        local capture = { client = { locale = "frFR" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
            enums = { TooltipDataType = { Item = ITEM, Spell = SPELL, Unit = UNIT, Object = OBJECT },
                TooltipDataLineType = LINE },
            data = { type = kind, id = 2000, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and nameType or 0, lineIndex = index,
                leftText = left, rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local ns, world = test.load(FILES, capture)
        return ns.TooltipTypes[kind].read(world.main, capture.data, ns.Game), ns
    end

    local model, ns = read(ITEM, {
        "Faucheur en arcanite",
        "Lié quand équipé",
        { "Dégâts : 153 - 256", "Vitesse 3,80" },
        "(53,8 dégâts par seconde)",
        "+13 Endurance",
        "Durabilité 61 / 120",
        "Classes : Guerrier",
        "Niveau 58 requis",
    }, LINE.ItemName)
    test.check("frFR: supported", ns.Locale.supported, true)
    local primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left))
    test.check("frFR: an item", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = primary, durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Lié quand équipé", weapon = { "Dégâts : 153 - 256", "Vitesse 3,80" }, dps = "53,8",
        primary = "+13 Endurance", durability = { 61, 120 }, level = "Niveau 58 requis", extras = 0,
    })

    model = read(ITEM, { "Plans : Ceinture en anneaux de cuivre", "Forge (35) requis",
        "Utiliser : Vous apprend à forger une Ceinture en anneaux de cuivre." }, LINE.ItemName)
    test.check("frFR: a recipe", { model.skill and model.skill.name, model.effects[1] ~= nil }, { "Forge", true })

    model, ns = read(SPELL, {
        { "Boule de feu", "Rang 1" },
        { "Mana : 30", "portée de 35 m." },
        { "1,5 s d’incantation", "8 s de recharge" },
        "Projette une boule enflammée qui inflige 16 à 25 points de dégâts de Feu.",
    }, LINE.SpellName)
    test.check("frFR: a spell's strip", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Mana" }, { "1,5 s", "Incantation" }, { "8 s", "Recharge" }, { "35 m", "Portée" } })
    test.check("frFR: its school from the description", ns.Palette.detectSchool(model.description, "Boule de feu"),
        "Fire")
    test.check("frFR: a school after a curly apostrophe", {
        ns.Palette.detectSchool({ "Inflige 30 points de dégâts d’ombre." }, "Sort inconnu"),
        ns.Palette.detectSchool({ "Inflige 30 points de dégâts de feu-sacré." }, "Sort inconnu"),
    }, { "Shadow", "Holyfire" })
    test.check("frFR: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Doulourante", "Herboristerie" })
    test.check("frFR: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })

    model = read(UNIT, { "Azuregos", "Niveau ?? (Boss)" })
    test.check("frFR: a boss", model.classification, "worldboss")
end
