-- Drive the comparison manager's real call order: item post-call, Show,
-- appended deltas, SetShown, then several anchor points per comparison.
return function(test)
    local item = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Equipment" } } }
    local capture = { data = item, lines = { { left = { text = "Equipment" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = item, lines = capture.lines,
        comparisons = { capture, { data = item, lines = capture.lines } },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local reads, renders, paddingSets, clears = 0, 0, 0, 0
    local lastRows, lastID
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, data) return data.id end,
        read = function(tooltip, data)
            reads = reads + 1
            return { rows = tooltip:NumLines(), id = data.id }
        end,
        render = function(panel, _, model)
            renders = renders + 1
            lastRows, lastID = model.rows, model.id
            panel.renderedID = model.id
            panel:SetSize(200, model.rows * 50)
            panel:Show()
        end,
    }
    local primary, secondary = ShoppingTooltip1, ShoppingTooltip2
    local deferNativeLayout = false
    local keepPadding = false
    local resetOwnerAnchors = false
    for _, tooltip in ipairs({ primary, secondary }) do
        tooltip.SetOwner = function(self)
            if resetOwnerAnchors then self:ClearAllPoints() end
        end
        tooltip._padding = { 0, 0, 0, 0 }
        tooltip.GetPadding = function(self) return unpack(self._padding) end
        tooltip.SetPadding = function(self, right, bottom, left, top)
            paddingSets = paddingSets + 1
            self._padding = { right, bottom, left, top }
            self:SetSize(100 + right, (self._naturalHeight or self:NumLines() * 10) + bottom)
        end
        tooltip.Show = function(self)
            self._shown = true
            if not keepPadding then self._padding = { 0, 0, 0, 0 } end
            self._naturalHeight = self:NumLines() * 10
            self:SetSize(100 + self._padding[1], self._naturalHeight + self._padding[2])
        end
        local setShown = tooltip.SetShown
        tooltip.SetShown = function(self, visible)
            setShown(self, visible)
            if visible and deferNativeLayout then
                self._naturalHeight = self:NumLines() * 10
                self:SetSize(100 + self._padding[1], self._naturalHeight + self._padding[2])
            end
        end
        local clear = tooltip.ClearAllPoints
        tooltip.ClearAllPoints = function(self) clears = clears + 1; clear(self) end
    end
    local deltas, deltaText, itemID = 2, "+5 Strength", 1
    local duringFill, beforeFill
    TooltipComparisonManager = nil
    ns.Hooks.install()
    test.check("startup without the comparison manager leaves batching inactive", ns.Hooks.comparisonsBatched(), false)
    GameTooltip.shoppingTooltips = { primary, secondary }
    TooltipComparisonManager = {
        tooltip = GameTooltip,
        SetItemTooltip = function(_, isPrimary)
            local tooltip = isPrimary and primary or secondary
            tooltip._lines = { capture.lines[1] }
            tooltip:GetScript("OnTooltipCleared")(tooltip)
            beforeFill = { reads, renders, paddingSets }
            local data = { type = 0, id = itemID, lines = item.lines }
            tooltip._data = data
            world.postCalls[0][1](tooltip, data)
            tooltip:Show()
            duringFill = { reads, renders, paddingSets }
            for _ = 1, deltas do tooltip:AddLine(deltaText, 1, 1, 1) end
            if not deferNativeLayout then
                tooltip._naturalHeight = tooltip:NumLines() * 10
                tooltip:SetSize(100, tooltip._naturalHeight)
            end
            return true
        end,
        AnchorShoppingTooltips = function(_, left)
            primary:SetShown(true)
            secondary:SetShown(true)
            primary:SetPoint("TOP", GameTooltip, 0, 0)
            secondary:SetPoint("TOP", GameTooltip, 0, 0)
            if left then
                primary:SetPoint("RIGHT", GameTooltip, "LEFT")
                secondary:SetPoint("TOPRIGHT", primary, "TOPLEFT")
            else
                secondary:SetPoint("LEFT", GameTooltip, "RIGHT")
                primary:SetPoint("TOPLEFT", secondary, "TOPRIGHT")
            end
        end,
    }
    local main = ns.ui.getPanel(GameTooltip)
    main:SetSize(200, 100)
    main:Show()
    GameTooltip:SetSize(200, 100)
    GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 850, 700)
    -- Hooks are installed by the first data handover, before the clear script
    -- in SetItemTooltip would normally run on subsequent refreshes.
    for _, tooltip in ipairs({ primary, secondary }) do
        world.postCalls[0][1](tooltip, item)
    end
    test.check("the first data handover installs batching when the manager arrives later", ns.Hooks.comparisonsBatched(), true)
    local function refresh(left)
        GameTooltip.GetAnchorType = function() return left and "ANCHOR_LEFT" or "ANCHOR_RIGHT" end
        primary:ClearAllPoints()
        secondary:ClearAllPoints()
        TooltipComparisonManager:SetItemTooltip(true)
        TooltipComparisonManager:SetItemTooltip(false)
        TooltipComparisonManager:AnchorShoppingTooltips(left)
    end
    refresh(true)
    test.check("no read, render, or padding change during the partial item fill", duringFill, beforeFill)
    test.check("each completed comparison is read and rendered once", { reads, renders, lastRows }, { 2, 2, 3 })
    test.check("comparisons never pad native frames", paddingSets, 0)
    test.check("native anchors are only cleared by the producer", clears, 2)
    local first, second = ns.ui.panels[primary], ns.ui.panels[secondary]
    test.check("left comparisons attach to the main and neighbouring panels",
        { select(2, first:GetPoint(2)) == main, select(2, second:GetPoint(2)) == first,
            first.side, second.side }, { true, true, "RIGHT", "RIGHT" })
    test.check("native tooltips remain hidden throughout the refresh", { primary:GetAlpha(), secondary:GetAlpha() }, { 0, 0 })
    flush()
    test.check("fallback timers do not repeat completed work", { reads, renders, paddingSets, clears }, { 2, 2, 0, 2 })

    for _ = 1, 20 do refresh(true); flush() end
    test.check("unchanged comparison refreshes never rebuild their panels", { reads, renders }, { 2, 2 })
    test.check("refreshes do not rewrite native padding", paddingSets, 0)
    test.check("refreshes leave native anchors to the producer", clears, 42)

    deltaText = "+10 Strength"
    refresh(false)
    test.check("changed deltas redraw even with the same item and line count", { reads, renders }, { 4, 4 })
    test.check("native anchor changes preserve a Pretty side that still fits",
        { select(2, first:GetPoint(2)) == main, select(2, second:GetPoint(2)) == first,
            first.side, second.side }, { true, true, "RIGHT", "RIGHT" })
    deltas = 0
    refresh(true)
    test.check("a shorter completed comparison shrinks without a second fit",
        { lastRows, first:GetHeight(), primary:GetHeight() }, { 1, 50, 10 })
    itemID = 2
    refresh(true)
    test.check("a different item with identical text still redraws", { lastID, renders }, { 2, 8 })
    flush()

    -- Another addon hooks the manager after us and appends its own row.
    TooltipComparisonManager:SetItemTooltip(true)
    primary:AddLine("Addon information", 1, 1, 1)
    primary._naturalHeight = primary:NumLines() * 10
    primary:SetSize(100 + primary._padding[1], primary:NumLines() * 10 + primary._padding[2])
    flush()
    test.check("rows appended after the manager's post-hook are included next frame",
        { lastRows, renders }, { 2, 9 })

    -- A third party can fill shopping tooltips without using the manager.
    itemID = 3
    world.postCalls[0][1](primary, { type = 0, id = itemID, lines = item.lines })
    primary:Show()
    flush()
    test.check("direct fills settle through the next-frame fallback", lastID, 3)
    primary:ClearAllPoints()
    primary:SetPoint("TOP", GameTooltip, 0, 0)
    primary:SetPoint("LEFT", GameTooltip, "RIGHT")
    flush()
    test.check("direct anchor changes settle without the manager",
        { select(2, first:GetPoint(1)) == main, first.side }, { true, "RIGHT" })
    itemID = 4
    world.postCalls[0][1](primary, { type = 0, id = itemID, lines = item.lines })
    primary:Hide()
    primary:GetScript("OnHide")(primary)
    flush()
    test.check("hiding cancels a pending comparison", { lastID, first:IsShown() }, { 3, false })
    test.check("hiding releases both queued layout flags",
        { first.comparisonPending == nil, first.comparisonAnchorPending == nil }, { true, true })

    primary:Show()
    world.postCalls[0][1](primary, { type = 0, id = 5, lines = item.lines })
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    flush()
    test.check("the original-tooltip modifier cancels queued rendering",
        { lastID, first:IsShown(), primary:GetAlpha() }, { 3, false, 1 })
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("releasing the modifier restores the latest comparison", { first.renderedID, first:IsShown() }, { 5, true })

    local failedRead = ns.TooltipTypes[0].read
    ns.TooltipTypes[0].read = function() error("unreadable comparison") end
    world.postCalls[0][1](primary, { type = 0, id = 6, lines = item.lines })
    flush()
    test.check("a failed reader restores the native tooltip",
        { first:IsShown(), primary:GetAlpha(), first.comparisonPending == nil }, { false, 1, true })
    ns.TooltipTypes[0].read = failedRead

    -- The anchor fixes must also hold while batching is active: Alt-only
    -- addon rows must not enlarge the returning comparison for one frame.
    itemID, deltas = 7, 2
    refresh(false)
    flush()
    local savedReads, savedHeight = reads, first:GetHeight()
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    for _, tooltip in ipairs({ primary, secondary }) do
        tooltip:AddLine("Alt-only addon information", 1, 1, 1)
        world.postCalls[0][1](tooltip, { type = 0, id = itemID, lines = item.lines })
        tooltip:Show()
    end
    flush()
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("batched comparisons return from Alt without reading its extra rows",
        { reads, first:GetHeight(), first:IsShown(), primary:GetAlpha() }, { savedReads, savedHeight, true, 0 })
    test.check("returning from Alt reconnects batched comparisons in the same event",
        { select(2, first:GetPoint(2)) == main, select(2, second:GetPoint(2)) == first }, { true, true })

    -- Reenter another item before any cleanup or fallback timer can run.
    world.postCalls[0][1](primary, { type = 0, id = 8, lines = item.lines })
    primary:Hide()
    primary:GetScript("OnHide")(primary)
    test.check("hiding a batched comparison dismisses its panel immediately", first:IsShown(), false)
    primary:Show()
    world.postCalls[0][1](primary, { type = 0, id = 9, lines = item.lines })
    flush()
    test.check("old comparison timers cannot restore an item replaced in the same frame",
        { first.renderedID, first:IsShown(), primary:GetAlpha() }, { 9, true, 0 })

    -- On the client GetHeight still reports the base item after deltas were
    -- appended. The final SetShown settles their height before anchoring.
    deferNativeLayout = true
    keepPadding = true
    itemID, deltas = 10, 2
    local beforePadding = paddingSets
    refresh(true)
    test.check("late native layout fits each comparison only once at its final Show",
        paddingSets - beforePadding, 0)
    test.check("both comparisons have their completed height before anchors are used",
        { primary:GetHeight(), secondary:GetHeight(), first:GetHeight(), second:GetHeight() }, { 30, 30, 150, 150 })
    beforePadding = paddingSets
    flush()
    test.check("fallback timers do not repeat the settled comparison fits", paddingSets, beforePadding)
    local beforeRenders = renders
    for _ = 1, 20 do refresh(true); flush() end
    test.check("a static three-way comparison never rewrites padding during repeated partial fills", paddingSets, beforePadding)
    test.check("a static three-way comparison never redraws its panels", renders, beforeRenders)

    local font = primary:GetLeftLine(1)
    local getText = font.GetText
    font.GetText = function() error("restricted font string") end
    local completed = pcall(TooltipComparisonManager.SetItemTooltip, TooltipComparisonManager, true)
    local settled = pcall(flush)
    font.GetText = getText
    test.check("unreadable text cannot escape the manager hook or its deferred check", { completed, settled }, { true, true })
    test.check("an unreadable comparison restores the native tooltip", { first:IsShown(), primary:GetAlpha() }, { false, 1 })
    TooltipComparisonManager = nil

    -- A client without these manager methods keeps the ordinary hook path.
    ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = item, lines = capture.lines,
        comparisons = { capture },
    })
    renders = 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, data) return data.id end,
        read = function() return {} end,
        render = function(panel) renders = renders + 1; panel:Show() end,
    }
    ns.Hooks.install()
    world.postCalls[0][1](ShoppingTooltip1, item)
    test.check("clients without a comparison manager still render immediately", renders, 1)
end
