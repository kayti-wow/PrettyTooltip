-- Details wait for their modifier, Shift by default: shown while it is held and
-- hidden otherwise, always shown with "Always Show" or in the editor's previews, and
-- never with their own setting off.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
        data = { type = 0, id = 1307, quality = 1, lines = {
            { type = 1, lineIndex = 1, leftText = "Gold Pickup Schedule" },
            { type = 2, lineIndex = 2, leftText = "Soulbound" },
        } },
        lines = { { left = { text = "Gold Pickup Schedule" } }, { left = { text = "Soulbound" } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua",
        "Integration/Native.lua", "Integration/Placement.lua" }, capture)
    local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
    local panel = ns.ui.getPanel(world.main)
    local preview = { isPreview = true }

    local function hasID()
        ns.TooltipTypes[0].render(panel, world.main, model)
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text == "Item ID: 1307" then return true end
        end
        return false
    end

    test.check("with Shift held, details show", { ns.showsDetail("disenchant"), hasID() }, { true, true })
    capture.shiftUp = true
    test.check("without it, they wait", { ns.showsDetail("disenchant"), hasID() }, { false, false })
    test.check("previews show them regardless", ns.showsDetail("disenchant", preview), true)
    test.check("Shift redraws them", { ns.isDetailsKey("LSHIFT"), ns.isDetailsKey("RSHIFT"), ns.isDetailsKey("LALT") },
        { true, true, false })
    PrettyTooltipDB = { detailsKey = "CTRL" }
    test.check("another key needs no code of its own", { ns.isDetailsKey("LCTRL"), ns.isDetailsKey("LSHIFT"),
        ns.showsDetail("disenchant") }, { true, false, false })
    PrettyTooltipDB = { detailsKey = "ALWAYS" }
    test.check("with Always, they always show", { ns.showsDetail("disenchant"), hasID() }, { true, true })
    test.check("and no key redraws them", ns.isDetailsKey("LSHIFT"), false)
    PrettyTooltipDB = { detailsKey = "ALWAYS", showIDs = false, disenchant = false }
    test.check("a detail's own setting still turns it off",
        { ns.showsDetail("disenchant"), ns.showsDetail("disenchant", preview), hasID() }, { false, false, false })
end
