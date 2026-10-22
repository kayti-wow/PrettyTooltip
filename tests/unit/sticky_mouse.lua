-- DungeonJournal creates a button over its appended native tooltip line.
-- Alpha zero hides the line, but the button must stop receiving mouse input.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Ring" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, tooltip = "ItemRefTooltip", data = data,
        lines = { { left = { text = "Ring" } } },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function() return {} end,
        render = function(panel, tooltip)
            ns.ui.drawChrome(panel, tooltip, { tooltipType = "item", color = { 1, 1, 1 } })
            panel:SetSize(200, 300)
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    local tooltip = world.main
    tooltip:SetSize(200, 200)
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    tooltip:EnableMouse(true)
    tooltip.GetPadding = function() return 0, 0, 0, 0 end
    tooltip.SetPadding = function() end
    local close = CreateFrame("Button", "ItemRefCloseButton", tooltip)
    local closed = 0
    close.Click = function(self)
        if not self:IsMouseEnabled() then return end
        closed = closed + 1
        tooltip:Hide()
        tooltip:GetScript("OnHide")(tooltip)
    end
    local disabled = CreateFrame("Button", nil, tooltip)
    disabled:EnableMouse(false)
    local protected = CreateFrame("Button", nil, tooltip)
    protected.IsProtected = function() return true end
    local forbidden = CreateFrame("Button", nil, tooltip)
    forbidden.IsForbidden = function() return true end
    local secret = CreateFrame("Button", nil, tooltip)
    secret.IsMouseEnabled = function() return world.secret end
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    post(tooltip, data)
    -- Another addon's item post-call runs after Pretty's and adds the button.
    local clicker = CreateFrame("Button", nil, tooltip)
    clicker.itemID = 1
    clicker:SetPoint("TOPLEFT", tooltip:GetLeftLine(1), "TOPLEFT", -2, 2)
    local opened = 0
    clicker:SetScript("OnClick", function() opened = opened + 1 end)
    tooltip:Show()
    flush()
    test.check("a native source-line button added after the panel render cannot steal mouse focus",
        clicker:IsMouseEnabled(), false)
    test.check("the sticky tooltip still receives mouse motion for comparisons and dragging",
        tooltip:IsMouseEnabled(), true)
    test.check("protected, forbidden and unreadable native controls are left alone",
        { protected:IsMouseEnabled(), forbidden:IsMouseEnabled(), secret._mouseEnabled == nil }, { true, true, true })
    for _ = 1, 10 do post(tooltip, data); tooltip:Show(); flush() end
    test.check("repeated refreshes keep the native clicker disabled", clicker:IsMouseEnabled(), false)
    test.check("the native close button remains available to the visible Pretty X", close:IsMouseEnabled(), true)
    local panel = ns.ui.panels[tooltip]
    panel.close:GetScript("OnClick")(panel.close)
    test.check("clicking the Pretty X closes the sticky tooltip through its native close button",
        { closed, tooltip:IsShown(), panel:IsShown() }, { 1, false, false })
    flush()
    tooltip:Show()
    post(tooltip, data)
    flush()
    test.check("reopening keeps the hidden source strip disabled", clicker:IsMouseEnabled(), false)
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("the original-tooltip modifier restores visible native controls",
        { tooltip:GetAlpha(), clicker:IsMouseEnabled(), disabled:IsMouseEnabled() }, { 1, true, false })
    clicker:GetScript("OnClick")(clicker)
    test.check("the journal click action is preserved for the original tooltip", opened, 1)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("returning to Pretty disables the invisible button again", clicker:IsMouseEnabled(), false)
    ns.TooltipTypes[0].read = function() error("unreadable item") end
    post(tooltip, { type = 0, id = 2, lines = data.lines })
    test.check("native fallback restores the clicker's mouse input", clicker:IsMouseEnabled(), true)
    ns.TooltipTypes[0].read = function() return {} end
    post(tooltip, data)
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    flush()
    test.check("closing the sticky tooltip restores child mouse state for reuse", clicker:IsMouseEnabled(), true)
    tooltip:Show()
    post(tooltip, data)
    ns.setOption("itemPanels", false)
    post(tooltip, data)
    test.check("turning restyling off restores the native clicker", clicker:IsMouseEnabled(), true)
end
