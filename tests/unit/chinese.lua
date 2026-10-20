-- Simplified Chinese game strings and client-table wording. fixtures/*-cn.lua
-- also cover captured items, a spell, and an NPC.
return function(test)
    local ITEM, SPELL, UNIT, OBJECT = 0, 1, 2, 33
    local LINE = { None = 0, ItemName = 1, SpellName = 13 }
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Locale/zhCN.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Schools.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Tooltips/Item.lua",
        "Tooltips/Spell.lua", "Tooltips/Object.lua", "Tooltips/Unit.lua" }

    local function read(kind, lines, nameType)
        local capture = { client = { locale = "zhCN" }, calls = { UnitLevel = { player = { n = 1, 30 } } },
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
        "维里甘之拳", "装备后绑定", { "153 - 256伤害", "速度 3.80" },
        "（每秒伤害53.8）", "+13 耐力", "耐久度 61 / 120", "职业：圣骑士", "需要等级 58",
    }, LINE.ItemName)
    test.check("zhCN: supported", ns.Locale.supported, true)
    test.check("zhCN: an item with full-width punctuation", {
        header = model.header[1] and model.header[1].left, weapon = { model.weaponDamage, model.weaponSpeed },
        dps = model.weaponDps, primary = model.primary[1] and ns.util.trim(ns.util.plainText(model.primary[1].left)),
        durability = model.footerLeft[1].durability,
        level = model.levelRequirement and model.levelRequirement.text, extras = #model.extras,
    }, {
        header = "装备后绑定", weapon = { "153 - 256伤害", "速度 3.80" }, dps = "53.8",
        primary = "+13 耐力", durability = { 61, 120 }, level = "需要等级 58", extras = 0,
    })
    local stat = ns.Stats.read("+13 耐力")
    test.check("zhCN: a stat", { stat.key, ns.Stats.text(stat) }, { "STAMINA", "+13 耐力" })
    test.check("zhCN: combined equip bonuses use Chinese labels", ns.Stats.rewrite(
        "装备：使所有法术和魔法效果造成的治疗效果提高最多20点，伤害提高最多10点。"),
        { "+20 治疗强度", "+10 法术伤害" })

    model = read(ITEM, { "设计图：铜质链甲外衣", "需要锻造（35）", "使用：教你学会制作铜质链甲背心。" }, LINE.ItemName)
    test.check("zhCN: a recipe without spaces", { model.skill and model.skill.name, model.effects[1] ~= nil },
        { "锻造", true })

    model, ns = read(SPELL, {
        { "火球术", "等级 1" }, { "30法力值", "35码距离" },
        { "1.5秒施法时间", "8秒冷却时间" }, "发射一枚火球攻击目标，对其造成16至25点火焰伤害。",
    }, LINE.SpellName)
    test.check("zhCN: a spell's strip without spaces", { model.cost, model.cast, model.cooldown, model.range },
        { { "30", "法力值" }, { "1.5秒", "施法" }, { "8秒", "冷却时间" }, { "35码", "射程" } })
    local function school(text) return ns.Palette.detectSchool({ text }, "未知法术") end
    test.check("zhCN: school phrases within unspaced text", {
        school("发射一枚火球攻击目标，对其造成16点火焰伤害。"),
        school("射出暗影箭，对其造成30点暗影伤害。"), school("使你的自然法术伤害提高。"),
        school("对其造成30点冰霜伤害并使其移动速度降低。"), school("使你的神圣法术伤害提高。"),
        school("以大锻炉之焰点燃目标，造成39点神圣火焰伤害。"),
        school("造成30点霜火伤害，使其移动速度降低。"), school("使你的奥术法术伤害提高。"),
    }, { "Fire", "Shadow", "Nature", "Frost", "Holy", "Holyfire", "Frostfire", "Arcane" })
    test.check("zhCN: a school attached to a spell name", ns.Palette.detectSchool({}, "暗影新星"), "Shadow")
    test.check("zhCN: a compound school takes precedence over its prefix",
        ns.Palette.detectSchool({}, "神圣火焰冲击"), "Holyfire")
    test.check("zhCN: a school is not inferred from elemental creature names", school("对火元素和土元素造成3倍伤害。"), nil)
    test.check("zhCN: localized spell power rows enabled", ns.Locale.features.coefficients, true)

    model = read(OBJECT, { "跌打草", "草药学" })
    test.check("zhCN: a herb", { model.skill, model.skillRow and model.skillRow.level, #(model.loot or {}) },
        { "Herbalism", 100, 1 })
    model = read(OBJECT, { "铜矿脉", "采矿" })
    test.check("zhCN: an ore vein", { model.skill, model.skillRow and model.skillRow.level }, { "Mining", 1 })
    model = read(UNIT, { "艾索雷葛斯", "等级 ??（首领）" })
    test.check("zhCN: a boss", model.classification, "worldboss")
    model = read(UNIT, { "稀有怪物", "等级 30（稀有精英）" })
    test.check("zhCN: a rare elite", model.classification, "rareelite")

    local function enchants(text)
        local rows = ns.ui.enchantRows(text)
        for index, row in ipairs(rows) do rows[index] = ns.util.plainText(row) end
        return rows
    end
    test.check("zhCN: full-width commas split enchant bonuses", enchants("耐力 +16，护甲 +100"),
        { "+16 耐力", "+100 护甲" })
    test.check("zhCN: slashes split enchant bonuses", enchants("+1 敏捷/+1 智力"), { "+1 敏捷", "+1 智力" })
    test.check("zhCN: conjunctions within a stat name stay intact", enchants("治疗和法术伤害 +13"),
        { "+13 治疗和法术伤害" })
    test.check("zhCN: sentences split without spaces", ns.util.splitSentences("造成16点伤害。持续4秒。"),
        { "造成16点伤害。", "持续4秒。" })

    -- Switching a saved Latin font to this client falls back to its Chinese
    -- faces, even with EllesmereUI installed.
    test.check("zhCN: native fonts without LibSharedMedia", ns.fontNames(), { "默认", "聊天", "伤害数字" })
    test.check("zhCN: a Latin font is not resolved", ns.fontPath("Arial Narrow"), nil)
    test.check("zhCN: the native chat font resolves", ns.fontPath("聊天"), "Fonts\\ARHei.ttf")
    C_AddOns.GetAddOnInfo = function(addon) if addon == "EllesmereUI" then return addon end end
    STANDARD_TEXT_FONT = "Fonts\\ARKai_T.ttf"
    GameTooltipText:SetFont(STANDARD_TEXT_FONT, 12)
    GameTooltipHeaderText:SetFont("Fonts\\ARHei.ttf", 14)
    ns.setOption("titleFont", "Arial Narrow")
    ns.setOption("bodyFont", "Friz Quadrata")
    local spell = ns.ui.spellModel({ name = "火球术", rank = "等级 1", cast = { "瞬发", "施法" },
        description = { "造成16点火焰伤害。" } })
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, SPELL)
    local fonts, coefficients = {}, false
    for _, font in ipairs(panel.pool) do
        local text = ns.util.plainText(font:GetText() or "")
        if font:IsShown() and text == "火球术" then fonts.title = font:GetFont() end
        if font:IsShown() and text == "造成16点火焰伤害。" then fonts.body = font:GetFont() end
        if font:IsShown() and text:find("系数", 1, true) then coefficients = true end
    end
    test.check("zhCN: rendered Chinese uses native fonts with EllesmereUI installed", fonts,
        { title = "Fonts\\ARHei.ttf", body = "Fonts\\ARKai_T.ttf" })
    test.check("zhCN: rendered spells show localized coefficient rows", coefficients, true)
end
