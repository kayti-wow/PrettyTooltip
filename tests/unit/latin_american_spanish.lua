-- Latin American Spanish uses its own game strings, decimal points, and
-- Uso/Calabozo wording. These cases come from the client's tables;
-- fixtures/*-mx.lua also cover captured items, a spell, and an NPC.
return function(test)
    local ITEM, SPELL, UNIT, QUEST, OBJECT = 0, 1, 2, 23, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/esMX.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/NodeSkills.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua", "Tooltips/Quest.lua" }

    local function read(kind, lines, nameType)
        local capture = { client = { locale = "esMX" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
            enums = { TooltipDataType = { Item = ITEM, Spell = SPELL, Unit = UNIT, Quest = QUEST, Object = OBJECT },
                TooltipDataLineType = LINE }, data = { type = kind, id = 2000, lines = {} }, lines = {} }
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
        "Puño de Verigan", "Se liga al equiparlo", { "153 - 256 p. de daño", "Velocidad 3.80" },
        "(53.8 p. de daño por segundo)", "+13 p. de aguante", "Durabilidad 61 / 120",
        "Clases: Paladín", "Necesitas ser de nivel 58",
    }, LINE.ItemName)
    test.check("esMX: supported", ns.Locale.supported, true)
    test.check("esMX: native number separators", { DECIMAL_SEPERATOR, LARGE_NUMBER_SEPERATOR }, { ".", "," })
    test.check("esMX: an item with its own damage wording", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left)),
        durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Se liga al equiparlo", weapon = { "153 - 256 p. de daño", "Velocidad 3.80" }, dps = "53.8",
        primary = "+13 Aguante", durability = { 61, 120 }, level = "Necesitas ser de nivel 58", extras = 0,
    })
    local stat = ns.Stats.read("+13 p. de aguante")
    test.check("esMX: a stat uses the client's capitalized label", { stat.key, ns.Stats.text(stat) },
        { "STAMINA", "+13 Aguante" })
    test.check("esMX: grouped stat numbers", ns.Stats.read("+1,200 p. de aguante").amount, "1200")
    test.check("esMX: combined equip effects use its own wording", ns.Stats.rewrite(
        "Equipar: Aumenta hasta 20 p. la sanación realizada y hasta 10 p. el daño que infligen todos los efectos y hechizos mágicos."),
        { "+20 Poder de sanación", "+10 Daño con hechizos" })
    model.icon, model.level, model.equippable = 133042, 31, true
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, ITEM)
    test.check("esMX: the item badge uses the client's abbreviation", panel.badgeText:GetText(), "Niv 31")
    test.check("esMX: regional UI terms", { ns.L["Cost"], ns.L["Dungeon"], ns.L["Use and other effects"] },
        { "Costo", "Calabozo", "Uso y otros efectos" })

    model = read(ITEM, { "Diseño: jubón de anillas de cobre", "Requiere Herrería (35)",
        "Uso: Te enseña a hacer un jubón de anillas de cobre." }, LINE.ItemName)
    test.check("esMX: a smithing recipe uses Uso", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "Herrería", true })
    model = read(ITEM, { "Patrón: toga de lino rojo", "Requiere Sastrería (15)",
        "Uso: Te enseña a confeccionar una toga de lino rojo." }, LINE.ItemName)
    test.check("esMX: a tailoring recipe", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "Sastrería", true })
    model = read(ITEM, { "Poción", "Uso: Restaura 100 p. de salud." }, LINE.ItemName)
    test.check("esMX: an ordinary use effect loses only its prefix", { model.effects[1].left, model.effects[1].use },
        { "Restaura 100 p. de salud.", true })
    model = read(ITEM, { "Puño de Verigan",
        "Probabilidad al acertar: Prende fuego al objetivo, lo que inflige 39 p. de daño de Fuego Sagrado." }, LINE.ItemName)
    test.check("esMX: its proc prefix is recognized", { model.equipEffects[1].left, model.equipEffects[1].onHit },
        { "Prende fuego al objetivo, lo que inflige 39 p. de daño de Fuego Sagrado.", true })

    model, ns = read(SPELL, {
        { "Bola de Fuego", "Rango 1" }, { "30 p. de maná", "Alcance de 35 m" },
        { "Lanzamiento de 1.5 s", "Tiempo de reutilización de 8 s" },
        "Lanza una bola ígnea que inflige de 16 a 25 p. de daño de Fuego.",
    }, LINE.SpellName)
    test.check("esMX: cost, cast, and cooldown use its game strings", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Maná" }, { "1.5 s", "Lanzamiento" }, { "8 s", "Reutilización" }, { "35 m", "Alcance" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "Hechizo desconocido") end
    test.check("esMX: schools in client descriptions", {
        school("Lanza una bola ígnea que inflige 30 p. de daño de Fuego."),
        school("Inflige 30 p. de daño de las Sombras."), school("Inflige 30 p. de daño de Naturaleza."),
        school("Inflige 30 p. de daño de Escarcha."), school("Mejora tus hechizos Sagrados."),
        school("Prende fuego al objetivo, lo que inflige 39 p. de daño de Fuego Sagrado."),
        school("Lanza una descarga que inflige 30 p. de daño de Pirofrío."), school("Mejora tus hechizos Arcanos."),
    }, { "Fire", "Shadow", "Nature", "Frost", "Holy", "Holyfire", "Frostfire", "Arcane" })
    test.check("esMX: a creature type does not name a damage school", school("Inflige 3 veces el daño a elementales de fuego."), nil)
    test.check("esMX: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Hierba cardenal", "Herboristería" })
    test.check("esMX: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })
    model = read(OBJECT, { "Filón de cobre", "Minería" })
    test.check("esMX: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model = read(UNIT, { "Azuregos", "Nivel ?? (Jefe)" })
    test.check("esMX: a boss", model.classification, "worldboss")
    model = read(QUEST, { "Una prueba", "Calabozo", "Objetivos", "Reúne 2 objetos: 0/2" })
    test.check("esMX: a quest's Calabozo tag", model.tags, { "Calabozo" })

    local function enchants(text)
        local rows = ns.ui.enchantRows(text)
        for index, row in ipairs(rows) do rows[index] = ns.util.plainText(row) end
        return rows
    end
    test.check("esMX: bonuses joined by y", enchants("Aguante +16 y armadura +100"),
        { "+16 Aguante", "+100 armadura" })
    test.check("esMX: bonuses joined by e", enchants("Aguante +16 e intelecto +5"),
        { "+16 Aguante", "+5 intelecto" })
    test.check("esMX: slash-separated bonuses with uneven spaces", enchants("Defensa +7/Aguante +10 /Valor de bloqueo +15"),
        { "+7 Defensa", "+10 Aguante", "+15 Valor de bloqueo" })
    test.check("esMX: a named enchant stays whole", enchants("Cruzado"), { "Cruzado" })

    local spell = ns.ui.spellModel({ name = "Bola de Fuego", rank = "Rango 1", cast = { "Instantáneo", "Lanzamiento" },
        description = { "Inflige 16 p. de daño de Fuego." }, spellPower = 10 })
    panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, SPELL)
    local coefficients = false
    for _, font in ipairs(panel.pool) do
        if font:IsShown() and ns.util.plainText(font:GetText() or ""):find("Coeficiente", 1, true) then coefficients = true end
    end
    test.check("esMX: rendered spells show localized coefficient rows", coefficients, true)
end
