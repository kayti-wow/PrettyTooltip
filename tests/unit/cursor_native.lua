-- A tooltip that follows the cursor without a panel, as the game's own: it is
-- placed by its bottom, so a height the game hides (a secret value) still lets
-- it follow.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Integration/Cursor.lua" },
        { enums = { TooltipDataType = { Object = 1 } } })
    InCombatLockdown = function() return false end
    GetCursorPosition = function() return 100, 200 end
    GameTooltip_SetDefaultAnchor = function(tooltip)
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    local panel
    ns.ui = { shownPanel = function() return panel end, alignPanel = function() end }
    ns.Cursor.register()
    local follower = world.objects[#world.objects]
    local function point()
        local anchor, relativeTo, relativePoint, x, y = GameTooltip:GetPoint()
        return { anchor, relativeTo == follower, relativePoint, x, y }
    end

    GameTooltip.GetHeight = function() return world.secret end
    GameTooltip_SetDefaultAnchor(GameTooltip)
    for _, callback in ipairs(world.postCalls[1]) do callback(GameTooltip) end
    test.check("a secret height still follows", follower:IsShown(), true)
    test.check("placed by its bottom, above and right of the cursor", point(),
        { "BOTTOMLEFT", true, "BOTTOMLEFT", 16, 16 })

    -- A panel shown over it hangs the tooltip by its top again.
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetHeight(80)
    follower:GetScript("OnUpdate")(follower)
    test.check("with a panel, placed by its top", point(), { "TOPLEFT", true, "BOTTOMLEFT", 16, 96 })
    panel = nil
    follower:GetScript("OnUpdate")(follower)
    test.check("and by its bottom once the panel goes", point(), { "BOTTOMLEFT", true, "BOTTOMLEFT", 16, 16 })
end
