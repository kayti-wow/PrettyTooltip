-- Two secondary stats, an enchant, a socket, and an equip effect, in that
-- order, each a row apart, but the enchant and the socket 8 from the rows
-- around them (5 more than a row's own gap of 3), and once between the two.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, GemSocket = 3, ItemEnchantmentPermanent = 15, EquipSlot = 21, ItemName = 22,
        ItemLevel = 31, ItemSpellTriggerOnEquip = 45 }
    local lines = {
        { leftText = "Socketed Gauntlets", type = LINE.ItemName },
        { leftText = "Item Level 639", type = LINE.ItemLevel },
        { leftText = "Hands", rightText = "Leather", type = LINE.EquipSlot },
        { leftText = "+120 Intellect", type = LINE.None },
        { leftText = "+70 Haste", type = LINE.None },
        { leftText = "+50 Mastery", type = LINE.None },
        { leftText = "Enchanted: +20 Agility", type = LINE.ItemEnchantmentPermanent },
        { leftText = "Prismatic Socket", type = LINE.GemSocket, socketType = "Prismatic" },
        { leftText = "Equip: Your attacks sometimes heal you.", type = LINE.ItemSpellTriggerOnEquip },
    }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 3001, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        line.lineIndex = index
        line.leftColor = { r = 1, g = 1, b = 1 }
        capture.data.lines[index] = line
        capture.lines[index] = { left = { text = line.leftText } }
    end
    local ns, world = test.load(test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }), capture)
    PrettyTooltipDB = {}
    local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    test.check("each part read", { #model.secondary, #model.enchants, #model.sockets, #model.equipEffects },
        { 2, 1, 1, 1 })

    -- One size for every part, so each row is as tall as the next.
    ns.setOption("styles", { secondaryStats = { size = 13 }, enchants = { size = 13 }, gems = { size = 13 },
        equipEffects = { size = 13 } })
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, ITEM)
    local wanted = { "Haste", "Mastery", "Agility", "Prismatic Socket", "heal you" }
    local tops = {}
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text then
            for index, text in ipairs(wanted) do
                if font._text:find(text, 1, true) then tops[index] = -select(5, font:GetPoint(1)) end
            end
        end
    end
    test.check("every part drawn",
        { tops[1] ~= nil, tops[2] ~= nil, tops[3] ~= nil, tops[4] ~= nil, tops[5] ~= nil },
        { true, true, true, true, true })
    if not (tops[1] and tops[2] and tops[3] and tops[4] and tops[5]) then return end
    local row = tops[2] - tops[1]
    test.check("each part a row below the last, the enchant and socket 5 further apart",
        { tops[3] - tops[2], tops[4] - tops[3], tops[5] - tops[4] },
        { row + 5, row + 5, row + 5 })
    ns.setOption("styles", nil)
end
