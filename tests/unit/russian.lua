-- Russian game strings and client-table wording. fixtures/*-ru.lua also cover
-- captured items, a spell, and an NPC. Rare-unit and base-mana formats await captures.
return function(test)
    local ITEM, SPELL, UNIT, QUEST, OBJECT = 0, 1, 2, 23, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/ruRU.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua", "Tooltips/Quest.lua" }

    local function read(kind, lines, nameType)
        local capture = { client = { locale = "ruRU" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "Боевая перчатка Веригана", "Становится персональным при надевании",
        { "Урон: 153-256", "Скорость 3,80" }, "(53,8 ед. урона в секунду)", "+13 к выносливости",
        "Прочность: 61 / 120", "Классы: Паладин", "Требуется 58-й уровень",
    }, LINE.ItemName)
    test.check("ruRU: supported", ns.Locale.supported, true)
    test.check("ruRU: native number separators", { DECIMAL_SEPERATOR, LARGE_NUMBER_SEPERATOR }, { ",", "" })
    test.check("ruRU: weapon, stat, and requirement wording", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left)),
        durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "Становится персональным при надевании", weapon = { "Урон: 153-256", "Скорость 3,80" },
        dps = "53,8", primary = "+13 к выносливости", durability = { 61, 120 },
        level = "Требуется 58-й уровень", extras = 0,
    })
    local stat = ns.Stats.read("+13 к выносливости")
    test.check("ruRU: stat labels keep the client's grammar", { stat.key, ns.Stats.text(stat) },
        { "STAMINA", "+13 к выносливости" })
    test.check("ruRU: a declined school in the game's weapon damage format",
        ns.util.pack(ns.util.unformat("12 - 20 ед. огня", DAMAGE_TEMPLATE_WITH_SCHOOL)),
        { n = 3, "12", "20", "огня" })
    test.check("ruRU: a declined faction in the game's reputation requirement",
        ns.util.pack(ns.util.unformat("Требуется: Уважение со стороны Серебряного Рассвета", ITEM_REQ_REPUTATION)),
        { n = 2, "Серебряного Рассвета", "Уважение" })
    local slots = {}
    for _, count in ipairs({ 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 111 }) do
        slots[#slots + 1] = ns.util.fill(CONTAINER_SLOTS, count, "Сумка")
    end
    test.check("ruRU: the game's three plural forms", slots, {
        "Сумка (1 ячейка)", "Сумка (2 ячейки)", "Сумка (4 ячейки)", "Сумка (5 ячеек)",
        "Сумка (11 ячеек)", "Сумка (12 ячеек)", "Сумка (14 ячеек)", "Сумка (21 ячейка)",
        "Сумка (22 ячейки)", "Сумка (25 ячеек)", "Сумка (111 ячеек)",
    })
    test.check("ruRU: addon bag counts use the same plural forms", ns.util.fill(ns.L["%s Slots"], 22), "22 ячейки")
    test.check("ruRU: combined healing and damage equip effect", ns.Stats.rewrite(
        "Если на персонаже: усиливает творимое исцеление максимум на 20 ед., а урон от магических эффектов и заклинаний – максимум на 10 ед."),
        { "+20 к силе исцеления", "+10 к урону от заклинаний" })
    model.icon, model.level, model.equippable = 133042, 31, true
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, ITEM)
    test.check("ruRU: the badge uses a compact item-level abbreviation", panel.badgeText:GetText(), "УП 31")
    test.check("ruRU: the badge keeps the default icon size", panel.icon:GetWidth(), 43)
    test.check("ruRU: raw plural controls in set bonuses are read",
        ns.util.pack(ns.util.unformat("Комплект (2 |4предмет:предмета:предметов;): +22 к силе.", ITEM_SET_BONUS_GRAY)),
        { n = 2, "2", "+22 к силе." })

    model = read(ITEM, { "Чертеж: медный плетеный нагрудник", "Требуется: Кузнечное дело (35)",
        "Использование: Обучает изготовлению медного плетеного нагрудника." }, LINE.ItemName)
    test.check("ruRU: a smithing recipe", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "Кузнечное дело", true })
    model = read(ITEM, { "Выкройка: красное льняное одеяние", "Требуется: Портняжное дело (15)",
        "Использование: Обучает изготовлению красного льняного одеяния." }, LINE.ItemName)
    test.check("ruRU: a tailoring recipe", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "Портняжное дело", true })
    model = read(ITEM, { "Зелье", "Использование: Восполняет 100 ед. здоровья." }, LINE.ItemName)
    test.check("ruRU: a use effect loses only its prefix", { model.effects[1].left, model.effects[1].use },
        { "Восполняет 100 ед. здоровья.", true })
    model = read(ITEM, { "Боевая перчатка Веригана",
        "Возможный эффект при попадании: Окутывает цель пламенем Великой Кузни, нанося 39 ед. урона от священного огня." }, LINE.ItemName)
    test.check("ruRU: the proc prefix is recognized", { model.equipEffects[1].left, model.equipEffects[1].onHit },
        { "Окутывает цель пламенем Великой Кузни, нанося 39 ед. урона от священного огня.", true })

    model, ns = read(SPELL, {
        { "Огненный шар", "Уровень 1" }, { "Мана: 30", "Радиус действия: 35 м." },
        { "Применение: 1,5 сек.", "Восстановление: 8 сек." },
        "Бросок огненного шара, который наносит от 16 до 25 ед. урона от огня.",
    }, LINE.SpellName)
    test.check("ruRU: spell strip reads decimal commas and native formats", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "Мана" }, { "1,5 сек", "Применение" }, { "8 сек", "Восстановление" }, { "35 м", "Дальность" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "Неизвестное заклинание") end
    test.check("ruRU: schools in client descriptions", {
        school("Наносит 30 ед. урона от тайной магии."), school("Наносит 30 ед. урона от огня."),
        school("Наносит 30 ед. урона от магии льда."), school("Наносит 30 ед. урона светлой магии."),
        school("Наносит 30 ед. урона от сил природы."), school("Наносит 30 ед. урона от темной магии."),
        school("Наносит 30 ед. урона от священного огня."), school("Наносит 30 ед. урона от ледяного огня."),
    }, { "Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow", "Holyfire", "Frostfire" })
    test.check("ruRU: alternate school wordings", {
        school("Наносит 30 ед. урона от природной магии."), school("Наносит 30 ед. урона от льда."),
        school("Наносит 30 ед. урона от тьмы."),
    }, { "Nature", "Frost", "Shadow" })
    test.check("ruRU: Cyrillic school matching ignores case", school("Наносит 30 ед. УРОНА ОТ ОГНЯ."), "Fire")
    test.check("ruRU: an elementals clause does not name a damage school",
        school("Наносит в 3 раза больше урона элементалям огня и земли."), nil)
    test.check("ruRU: partial Cyrillic words do not match", school("Наносит урона от огняного существа."), nil)
    test.check("ruRU: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "Магороза", "Травничество" })
    test.check("ruRU: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 50, 2 })
    model = read(OBJECT, { "Медная жила", "Горное дело" })
    test.check("ruRU: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model = read(UNIT, { "Азурегос", "Уровень ?? (босс)" })
    test.check("ruRU: a boss", model.classification, "worldboss")
    model = read(QUEST, { "Проверка", "Подземелье", "Цели задания", "Соберите 2 предмета: 0/2" })
    test.check("ruRU: a dungeon quest tag", model.tags, { "Подземелье" })

    local function enchants(text)
        local rows = ns.ui.enchantRows(text)
        for index, row in ipairs(rows) do rows[index] = ns.util.plainText(row) end
        return rows
    end
    test.check("ruRU: signed bonuses joined by a conjunction", enchants("+16 к выносливости и +100 к броне"),
        { "+16 к выносливости", "+100 к броне" })
    test.check("ruRU: slash-separated bonuses", enchants("+1 к ловкости / +1 к духу"),
        { "+1 к ловкости", "+1 к духу" })
    test.check("ruRU: a conjunction inside one bonus stays", enchants("+8 к урону от заклинаний и исцелению"),
        { "+8 к урону от заклинаний и исцелению" })
    test.check("ruRU: semicolon between compound and simple bonuses",
        enchants("+13 к урону от заклинаний и исцелению; +15 к интеллекту"),
        { "+13 к урону от заклинаний и исцелению", "+15 к интеллекту" })
    test.check("ruRU: commas separate bonuses without consuming their signs",
        enchants("+1 к силе, +2 к ловкости, и +3 к выносливости"),
        { "+1 к силе", "+2 к ловкости", "+3 к выносливости" })
    test.check("ruRU: a named enchant stays whole", enchants("Рыцарь"), { "Рыцарь" })

    test.check("ruRU: Cyrillic capitals include yo", ns.util.upper("Огненный шар, лёд и Ёж"), "ОГНЕННЫЙ ШАР, ЛЁД И ЁЖ")
    test.check("ruRU: Cyrillic lower case includes yo", ns.util.lower("ОГНЕННЫЙ ШАР, ЛЁД И ЁЖ"), "огненный шар, лёд и ёж")
    test.check("ruRU: a decimal comma is colored with its number",
        ns.util.colorNumbers("1,5 сек., 3 цели.", "FF0000"),
        "|cffFF00001,5|r сек., |cffFF00003|r цели.")
    test.check("ruRU: number colors leave declension controls intact",
        ns.util.colorNumbers("+3 ед. |3-1(огонь)", "FF0000"), "+|cffFF00003|r ед. |3-1(огонь)")
    test.check("ruRU: abbreviations before lower-case words stay in the sentence",
        ns.util.splitSentences("Наносит 30 ед. урона от огня за 5 сек. Следующий удар."),
        { "Наносит 30 ед. урона от огня за 5 сек.", "Следующий удар." })
    test.check("ruRU: Cyrillic fonts without LibSharedMedia", {
        ns.fontPath("Friz Quadrata"), ns.fontPath("Arial Narrow"), ns.fontPath("Morpheus"), ns.fontPath("Skurri"),
    }, { "Fonts\\FRIZQT___CYR.TTF", "Fonts\\ARIALN.TTF", "Fonts\\MORPHEUS_CYR.TTF", "Fonts\\SKURRI_CYR.TTF" })
    local spell = ns.ui.spellModel({ name = "Огненный шар", rank = "Уровень 1", cast = { "Мгновенное", "Применение" },
        description = { "Наносит 16 ед. урона от огня." }, spellPower = 10 })
    panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, SPELL)
    local coefficients = false
    for _, font in ipairs(panel.pool) do
        if font:IsShown() and ns.util.plainText(font:GetText() or ""):find("Коэффициент", 1, true) then coefficients = true end
    end
    test.check("ruRU: rendered spells show localized coefficient rows", coefficients, true)
end
