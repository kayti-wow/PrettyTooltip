-- Korean game strings and client-table wording, not translated English fixtures.
-- fixtures/*-kr.lua also cover captured items, a spell, and an NPC.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/koKR.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    local function read(kind, lines, nameType)
        local capture = { client = { locale = "koKR" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
            enums = { TooltipDataType = { Item = ITEM, Spell = SPELL, Unit = UNIT, Object = OBJECT },
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
        "베리간의 망치", "착용 시 귀속", { "공격력 153 - 256", "속도 3.80" },
        "(초당 공격력 53.8)", "체력 +13", "내구도 61 / 120", "직업: 성기사", "최소 요구 레벨 58",
    }, LINE.ItemName)
    test.check("koKR: supported", ns.Locale.supported, true)
    test.check("koKR: an item", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left)),
        durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "착용 시 귀속", weapon = { "공격력 153 - 256", "속도 3.80" }, dps = "53.8",
        primary = "체력 +13", durability = { 61, 120 }, level = "최소 요구 레벨 58", extras = 0,
    })
    local stat = ns.Stats.read("체력 +13")
    test.check("koKR: stats keep the name before the amount", { stat.key, ns.Stats.text(stat) },
        { "STAMINA", "체력 +13" })
    test.check("koKR: combined equip bonuses use Korean labels", ns.Stats.rewrite(
        "착용 효과: 모든 마법 주문 및 효과에 의한 치유량이 최대 20만큼, 주문 공격력이 최대 10만큼 증가합니다."),
        { "치유량 증가 +20", "주문 공격력 +10" })

    model = read(ITEM, { "도면: 구리 사슬 조끼", "요구 사항: 대장기술 (35)",
        "사용 효과: 구리 사슬 조끼 만드는 법을 배웁니다." }, LINE.ItemName)
    test.check("koKR: a recipe", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "대장기술", true })

    model, ns = read(SPELL, {
        { "화염구", "1 레벨" }, { "마나 30", "유효 거리 35미터" },
        { "시전 시간 1.5초", "8초 후 재사용 가능" },
        "적에게 불타는 구체를 날려 16에서 25의 화염 피해를 입힙니다.",
    }, LINE.SpellName)
    test.check("koKR: a spell's strip", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "마나" }, { "1.5초", "시전" }, { "8초", "재사용 대기시간" }, { "35미터", "사거리" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "알 수 없는 주문") end
    test.check("koKR: particles after damage and spell names", {
        school("적에게 불타는 구체를 날려 16의 화염 피해를 입힙니다."),
        school("적에게 어둠의 화살을 발사하여 30의 암흑 피해를 입힙니다."),
        school("30의 자연 피해를 입힙니다."), school("냉기 주문이 극대화 효과를 발휘합니다."),
        school("30의 신성 피해를 입힙니다."), school("39의 신성화염 피해를 입힙니다."),
        school("30의 냉기화염 피해를 입힙니다."), school("비전 주문의 위력이 증가합니다."),
    }, { "Fire", "Shadow", "Nature", "Frost", "Holy", "Holyfire", "Frostfire", "Arcane" })
    test.check("koKR: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "생채기풀", "약초채집" })
    test.check("koKR: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })
    model = read(OBJECT, { "구리 광맥", "채광" })
    test.check("koKR: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model = read(UNIT, { "아주어고스", "레벨 ?? (우두머리)" })
    test.check("koKR: a boss", model.classification, "worldboss")
    model = read(UNIT, { "희귀 몬스터", "레벨 30 (희귀 정예)" })
    test.check("koKR: a rare elite", model.classification, "rareelite")

    -- Named enchants containing 및 stay whole; slashes split distinct bonuses.
    local rows = ns.ui.enchantRows("치유 및 주문 공격력 +13 / 지능 +15")
    for index, row in ipairs(rows) do rows[index] = ns.util.plainText(row) end
    test.check("koKR: enchant names and bonus separators", rows, { "치유 및 주문 공격력 +13", "지능 +15" })

    -- A previously saved Latin font must not survive switching the client to
    -- Korean, and EllesmereUI must not replace Hangul titles with Expressway.
    test.check("koKR: native font choices without LibSharedMedia", ns.fontNames(),
        { "기본 글꼴", "굵은 글꼴", "퀘스트 글꼴" })
    test.check("koKR: a Latin font is not resolved", ns.fontPath("Arial Narrow"), nil)
    test.check("koKR: the native bold font resolves", ns.fontPath("굵은 글꼴"), "Fonts\\2002B.TTF")
    C_AddOns.GetAddOnInfo = function(addon) if addon == "EllesmereUI" then return addon end end
    STANDARD_TEXT_FONT = "Fonts\\2002.TTF"
    GameTooltipText:SetFont(STANDARD_TEXT_FONT, 12)
    GameTooltipHeaderText:SetFont("Fonts\\2002B.TTF", 14)
    ns.setOption("titleFont", "Arial Narrow")
    ns.setOption("bodyFont", "Friz Quadrata")
    local spell = ns.ui.spellModel({ name = "화염구", rank = "1 레벨", cast = { "즉시 시전", "시전" },
        description = { "16의 화염 피해를 입힙니다." } })
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, SPELL)
    local fonts, coefficients = {}, false
    for _, font in ipairs(panel.pool) do
        local text = ns.util.plainText(font:GetText() or "")
        if font:IsShown() and text == "화염구" then fonts.title = font:GetFont() end
        if font:IsShown() and text == "16의 화염 피해를 입힙니다." then fonts.body = font:GetFont() end
        if font:IsShown() and text:find("계수", 1, true) then coefficients = true end
    end
    test.check("koKR: rendered Hangul uses native fonts with EllesmereUI installed", fonts,
        { title = "Fonts\\2002B.TTF", body = "Fonts\\2002.TTF" })
    test.check("koKR: rendered spells show localized coefficient rows", coefficients, true)
end
