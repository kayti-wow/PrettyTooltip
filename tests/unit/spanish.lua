-- A Spanish client loads Locale\esES.lua and reads its own tooltips: an item,
-- a spell, a herb node, and a boss, each worded as the Spanish client words it.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/esES.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    -- A model from lines, the first the name: each a left text, or { left, right }.
    local function read(kind, lines, nameType)
        local capture = { client = { locale = "esES" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "Segadora de arcanita",
        "Se liga al equiparlo",
        { "153 - 256 Daño", "Velocidad 3,80" },
        "(53,8 daño por segundo)",
        "+13 p. de aguante",
        "Durabilidad 61 / 120",
        "Clases: Guerrero",
        "Necesitas ser de nivel 58",
    }, LINE.ItemName)
    test.check("esES: supported", ns.Locale.supported, true)
    local primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left))
    local stamina = ns.Stats.read("+13 p. de aguante")
    test.check("esES: a stat as the game words it", { stamina and stamina.key, stamina and ns.Stats.text(stamina) },
        { "STAMINA", "+13 aguante" })
    test.check("esES: an item", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = primary, durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Se liga al equiparlo", weapon = { "153 - 256 Daño", "Velocidad 3,80" }, dps = "53,8",
        primary = "+13 aguante", durability = { 61, 120 }, level = "Necesitas ser de nivel 58", extras = 0,
    })

    model = read(ITEM, { "Diseño: Cinturón de anillas de cobre", "Requiere Herrería (35)",
        "Usar: Te enseña a fabricar un Cinturón de anillas de cobre." }, LINE.ItemName)
    test.check("esES: a recipe", { model.skill and model.skill.name, model.effects[1] ~= nil }, { "Herrería", true })
    model = read(ITEM, { "Patrón: Camisa de lino marrón", "Requiere Costura (10)",
        "Usar: Enseña a confeccionar una Camisa de lino marrón." }, LINE.ItemName)
    test.check("esES: a recipe in the other wording, by Tailoring's other name",
        { model.skill and model.skill.name, model.effects[1] ~= nil }, { "Costura", true })

    model, ns = read(SPELL, {
        { "Bola de Fuego", "Rango 1" },
        { "30 Maná", "Alcance de 35 m" },
        { "1,5 s para lanzar", "Reutilización: 8 s" },
        "Lanza una bola ígnea que inflige de 16 a 25 p. de daño de Fuego.",
    }, LINE.SpellName)
    test.check("esES: a spell's strip", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Maná" }, { "1,5 s", "Lanzamiento" }, { "8 s", "Reutilización" }, { "35 m", "Alcance" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "Hechizo desconocido") end
    test.check("esES: schools as descriptions word them", {
        school("Lanza una bola ígnea que inflige de 16 a 25 p. de daño de Fuego."),
        school("Inflige 30 p. de daño de las Sombras."),
        school("Aumenta un 5% la probabilidad de efecto crítico de tus hechizos Sagrados."),
        school("Acomete al enemigo causándole 30 p. de daño Sagrado."),
        school("Inflige 39 p. de daño de Fuego Sagrado."),
        school("Inflige 30 p. de daño de Pirofrío."),
    }, { "Fire", "Shadow", "Holy", "Holy", "Holyfire", "Frostfire" })
    test.check("esES: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Hierba cardenal", "Botánica" })
    test.check("esES: a herb, by the name herb nodes give Herbalism",
        { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) }, { "Herbalism", 100, 1 })

    model = read(UNIT, { "Azuregos", "Nivel ?? (Jefe)" })
    test.check("esES: a boss", model.classification, "worldboss")
end
