-- EllesmereUI's Show Tooltips setting moves a shown GameTooltip into a hidden
-- frame instead of hiding it. The panel goes out of sight with it, keeps its
-- state for the modifier that brings the tooltip back, and stays out of sight
-- when content arrives while the tooltip is in that frame.
return function(test)
    local fixture = { enums = { TooltipDataType = { Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua" }, fixture)
    local tooltip = world.main
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.Hooks.install()
    local callback = world.postCalls[33][1]
    local hiddenHost = CreateFrame("Frame", nil, UIParent)
    hiddenHost:Hide()
    -- The game runs OnShow and OnHide when a new parent changes what is in sight.
    local function reparent(parent)
        local before = tooltip:IsVisible()
        tooltip:SetParent(parent)
        local after = tooltip:IsVisible()
        if before and not after then tooltip:GetScript("OnHide")(tooltip) end
        if after and not before then tooltip:GetScript("OnShow")(tooltip) end
    end

    tooltip:SetAlpha(1)
    callback(tooltip, fixture.data)
    tooltip:Show()
    flush()
    local panel = ns.ui.panels[tooltip]
    test.check("with its tooltip in sight the panel is too", { panel:IsShown(), panel:IsVisible() }, { true, true })

    -- Combat starting while the tooltip is up.
    reparent(hiddenHost)
    flush()
    test.check("a hidden parent takes the panel out of sight, its state kept",
        { panel:IsShown(), panel:IsVisible(), tooltip:GetAlpha() }, { true, false, 0 })

    -- EllesmereUI's modifier, held.
    reparent(UIParent)
    test.check("the panel comes back with its tooltip", { panel:IsVisible(), tooltip:GetAlpha() }, { true, 0 })

    -- A hover in combat: the tooltip is moved at SetOwner, before its content.
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    flush()
    test.check("the game's own hide still hides the panel", panel:IsShown(), false)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    reparent(hiddenHost)
    callback(tooltip, fixture.data)
    tooltip:Show()
    flush()
    test.check("content drawn while the parent is hidden stays out of sight",
        { panel:IsShown(), panel:IsVisible() }, { true, false })
    reparent(UIParent)
    test.check("and shows when the tooltip returns", panel:IsVisible(), true)

    -- A unit panel holds on to the game's health bar while out of sight.
    ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua", "Integration/Native.lua", "Integration/Placement.lua" },
        { enums = { TooltipDataType = { Item = 0, Unit = 2 } } })
    local bar = CreateFrame("StatusBar", nil, GameTooltip)
    bar:SetHeight(9)
    GameTooltipStatusBar = bar
    local unitPanel = ns.ui.getPanel(GameTooltip)
    ns.TooltipTypes[2].render(unitPanel, GameTooltip, ns.ui.unitModel({ name = "Guard", level = 20 }))
    unitPanel.host:Hide()
    unitPanel:GetScript("OnHide")(unitPanel)
    test.check("a unit panel out of sight keeps the health bar", bar:GetParent() == unitPanel, true)
    unitPanel:Hide()
    unitPanel:GetScript("OnHide")(unitPanel)
    test.check("hiding the panel returns it", bar:GetParent() == GameTooltip, true)
end
