-- Auction price rows rebuild GameTooltip every .2 s. Auction details are
-- appended after the item post-call, so bottom-anchored panels must finish
-- growing before SetAuctionHouseTooltip returns, rather than next frame.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Ring" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = data,
        lines = { { left = { text = "Ring" } } },
        comparisons = {
            { data = data, lines = { { left = { text = "Equipped ring" } } } },
            { data = data, lines = { { left = { text = "Other equipped ring" } } } },
        },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local tooltip = world.main
    local primary, secondary = ShoppingTooltip1, ShoppingTooltip2
    tooltip.shoppingTooltips = { primary, secondary }
    local row = CreateFrame("Frame", "AuctionPriceRow", UIParent)
    row:SetSize(590, 20)
    row.GetLeft, row.GetTop = function() return 210 end, function() return 700 end
    local currentOwner, extraRows, title = row, 3, "Ring"
    tooltip.GetOwner = function() return currentOwner end
    tooltip.SetOwner = function(self, owner)
        currentOwner = owner
        local clear = self:GetScript("OnTooltipCleared")
        if clear then clear(self) end
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    end
    local function hide()
        for _, native in ipairs({ tooltip, primary, secondary }) do
            native:Hide()
            local onHide = native:GetScript("OnHide")
            if onHide then onHide(native) end
        end
    end
    local reads, renders, partialReads, nativeSuppressed = 0, 0, 0, true
    local totalReads, totalRenders = 0, 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(native, item)
            totalReads = totalReads + 1
            if native == tooltip then reads = reads + 1 end
            return { rows = native:NumLines(), id = item.id }
        end,
        render = function(panel, native, model)
            totalRenders = totalRenders + 1
            if native == tooltip then renders = renders + 1 end
            panel:SetSize(260, model.rows * 40)
            panel.GetLeft = function() return 800 end
            panel.GetTop = function(self) return 700 + self:GetHeight() end
            panel.renderedID = model.id
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    TooltipComparisonManager = {
        tooltip = tooltip,
        SetItemTooltip = function(_, isPrimary)
            local comparison = isPrimary and primary or secondary
            comparison._lines, comparison._left, comparison._right = {}, {}, {}
            local clear = comparison:GetScript("OnTooltipCleared")
            if clear then clear(comparison) end
            comparison:AddLine("Equipped ring", 1, 1, 1)
            local item = { type = 0, id = isPrimary and 100 or 101, lines = data.lines }
            comparison._data = item
            world.postCalls[0][1](comparison, item)
            comparison:Show()
            comparison:AddLine("Comparison delta", 1, 1, 1)
        end,
        AnchorShoppingTooltips = function()
            primary:SetShown(true)
            secondary:SetShown(true)
            primary:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", 0, 0)
            secondary:SetPoint("TOPRIGHT", primary, "TOPLEFT", 0, 0)
        end,
    }
    -- The auction UI loads on demand, after our startup.
    ns.Hooks.install()
    AuctionHouseItemListLineMixin = { GetRowData = function(self) return self.rowData end }
    row.GetRowData = AuctionHouseItemListLineMixin.GetRowData
    row.rowData = { itemLink = "item:1" }
    AuctionHouseUtil = {
        SetAuctionHouseTooltip = function(owner)
            hide()
            tooltip:SetOwner(owner, "ANCHOR_RIGHT")
            tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
            tooltip:AddLine(title, 1, 1, 1)
            tooltip._data = data
            tooltip:Show() -- PTR feedback can show it before the item post-call.
            TooltipComparisonManager:SetItemTooltip(true)
            TooltipComparisonManager:SetItemTooltip(false)
            TooltipComparisonManager:AnchorShoppingTooltips()
            local beforeRead = reads
            world.postCalls[0][1](tooltip, data)
            tooltip:Show() -- TooltipDataHandler has finished the base item.
            partialReads = partialReads + reads - beforeRead
            if owner == row and ns.restyles("itemPanels") then
                nativeSuppressed = nativeSuppressed and tooltip:GetAlpha() == 0
            end
            for index = 1, extraRows do tooltip:AddLine("Auction detail " .. index, 1, 1, 1) end
            tooltip:Show() -- AuctionHouseUtil's completed tooltip.
        end,
    }
    world.fireEvent("ADDON_LOADED", "Blizzard_AuctionHouseUI")
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    local panel = ns.ui.panels[tooltip]
    test.check("the first auction is read and rendered only once", { reads, renders, partialReads }, { 1, 1, 0 })
    test.check("one main tooltip and two completed comparisons need three renders", { totalReads, totalRenders }, { 3, 3 })
    test.check("the deferred native tooltip stays invisible", nativeSuppressed, true)
    test.check("the auction completion callback includes appended rows immediately", panel:GetHeight(), 160)
    test.check("the completed auction keeps its bottom anchor on the price row",
        { (select(1, panel:GetPoint(1))), select(2, panel:GetPoint(1)) == row }, { "BOTTOMLEFT", true })
    local before = reads
    flush()
    test.check("the fallback does not rerender a completed auction", reads, before)
    local stable = panel:GetTop()
    local steady = true
    for _ = 1, 25 do
        AuctionHouseUtil.SetAuctionHouseTooltip(row)
        local top = panel:GetTop()
        flush()
        steady = steady and top == stable and panel:GetTop() == top
    end
    test.check("25 repeated auction fills each need one completed read and render", { reads, renders }, { 26, 26 })
    test.check("25 refills with comparisons have no partial render overhead", { totalReads, totalRenders }, { 78, 78 })
    test.check("repeated auction fills never move the top on the following frame", steady, true)
    extraRows = 1
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    test.check("a shorter completed auction takes effect before the callback returns", panel:GetHeight(), 80)
    before = reads
    flush()
    test.check("a shorter auction needs no next-frame redraw", reads, before)
    data.id, title = 2, "Other ring"
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    test.check("a changed auction item still renders its own final content", { panel.renderedID, panel:GetHeight() }, { 2, 80 })
    flush()
    extraRows = 0
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    test.check("removing auction details also completes synchronously", panel:GetHeight(), 40)
    flush()
    ns.setOption("itemPanels", false)
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    test.check("the auction completion hook respects native-only presentation", { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
    flush()
    ns.setOption("itemPanels", true)
    extraRows = 2
    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    test.check("Pretty can resume with the current auction details", { panel:IsShown(), panel:GetHeight() }, { true, 120 })
    flush()
    -- Icon buttons have their own fill rather than the list-row producer.
    local icon = CreateFrame("Button", "AuctionItemIcon", row)
    hide()
    tooltip:SetOwner(icon, "ANCHOR_RIGHT")
    local beforeRender = renders
    world.postCalls[0][1](tooltip, data)
    test.check("an auction icon keeps its immediate render", renders - beforeRender, 1)
    flush()

    -- Cached/direct callers can fill a list row without the hooked producer.
    -- The existing fallback must finish those, and stale work must not revive
    -- a hidden tooltip or replace a newer icon fill.
    local function directFill(owner, item)
        hide()
        tooltip:SetOwner(owner, "ANCHOR_RIGHT")
        tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
        tooltip:AddLine("Direct item", 1, 1, 1)
        tooltip._data = item
        world.postCalls[0][1](tooltip, item)
        tooltip:Show()
    end
    before = reads
    directFill(row, data)
    tooltip:AddLine("Appended by a direct caller", 1, 1, 1)
    test.check("a direct auction fill also avoids a partial read", reads, before)
    flush()
    test.check("the fallback completes a direct auction fill once",
        { reads - before, panel:GetHeight(), panel.contentPending }, { 1, 80, nil })

    before = reads
    directFill(row, data)
    hide()
    flush()
    test.check("a cancelled deferred fill cannot render or revive the panel",
        { reads - before, panel:IsShown(), panel.contentPending }, { 0, false, nil })

    directFill(row, data)
    local iconData = { type = 0, id = 3, lines = data.lines }
    directFill(icon, iconData)
    before = reads
    flush()
    test.check("a newer icon fill replaces pending auction work immediately",
        { panel.renderedID, reads - before, panel.contentPending }, { 3, 0, nil })

    AuctionHouseUtil.SetAuctionHouseTooltip(row)
    before = reads
    tooltip:AddLine("Appended after the producer returned", 1, 1, 1)
    flush()
    test.check("later addon rows still trigger the existing fallback check",
        { reads - before, panel:GetHeight() }, { 1, 160 })

    local otherRow = CreateFrame("Frame", "OtherAuctionPriceRow", UIParent)
    otherRow:SetSize(590, 20)
    otherRow.GetRowData = AuctionHouseItemListLineMixin.GetRowData
    tooltip:SetOwner(otherRow, "ANCHOR_RIGHT")
    before = reads
    world.postCalls[0][1](tooltip, data)
    tooltip:Show()
    flush()
    test.check("unchanged deferred content still follows a new row without rerendering",
        { reads - before, select(2, panel:GetPoint(1)) == otherRow }, { 0, true })
    local otherItem = { type = 0, id = 4, lines = data.lines }
    tooltip._data = otherItem
    before = reads
    world.postCalls[0][1](tooltip, otherItem)
    tooltip:Show()
    flush()
    test.check("identical text for a different item still replaces the deferred model",
        { reads - before, panel.renderedID, panel.key }, { 1, 4, 4 })
    hide()
    flush()
    test.check("leaving the auction row still hides the panel immediately", panel:IsShown(), false)
end
