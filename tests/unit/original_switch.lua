-- Alt-only rows from another addon remain on the native tooltip until its
-- next refill. Returning to PrettyTooltip must not briefly draw those rows,
-- or leave comparisons attached to the wider native tooltip's edge.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Equipment" } } }
    local capture = { data = data, lines = { { left = { text = "Equipment" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = data, lines = capture.lines,
        comparisons = { capture },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local reads = 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(tooltip, item)
            reads = reads + 1
            return { rows = tooltip:NumLines(), id = item.id }
        end,
        render = function(panel, tooltip, model)
            local comparison = ns.ui.isComparison(tooltip)
            panel:SetSize(comparison and 326 or 260, (comparison and 480 or 330) + (model.rows - 1) * 15)
            panel.renderedID = model.id
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    local main, comparison = world.main, ShoppingTooltip1
    for _, tooltip in ipairs({ main, comparison }) do
        tooltip._padding = { 0, 0, 0, 0 }
        tooltip._baseHeight = tooltip == main and 210 or 340
        tooltip._baseWidth = tooltip == main and 286 or 251
        tooltip.GetPadding = function(self) return unpack(self._padding) end
        tooltip.Show = function(self)
            self._shown = true
            self:SetSize(self._baseWidth + self._padding[1],
                self._baseHeight + (self:NumLines() - 1) * 14 + self._padding[2])
        end
        tooltip.SetPadding = function(self, right, bottom, left, top)
            self._padding = { right, bottom, left, top }
            self:SetSize(self._baseWidth + right, self._baseHeight + (self:NumLines() - 1) * 14 + bottom)
        end
    end
    main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    comparison:SetPoint("TOP", main, "TOP", 0, 0)
    comparison:SetPoint("RIGHT", main, "LEFT", 0, 0)
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    for _, tooltip in ipairs({ main, comparison }) do tooltip:Show(); post(tooltip, data) end
    flush()
    local primary, secondary = ns.ui.panels[main], ns.ui.panels[comparison]
    local original = false
    IsAltKeyDown = function() return original end
    local function key(down)
        original = down
        world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", down and 1 or 0)
    end
    key(true)
    test.check("Alt shows the original pair", { primary:IsShown(), secondary:IsShown(), main:GetAlpha(), comparison:GetAlpha() },
        { false, false, 1, 1 })
    -- Simulate EllesmereUI's item post-call while its modifier is held.
    for _, tooltip in ipairs({ main, comparison }) do
        tooltip:AddDoubleLine("ItemID", "1", 1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine("IconID", "123", 1, 1, 1, 1, 1, 1)
        post(tooltip, data)
        tooltip:Show()
    end
    flush()
    local before = reads
    key(false)
    test.check("returning restores the previous panel sizes immediately", { primary:GetHeight(), secondary:GetHeight() }, { 330, 480 })
    test.check("Alt-only native rows are not read into the returning panels", reads, before)
    test.check("native comparison anchors stay with the original tooltip",
        { select(2, comparison:GetPoint(1)) == main, select(2, comparison:GetPoint(2)) == main }, { true, true })
    test.check("returning to Pretty leaves native sizes independent", { main:GetHeight(), comparison:GetHeight() }, { 238, 368 })
    test.check("returning hides the original pair", { main:GetAlpha(), comparison:GetAlpha() }, { 0, 0 })

    -- The following ordinary refill removes the modifier-only rows.
    for _, tooltip in ipairs({ main, comparison }) do
        tooltip:GetScript("OnTooltipCleared")(tooltip)
        tooltip._lines = { capture.lines[1] }
        post(tooltip, data)
        tooltip:Show()
    end
    flush()
    flush()
    test.check("the next refill keeps both panel sizes steady", { primary:GetHeight(), secondary:GetHeight() }, { 330, 480 })
    test.check("but ordinary refills still read fresh models", reads > before, true)

    key(true)
    local changed = { type = 0, id = 2, lines = data.lines }
    main._data = changed
    post(main, changed)
    key(false)
    test.check("a different item while Alt is held gets a fresh model", primary.renderedID, 2)
    key(true)
    ns.setOption("padding", 25)
    before = reads
    key(false)
    test.check("settings changes while Alt is held invalidate the saved model", reads > before, true)

    key(true)
    local read = ns.TooltipTypes[0].read
    ns.TooltipTypes[0].read = function(tooltip, item)
        if ns.util.isSecret(tooltip:GetLeftLine(1):GetText()) then return end
        return read(tooltip, item)
    end
    main:GetLeftLine(1):SetText(world.secret)
    key(false)
    test.check("restricted content cannot revive the saved model", { primary:IsShown(), main:GetAlpha() }, { false, 1 })

    main:GetLeftLine(1):SetText("Equipment")
    post(main, changed)
    flush()
    key(true)
    local font = main:GetLeftLine(1)
    local getText = font.GetText
    font.GetText = function() error("restricted font string") end
    local readable = pcall(key, false)
    font.GetText = getText
    test.check("an unreadable font cannot escape the modifier callback", readable, true)
    test.check("failed cache validation keeps the original tooltip", { primary:IsShown(), main:GetAlpha() }, { false, 1 })
end
