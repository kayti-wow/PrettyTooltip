-- Retail greys or reds a Use or Equip effect the character will not get, as
-- one from another specialization's gear. The panel keeps it in that color,
-- its numbers and marker too, even under a color set in the editor, and the
-- game's own tooltip keeps its stat colors out of it.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 1 }
    local FILES = test.retail({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" })
    local WHITE, GREEN = { r = 1, g = 1, b = 1 }, { r = 0, g = 1, b = 0 }
    local GREY, RED = { r = .5, g = .5, b = .5 }, { r = 1, g = .125, b = .125 }
    local ACTIVE = "Equip: Your attacks have a chance to deal 300 Fire damage."
    local GREYED = "Equip: Your spells have a chance to deal 500 Frost damage."
    local REDDENED = "Use: Shield yourself for 2,000 damage for 10 sec."
    local lines = {
        { "Gauntlets of Many Paths", WHITE }, { "+200 Stamina", WHITE },
        { ACTIVE, GREEN }, { GREYED, GREY }, { REDDENED, RED },
    }
    local capture = { enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
        data = { type = ITEM, id = 3001, lines = {} }, lines = {} }
    for index, line in ipairs(lines) do
        capture.data.lines[index] = { type = index == 1 and LINE.ItemName or 0, lineIndex = index,
            leftText = line[1], leftColor = line[2] }
        capture.lines[index] = { left = { text = line[1] } }
    end
    local ns, world = test.load(FILES, capture)
    PrettyTooltipDB = {}
    local function read() return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game) end

    local model = read()
    local equip = {}
    for _, row in ipairs(model.equipEffects) do equip[#equip + 1] = { row.inactive or false, row.color } end
    test.check("an active equip effect as before, a greyed one in its grey", equip,
        { { false, nil }, { true, { .5, .5, .5 } } })
    test.check("a reddened use effect in its red", { model.effects[1].inactive, model.effects[1].color, model.effects[1].use },
        { true, { 1, .125, .125 }, true })

    -- Drawn: each in its color, even under an editor color, with no stat colors in its numbers.
    ns.setOption("styles", { equipEffects = { color = { 0, 0, 1 } }, effects = { color = { 0, 0, 1 } } })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, read(), ITEM)
    local drawn = {}
    for _, font in ipairs(panel.pool or {}) do
        local text = font._shown and font._text
        for key, wording in pairs({ active = "300 Fire", greyed = "500 Frost", reddened = "2,000 damage" }) do
            if text and text:find(wording, 1, true) then
                local r, g, b = font:GetTextColor()
                drawn[key] = { r, g, b, text:find("|c", 1, true) ~= nil }
            end
        end
        if text and text:find("stat-marker", 1, true) and text:find(":128:128:128|t", 1, true) then drawn.greyMarker = true end
        if text and text:find("marker-gear", 1, true) and text:find(":255:32:32|t", 1, true) then drawn.redMarker = true end
    end
    test.check("an editor color still colors the active effect", { drawn.active[1], drawn.active[2], drawn.active[3] },
        { 0, 0, 1 })
    test.check("the greyed effect grey, its numbers uncolored", drawn.greyed, { .5, .5, .5, false })
    test.check("the reddened effect red, its numbers uncolored", drawn.reddened, { 1, .125, .125, false })
    test.check("their markers in their colors", { drawn.greyMarker or false, drawn.redMarker or false }, { true, true })
    ns.setOption("styles", nil)

    -- The game's own tooltip (Lite wording): stat colors in an active effect's
    -- numbers, none in a greyed one's.
    local function lite(text, color)
        local wording = ns.TooltipData.itemWording({ leftText = text, leftColor = color, type = 0 })
        return wording and wording.lite or text
    end
    local PROC = "Chance on hit: Blasts the enemy for 300 Fire damage."
    test.check("lite wording colors an active effect's numbers", lite(PROC, GREEN):find("|c", 1, true) ~= nil, true)
    test.check("lite wording leaves a greyed effect in the game's grey", lite(PROC, GREY), PROC)
end
