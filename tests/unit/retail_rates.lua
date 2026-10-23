-- Retail has no spell power coefficients, but a spell's rates need none: its
-- description already counts the player's stats in. An instant counts retail's
-- global cooldown, which shrinks with haste, and is 1 sec for energy users.
return function(test)
    local SPELL = 1
    local files = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Game/SpellAmounts.lua",
        "Retail/Data/Schools.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" })
    local ns = test.load(files, { enums = { TooltipDataType = { Item = 0, Spell = SPELL } } })

    -- The global cooldown, from the player's power and haste.
    local power, haste = "MANA", 0
    UnitPowerType = function() return 0, power end
    UnitSpellHaste = function() return haste end
    local gcd = ns.Game.globalCooldown
    haste = 25
    test.check("haste shortens the global cooldown", gcd(), 1.2)
    haste = 200
    test.check("to 0.75 sec at the least", gcd(), .75)
    power = "ENERGY"
    test.check("an energy user's is 1 sec, whatever the haste", gcd(), 1)
    power, haste = "MANA", 0
    local retail = ns.Retail
    ns.Retail = nil
    test.check("Forever's is 1.5 sec", gcd(), 1.5)
    ns.Retail = retail

    local game = { globalCooldown = function() return 1.2 end }
    local function rates(cast, cost, text)
        local found = ns.SpellAmounts.rateRowsOf({ cast = { cast, "Cast" }, cost = cost, description = { text } }, game)
        if not found then return "none" end
        local out = {}
        for _, row in ipairs(found) do out[#out + 1] = row.left .. " | " .. row.right end
        return table.concat(out, "\n")
    end
    test.check("a cast's damage over its cast time and its mana", rates("2.25 sec", { "1,000", "Mana" },
        "Throws a fiery ball that causes 12,340 Fire damage."), "Damage per Second | 5,484.4\nDamage per Mana | 12.34")
    test.check("an instant over the hasted global cooldown", rates("Instant", { "500", "Mana" },
        "Blasts the enemy for 6,000 Fire damage."), "Damage per Second | 5,000.0\nDamage per Mana | 12.00")
    test.check("a heal", rates("1.5 sec", { "2,000", "Mana" }, "Heals a friendly target for 9,000."),
        "Healing per Second | 6,000.0\nHealing per Mana | 4.50")
    test.check("damage over time over its duration", rates("Instant", { "300", "Mana" },
        "A word of darkness that causes 4,800 Shadow damage over 16 sec."),
        "Damage per Second | 300.0\nDamage per Mana | 16.00")
    -- Retail's share of base mana, as the game works it out for the player.
    game.spellManaCost = function(spellID) return spellID == 133 and 1000 or nil end
    local found = ns.SpellAmounts.rateRowsOf({ spellID = 133, cast = { "2.25 sec", "Cast" },
        cost = { "2%", ns.L["Base Mana"] }, description = { "Throws a fiery ball that causes 12,340 Fire damage." } },
        game)
    test.check("a share of base mana, by the game's cost", found and found[2] and found[2].right, "12.34")
    found = ns.SpellAmounts.rateRowsOf({ spellID = 1, cast = { "2.25 sec", "Cast" },
        cost = { "2%", ns.L["Base Mana"] }, description = { "Throws a fiery ball that causes 12,340 Fire damage." } },
        game)
    test.check("without the game's cost, no per mana", #found, 1)
    local spellAPI = C_Spell
    C_Spell = { GetSpellPowerCost = function(spellID)
        if spellID == 133 then return { { type = 3, cost = 30 }, { type = 0, cost = 1000 } } end
    end }
    test.check("the game's cost is the mana one", { ns.Game.spellManaCost(133), ns.Game.spellManaCost(2) }, { 1000, nil })
    C_Spell = spellAPI
    test.check("thousands grouped as the client groups them", { ns.SpellAmounts.decimal(1234567.25, 1),
        ns.SpellAmounts.decimal(999.94, 1), ns.SpellAmounts.decimal(123456, 2) }, { "1,234,567.2", "999.9", "123,456.00" })
    local group, point = LARGE_NUMBER_SEPERATOR, DECIMAL_SEPERATOR
    LARGE_NUMBER_SEPERATOR, DECIMAL_SEPERATOR = ".", ","
    test.check("and in German", ns.SpellAmounts.decimal(5484.44, 1), "5.484,4")
    LARGE_NUMBER_SEPERATOR, DECIMAL_SEPERATOR = group, point
    test.check("another power has no per mana", rates("Instant", { "30", "Energy" },
        "Blasts the enemy for 6,000 Fire damage."), "Damage per Second | 5,000.0")
    test.check("a physical ability has no rates", rates("Instant", { "30", "Rage" },
        "A vicious strike that deals 500 damage."), "none")

    -- The panel shows the rates without a spell power split.
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, { name = "Fireball", rank = "", icon = 135812, cast = { "2.25 sec", "Cast" },
        cost = { "1,000", "Mana" }, cells = { { "2.25 sec", "Cast" } }, details = {}, requirements = {},
        description = { "Throws a fiery ball that causes 12,340 Fire damage." }, extras = {} }, SPELL)
    local texts = {}
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text then texts[#texts + 1] = font._text end
    end
    local text = table.concat(texts, " | ")
    test.check("the panel shows the rates, and no coefficient", { text:find("Damage per Second", 1, true) ~= nil,
        text:find("Coefficient", 1, true) ~= nil }, { true, false })
    UnitPowerType, UnitSpellHaste = nil, nil
end
