-- A German client loads Locale\deDE.lua and reads its own tooltips: an item,
-- a spell, a herb node, and a boss, each worded as the German client words it.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/deDE.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/NodeSkills.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    -- A model from lines, the first the name: each a left text, or { left, right }.
    local function read(kind, lines, nameType)
        local capture = { client = { locale = "deDE" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "Arkanitschnitter",
        "Wird beim Anlegen gebunden",
        { "153 - 256 Schaden", "Tempo 3,80" },
        "(53,8 Schaden pro Sekunde)",
        "+13 Ausdauer",
        "Haltbarkeit 61 / 120",
        "Klassen: Krieger",
        "Benötigt Stufe 58",
    }, LINE.ItemName)
    test.check("deDE: supported", ns.Locale.supported, true)
    local primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left))
    test.check("deDE: an item", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = primary, durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Wird beim Anlegen gebunden", weapon = { "153 - 256 Schaden", "Tempo 3,80" }, dps = "53,8",
        primary = "+13 Ausdauer", durability = { 61, 120 }, level = "Benötigt Stufe 58", extras = 0,
    })

    model = read(ITEM, { "Pläne: Kupferkettengürtel", "Benötigt Schmiedekunst (35)",
        "Benutzen: Lehrt Euch, wie man einen Kupferkettengürtel herstellt." }, LINE.ItemName)
    test.check("deDE: a recipe in the other wording", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "Schmiedekunst", true })

    model, ns = read(SPELL, {
        { "Feuerball", "Rang 1" },
        { "30 Mana", "35 m Reichweite" },
        { "Wirken in 1,5 Sek.", "8 Sek. Abklingzeit" },
        "Schleudert eine glühende Kugel, die 16 bis 25 Punkt(e) Feuerschaden verursacht.",
    }, LINE.SpellName)
    test.check("deDE: a spell's strip", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Mana" }, { "1,5 Sek.", "Wirken" }, { "8 Sek.", "Abklingzeit" }, { "35 m", "Reichweite" } })
    test.check("deDE: its school from the description", ns.Palette.detectSchool(model.description, "Feuerball"),
        "Fire")
    test.check("deDE: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Beulengras", "Kräuterkunde" })
    test.check("deDE: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })

    model = read(UNIT, { "Azuregos", "Stufe ?? (Boss)" })
    test.check("deDE: a boss", model.classification, "worldboss")
end
