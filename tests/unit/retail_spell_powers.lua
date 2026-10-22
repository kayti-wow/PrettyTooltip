-- Retail's spells cost its own resources too, "3 Holy Power": the cost goes
-- in the strip, in the resource's color, as Forever's five do, not among the
-- other addons' rows. Forever, which has none of them, reads them as before.
return function(test)
    local SPELL, NAME, DESCRIPTION = 1, 13, 34
    local function files(locale, retail)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua" }
        if locale ~= "enUS" then list[#list + 1] = "Locale/" .. locale .. ".lua" end
        for _, file in ipairs({ "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua",
            "Tooltips/Spell.lua" }) do list[#list + 1] = file end
        if retail then list = test.retail(list) end
        return list
    end

    -- The range and cast as each client words them.
    local WORDS = { enUS = { "Melee Range", "Instant" }, deDE = { "Nahkampfreichweite", "Spontan" } }
    local function read(locale, retail, cost)
        local words = WORDS[locale]
        local lines = { "Templar's Verdict", { cost, words[1] }, words[2],
            "Unleashes a powerful weapon strike that deals 950 Holy damage to an enemy target." }
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = 0, Spell = SPELL }, TooltipDataLineType = { None = 0, SpellName = NAME,
                SpellDescription = DESCRIPTION } },
            data = { type = SPELL, id = 85256, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and NAME or index == #lines and DESCRIPTION or 0,
                lineIndex = index, leftText = left, rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local ns, world = test.load(files(locale, retail), capture)
        return ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game), ns
    end
    local function summary(model)
        return { cost = model.cost, power = model.power, extras = #model.extras }
    end

    local model, ns = read("enUS", true, "3 Holy Power")
    test.check("Holy Power is the strip's cost", summary(model),
        { cost = { "3", "Holy Power" }, power = "Holy Power", extras = 0 })
    model = read("enUS", true, "1 Soul Shard")
    test.check("a resource the game words in the singular and plural", summary(model),
        { cost = { "1", "Soul Shards" }, power = "Soul Shards", extras = 0 })
    model = read("enUS", true, "40 Fury")
    test.check("Fury", summary(model), { cost = { "40", "Fury" }, power = "Fury", extras = 0 })
    model = read("deDE", true, "40 Jähzorn")
    test.check("in the client's language", summary(model), { cost = { "40", "Jähzorn" }, power = "Fury", extras = 0 })

    -- The cost's value takes its resource's color, lightened as the others are.
    model, ns = read("enUS", true, "3 Holy Power")
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, SPELL)
    local color
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text == "3" then color = { font:GetTextColor() } end
    end
    local holy = ns.Retail.Spell.POWERS[1].color
    local function lifted(value) return value * .45 + .55 end
    test.check("drawn in Holy Power's color", color and { color[1], color[2], color[3] },
        { lifted(holy[1]), lifted(holy[2]), lifted(holy[3]) })

    -- Forever reads only its own five.
    model = read("enUS", false, "3 Holy Power")
    test.check("Forever reads no retail resource", { model.cost, model.extras[1] and model.extras[1].left },
        { nil, "3 Holy Power" })
end
