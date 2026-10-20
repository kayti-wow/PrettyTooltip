-- Drive tooltip handovers and combat events, including an already-open panel.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "UI/Options.lua", "Integration/Cursor.lua" },
        { enums = { TooltipDataType = { Object = 1, Spell = 2, Unit = 3 } } })
    local combat, clamped = false, true
    InCombatLockdown = function() return combat end
    local cursorX, cursorY = 100, 200
    GetCursorPosition = function() return cursorX, cursorY end
    GameTooltip.IsClampedToScreen = function() return clamped end
    GameTooltip.SetClampedToScreen = function(_, value) clamped = value end
    GameTooltip_SetDefaultAnchor = function(tooltip)
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetHeight(80)
    local alignments = 0
    ns.ui = {
        shownPanel = function() return panel end,
        alignPanel = function() alignments = alignments + 1 end,
    }
    -- The game fades a world unit's tooltip with a method of its own.
    GameTooltip.FadeOut = function() end
    ns.Cursor.register()
    local follower = world.objects[#world.objects]
    local function point()
        local anchor, _, relativePoint, x, y = GameTooltip:GetPoint()
        return { anchor, relativePoint, x, y }
    end
    local function handover(dataType)
        for _, callback in ipairs(world.postCalls[dataType]) do callback(GameTooltip) end
    end
    local function beginCombat()
        combat = true
        world.fireEvent("PLAYER_REGEN_DISABLED")
    end
    local function endCombat()
        combat = false
        world.fireEvent("PLAYER_REGEN_ENABLED")
    end
    local default = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 30 }
    -- Following, the tooltip hangs from the tracker, the panel's height (80) and
    -- 16 more above it, and the tracker sits at the cursor.
    local cursor = { "TOPLEFT", "BOTTOMLEFT", 16, 96 }
    GameTooltip_SetDefaultAnchor(GameTooltip)
    handover(1)
    test.check("objects follow the cursor outside combat", point(), cursor)
    test.check("the tooltip hangs from the tracker, which sits at the cursor", {
        select(2, GameTooltip:GetPoint()) == follower, { follower:GetPoint() } },
        { true, { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 200 } })
    local setPoint, anchorings = GameTooltip.SetPoint, 0
    GameTooltip.SetPoint = function(...) anchorings = anchorings + 1 return setPoint(...) end
    cursorX, cursorY = 140, 260
    follower:GetScript("OnUpdate")(follower)
    test.check("moving the cursor moves the tracker, not the tooltip",
        { anchorings, ({ follower:GetPoint() })[4], ({ follower:GetPoint() })[5] }, { 0, 140, 260 })
    panel:SetHeight(120)
    follower:GetScript("OnUpdate")(follower)
    test.check("a taller panel anchors the tooltip again", { anchorings, point() },
        { 1, { "TOPLEFT", "BOTTOMLEFT", 16, 136 } })
    GameTooltip.SetPoint = setPoint
    panel:SetHeight(80)
    cursorX, cursorY = 100, 200
    follower:GetScript("OnUpdate")(follower)
    test.check("following a panel temporarily disables native clamping", clamped, false)
    beginCombat()
    test.check("the default setting disables following during combat", follower:IsShown(), false)
    test.check("the default setting restores the original anchor during combat", point(), default)
    endCombat()
    test.check("the default setting resumes following after combat", follower:IsShown(), true)
    ns.setOption("cursorDisableInCombat", false)
    beginCombat()
    test.check("a saved false preserves following during combat", follower:IsShown(), true)
    endCombat()

    ns.setOption("cursorDisableInCombat", true)
    local before = alignments
    beginCombat()
    test.check("combat restores the original anchor of an open tooltip", point(), default)
    test.check("combat stops cursor updates", follower:IsShown(), false)
    test.check("combat restores native clamping", clamped, true)
    test.check("the replacement panel is realigned after restoring its anchor", alignments, before + 1)
    test.check("combat does not change the per-type cursor preference", ns.option("cursorObjects"), true)
    handover(1)
    test.check("tooltip refreshes in combat keep the default position", point(), default)
    endCombat()
    test.check("an open tooltip resumes following when combat ends", point(), cursor)
    test.check("following resumes without reopening the tooltip", follower:IsShown(), true)

    -- A same-owner refresh can clear content without resetting its anchor.
    GameTooltip:GetScript("OnTooltipCleared")(GameTooltip)
    handover(1)
    beginCombat()
    test.check("a same-owner content refresh retains the real default anchor", point(), default)
    endCombat()
    GameTooltip:GetScript("OnTooltipCleared")(GameTooltip)
    handover(2)
    test.check("switching content to a type with following off restores its anchor", point(), default)
    handover(1)

    -- Combat state can change before this frame receives its combat event.
    combat = true
    GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    test.check("the SetPoint hook also checks combat before moving to the cursor", point(), default)
    test.check("the SetPoint hook suspends following before the combat event", follower:IsShown(), false)
    endCombat()

    beginCombat()
    GameTooltip_SetDefaultAnchor(GameTooltip)
    handover(1)
    test.check("new tooltips opened in combat use their default anchor", point(), default)
    endCombat()
    test.check("tooltips opened in combat follow when combat ends", point(), cursor)
    beginCombat()
    ns.setOption("cursorObjects", false)
    endCombat()
    test.check("a disabled per-type preference does not resume", point(), default)
    ns.setOption("cursorObjects", true)

    -- A tooltip placed beside a bag or other owner is never cursor-anchored.
    GameTooltip:SetOwner(panel, "ANCHOR_RIGHT")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("LEFT", panel, "RIGHT", 5, 0)
    handover(1)
    beginCombat()
    endCombat()
    test.check("combat transitions leave owner-anchored tooltips alone", point(), { "LEFT", "RIGHT", 5, 0 })
    test.check("owner-anchored tooltips never start following", follower:IsShown(), false)

    GameTooltip_SetDefaultAnchor(GameTooltip)
    handover(2)
    beginCombat()
    endCombat()
    test.check("types with follow cursor off stay at the default anchor", point(), default)
    ns.setOption("cursorUnits", true)
    handover(3)
    beginCombat()
    test.check("the combat override also applies to units", point(), default)
    endCombat()
    test.check("units resume following after combat", point(), cursor)
    GameTooltip:GetScript("OnTooltipCleared")()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 10)
    beginCombat()
    endCombat()
    test.check("cleared tooltip content is not resumed", point(), { "BOTTOM", "BOTTOM", 0, 10 })

    -- Post-calls can arrive before Show; the first update still follows.
    GameTooltip:Hide()
    GameTooltip_SetDefaultAnchor(GameTooltip)
    handover(1)
    test.check("a handover before Show still places the tooltip", point(), cursor)
    GameTooltip:Show()
    beginCombat()
    test.check("the pre-Show handover retained the original anchor", point(), default)
    GameTooltip:GetScript("OnHide")()
    GameTooltip:Hide()
    endCombat()
    test.check("hidden tooltips do not resume after combat", follower:IsShown(), false)

    -- The main options control saves the setting and participates in Defaults.
    local page
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas) page = canvas return {} end,
        RegisterAddOnCategory = function() end,
    }
    ns.Options.register()
    local combatBox
    for _, child in ipairs({ page:GetChildren() }) do
        if child:GetObjectType() == "CheckButton" then
            for _, label in ipairs({ child:GetRegions() }) do
                if label:GetText() == "Disable in combat" then combatBox = child end
            end
        end
    end
    test.check("main options reflects the saved combat setting", combatBox:GetChecked(), true)
    combatBox:SetChecked(false)
    combatBox:GetScript("OnClick")(combatBox)
    test.check("unchecking the control saves false", ns.option("cursorDisableInCombat"), false)
    combatBox:SetChecked(true)
    combatBox:GetScript("OnClick")(combatBox)
    test.check("checking the control saves true", ns.option("cursorDisableInCombat"), true)
    page.OnDefault()
    test.check("Defaults restores the combat override", ns.option("cursorDisableInCombat"), true)
    test.check("Defaults refreshes the checkbox", combatBox:GetChecked(), true)

    -- A following tooltip that starts fading is left to the game's fade and
    -- keeps following: hiding it would run its OnHide under the addon's taint.
    local hide, hides = GameTooltip.Hide, 0
    GameTooltip.Hide = function(self) hides = hides + 1 return hide(self) end
    ns.setOption("cursorDisableInCombat", false)
    GameTooltip:Show()
    GameTooltip_SetDefaultAnchor(GameTooltip)
    handover(1)
    combat = true
    GameTooltip:FadeOut()
    test.check("in combat a fading tooltip is not hidden by the addon", { hides, follower:IsShown() }, { 0, true })
    combat = false
    handover(1)
    GameTooltip:FadeOut()
    test.check("outside combat a fading tooltip is not hidden either", { hides, follower:IsShown() }, { 0, true })
    GameTooltip.Hide = hide
end
