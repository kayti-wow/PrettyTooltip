-- Other addons separate their sections with blank lines. A panel keeps one as
-- an empty line between two rows, but never first, last, or two together.
return function(test)
    local OBJECT = 4
    local appended = { "", "Addon A: first", "Addon A: second", "", " ", "|cffffffff|r", "Addon B", "", "" }
    local capture = { enums = { TooltipDataType = { Item = 0, Object = OBJECT }, TooltipDataLineType = { None = 0 } },
        data = { type = OBJECT, lines = { { type = 0, lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    for _, text in ipairs(appended) do capture.lines[#capture.lines + 1] = { left = { text = text } } end
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" }, capture)

    local model = ns.TooltipTypes[OBJECT].read(world.main, capture.data, ns.Game)
    local shown = {}
    for _, row in ipairs(model.extras) do shown[#shown + 1] = row.blank and "(gap)" or row.left end
    test.check("blank lines become one gap between sections", shown,
        { "Addon A: first", "Addon A: second", "(gap)", "Addon B" })

    -- The gap is one empty line of the extras' style.
    local anchor = CreateFrame("Frame", nil, UIParent)
    local withGap = ns.ui.renderPreview(anchor, model, OBJECT):GetHeight()
    table.remove(model.extras, 3)
    local without = ns.ui.renderPreview(anchor, model, OBJECT):GetHeight()
    local size = ns.ui.styleOf("extras").size
    test.check("a gap is one line high", withGap - without, math.floor(size * 1.15 + .5) + 2)

    local only = {}
    ns.TooltipData.addExtras(only, { { left = "", right = "" }, { left = " ", right = "" } })
    test.check("blank lines alone add nothing", #only, 0)
    local after = { { left = "The game's own row", right = "" } }
    ns.TooltipData.addExtras(after, { { left = "", right = "" }, { left = "Addon row", right = "" } })
    test.check("a gap after the game's own rows", after[2].blank, true)
    local right = {}
    ns.TooltipData.addExtras(right, { { left = "", right = "5g" } })
    test.check("a row with only right-hand text is not blank", right[1].right, "5g")
end
