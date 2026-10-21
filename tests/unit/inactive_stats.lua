-- Retail gear can carry Strength, Agility, and Intellect together; only the
-- one the player's specialization uses counts, and the game greys the others.
-- The panel keeps them grey, without their stat colors, under a grey marker.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 1 }
    local FILES = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" })
    local WHITE, GREY, GREEN = { r = 1, g = 1, b = 1 }, { r = .5, g = .5, b = .5 }, { r = 0, g = 1, b = 0 }
    local lines = {
        { "Ancestral Gauntlets", WHITE }, { "+120 Intellect", WHITE }, { "+120 Agility", GREY },
        { "+120 Strength", GREY }, { "+200 Stamina", WHITE }, { "+80 Critical Strike", GREEN },
    }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        capture.data.lines[index] = { type = index == 1 and LINE.ItemName or 0, lineIndex = index,
            leftText = line[1], leftColor = line[2] }
        capture.lines[index] = { left = { text = line[1] } }
    end
    local ns, world = test.load(FILES, capture)
    PrettyTooltipDB = {}

    local function primary()
        local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
        local rows = {}
        for _, row in ipairs(model.primary) do
            rows[#rows + 1] = { ns.util.trim(ns.util.plainText(row.left)), row.inactive or false,
                row.left:find("128:128:128", 1, true) ~= nil, row.left:find("|c", 1, true) ~= nil }
        end
        return rows, model
    end
    local rows, model = primary()
    test.check("the spec's stat in its color, the others grey", rows, {
        { "+120 Intellect", false, false, true }, { "+120 Agility", true, true, false },
        { "+120 Strength", true, true, false }, { "+200 Stamina", false, false, true } })
    test.check("grey as the game draws them", model.primary[2].color, { .5, .5, .5 })
    test.check("a green secondary stat is still active", #model.secondary, 1)

    ns.setOption("statMarkers", false)
    rows = primary()
    test.check("without markers, no grey marker", rows[2], { "+120 Agility", true, false, false })
    ns.setOption("statMarkers", nil)

    -- A stats color set in the editor colors the active stats, not the grey ones.
    ns.setOption("styles", { stats = { color = { 1, 0, 0 } } })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, select(2, primary()), ITEM)
    local colors = {}
    for _, font in ipairs(panel.pool or {}) do
        for _, stat in ipairs({ "+120 Intellect", "+120 Agility" }) do
            if font._shown and font._text and font._text:find(stat, 1, true) then colors[stat] = { font:GetTextColor() } end
        end
    end
    test.check("an editor color leaves the inactive stats grey", { (colors["+120 Intellect"] or {})[1], (colors["+120 Agility"] or {})[1] },
        { 1, .5 })
end
