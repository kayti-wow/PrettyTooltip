-- The addon asks the game through ns.Game alone: answers the game hides come
-- back as nil, and code given the game works from any table that answers the same.
return function(test)
    local secret = { __secret = true }
    local ns = test.load({ "Core/Util.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua" }, { calls = {
        UnitName = { party1 = { n = 2, secret }, player = { n = 2, "Moonseeker" } },
        UnitLevel = { player = { n = 1, secret } },
        ["C_Item.GetItemInfo"] = { ["19019"] = { n = 11, "Thunderfury", secret, 5, 80, 60, "Weapon", "One-Handed Swords",
            1, "INVTYPE_WEAPONMAINHAND", 135349, 255000 } },
    } })
    local game = ns.Game
    test.check("a hidden name is nil", game.unitName("party1"), nil)
    test.check("a readable name passes", game.unitName("player"), "Moonseeker")
    test.check("a hidden level is nil", game.playerLevel(), nil)
    test.check("a hidden field leaves the others", game.itemInfo(19019),
        { name = "Thunderfury", quality = 5, icon = 135349, price = 255000 })
    test.check("an unknown item has no fields", game.itemInfo(1), {})
    test.check("an API the client lacks answers nothing", game.itemType(19019), nil)
    test.check("without Auctionator there is no price", game.auctionPrice(19019), nil)

    -- A skill is asked for by the addon's name, and found by the client's.
    ns = test.load({ "Core/Util.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua" }, { calls = {
        GetProfessions = { [""] = { n = 2, 6, 7 } },
        GetProfessionInfo = { ["6"] = { n = 3, "K\195\188rschnerei", 134366, 125 },
            ["7"] = { n = 3, "Verzauberkunst", 136244, 80 } },
    } })
    ns.Locale.skills.Skinning, ns.Locale.skills.Enchanting = "K\195\188rschnerei", "Verzauberkunst"
    test.check("a skill by the client's name for it", { ns.Game.skill("Skinning"), ns.Game.skill("Enchanting") },
        { 125, 80 })
    test.check("a skill the player lacks", ns.Game.skill("Mining"), nil)

    -- Disenchant results from a table standing in for the game.
    ns = test.load({ "Core/Util.lua", "Data/Disenchant.lua" })
    local NEXUS = 20725
    local stub = {
        skill = function(name) return name == "Enchanting" and 300 or nil end,
        itemName = function(id) return id == NEXUS and "Nexus Crystal (loaded)" or nil end,
        itemIcon = function() return 132877 end,
        auctionPrice = function() return 10000 end,
    }
    -- An epic level 63 weapon: one or two Nexus Crystals, at 1.5 crystals on average.
    test.check("disenchant asks only the game given", ns.disenchantFor(2, 4, 63, "INVTYPE_2HWEAPON", nil, stub), {
        skill = 225, player = 300, value = 15000,
        rows = { { id = NEXUS, name = "Nexus Crystal (loaded)", icon = 132877, count = { 1, 2 }, chance = 100 } },
    })
    local unknown = { skill = function() end, itemName = function() end, itemIcon = function() end,
        auctionPrice = function() end }
    local result = ns.disenchantFor(2, 4, 63, "INVTYPE_2HWEAPON", nil, unknown)
    test.check("an unloaded result keeps its known name", result.rows[1].name, "Nexus Crystal")
    test.check("an unpriced result gives no value", result.value, nil)
end
