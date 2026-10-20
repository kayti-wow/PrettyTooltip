-- A Portuguese client loads Locale\Portuguese.lua and reads its own tooltips: an item,
-- a spell, a herb node, and a boss, each worded as the Portuguese client words it.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/Portuguese.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    -- A model from lines, the first the name: each a left text, or { left, right }.
    local function read(kind, lines, nameType, client)
        local capture = { client = { locale = client or "ptBR" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "Ceifadora de Arcanita",
        "Vincula-se quando equipado",
        { "153 - 256 de dano", "Velocidade 3,80" },
        "(53,8 de dano por segundo)",
        "+13 Vigor",
        "Durabilidade 61 / 120",
        "Classes: Guerreiro",
        "Requer o Nível 58",
    }, LINE.ItemName)
    test.check("ptBR: supported", ns.Locale.supported, true)
    local primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left))
    test.check("ptBR: an item", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = primary, durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Vincula-se quando equipado", weapon = { "153 - 256 de dano", "Velocidade 3,80" }, dps = "53,8",
        primary = "+13 Vigor", durability = { 61, 120 }, level = "Requer o Nível 58", extras = 0,
    })
    local stamina = ns.Stats.read("+13 Vigor")
    test.check("ptBR: a stat", stamina and stamina.key, "STAMINA")

    model = read(ITEM, { "Diagrama: Cinto Encadeado de Cobre", "Requer Ferraria (35)",
        "Usar: Ensina a fazer Cinto Encadeado de Cobre." }, LINE.ItemName)
    test.check("ptBR: a recipe", { model.skill and model.skill.name, model.effects[1] ~= nil }, { "Ferraria", true })

    model, ns = read(SPELL, {
        { "Bola de Fogo", "Grau 1" },
        { "30 de Mana", "Alcance de 35 m" },
        { "Lançamento de 1,5 s", "Recarga de 8 s" },
        "Arremessa uma bola flamejante que causa de 16 a 25 de dano de Fogo.",
    }, LINE.SpellName)
    test.check("ptBR: a spell's strip", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Mana" }, { "1,5 s", "Lançamento" }, { "8 s", "Recarga" }, { "35 m", "Alcance" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "Feitiço desconhecido") end
    test.check("ptBR: schools as descriptions word them", {
        school("Arremessa uma bola flamejante que causa de 16 a 25 de dano de Fogo."),
        school("Lança uma seta de sombra contra o inimigo, causando 30 de dano de Sombra."),
        school("Aumenta em 5% a chance de efeito crítico dos seus feitiços Sagrados."),
        school("Castiga um inimigo, causando 30 de dano Sagrado."),
        school("Incendeia o alvo nas chamas da Grande Forja, causando 39 de dano de Fogo Sagrado."),
        school("Lança uma seta de fogofrio contra o inimigo, causando 30 de dano de Fogofrio."),
        school("Reduz em 10% a ameaça gerada pelos seus feitiços Arcanos."),
    }, { "Fire", "Shadow", "Holy", "Holy", "Holyfire", "Frostfire", "Arcane" })
    test.check("ptBR: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Ervamossa", "Herborismo" })
    test.check("ptBR: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })
    model = read(OBJECT, { "Veio de Cobre", "Mineração" })
    test.check("ptBR: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model, ns = read(OBJECT, { "Veio de Cobre", "Mineração" }, nil, "ptPT")
    test.check("ptPT: the same file and names",
        { ns.Locale.supported, model.skill, model.skillRow and model.skillRow.level }, { true, "Mining", 1 })

    model = read(UNIT, { "Azuregos", "Nível ?? (Chefe)" })
    test.check("ptBR: a boss", model.classification, "worldboss")
end
