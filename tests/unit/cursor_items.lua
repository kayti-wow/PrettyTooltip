-- Real Native/Hooks/Cursor interaction: action buttons clear, hide and refill
-- the tooltip between hovers. Item refresh holds must yield to cursor placement.
return function(test)
    local item = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "First item" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Hooks.lua",
        "Integration/Cursor.lua" }, {
        enums = { TooltipDataType = { Item = 0, Spell = 1 } }, data = item,
        lines = { { left = { text = "First item" } } },
    })
    local tooltip = world.main
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local function fire(event)
        local handler = tooltip:GetScript(event)
        if handler then handler(tooltip) end
    end
    local padding = { 0, 0, 0, 0 }
    tooltip.GetPadding = function() return unpack(padding) end
    tooltip.SetPadding = function(self, right, bottom, left, top)
        padding = { right, bottom, left, top }
        self:SetSize(254 + right, 107 + bottom)
    end
    tooltip.Show = function(self)
        self._shown = true
        self:SetSize(254 + padding[1], 107 + padding[2])
    end
    tooltip.Hide = function(self)
        self._shown = false
        fire("OnTooltipCleared")
        fire("OnHide")
    end
    tooltip.SetOwner = function(self)
        fire("OnTooltipCleared")
        padding = { 0, 0, 0, 0 }
        self:SetSize(254, 107)
    end
    GameTooltip_SetDefaultAnchor = function(self, owner)
        self:SetOwner(owner, "ANCHOR_NONE")
        self:ClearAllPoints()
        self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, data) return data.id end,
        read = function(_, data) return { id = data.id } end,
        render = function(panel, native, model)
            panel:SetSize(model.id == 1 and 270 or 300, 196)
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    ns.TooltipTypes[1] = {
        option = "spellPanels", key = function(_, data) return data.id end,
        read = function(_, data) return { id = data.id } end,
        render = function(panel, native, model)
            panel:SetSize(280, model.id == 1 and 119 or 196)
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    local x, y = 500, 100
    GetCursorPosition = function() return x, y end
    ns.setOption("cursorItems", true)
    ns.setOption("cursorSpells", true)
    ns.Hooks.install()
    ns.Cursor.register()
    local follower = world.objects[#world.objects]
    -- Geometry follows actual anchors rather than the harness's fixed origin.
    tooltip.GetTop = function(self)
        local point, target, _, _, offset = self:GetPoint(1)
        if target == follower then return y + offset end
        return point:find("BOTTOM") and 30 + self:GetHeight() or 800
    end
    tooltip.GetBottom = function(self) return self:GetTop() - self:GetHeight() end
    local panel = ns.ui.getPanel(tooltip)
    local function panelTop()
        local _, target, relative, _, offset = panel:GetPoint(1)
        if target == UIParent then return offset end
        if relative:find("BOTTOM") then return tooltip:GetBottom() + offset end
        return tooltip:GetTop() + offset
    end
    panel.GetTop = panelTop
    local function show(id, dataType)
        GameTooltip_SetDefaultAnchor(tooltip, UIParent)
        local data = { type = dataType or 0, id = id, lines = item.lines }
        tooltip._data = data
        world.postCalls[data.type][1](tooltip, data)
        tooltip:Show()
    end
    show(1)
    flush()
    local top = panelTop()
    show(2)
    test.check("changing cursor items does not retain the bottom-edge hold for a frame",
        math.abs(panelTop() - top) < .01, true)
    test.check("the cursor panel immediately uses its tooltip's top edge", (select(3, panel:GetPoint(1))), "TOPLEFT")
    flush()
    test.check("the delayed native fit preserves the cursor panel position", math.abs(panelTop() - top) < .01, true)

    tooltip:Hide()
    test.check("leaving an action button hides its panel in the same frame", panel:IsShown(), false)
    test.check("hiding cancels its pending item hold", panel.refreshPending, nil)
    flush()
    test.check("queued work cannot show the old panel after hide", panel:IsShown(), false)
    tooltip:Show()
    test.check("a bare native Show cannot revive the old panel", panel:IsShown(), false)
    tooltip:Hide()
    show(1)
    test.check("an item entered in the same frame is shown immediately", panel:IsShown(), true)
    test.check("the new item immediately uses the cursor anchor", (select(3, panel:GetPoint(1))), "TOPLEFT")
    test.check("the new item is at the expected cursor height", math.abs(panelTop() - top) < .01, true)
    flush()
    test.check("the new panel survives old restore timers", panel:IsShown(), true)

    -- Native hide/clear can be delivered in either order, with no time to run
    -- any deferred callbacks between entering successive action buttons.
    local steady = true
    for index = 1, 20 do
        tooltip:Hide()
        if panel:IsShown() then steady = false end
        x = x + 3
        show(index % 2 + 1)
        if not panel:IsShown() or math.abs(panelTop() - top) > .01 then steady = false end
    end
    flush()
    test.check("rapid alternating item hovers never show an orphan or displaced panel", steady, true)

    show(2)
    test.check("a shown item refill has a pending native fit", panel.refreshPending ~= nil, true)
    tooltip:Hide()
    test.check("hiding cancels an active hold immediately", { panel:IsShown(), panel.refreshPending == nil }, { false, true })
    show(1)
    flush()
    test.check("the cancelled fit cannot reposition a newly entered cursor item",
        { panel:IsShown(), math.abs(panelTop() - top) < .01 }, { true, true })

    -- A spell and item can share a numeric ID or a panel height; neither is
    -- enough to identify the content or preserve an old item's anchor hold.
    local function atCursor()
        return panel:IsShown() and math.abs(panelTop() - (y + 16 + panel:GetHeight())) < .01
            and select(3, panel:GetPoint(1)) == "TOPLEFT"
    end
    show(1, 1)
    test.check("an item-to-spell switch renders the new type before deferred work",
        { panel.dataType, panel:GetHeight(), atCursor() }, { 1, 119, true })
    flush()
    test.check("the item's deferred fit keeps the following spell at the cursor", atCursor(), true)
    show(1)
    test.check("a spell-to-item switch renders even when the numeric ID is unchanged",
        { panel.dataType, panel:GetHeight(), atCursor() }, { 0, 196, true })
    flush()
    local mixedSteady = true
    for index = 1, 20 do
        if index % 3 == 0 then
            tooltip:Hide()
            if panel:IsShown() then mixedSteady = false end
        end
        x, y = x + 3, y + 2
        show(math.floor((index - 1) / 2) % 2 + 1, index % 2)
        if not atCursor() then mixedSteady = false end
        if index % 4 == 0 then
            flush()
            if not atCursor() then mixedSteady = false end
        end
    end
    flush()
    test.check("rapid mixed spell and item hovers stay at the cursor through queued callbacks",
        mixedSteady and atCursor(), true)
end
