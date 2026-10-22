-- Sticky comparisons can refresh through both hooked manager calls and
-- cached Blizzard functions. Their existing panel anchors must survive both.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Equipped ring" } } }
    local lines = { { left = { text = "Equipped ring" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, tooltip = "ItemRefTooltip", data = data, lines = lines,
        comparisons = {
            { tooltip = "ItemRefShoppingTooltip1", data = data, lines = lines },
            { tooltip = "ItemRefShoppingTooltip2", data = data, lines = lines },
        },
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
        read = function() reads = reads + 1; return {} end,
        render = function(panel, tooltip)
            panel:SetSize(200, 100)
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    local owner = world.main
    local main = ns.ui.getPanel(owner)
    main.IsMouseOver = function() return true end
    main:SetSize(200, 100)
    main:Show()
    local primary, secondary = ItemRefShoppingTooltip1, ItemRefShoppingTooltip2
    for _, tooltip in ipairs({ primary, secondary }) do
        tooltip:SetSize(200, 100)
        tooltip:Show()
        tooltip.SetOwner = function(self)
            local clear = self:GetScript("OnTooltipCleared")
            if clear then clear(self) end
        end
        tooltip.GetPadding = function() return 0, 0, 0, 0 end
        tooltip.SetPadding = function() end
    end
    owner.shoppingTooltips = { primary, secondary }
    TooltipComparisonManager = {
        tooltip = owner,
        SetItemTooltip = function(_, isPrimary)
            local tooltip = isPrimary and primary or secondary
            world.postCalls[0][1](tooltip, data)
            tooltip:Show()
            return true
        end,
        AnchorShoppingTooltips = function()
            primary:SetShown(true)
            secondary:SetShown(true)
            primary:SetPoint("TOP", owner, "TOP", 0, 0)
            secondary:SetPoint("TOP", owner, "TOP", 0, 0)
            primary:SetPoint("RIGHT", owner, "LEFT", 0, 0)
            secondary:SetPoint("TOPRIGHT", primary, "TOPLEFT", 0, 0)
        end,
    }
    local manager = TooltipComparisonManager
    local cachedFill, cachedAnchor = manager.SetItemTooltip, manager.AnchorShoppingTooltips
    ns.Hooks.install()
    local anchored = true
    local function observe()
        for _, tooltip in ipairs({ primary, secondary }) do
            local panel = ns.ui.panels[tooltip]
            if panel and panel:IsShown() and panel:GetNumPoints() == 0 then anchored = false end
        end
    end
    local function refresh(cached)
        for _, tooltip in ipairs({ primary, secondary }) do
            tooltip:SetOwner(owner, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            observe()
        end
        local fill = cached and cachedFill or manager.SetItemTooltip
        local anchor = cached and cachedAnchor or manager.AnchorShoppingTooltips
        fill(manager, true)
        fill(manager, false)
        anchor(manager)
        observe()
    end
    refresh(false)
    flush()
    local rejectedPins = 0
    for _, tooltip in ipairs({ primary, secondary }) do
        local panel = ns.ui.panels[tooltip]
        local setPoint = panel.SetPoint
        panel.SetPoint = function(self, point, relative, ...)
            if relative == UIParent then
                rejectedPins = rejectedPins + 1
                error("absolute anchor rejected")
            end
            return setPoint(self, point, relative, ...)
        end
    end
    local initialReads = reads
    for _ = 1, 10 do
        refresh(false)
        refresh(true)
        observe()
        flush()
        observe()
    end
    test.check("sticky refreshes never leave a visible comparison without anchors", anchored, true)
    test.check("independent comparison panels need no temporary absolute anchor", rejectedPins, 0)
    test.check("sticky refreshes keep their completed models", reads, initialReads)
    local first, second = ns.ui.panels[primary], ns.ui.panels[secondary]
    local near = first.side == "RIGHT" and first or second
    local far = near == first and second or first
    test.check("sticky comparisons return to their owner and neighbour after cached refreshes",
        { select(2, first:GetPoint(1)) == main, select(2, second:GetPoint(1)) == main,
            select(2, near:GetPoint(2)) == main, select(2, far:GetPoint(2)) == near }, { true, true, true, true })
    TooltipComparisonManager = nil
end
