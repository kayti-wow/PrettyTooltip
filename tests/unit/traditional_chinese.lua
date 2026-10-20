-- Traditional Chinese client strings and table wording, including stat and
-- enchant text with no spaces. fixtures/*-tw.lua also cover real tooltips.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/zhTW.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    local function read(kind, lines, nameType)
        local capture = { client = { locale = "zhTW" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "維里甘之拳", "裝備後綁定", { "153 - 256傷害", "速度 3.80" },
        "（每秒傷害53.8）", "+13耐力", "耐久度 61 / 120", "職業：聖騎士", "需要等級 58",
    }, LINE.ItemName)
    test.check("zhTW: supported", ns.Locale.supported, true)
    test.check("zhTW: an item with full-width punctuation and no-space stats", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left)),
        durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "裝備後綁定", weapon = { "153 - 256傷害", "速度 3.80" }, dps = "53.8",
        primary = "+13耐力", durability = { 61, 120 }, level = "需要等級 58", extras = 0,
    })
    local stat = ns.Stats.read("+13耐力")
    test.check("zhTW: stats print without a space", { stat.key, ns.Stats.text(stat) }, { "STAMINA", "+13耐力" })
    test.check("zhTW: a percent stays with the amount before an unspaced label",
        { ns.Stats.lineParts("+1%法術致命一擊機率") }, { "+", "1%", "法術致命一擊機率" })
    test.check("zhTW: combined equip bonuses use Traditional labels", ns.Stats.rewrite(
        "裝備：使法術和魔法效果所造成的治療效果提高最多20點，法術傷害提高最多10點。"),
        { "+20治療能量", "+10法術傷害" })
    model.icon, model.level, model.equippable = 133042, 31, true
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, ITEM)
    test.check("zhTW: the rendered item badge is localized", panel.badgeText:GetText(), "裝等 31")

    model = read(ITEM, { "設計圖：銅質鍊甲外衣", "需要鍛造（35）", "使用：教你學會如何製作銅質鍊甲外衣。" }, LINE.ItemName)
    test.check("zhTW: a smithing recipe", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "鍛造", true })
    model = read(ITEM, { "圖樣：紅色亞麻長袍", "需要裁縫（15）", "使用：教你學會如何縫製紅色亞麻長袍。" }, LINE.ItemName)
    test.check("zhTW: a tailoring recipe with its own verb", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "裁縫", true })

    model, ns = read(SPELL, {
        { "火球術", "等級 1" }, { "30法力", "35碼距離" },
        { "施法時間1.5秒", "冷卻時間8秒" }, "發射一枚火球攻擊目標，對其造成16點到25點火焰傷害。",
    }, LINE.SpellName)
    test.check("zhTW: cast and cooldown labels precede their numbers", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "法力" }, { "1.5秒", "施法" }, { "8秒", "冷卻時間" }, { "35碼", "射程" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "未知法術") end
    test.check("zhTW: native school phrases within unspaced text", {
        school("發射一枚火球，對其造成16點火焰傷害。"), school("對其造成30點暗影傷害。"),
        school("對其造成30點自然傷害。"), school("對其造成30點冰霜傷害並使其移動速度降低。"),
        school("使你的神聖法術傷害提高。"),
        school("以大鍛爐的火焰點燃目標，造成39點神聖之火傷害。"),
        school("造成30點霜火傷害並使其移動速度降低。"), school("使你的秘法法術傷害提高。"),
    }, { "Fire", "Shadow", "Nature", "Frost", "Holy", "Holyfire", "Frostfire", "Arcane" })
    test.check("zhTW: an unspaced school at the start of a name", ns.Palette.detectSchool({}, "秘法衝擊"), "Arcane")
    test.check("zhTW: the longer compound school takes precedence", ns.Palette.detectSchool({}, "神聖之火衝擊"), "Holyfire")
    test.check("zhTW: elemental creatures do not name a damage school", school("對火元素與土元素造成3倍傷害。"), nil)
    test.check("zhTW: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "跌打草", "草藥學" })
    test.check("zhTW: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })
    model = read(OBJECT, { "銅礦脈", "採礦" })
    test.check("zhTW: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model = read(UNIT, { "艾索雷葛斯", "等級 ??（首領）" })
    test.check("zhTW: a boss", model.classification, "worldboss")
    model = read(UNIT, { "稀有怪物", "等級 30（稀有精英生物）" })
    test.check("zhTW: a rare elite", model.classification, "rareelite")
    test.check("zhTW: dispel names from the client", { ns.Locale.dispels.Curse, ns.Locale.dispels.Poison },
        { "詛咒", "中毒" })

    local function enchants(text)
        local rows = ns.ui.enchantRows(text)
        for index, row in ipairs(rows) do rows[index] = ns.util.plainText(row) end
        return rows
    end
    test.check("zhTW: enchant amounts joined to labels and 點", enchants("耐力+16點，護甲+100點"),
        { "+16耐力", "+100護甲" })
    test.check("zhTW: slash-separated bonuses without spaces", enchants("防禦+7/耐力+10/格擋值+15"),
        { "+7防禦", "+10耐力", "+15格擋值" })
    test.check("zhTW: joined percent bonus", enchants("加速+1%"), { "+1%加速" })
    test.check("zhTW: conjunctions belong inside stat names", enchants("治療和法術傷害 +13"), { "+13治療和法術傷害" })
    test.check("zhTW: a named enchant stays whole", enchants("十字軍"), { "十字軍" })
    test.check("zhTW: an unrecognized amount preserves the complete enchant", enchants("耐力+很多點，護甲+100點"),
        { "耐力+很多點，護甲+100點" })
    test.check("zhTW: sentences split without spaces", ns.util.splitSentences("造成16點傷害。持續4秒。"),
        { "造成16點傷害。", "持續4秒。" })

    test.check("zhTW: native fonts without LibSharedMedia", ns.fontNames(), { "預設", "提示訊息", "聊天", "傷害數字" })
    test.check("zhTW: a Latin font is not resolved", ns.fontPath("Arial Narrow"), nil)
    test.check("zhTW: native chat font resolves", ns.fontPath("聊天"), "Fonts\\bHEI01B.ttf")
    C_AddOns.GetAddOnInfo = function(addon) if addon == "EllesmereUI" then return addon end end
    STANDARD_TEXT_FONT = "Fonts\\bLEI00D.ttf"
    GameTooltipText:SetFont(STANDARD_TEXT_FONT, 12)
    GameTooltipHeaderText:SetFont("Fonts\\bHEI00M.ttf", 14)
    ns.setOption("titleFont", "Arial Narrow")
    ns.setOption("bodyFont", "Friz Quadrata")
    local spell = ns.ui.spellModel({ name = "火球術", rank = "等級 1", cast = { "立即", "施法" },
        description = { "造成16點火焰傷害。" } })
    panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, SPELL)
    local fonts, coefficients = {}, false
    for _, font in ipairs(panel.pool) do
        local text = ns.util.plainText(font:GetText() or "")
        if font:IsShown() and text == "火球術" then fonts.title = font:GetFont() end
        if font:IsShown() and text == "造成16點火焰傷害。" then fonts.body = font:GetFont() end
        if font:IsShown() and text:find("係數", 1, true) then coefficients = true end
    end
    test.check("zhTW: native fonts with EllesmereUI installed", fonts,
        { title = "Fonts\\bHEI00M.ttf", body = "Fonts\\bLEI00D.ttf" })
    test.check("zhTW: rendered spells show localized coefficient rows", coefficients, true)
end
