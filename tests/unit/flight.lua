-- Flight map nodes, as /ptip capture saw them: the name and zone, then the
-- cost in coins or "You are here". The flight map's hook draws the panel.
return function(test)
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/FlightPath.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua" }
    local WHITE, GOLD = { 1, 1, 1 }, { 1, .82, 0 }
    local function capture(second)
        return { enums = { TooltipDataType = { Item = 0 } }, lines = {
            { left = { text = "Astranaar, Ashenvale", color = GOLD } },
            { left = { text = second, color = WHITE } },
        } }
    end
    local cost = "2|A:coin-silver:14:14:2:0|a 97|A:coin-copper:14:14:2:0|a"

    local ns, world = test.load(FILES, capture(cost))
    local taxi = ns.TooltipTypes.taxi
    local model = taxi.read(world.main)
    test.check("a destination", { model.name, model.zone, model.cost, model.current or false },
        { "Astranaar", "Ashenvale", 297, false })

    -- Drawn when the flight map, loaded on demand, fills the tooltip.
    C_Timer.After = function(_, callback) callback() end
    TaxiNodeOnButtonEnter = function() end
    world.fireEvent("ADDON_LOADED", "Blizzard_TaxiUI")
    TaxiNodeOnButtonEnter()
    local panel = ns.ui.shownPanel(world.main)
    local shown = {}
    for _, font in ipairs(panel and panel.pool or {}) do
        if font._shown and font._text and font._text ~= "" then shown[#shown + 1] = ns.util.plainText(font._text) end
    end
    test.check("the hook draws the panel", shown, { "ASTRANAAR", "Ashenvale", "Cost", "2 97" })

    ns, world = test.load(FILES, capture("You are here"))
    model = ns.TooltipTypes.taxi.read(world.main)
    test.check("where you are", { model.name, model.cost or false, model.current }, { "Astranaar", false, true })
end
