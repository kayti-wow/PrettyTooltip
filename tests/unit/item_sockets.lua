-- Retail's gems, sockets, and crafted quality. A socketed gem's line is its
-- stat ("+70 Haste") with its icon, which the item's own stats must not take
-- in; an empty socket names its kind; the socket bonus and a crafted item's
-- quality follow. Each is drawn in a style part of its own.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, GemSocket = 3, ProfessionCraftingQuality = 12, EquipSlot = 21, ItemName = 22,
        GemSocketEnchantment = 30, ItemLevel = 31 }
    local GREY, GREEN = { r = .5, g = .5, b = .5 }, { r = 0, g = 1, b = 0 }
    local QUALITY = "Quality: |A:Professions-ChatIcon-Quality-Tier5:17:17|a"
    local lines = {
        { leftText = "Crafted Gauntlets", type = LINE.ItemName },
        { leftText = "Item Level 639", type = LINE.ItemLevel },
        { leftText = QUALITY, type = LINE.ProfessionCraftingQuality },
        { leftText = "Hands", rightText = "Leather", type = LINE.EquipSlot },
        { leftText = "+120 Intellect", type = LINE.None },
        { leftText = "+70 Haste", type = LINE.GemSocket, gemIcon = 4555555, leftColor = { r = 1, g = 1, b = 1 } },
        { leftText = "Your spells sometimes burn the target.", type = LINE.GemSocketEnchantment },
        { leftText = "Prismatic Socket", type = LINE.GemSocket, socketType = "Prismatic", leftColor = GREY },
        { leftText = "Socket Bonus: +8 Stamina", type = LINE.None, leftColor = GREY },
        { leftText = "<Shift Right Click to Socket>", type = LINE.None, leftColor = GREEN },
    }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 3000, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        line.lineIndex = index
        line.leftColor = line.leftColor or { r = 1, g = 1, b = 1 }
        capture.data.lines[index] = line
        capture.lines[index] = { left = { text = line.leftText } }
    end
    local ns, world = test.load({ "Core/Retail.lua", "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }, capture)
    PrettyTooltipDB = {}
    local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)

    test.check("a gem's stat is not the item's", { #model.primary, #model.secondary, #model.extras }, { 1, 0, 0 })
    local rows = {}
    for _, row in ipairs(model.sockets) do
        rows[#rows + 1] = { ns.util.plainText(row.left), row.icon or false, row.indent or 0 }
    end
    test.check("the sockets, each with its icon", rows, {
        { "+70 Haste", 4555555, 0 },
        { "Your spells sometimes burn the target.", false, 20 },
        { "Prismatic Socket", "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic", 0 },
        { "Socket Bonus: +8 Stamina", false, 0 }, { "<Shift Right Click to Socket>", false, 0 } })
    test.check("the gem's stat in its stat color", model.sockets[1].left:find("|cffF2D57C", 1, true) ~= nil, true)
    test.check("an empty socket and an inactive bonus in the game's grey",
        { model.sockets[3].color, model.sockets[4].color }, { ns.TooltipData.colorOf(GREY), ns.TooltipData.colorOf(GREY) })
    test.check("the crafted quality with its icon", model.craftingQuality, QUALITY)

    -- Drawn: the quality in the header, the sockets with their icons in their part.
    ns.setOption("styles", { gems = { size = 16 }, craftingQuality = { size = 15 } })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, ITEM)
    local found = {}
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text then
            if font._text:find("|T4555555:20:20", 1, true) then found.gem = select(2, font:GetFont()) end
            if font._text:find("UI-EmptySocket-Prismatic:20:20", 1, true) then found.empty = true end
            -- The quality icon at the line's size, not the game's 20 px.
            if font._text:find("Quality: |A:Professions-ChatIcon-Quality-Tier5:15:15:0:0|a", 1, true) then
                found.quality = select(2, font:GetFont())
            end
        end
    end
    test.check("drawn in their own parts", found, { gem = 16, empty = true, quality = 15 })
    local parts = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if element.key == "gems" or element.key == "craftingQuality" then parts[element.key] = element.retail end
    end
    test.check("offered on retail", parts, { gems = true, craftingQuality = true })
    -- The socket hint can be turned off.
    ns.setOption("socketHint", false)
    model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    test.check("the socket hint hidden", { #model.sockets, model.sockets[4].left, #model.extras, #model.effects },
        { 4, "Socket Bonus: +8 Stamina", 0, 0 })
    ns.setOption("socketHint", nil)
    -- A reagent's quality icon is larger than gear's, which keeps the line's size.
    local reagent = ns.ui.itemModel({ name = "Dazzling Thorium", quality = 3, craftingQuality = QUALITY,
        kinds = { reagent = "Crafting Reagent" } })
    panel = ns.ui.renderPreview(anchor, reagent, ITEM)
    local reagentIcon
    for _, font in ipairs(panel.pool or {}) do
        if font._shown and font._text and font._text:find("Quality:", 1, true) then
            reagentIcon = font._text:match("Tier5:(%d+):")
        end
    end
    test.check("a reagent's quality icon larger, gear's as it was", { reagentIcon, found.quality }, { "24", 15 })
    -- An active bonus keeps the game's green.
    lines[9].leftColor = GREEN
    model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
    test.check("an active bonus green", model.sockets[4].color, ns.TooltipData.colorOf(GREEN))
end
