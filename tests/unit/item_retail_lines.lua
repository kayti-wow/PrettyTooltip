-- Retail's item lines about where an item comes from ("Heroic", under its
-- name), its upgrade level ("Upgrade Level: Myth 2/6"), and what it is
-- transmogrified to, each a line of its own in the panel's header, in its own
-- style part.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemBinding = 20, EquipSlot = 21, ItemName = 22, ItemLevel = 31, ItemUpgradeLevel = 32 }
    local GREEN, WHITE, PINK = { r = .12, g = 1, b = .12 }, { r = 1, g = 1, b = 1 }, { r = 1, g = .5, b = 1 }
    local function files(retail)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
            "Panel/Render.lua", "Tooltips/Item.lua" }
        if retail then list = test.retail(list) end
        return list
    end
    local function read(lines, retail)
        local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = line[2], lineIndex = index, leftText = line[1], rightText = line[3],
                leftColor = line[4] or WHITE }
            capture.lines[index] = { left = { text = line[1] }, right = line[3] and { text = line[3] } }
        end
        local ns, world = test.load(files(retail), capture)
        PrettyTooltipDB = {}
        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game), ns
    end
    local function lines(transmog)
        local list = {
            { "Bloodforged Greataxe", LINE.ItemName }, { "Heroic", LINE.None, nil, GREEN },
            { "Item Level 639", LINE.ItemLevel }, { "Upgrade Level: Myth 2/6", LINE.ItemUpgradeLevel },
            { "Soulbound", LINE.ItemBinding },
        }
        for _, line in ipairs(transmog) do list[#list + 1] = line end
        list[#list + 1] = { "Illusion: Crusader", LINE.None, nil, PINK }
        list[#list + 1] = { "Two-Hand", LINE.EquipSlot, "Axe" }
        list[#list + 1] = { "+120 Strength", LINE.None }
        return list
    end
    local function summary(model)
        local retail = model.retail
        return { source = retail.source, sourceColor = retail.sourceColor, upgrade = retail.upgrade,
            transmog = retail.transmog, illusion = retail.illusion, extras = #model.extras }
    end
    local expected = { source = "Heroic", upgrade = "Myth 2/6", transmog = "Ravager",
        illusion = "Illusion: Crusader", extras = 0 }

    local model, ns = read(lines({ { "Transmogrified to:", LINE.None, nil, PINK }, { "Ravager", LINE.None, nil, PINK } }),
        true)
    -- The source in the game's color, as the panel shows a game color.
    expected.sourceColor = ns.TooltipData.colorOf(GREEN)
    test.check("the source, upgrade, and transmogrification, the name on the next line", summary(model), expected)
    model = read(lines({ { "Transmogrified to:\nRavager", LINE.None, nil, PINK } }), true)
    test.check("the name on the same line", summary(model), expected)
    model = read(lines({ { "Transmogrified to:|nNightblade", LINE.None, nil, PINK } }), true)
    test.check("a name after an escaped line break keeps its letters", model.retail.transmog, "Nightblade")

    -- Forever names no source under the name; the line after it is read as before.
    local forever = read({ { "Arcanite Reaper", LINE.ItemName }, { "Heroic", LINE.None, nil, GREEN } }, false)
    test.check("Forever reads no source", forever.retail, nil)

    -- Drawn in the header: the name, the source, the slot, the upgrade, the
    -- binding, then the transmogrification.
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, ITEM)
    local order = {}
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text then
            for _, part in ipairs({ "Heroic", "Myth 2/6", "Soulbound", "Transmogrified to: Nightblade",
                "Illusion: Crusader" }) do
                if font._text:find(part, 1, true) then order[#order + 1] = part end
            end
        end
    end
    test.check("each a line of its own, in order", order,
        { "Heroic", "Myth 2/6", "Soulbound", "Transmogrified to: Nightblade", "Illusion: Crusader" })
    local parts = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if element.retail and not element.tooltipType and element.key:find("^item") then parts[#parts + 1] = element.key end
    end
    test.check("each its own style part, offered on retail", parts, { "itemSource", "itemCosmetic", "itemUpgrade", "itemTransmog" })
end
