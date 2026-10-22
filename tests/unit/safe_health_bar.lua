-- Borrow the native bar without reading its health, and leave restricted
-- bars alone. If access changes, retain the loan until it can be returned.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua", "Integration/Native.lua", "Integration/Placement.lua" },
        { enums = { TooltipDataType = { Item = 0, Unit = 2 } } })
    local native = CreateFrame("StatusBar", nil, GameTooltip)
    native:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 4, -5)
    native:SetHeight(9)
    GameTooltipStatusBar = native
    local reads = 0
    native.GetValue = function() reads = reads + 1 error("health is secret") end
    UnitHealth = native.GetValue
    UnitHealthMax = native.GetValue
    local panel = ns.ui.getPanel(GameTooltip)
    local model = ns.ui.unitModel({ name = "Guard", level = 20 })
    local render = ns.TooltipTypes[2].render
    render(panel, GameTooltip, model)
    test.check("the native bar is borrowed", native:GetParent() == panel, true)
    test.check("health values were never read", reads, 0)
    test.check("hook bookkeeping stays off the Blizzard bar", rawget(native, "prettyTooltipHooked"), nil)
    panel.release(panel)
    test.check("the bar's native parent is restored", native:GetParent() == GameTooltip, true)
    test.check("the bar's native height is restored", native:GetHeight(), 9)
    test.check("the bar's native anchor is restored", { ({ native:GetPoint() })[1], ({ native:GetPoint() })[5] },
        { "BOTTOMLEFT", -5 })

    native.IsProtected = function() return true end
    render(panel, GameTooltip, model)
    test.check("protected health bars stay with the native tooltip", native:GetParent() == GameTooltip, true)
    native.IsProtected = function() return false end
    native.IsForbidden = function() return true end
    render(panel, GameTooltip, model)
    test.check("forbidden health bars stay with the native tooltip", native:GetParent() == GameTooltip, true)
    native.IsForbidden = function() return false end
    render(panel, GameTooltip, model)
    native.IsProtected = function() return true end
    panel.release(panel)
    test.check("a newly restricted loan does not attempt reparenting", native:GetParent() == panel, true)
    native.IsProtected = function() return false end
    world.fireEvent("PLAYER_REGEN_ENABLED")
    test.check("a pending loan is returned once access is restored", native:GetParent() == GameTooltip, true)
    test.check("health was never read during cleanup", reads, 0)
end
