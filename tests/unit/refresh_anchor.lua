-- Early native Show/layout changes must not move Pretty panels or need padding.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Boots" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua" }, { enums = { TooltipDataType = { Item = 0 } }, data = data,
            lines = { { left = { text = "Boots" } } } })
    local pending, paddingWrites = {}, 0
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local tooltip = world.main
    tooltip:SetSize(254, 207)
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 100)
    tooltip.SetPadding = function() paddingWrites = paddingWrites + 1 end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(_, item) return { id = item.id } end,
        render = function(panel, native, model)
            panel:SetSize(269, model.id == 1 and 303 or 160)
            panel.renderedID = model.id
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    post(tooltip, data)
    flush()
    local panel = ns.ui.panels[tooltip]
    local points = { panel:GetPoint(1) }
    local steady = true
    for _ = 1, 20 do
        tooltip:GetScript("OnTooltipCleared")(tooltip)
        tooltip:SetSize(254, 231)
        tooltip:Show()
        local current = { panel:GetPoint(1) }
        for index = 1, 5 do steady = steady and current[index] == points[index] end
        post(tooltip, data)
        tooltip:SetSize(254, 207)
        tooltip:Show()
        flush()
    end
    test.check("early shows preserve the completed Pretty anchor", steady, true)
    test.check("native refills keep the completed Pretty size", panel:GetHeight(), 303)
    test.check("native dimensions stay independent", tooltip:GetHeight(), 207)
    test.check("unchanged refills need no native padding", paddingWrites, 0)
    data.id = 2
    post(tooltip, data)
    flush()
    test.check("a completed shorter item updates Pretty", { panel.renderedID, panel:GetHeight() }, { 2, 160 })
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    data.id = 3
    tooltip:Show()
    post(tooltip, data)
    flush()
    test.check("old cleanup cannot restore a newer item", { panel.renderedID, panel:IsShown(), tooltip:GetAlpha() }, { 3, true, 0 })
    test.check("all refresh and cancellation paths avoid native padding", paddingWrites, 0)
end
