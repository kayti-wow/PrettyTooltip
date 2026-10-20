-- The retail .toc loads every file Forever's does but the Classic-only data,
-- and what is drawn from that data stays off.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Object = 3 },
            TooltipDataLineType = { None = 0, ItemName = 1 } },
    }
    local function start(files)
        local ns, world = test.load(files, capture)
        PrettyTooltipDB = {}
        world.fireEvent("ADDON_LOADED", "PrettyTooltip")
        return ns, world
    end

    local ns, world = start(test.tocs.retail)
    test.check("retail is flagged", ns.retail, true)
    test.check("retail starts the addon", #world.postCalls[0] > 0, true)
    test.check("retail has no disenchant tables", ns.disenchantFor, nil)
    test.check("retail has no spell power coefficients", ns.spellPowerRows, nil)
    test.check("retail has no spell schools by name", ns.spellSchool, nil)
    test.check("retail has no Classic node names", ns.nodeNames, nil)
    test.check("retail has no spell ranks", ns.spellRanks, nil)
    test.check("retail has no skinning loot", ns.skinningLoot, nil)
    test.check("retail has no node loot", ns.nodeLoot, nil)
    test.check("retail knows no Classic herb or ore node", ns.gatheringNode("Copper Vein"), nil)
    test.check("retail still rewrites item wording", ns.ItemLite.wording({ leftText =
        "Equip: Increases damage and healing done by magical spells and effects by up to 12." }) ~= nil, true)

    ns = start(test.tocs.forever)
    test.check("Forever is not flagged", ns.retail, nil)
    test.check("Forever has disenchant tables", type(ns.disenchantFor), "function")
    test.check("Forever knows Classic nodes", ns.gatheringNode("Copper Vein"), { level = 1, skill = "Mining" })

    local classic = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if element.classic then classic[#classic + 1] = element.key end
    end
    test.check("style parts drawn from Classic data", classic, { "disenchant", "objectLoot", "unitSkinning" })
end
