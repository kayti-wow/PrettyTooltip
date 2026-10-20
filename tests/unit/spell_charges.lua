-- Retail's spells with charges: "Max 2 Charges" as the panel's own part under
-- the strip, the time a charge takes in the strip's cooldown cell as its
-- recharge, and the time left on the next with the other times left.
return function(test)
    local SPELL, NAME, DESCRIPTION = 1, 13, 34
    local function files(locale)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua" }
        if locale ~= "enUS" then list[#list + 1] = "Locale/" .. locale .. ".lua" end
        for _, file in ipairs({ "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua",
            "Tooltips/Spell.lua" }) do list[#list + 1] = file end
        return list
    end

    local function read(locale, lines)
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = 0, Spell = SPELL }, TooltipDataLineType = { None = 0, SpellName = NAME,
                SpellDescription = DESCRIPTION } },
            data = { type = SPELL, id = 108853, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and NAME or index == #lines and DESCRIPTION or 0, lineIndex = index,
                leftText = left, rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local ns, world = test.load(files(locale), capture)
        return ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game), ns
    end
    local function summary(model)
        return { charges = model.charges, cooldown = model.cooldown, cells = #model.cells,
            details = model.details[1] and model.details[1].left, color = model.details[1] and model.details[1].color,
            extras = #model.extras }
    end

    local model, ns = read("enUS", { "Fire Blast", { "1% of base mana", "40 yd range" },
        { "Instant", "12 sec recharge" }, "Max 2 Charges", "Recharging: 5 sec",
        "Blasts the enemy for 950 Fire damage." })
    test.check("English: the charges, the recharge, and the time left", summary(model), {
        charges = "Max 2 Charges", cooldown = { "12 sec", "Recharge" }, cells = 4, details = "Recharging: 5 sec",
        color = { 1, .60, .25 }, extras = 0 })

    -- Russian words the time left as it words a cooldown.
    model = read("ruRU", { "Огненный взрыв", { "1% от базовой маны", "Радиус действия: 40 м." },
        { "Мгновенное", "Время восстановления 12 сек." }, "Максимум 2 заряда", "Восстановление: 5 сек.",
        "Наносит противнику 950 ед. урона от огня." })
    test.check("Russian: the time left does not replace the recharge", summary(model), {
        charges = "Максимум 2 заряда", cooldown = { "12 сек", "Восстановление" }, cells = 4,
        details = "Восстановление: 5 сек.", color = { 1, .60, .25 }, extras = 0 })

    -- Drawn under the strip, in its own part.
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, SPELL)
    local found
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text == "Максимум 2 заряда" then found = font end
    end
    test.check("the charges are drawn", found ~= nil, true)
    test.check("a style part for them", ns.style("spellCharges").size, 11)
    local element
    for _, part in ipairs(ns.ELEMENTS) do if part.key == "spellCharges" then element = part end end
    test.check("offered on retail alone", { element.tooltipType, element.retail }, { "spell", true })
end
