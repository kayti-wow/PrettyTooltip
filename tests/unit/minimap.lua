-- Several blips on the minimap are a list: herbs and ore with the skill each
-- needs, in its skill-up color; a player in their class color.
return function(test)
    local MINIMAP = 21
    local text = "Peacebloom\nCopper Vein\nThrall\nStranger"
    local capture = {
        enums = { TooltipDataType = { Item = 0, Object = 4, MinimapMouseover = MINIMAP } },
        data = { type = MINIMAP, lines = {
            { type = 0, lineIndex = 1, leftText = text, leftColor = { r = 1, g = .82, b = 0 } },
        } },
        lines = { { left = { text = text, color = { 1, .82, 0 } } } },
        calls = {
            UnitName = { party1 = { "Thrall", n = 1 } },
            UnitIsPlayer = { party1 = { true, n = 1 } },
            UnitClass = { party1 = { "Shaman", "SHAMAN", n = 2 } },
            GetNumSkillLines = { [""] = { 2, n = 1 } },
            GetSkillLineInfo = { ["1"] = { "Herbalism", false, false, 30, n = 4 },
                ["2"] = { "Mining", false, false, 1, n = 4 } },
        },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/NodeSkills.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua",
        "Tooltips/Minimap.lua" },
        capture)
    local model = ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game)
    local function blip(index)
        local found = model.blips[index]
        return { found.name, found.meta or false, found.metaColor or found.color or false }
    end
    test.check("each name is a blip", #model.blips, 4)
    test.check("a herb 29 past the skill is yellow", blip(1), { "Peacebloom", "Herbalism 1", { 1, 1, 0 } })
    test.check("ore at the skill is orange", blip(2), { "Copper Vein", "Mining 1", { 1, .50, .25 } })
    local shaman = ns.Game.classColor("SHAMAN")
    test.check("a player is in their class color", blip(3), { "Thrall", false, shaman })
    test.check("anyone else is just a name", blip(4), { "Stranger", false, false })

    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, MINIMAP)
    local shown = {}
    for _, font in ipairs(panel.pool) do
        if font._shown and font._text and font._text ~= "" then shown[#shown + 1] = ns.util.trim(ns.util.plainText(font._text)) end
    end
    test.check("a list, a name and its detail a row", shown,
        { "Peacebloom", "Herbalism 1", "Copper Vein", "Mining 1", "Thrall", "Stranger" })

    ns.setOption("classColorSHAMAN", { 1, 0, 0 })
    model = ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game)
    test.check("minimap players follow custom class colors", blip(3), { "Thrall", false, { 1, 0, 0 } })
    ns.setOption("classColorSHAMAN", nil)
    model = ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game)
    test.check("minimap reset follows the game again", blip(3), { "Thrall", false, shaman })
end
