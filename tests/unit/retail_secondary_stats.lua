-- Retail prints its secondary stats by their short names, "+120 Haste", which
-- Classic's stat names never read. Each is a stat of its own on retail, in a
-- color the style editor sets, under a style part of its own.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 22 }
    local function files(retail)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
            "Panel/Render.lua", "Tooltips/Item.lua" }
        if retail then list = test.retail(list) end
        return list
    end
    local lines = { "Ancestral Gauntlets", "+120 Intellect", "+80 Critical Strike", "+70 Haste", "+60 Mastery",
        "+50 Versatility", "+40 Leech", "+30 Avoidance", "+20 Speed" }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
    for index, text in ipairs(lines) do
        capture.data.lines[index] = { type = index == 1 and LINE.ItemName or LINE.None, lineIndex = index,
            leftText = text, leftColor = { r = 1, g = 1, b = 1 } }
        capture.lines[index] = { left = { text = text } }
    end
    local ns, world = test.load(files(true), capture)
    PrettyTooltipDB = {}

    local keys = {}
    for index = 3, #lines do keys[#keys + 1] = ns.Stats.read(lines[index]).key end
    test.check("each read as a stat", keys,
        { "CRITICAL_STRIKE", "HASTE", "MASTERY", "VERSATILITY", "LEECH", "AVOIDANCE", "SPEED" })
    local function valueColor(text) return (ns.Stats.styleStat(text, true, false)):match("|cff(%x%x%x%x%x%x)%+") end
    test.check("each in its own color", { valueColor("+70 Haste"), valueColor("+60 Mastery"),
        valueColor("+50 Versatility"), valueColor("+80 Critical Strike"), valueColor("+40 Leech") },
        { "F2D57C", "C3A6F7", "86D4CC", "F7A38E", "D2C4A8" })
    ns.setOption("statColorHaste", { 1, 0, 0 })
    test.check("a color the editor sets", valueColor("+70 Haste"), "FF0000")
    ns.setOption("statColorHaste", nil)
    local swatches = {}
    for _, category in ipairs(ns.Retail.Stats.CATEGORIES) do swatches[#swatches + 1] = category.key end
    test.check("the editor's swatches", swatches, { "CriticalStrike", "Haste", "Mastery", "Versatility", "Minor" })

    -- Drawn in the Secondary stats part, the primary stats in Stats.
    local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    test.check("all secondary", { #model.primary, #model.secondary }, { 1, 7 })
    ns.setOption("styles", { secondaryStats = { size = 20 }, stats = { size = 14 } })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, ITEM)
    local sizes = {}
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text then
            for _, stat in ipairs({ "Intellect", "Haste" }) do
                if font._text:find(stat, 1, true) then sizes[stat] = select(2, font:GetFont()) end
            end
        end
    end
    test.check("each part's own size", { sizes.Intellect, sizes.Haste }, { 14, 20 })

    -- Forever keeps Classic's stats alone.
    ns = test.load(files(false), capture)
    test.check("Forever reads no retail rating", ns.Stats.read("+70 Haste"), nil)
end
