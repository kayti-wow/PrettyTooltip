-- Fading hides only our panel; the native tooltip stays off screen until
-- reuse, which must restore its anchors without overriding a fresh position.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, UnitAura = 7 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Hooks.lua", "Integration/Cursor.lua" }, fixture)
    local tooltip = world.main
    local combat = false
    InCombatLockdown = function() return combat end
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.Hooks.install()
    local callback = world.postCalls[33][1]
    GameTooltip_SetDefaultAnchor = function(frame)
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    GetCursorPosition = function() return 500, 400 end
    ns.Cursor.register()
    local follower = world.objects[#world.objects]
    ns.setOption("cursorObjects", false)
    local function show()
        GameTooltip_SetDefaultAnchor(tooltip)
        tooltip:SetClampedToScreen(true)
        tooltip:Show()
        tooltip:SetAlpha(1)
        callback(tooltip, fixture.data)
        return ns.ui.panels[tooltip]
    end
    local function anchor(frame)
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        return { point, relativeTo == UIParent, relativePoint, x, y }
    end
    local default = { "BOTTOMRIGHT", true, "BOTTOMRIGHT", -20, 30 }
    local parked = { "TOPRIGHT", true, "BOTTOMLEFT", -10000, -10000 }
    local PARKED_DRIFT = -9999.999023

    for _, inCombat in ipairs({ true, false }) do
        local label = inCombat and "in combat" or "out of combat"
        combat = inCombat
        local panel = show()
        tooltip:FadeOut()
        test.check(label .. ": only the panel disappears immediately",
            { tooltip:IsShown(), panel:IsShown() }, { true, false })
        test.check(label .. ": the native tooltip stays off screen, unclamped",
            { anchor(tooltip), tooltip:IsClampedToScreen() }, { parked, false })
        flush()
        test.check(label .. ": queued renders cannot revive the old panel", panel:IsShown(), false)
        tooltip:FadeOut()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        test.check(label .. ": reuse restores the original anchor and clamping",
            { anchor(tooltip), tooltip:IsClampedToScreen(), ns.Native.isParked(tooltip) }, { default, true, false })
        callback(tooltip, fixture.data)
        test.check(label .. ": new content shows the panel at its tooltip",
            { panel:IsShown(), select(2, panel:GetPoint(1)) == tooltip }, { true, true })
    end

    local panel = show()
    tooltip:FadeOut()
    callback(tooltip, fixture.data)
    test.check("a same-owner data handover also restores the position",
        { anchor(tooltip), tooltip:IsClampedToScreen(), panel:IsShown() }, { default, true, true })

    tooltip:FadeOut()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
    callback(tooltip, fixture.data)
    test.check("a fresh anchor from the game or another addon is preserved", anchor(tooltip),
        { "TOPLEFT", true, "TOPLEFT", 40, -60 })

    show()
    tooltip:SetClampedToScreen(false)
    tooltip:FadeOut()
    callback(tooltip, fixture.data)
    test.check("reuse preserves an originally unclamped tooltip",
        { anchor(tooltip), tooltip:IsClampedToScreen() }, { default, false })

    show()
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    local points = ns.util.framePoints(tooltip)
    tooltip:FadeOut()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    test.check("all saved anchor points are restored", ns.util.framePoints(tooltip), points)

    show()
    tooltip:FadeOut()
    tooltip._points[1][4], tooltip._points[1][5] = PARKED_DRIFT, PARKED_DRIFT
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    test.check("reuse restores the anchor when the parked offsets read back slightly off",
        { anchor(tooltip), tooltip:GetNumPoints(), ns.Native.isParked(tooltip) }, { default, 1, false })

    -- The game re-anchors a shown tooltip without clearing its points first.
    show()
    tooltip:FadeOut()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    callback(tooltip, fixture.data)
    test.check("a game anchor added beside the parked one replaces it",
        { anchor(tooltip), tooltip:GetNumPoints(), tooltip:IsClampedToScreen() }, { default, 1, true })

    show()
    tooltip:FadeOut()
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    flush()
    test.check("the game's own hide releases the parked position",
        { anchor(tooltip), tooltip:IsClampedToScreen(), panel:IsShown() }, { default, true, false })

    show()
    local getPoint = tooltip.GetPoint
    tooltip.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", world.secret, 0 end
    tooltip:FadeOut()
    tooltip.GetPoint = getPoint
    test.check("unreadable anchors are not parked, and the panel still disappears",
        { anchor(tooltip), ns.Native.isParked(tooltip), panel:IsShown() }, { default, false, false })

    -- Follow cursor must save the actual default anchor before parking, and
    -- resume on a same-owner handover even after a clear or combat transition.
    ns.setOption("cursorObjects", true)
    ns.setOption("cursorDisableInCombat", true)
    combat = false
    show()
    test.check("the integrated tooltip starts following",
        { select(2, tooltip:GetPoint(1)) == follower, follower:IsShown() }, { true, true })
    tooltip:FadeOut()
    test.check("fading hides the panel and stops following",
        { panel:IsShown(), follower:IsShown(), anchor(tooltip) }, { false, false, parked })
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    flush()
    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    combat = false
    world.fireEvent("PLAYER_REGEN_ENABLED")
    test.check("clearing and combat transitions leave the old tooltip parked",
        { panel:IsShown(), follower:IsShown(), anchor(tooltip) }, { false, false, parked })
    callback(tooltip, fixture.data)
    test.check("same-owner content resumes following",
        { panel:IsShown(), follower:IsShown(), select(2, tooltip:GetPoint(1)) == follower }, { true, true, true })
    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    test.check("combat still restores the real default anchor after reuse",
        { anchor(tooltip), tooltip:IsClampedToScreen() }, { default, true })
end
