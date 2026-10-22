-- The Heart of Azeroth's essence slots are read and drawn as sockets: each in
-- the game's border for its kind, an essence's icon inside it, cropped to its
-- face, and both greyed while the slot is disabled. The capture
-- (retail-heart-of-azeroth) has only empty slots.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, AzeriteEssenceSlot = 4, ItemName = 22, ItemLevel = 31 }
    local GREY, WHITE = { r = .5, g = .5, b = .5 }, { r = 1, g = 1, b = 1 }
    local lines = {
        { leftText = "Heart of Azeroth", type = LINE.ItemName },
        { leftText = "Item Level 35", type = LINE.ItemLevel },
        { leftText = "+7 Stamina", type = LINE.None },
        { leftText = "Essence of the Focusing Iris", type = LINE.AzeriteEssenceSlot, slotType = "major",
            essenceIcon = 2967101, disabled = false, leftColor = WHITE },
        { leftText = "Essence Slot Available", type = LINE.AzeriteEssenceSlot, slotType = "minor", disabled = true,
            leftColor = GREY },
    }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 158075, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        line.lineIndex = index
        line.leftColor = line.leftColor or WHITE
        capture.data.lines[index] = line
        capture.lines[index] = { left = { text = line.leftText } }
    end
    local ns, world = test.load(test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }), capture)
    PrettyTooltipDB = {}
    local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)

    local rows = {}
    for _, row in ipairs(model.sockets) do
        rows[#rows + 1] = { row.left, row.frame, row.icon or false, row.desaturated or false }
    end
    test.check("each slot a socket, in its border, its essence inside", rows, {
        { "Essence of the Focusing Iris", "tooltip-heartofazerothessence-major", 2967101, false },
        { "Essence Slot Available", "tooltip-heartofazerothessence-minor", false, true } })
    test.check("not the item's stats or extras", { #model.primary, #model.extras, #model.effects }, { 1, 0, 0 })

    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, ITEM)
    local textures = {}
    for index = 1, panel.texturesUsed do
        local texture = panel.texturePool[index]
        textures[tostring(texture._texture)] = texture
    end
    local major = textures["atlas:tooltip-heartofazerothessence-major"]
    local minor = textures["atlas:tooltip-heartofazerothessence-minor"]
    local essence = textures["2967101"]
    local function aspect(texture) return texture._width == math.floor(texture._height * 1.5 + .5) end
    test.check("the borders drawn half as wide again as tall, to the pixel", { aspect(major), aspect(minor) },
        { true, true })
    test.check("the essence inside its border, cropped to its face",
        { essence._width < major._height, essence._coords[1], essence._coords[2] }, { true, .171875, .828125 })
    test.check("a disabled slot greyed, an enabled one not", { minor._desaturated or false, major._desaturated or false,
        essence._desaturated or false }, { true, false, false })
    -- A texture the pool hands out again starts in color.
    model.sockets[2].desaturated = nil
    panel = ns.ui.renderPreview(anchor, model, ITEM)
    local greyed = 0
    for index = 1, panel.texturesUsed do
        if panel.texturePool[index]._desaturated then greyed = greyed + 1 end
    end
    test.check("a reused texture is not left greyed", greyed, 0)
end
