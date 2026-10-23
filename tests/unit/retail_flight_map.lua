-- Retail's flight map pins fill GameTooltip themselves, without the classic
-- map's TaxiNodeOnButtonEnter; the panel is drawn when a pin shows it. The
-- lines are the captures retail-flight1 and retail-flight2's. Forever, and
-- tooltips other frames own, are left alone.
return function(test)
    local function files(retail)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/FlightPath.lua", "Integration/Native.lua",
            "Integration/Placement.lua", "Integration/Hooks.lua" }
        if retail then list = test.retail(list) end
        return list
    end
    local WHITE, GOLD = { 1, 1, 1 }, { 1, .82, 0 }
    local function capture(name, second)
        return { enums = { TooltipDataType = { Item = 0 } }, lines = {
            { left = { text = name, color = GOLD } },
            { left = { text = second, color = WHITE } },
        } }
    end
    local COST = "2|A:coin-gold:14:14:2:0|a 40|A:coin-silver:14:14:2:0|a"

    local function hover(retail, fixture, makeOwner)
        local ns, world = test.load(files(retail), fixture)
        C_Timer.After = function(_, callback) callback() end
        local tooltip = world.main
        local owner = makeOwner()
        tooltip.GetOwner = function() return owner end
        tooltip.GetTooltipData = function() return nil end
        ns.Hooks.install()
        tooltip:Show()
        local panel = ns.ui.shownPanel(tooltip)
        local shown = {}
        for _, font in ipairs(panel and panel.pool or {}) do
            if font._shown and font._text and font._text ~= "" then shown[#shown + 1] = ns.util.plainText(font._text) end
        end
        return shown, panel and panel.dataType
    end
    local function pin()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame.taxiNodeData = { name = "Shadebasin Watch, Zul'Aman", slotIndex = 71, state = 1 }
        return frame
    end

    local shown, dataType = hover(true, capture("Shadebasin Watch, Zul'Aman", COST), pin)
    test.check("a pin's destination", { shown, dataType }, { { "SHADEBASIN WATCH", "Zul'Aman", "Cost", "2 40" }, "taxi" })
    shown = hover(true, capture("Sanctum of Light, Silvermoon City", "You are here"), pin)
    test.check("the pin where you are", shown, { "SANCTUM OF LIGHT", "Silvermoon City · You are here" })

    -- A tooltip another frame owns is not a flight node's.
    local function stranger() return CreateFrame("Frame", nil, UIParent) end
    shown = hover(true, capture("Shadebasin Watch, Zul'Aman", COST), stranger)
    test.check("not for other owners", shown, {})
    -- Forever's flight map goes through TaxiNodeOnButtonEnter alone.
    shown = hover(false, capture("Shadebasin Watch, Zul'Aman", COST), pin)
    test.check("Forever draws no pin's tooltip", shown, {})
end
