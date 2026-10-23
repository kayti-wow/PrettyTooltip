-- Retail's .toc loads Forever's files but Forever's own data, and retail's own
-- code from Retail/, which Forever's never loads. Each Retail/ file is named
-- for the shared file it serves, and retail's .toc places it by that name
-- (Retail/README.md). What is drawn from Forever's data stays off on retail.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Object = 3 },
            TooltipDataLineType = { None = 0, ItemName = 1 } },
    }
    -- The files only Forever's .toc loads; the first two have retail stand-ins.
    local FOREVER_ONLY = { "Data/Schools.lua", "Data/Imbues.lua", "Data/Disenchant.lua", "Data/Nodes.lua",
        "Data/NodeNames.lua", "Data/NodeSkills.lua", "Data/Skinning.lua", "Data/SpellRanks.lua",
        "Data/Coefficients.lua" }
    local DATA_SETS = { "disenchant", "coefficients", "nodeLoot", "nodeNames", "nodeSkills", "skinningLoot" }

    local fromRetail = {}
    for _, file in ipairs(test.tocs.forever) do
        if file:match("^Retail/") then fromRetail[#fromRetail + 1] = file end
    end
    test.check("Forever loads nothing from Retail/", fromRetail, {})
    test.check("retail's .toc places each file by its name", test.tocs.retail, test.retail(test.tocs.forever))

    local retailLoads, foreverOnly = {}, {}
    for _, file in ipairs(test.tocs.retail) do retailLoads[file] = true end
    for _, file in ipairs(test.tocs.forever) do
        if not retailLoads[file] then foreverOnly[#foreverOnly + 1] = file end
    end
    table.sort(foreverOnly)
    local expected = {}
    for _, file in ipairs(FOREVER_ONLY) do expected[#expected + 1] = file end
    table.sort(expected)
    test.check("Forever's own files", foreverOnly, expected)
    local unmarked = {}
    for _, file in ipairs(FOREVER_ONLY) do
        if not test.sources[file]:find("\n%-%- Forever only: ") then unmarked[#unmarked + 1] = file end
    end
    test.check("each says it is Forever's alone", unmarked, {})

    local unnamed = {}
    for file in pairs(test.sources) do
        local shared = file:match("^Retail/(.+)$")
        if shared and file ~= "Retail/Retail.lua" and not test.sources[shared]
            and not test.sources[(shared:gsub("Extension%.lua$", ".lua"))] then
            unnamed[#unnamed + 1] = file
        end
    end
    table.sort(unnamed)
    test.check("each Retail/ file is named for a shared one", unnamed, {})

    local function start(files)
        local ns, world = test.load(files, capture)
        PrettyTooltipDB = {}
        world.fireEvent("ADDON_LOADED", "PrettyTooltip")
        return ns, world
    end
    local function dataSets(ns)
        local has = {}
        for _, name in ipairs(DATA_SETS) do has[#has + 1] = ns.hasData(name) end
        return has
    end
    local function source(fn) return debug.getinfo(fn, "S").source end

    local ns, world = start(test.tocs.retail)
    test.check("retail is flagged", ns.IsRetail(), true)
    test.check("retail starts the addon", #world.postCalls[0] > 0, true)
    test.check("retail has none of Forever's data", dataSets(ns), { false, false, false, false, false, false })
    test.check("an unknown data set stops the load", pcall(ns.hasData, "nodeLot"), false)
    -- Retail's IDs and names, not Forever's: Frostbolt is 116 on retail, a rank
    -- of it on Forever is 7322; Chaos Bolt, of every school, has none.
    test.check("retail's spell schools", { ns.spellSchool(nil, 116), ns.spellSchool(nil, 7322),
        ns.spellSchool("Starsurge"), ns.spellSchool("Demonbolt"), ns.spellSchool("Frostfire Bolt"),
        ns.spellSchool("Chaos Bolt") }, { "Frost", nil, "Arcane", "Shadow", "Frostfire", nil })
    test.check("retail's imbues", { ns.imbues[5401] ~= nil, ns.imbues[1] }, { true, nil })
    test.check("retail knows no Classic herb or ore node", ns.gatheringNode("Copper Vein"), nil)
    test.check("retail answers the game's questions its own way", {
        source(ns.Game.spellManaCost), source(ns.Game.globalCooldown), source(ns.Game.classSpecs),
        source(ns.TooltipData.inactiveColor) }, { "@Retail/Game/GameExtension.lua", "@Retail/Game/GameExtension.lua",
        "@Retail/Game/GameExtension.lua", "@Retail/Game/TooltipDataExtension.lua" })
    test.check("a client replaces only what a module has",
        pcall(ns.replace, ns.Game, "Game/Game.lua", { spellMana = function() end }), false)
    test.check("retail still rewrites item wording", ns.TooltipData.itemWording({ leftText = "+120 Haste" }) ~= nil,
        true)

    ns = start(test.tocs.forever)
    test.check("Forever is not flagged", { ns.IsRetail(), ns.Retail }, { false })
    test.check("Forever has its data", dataSets(ns), { true, true, true, true, true, true })
    test.check("Forever's spell schools", { ns.spellSchool(nil, 7322), ns.spellSchool(nil, 116) }, { "Frost", "Frost" })
    test.check("Forever's imbues", { ns.imbues[1] ~= nil, ns.imbues[5401] }, { true, nil })
    test.check("Forever knows Classic nodes", ns.gatheringNode("Copper Vein"), { level = 1, skill = "Mining" })
    test.check("Forever's game answers", { ns.Game.spellManaCost(133), ns.Game.globalCooldown(), ns.Game.classSpecs(1) },
        { nil, 1.5, nil })
    test.check("Forever marks no line inactive", ns.TooltipData.inactiveColor({ r = .5, g = .5, b = .5 }), nil)

    local fromData = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if element.needs then fromData[#fromData + 1] = element.key .. " " .. element.needs end
    end
    test.check("style parts drawn from Forever's data", fromData,
        { "disenchant disenchant", "objectLoot nodeLoot", "unitSkinning skinningLoot" })
end
