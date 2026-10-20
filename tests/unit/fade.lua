-- A world unit's tooltip fading out: the panel fades in its place, the game's
-- tooltip is never hidden by the addon, and a faded panel stays shown at zero
-- alpha, holding the game's tooltip hidden, until the game hides it.
return function(test)
    local capture = { enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0 } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Integration/Native.lua" }, capture)
    local native, tooltip = ns.Native, world.main
    local panel = ns.ui.getPanel(tooltip)
    local function shownWithPanel()
        tooltip:Show()
        tooltip:SetAlpha(0)
        panel:Show()
        panel:SetAlpha(1)
        panel.nativeAlpha = 1
    end

    shownWithPanel()
    native.fadeOut(tooltip)
    test.check("the game's tooltip is not hidden by the addon", tooltip:IsShown(), true)
    test.check("the game's tooltip stays at zero", tooltip:GetAlpha(), 0)
    test.check("the panel fades", panel.fadePending, true)

    panel.fade:GetScript("OnFinished")()
    test.check("a faded panel stays shown while the game's tooltip fades", panel:IsShown(), true)

    -- The game hides its tooltip once its own fade ends; restoring follows.
    tooltip:Hide()
    native.restoreNative(tooltip)
    test.check("the faded panel goes with the game's tooltip", panel:IsShown(), false)
    test.check("the panel is ready to show again", panel:GetAlpha(), 1)
    test.check("the game's tooltip gets its alpha back", tooltip:GetAlpha(), 1)
    test.check("the fade is over", panel.fadePending, false)

    -- Its fade ending after the game's tooltip is gone, the panel hides then.
    shownWithPanel()
    native.fadeOut(tooltip)
    tooltip:Hide()
    panel.fade:GetScript("OnFinished")()
    test.check("a fade ending after the game's tooltip hides the panel", panel:IsShown(), false)
end
