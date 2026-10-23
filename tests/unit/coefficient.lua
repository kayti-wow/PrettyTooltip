-- Spell power coefficients and the base and spell power split, against values
-- checked in game (30 spell damage) and on foreverchanges.pro.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
        "Game/Game.lua", "Data/Schools.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua" })
    -- The player's power, given as the game would answer it.
    local game = { spellDamage = function() return 30 end, spellHealing = function() return 300 end }

    local function rows(name, cast, text, spellID)
        local found = ns.spellPowerRows({ name = name, cast = { cast, "Cast" }, description = { text },
            spellID = spellID }, "FFFFFF", game)
        if not found then return "none" end
        local out = {}
        for _, row in ipairs(found) do
            out[#out + 1] = row.left .. " | " .. row.right:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        end
        return table.concat(out, "\n")
    end

    -- In game: rank 3, 2.2 sec shown as 1.7 with Improved Frostbolt, 62 to 68 at 30 spell damage, base 45 to 51.
    test.check("Frostbolt rank 3, talented", rows("Frostbolt", "1.7 sec",
        "Launches a bolt of frost at the enemy, causing 62 to 68 Frost damage and slowing movement speed by 40% for 6 sec.",
        837), "Spell Power Coefficient | 59.7% · 45 to 51 + 17")
    -- In game: 66 to 83 at 30 spell damage; the burn does not scale.
    test.check("Fireball rank 3", rows("Fireball", "2.5 sec",
        "Hurls a fiery ball that causes 66 to 83 Fire damage and an additional 6 Fire damage over 6 sec.", 145),
        "Spell Power Coefficient | 71.4% · 45 to 62 + 21\nSpell Power Coefficient over time | 0.0% · 6 + 0")
    -- In game: rank 1, 39 to 48 at 30 spell damage; no penalty below level 20.
    test.check("Fire Blast rank 1", rows("Fire Blast", "Instant", "Blasts the enemy for 39 to 48 Fire damage.", 2136),
        "Spell Power Coefficient | 42.9% · 27 to 36 + 12")
    -- foreverchanges.pro: 20% a tick, six ticks; no cap over 100%.
    test.check("Shadow Word: Pain", rows("Shadow Word: Pain", "Instant",
        "A word of darkness that causes 30 Shadow damage over 18 sec."), "Spell Power Coefficient over time | 120.0% · 0 + 36")
    -- foreverchanges.pro: 28.6% at once, 7.1% a tick for seven ticks.
    test.check("Regrowth", rows("Regrowth", "2 sec", "Heals a friendly target for 89 to 103 and another 91 over 21 sec."),
        "Healing Power Coefficient | 28.6% · 4 to 18 + 85\nHealing Power Coefficient over time | 49.7% · 0 + 149")
    test.check("Holy Light rank 5", rows("Holy Light", "2.5 sec", "Heals a friendly target for 425 to 479.", 1042),
        "Healing Power Coefficient | 71.4% · 211 to 265 + 214")
    test.check("an unknown spell is an estimate", rows("Mystery Bolt", "2.5 sec",
        "Hits the target for 221 to 261 Shadow damage."), "Spell Power Coefficient | ~71.4% · 200 to 240 + 21")
    test.check("a channel's amount each second gains its share of the whole", rows("Arcane Missiles", "Channeled",
        "Launches Arcane Missiles at the enemy, causing 230 Arcane damage each second for 5 sec."),
        "Spell Power Coefficient over time | 143.0% · 222 + 8 each")
    test.check("a heal every few seconds, which never says heal", rows("Tranquility", "Channeled",
        "Regenerates all nearby group members for 1425 every 2 sec for 10 sec."),
        "Healing Power Coefficient over time | 33.5% · 1405 + 20 each")
    test.check("an unknown channeled spell shows nothing", rows("Mystery Channel", "Channeled",
        "Channels a mystery, causing 230 Arcane damage each second for 5 sec."), "none")
    test.check("a physical ability shows nothing", rows("Shield Bash", "Instant",
        "Bashes the target with your shield for 8 damage."), "none")
    test.check("a class spell the table lacks gains nothing", rows("Dampen Magic", "Instant",
        "Decreases magic damage taken by up to 10 and the amount healed by healing spells by up to 11."), "none")
    test.check("health is not healing", rows("Mystery Totem", "Instant",
        "Summons a Mystery Totem with 5 health at the feet of the caster for 45 sec."), "none")

    -- The rates rows: per second and per mana.
    local function rates(name, cast, cost, text, spellID)
        local _, found = ns.spellPowerRows({ name = name, cast = { cast, "Cast" }, cost = cost,
            description = { text }, spellID = spellID }, "FFFFFF", game)
        if not found then return "none" end
        local out = {}
        for _, row in ipairs(found) do out[#out + 1] = row.left .. " | " .. row.right end
        return table.concat(out, "\n")
    end
    test.check("a heal's rates", rates("Holy Light", "2.5 sec", { "275", "Mana" },
        "Heals a friendly target for 425 to 479.", 1042), "Healing per Second | 180.8\nHealing per Mana | 1.64")
    test.check("an instant counts the global cooldown", rates("Fire Blast", "Instant", { "40", "Mana" },
        "Blasts the enemy for 39 to 48 Fire damage.", 2136), "Damage per Second | 29.0\nDamage per Mana | 1.09")
    test.check("a cast under the global cooldown counts the global cooldown", rates("Frostbolt", "1.2 sec",
        { "35", "Mana" }, "Launches a bolt of frost at the enemy, causing 62 to 68 Frost damage.", 837),
        "Damage per Second | 43.3\nDamage per Mana | 1.86")
    test.check("damage over time counts over its duration, and in full per mana", rates("Fireball", "2.5 sec",
        { "65", "Mana" },
        "Hurls a fiery ball that causes 66 to 83 Fire damage and an additional 6 Fire damage over 6 sec.", 145),
        "Damage per Second | 30.8\nDamage per Mana | 1.24")
    test.check("an instant over time counts its duration, not the global cooldown", rates("Shadow Word: Pain",
        "Instant", { "25", "Mana" }, "A word of darkness that causes 30 Shadow damage over 18 sec."),
        "Damage per Second | 1.7\nDamage per Mana | 1.20")
    test.check("a heal at once and over time adds both rates", rates("Regrowth", "2 sec", { "100", "Mana" },
        "Heals a friendly target for 89 to 103 and another 91 over 21 sec."),
        "Healing per Second | 52.3\nHealing per Mana | 1.87")
    test.check("a channel counts its duration and every tick", rates("Arcane Missiles", "Channeled",
        { "1,055", "Mana" }, "Launches Arcane Missiles at the enemy, causing 230 Arcane damage each second for 5 sec."),
        "Damage per Second | 230.0\nDamage per Mana | 1.09")
    test.check("a share of base mana has no per mana", rates("Holy Light", "2.5 sec", { "5%", "Base Mana" },
        "Heals a friendly target for 425 to 479.", 1042), "Healing per Second | 180.8")
    test.check("a free spell has no per mana", rates("Holy Light", "2.5 sec", nil,
        "Heals a friendly target for 425 to 479.", 1042), "Healing per Second | 180.8")
    test.check("a spell that does not scale has no rates", rates("Shield Bash", "Instant", { "10", "Rage" },
        "Bashes the target with your shield for 8 damage."), "none")
end
