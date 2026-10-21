-- A weapon's temporary enchant ("Windfury Weapon (59 min)") is drawn under its
-- permanent ones. A shield's block is in shield_block.lua.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 22, ItemEnchantmentPermanent = 15 }
    local function read(lines)
        local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = line[2] or LINE.None, lineIndex = index, leftText = line[1],
                leftColor = { r = 1, g = 1, b = 1 } }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local ns, world = test.load(test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }), capture)
        PrettyTooltipDB = {}
        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game), ns
    end
    local function texts(ns, model)
        local anchor = CreateFrame("Frame", nil, UIParent)
        local panel = ns.ui.renderPreview(anchor, model, ITEM)
        local list = {}
        for _, font in ipairs(panel.pool or {}) do
            if font._shown and font._text then list[#list + 1] = ns.util.plainText(font._text) end
        end
        return table.concat(list, " | ")
    end

    local model, ns = read({ { "Thunderfury", LINE.ItemName }, { "Windfury Weapon (59 min)" },
        { "Enchanted: Crusader", LINE.ItemEnchantmentPermanent } })
    test.check("the imbue with the enchants, not other rows",
        { model.imbues and ns.util.plainText(model.imbues[1].left), #model.effects, #model.extras },
        { "Windfury Weapon (59 min)", 0, 0 })
    local drawn = texts(ns, model)
    local enchant, imbue = drawn:find("Crusader", 1, true), drawn:find("Windfury Weapon (59 min)", 1, true)
    test.check("under the permanent enchant", enchant ~= nil and imbue ~= nil and imbue > enchant, true)
end
