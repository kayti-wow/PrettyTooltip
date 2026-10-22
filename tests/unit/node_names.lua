-- Herb and ore nodes are named in the client's language; the node data knows
-- them by their English names, which each client's own map to.
return function(test)
    local ns = test.load({ "Data/NodeNames.lua" }, { client = { locale = "deDE" } })
    test.check("deDE: a vein", ns.nodeNames["Kupferader"], "Copper Vein")
    test.check("deDE: an ooze covered vein is its own", ns.nodeNames["Schlammbedeckte Silberader"], "Silver Vein")
    test.check("deDE: a herb", ns.nodeNames["Friedensblume"], "Peacebloom")
    test.check("deDE: only its own language", ns.nodeNames["\234\181\172\235\166\172 \234\180\145\235\167\165"], nil)
    ns = test.load({ "Data/NodeNames.lua" }, { client = { locale = "koKR" } })
    test.check("koKR: a herb whose node is named apart from its herb", ns.nodeNames["\236\157\128\236\151\189\236\136\152 \235\141\164\235\182\136"],
        "Silverleaf")
    ns = test.load({ "Data/NodeNames.lua" }, {})
    test.check("enUS: no names to map", next(ns.nodeNames), nil)

    -- The reader and the minimap with a German client's names, as the data
    -- file would leave them.
    local function german(_, loaded)
        loaded.nodeNames = { ["Kupferader"] = "Copper Vein", ["Schlammbedeckte Silberader"] = "Silver Vein",
            ["Beulengras"] = "Bruiseweed" }
    end
    local capture = { enums = { TooltipDataType = { Item = 0, Object = 33 } } }
    ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Nodes.lua", german, "Data/NodeSkills.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" }, capture)
    test.check("a vein by the client's name", ns.gatheringNode("Kupferader"), { level = 1, skill = "Mining" })
    test.check("an ooze covered one", ns.gatheringNode("Schlammbedeckte Silberader"), { level = 75, skill = "Mining" })
    test.check("a herb", ns.gatheringNode("Beulengras"), { level = 100, skill = "Herbalism" })
    local model = ns.ui.objectModel({ name = "Beulengras", skill = "Herbalism" })
    test.check("its skill level and loot", { model.skillRow.level, #model.loot }, { 100, 1 })
end
