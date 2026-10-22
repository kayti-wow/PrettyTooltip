-- The retail .toc loads every file Forever's does but the Classic-only data,
-- and what is drawn from that data stays off, then retail's own code from
-- Retail/, which Forever's never loads. Spell schools come from retail's own
-- table.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Object = 3 },
            TooltipDataLineType = { None = 0, ItemName = 1 } },
    }
    -- Every file Forever's .toc loads, in its order, but the Classic-only data.
    local CLASSIC_ONLY = {
        ["Data/Schools.lua"] = true, ["Data/Disenchant.lua"] = true, ["Data/Nodes.lua"] = true,
        ["Data/NodeNames.lua"] = true, ["Data/NodeSkills.lua"] = true, ["Data/Skinning.lua"] = true, ["Data/SpellRanks.lua"] = true,
        ["Data/Coefficients.lua"] = true,
    }
    -- Retail's own files are all in Retail/, and Forever loads none of them.
    local function retailOnly(file) return file:match("^Retail/") ~= nil end
    local foreverLoadsRetail = {}
    for _, file in ipairs(test.tocs.forever) do
        if retailOnly(file) then foreverLoadsRetail[#foreverLoadsRetail + 1] = file end
    end
    test.check("Forever loads nothing from Retail/", foreverLoadsRetail, {})
    test.check("retail loads Retail/Retail.lua first", test.tocs.retail[1], "Retail/Retail.lua")
    local inRetail = {}
    for _, file in ipairs(test.tocs.retail) do inRetail[file] = true end
    local expected, missing = {}, {}
    for _, file in ipairs(test.tocs.forever) do
        if not CLASSIC_ONLY[file] then
            if inRetail[file] then expected[#expected + 1] = file else missing[#missing + 1] = file end
        end
    end
    test.check("retail loads every file Forever does but the Classic-only data", missing, {})
    local shared = {}
    for _, file in ipairs(test.tocs.retail) do
        if not retailOnly(file) then shared[#shared + 1] = file end
    end
    test.check("retail loads them in Forever's order", shared, expected)

    local function start(files)
        local ns, world = test.load(files, capture)
        PrettyTooltipDB = {}
        world.fireEvent("ADDON_LOADED", "PrettyTooltip")
        return ns, world
    end

    local ns, world = start(test.tocs.retail)
    test.check("retail is flagged", ns.IsRetail(), true)
    test.check("retail starts the addon", #world.postCalls[0] > 0, true)
    test.check("retail has no disenchant tables", ns.disenchantFor, nil)
    test.check("retail has no spell power coefficients", ns.spellPowerRows, nil)
    -- Retail's IDs and names, not Forever's: Frostbolt is 116 on retail, a rank
    -- of it on Forever is 7322; Chaos Bolt, of every school, has none.
    test.check("retail's spell schools", { ns.spellSchool(nil, 116), ns.spellSchool(nil, 7322),
        ns.spellSchool("Starsurge"), ns.spellSchool("Demonbolt"), ns.spellSchool("Frostfire Bolt"),
        ns.spellSchool("Chaos Bolt") }, { "Frost", nil, "Arcane", "Shadow", "Frostfire", nil })
    test.check("retail has no Classic node names", ns.nodeNames, nil)
    test.check("retail has no spell ranks", ns.spellRanks, nil)
    test.check("retail has no skinning loot", ns.skinningLoot, nil)
    test.check("retail has no node loot", ns.nodeLoot, nil)
    test.check("retail knows no Classic herb or ore node", ns.gatheringNode("Copper Vein"), nil)
    test.check("retail answers the game's questions its own way", {
        ns.Game.spellManaCost == ns.Retail.Game.spellManaCost, ns.Game.globalCooldown == ns.Retail.Game.globalCooldown,
        ns.Game.classSpecs == ns.Retail.Game.classSpecs,
        ns.TooltipData.inactiveColor == ns.Retail.TooltipData.inactiveColor }, { true, true, true, true })
    test.check("retail still rewrites item wording", ns.TooltipData.itemWording({ leftText =
        "Equip: Increases damage and healing done by magical spells and effects by up to 12." }) ~= nil, true)

    ns = start(test.tocs.forever)
    test.check("Forever is not flagged", { ns.IsRetail(), ns.Retail }, { false })
    test.check("Forever has disenchant tables", type(ns.disenchantFor), "function")
    test.check("Forever's spell schools", { ns.spellSchool(nil, 7322), ns.spellSchool(nil, 116) }, { "Frost", "Frost" })
    test.check("Forever knows Classic nodes", ns.gatheringNode("Copper Vein"), { level = 1, skill = "Mining" })
    test.check("Forever's game answers", { ns.Game.spellManaCost(133), ns.Game.globalCooldown(), ns.Game.classSpecs(1) },
        { nil, 1.5, nil })
    test.check("Forever marks no line inactive", ns.TooltipData.inactiveColor({ r = .5, g = .5, b = .5 }), nil)

    local classic = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if element.classic then classic[#classic + 1] = element.key end
    end
    test.check("style parts drawn from Classic data", classic, { "disenchant", "objectLoot", "unitSkinning" })
end
