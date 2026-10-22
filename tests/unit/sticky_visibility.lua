-- Item links initially request comparisons before our main panel exists.
-- Once Pretty owns geometry, only actual hover may keep those panels open.
return function(test)
    local function setup(sticky, hovered)
        local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Ring" } } }
        local lines = { { left = { text = "Ring" } } }
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
            "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
            "Integration/Placement.lua", "Integration/Hooks.lua" }, {
            enums = { TooltipDataType = { Item = 0 } }, tooltip = sticky and "ItemRefTooltip" or "GameTooltip",
            data = data, lines = lines, comparisons = {
                { tooltip = sticky and "ItemRefShoppingTooltip1" or "ShoppingTooltip1", data = data, lines = lines },
                { tooltip = sticky and "ItemRefShoppingTooltip2" or "ShoppingTooltip2", data = data, lines = lines },
            },
        })
        local owner = world.main
        local first, second = _G[sticky and "ItemRefShoppingTooltip1" or "ShoppingTooltip1"],
            _G[sticky and "ItemRefShoppingTooltip2" or "ShoppingTooltip2"]
        owner.shoppingTooltips = { first, second }
        owner:SetSize(100, 50)
        owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 800, 600)
        local pending, clears, nativeHides, beforeAnchors = {}, 0, 0
        C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
        local function flush()
            local callbacks = pending
            pending = {}
            for _, callback in ipairs(callbacks) do callback() end
        end
        for _, tooltip in ipairs({ owner, first, second }) do
            tooltip:SetSize(100, 50)
            local hide = tooltip.Hide
            tooltip.Hide = function(self)
                local wasShown = self:IsShown()
                hide(self)
                if wasShown then
                    if self ~= owner then nativeHides = nativeHides + 1 end
                    local onHide = self:GetScript("OnHide")
                    if onHide then onHide(self) end
                end
            end
            tooltip.SetOwner = function(self)
                self:ClearAllPoints()
                local cleared = self:GetScript("OnTooltipCleared")
                if cleared then cleared(self) end
            end
        end
        ns.TooltipTypes[0] = {
            option = "itemPanels", key = function(_, item) return item.id end,
            read = function(tooltip) return { rows = tooltip:NumLines() } end,
            render = function(panel, tooltip, model)
                panel.IsMouseOver = function() return tooltip == owner and hovered end
                panel:SetSize(200, model.rows * 50)
                ns.ui.alignPanel(panel, tooltip)
                panel:Show()
            end,
        }
        local manager = {
            tooltip = owner,
            SetItemTooltip = function(_, primary)
                local tooltip = primary and first or second
                tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
                tooltip:AddLine("Equipped ring", 1, 1, 1)
                tooltip._data = data
                world.postCalls[0][1](tooltip, data)
                tooltip:Show()
                tooltip:AddLine("+5 Strength", 1, 1, 1)
                return true
            end,
            AnchorShoppingTooltips = function()
                first:SetShown(true)
                second:SetShown(true)
                beforeAnchors = { first:IsShown(), second:IsShown() }
                first:SetPoint("TOP", owner, "TOP", 0, 0)
                second:SetPoint("TOP", owner, "TOP", 0, 0)
                first:SetPoint("RIGHT", owner, "LEFT", 0, 0)
                second:SetPoint("TOPRIGHT", first, "TOPLEFT", 0, 0)
            end,
            Clear = function(self, tooltip)
                if self.tooltip ~= tooltip then return end
                clears = clears + 1
                self.tooltip = nil
                first:Hide()
                second:Hide()
            end,
        }
        TooltipComparisonManager = manager
        local cachedFill, cachedAnchor = manager.SetItemTooltip, manager.AnchorShoppingTooltips
        local function compare(cached)
            manager.tooltip = owner
            owner.updateTooltipTimer = .2
            first:SetOwner(owner, "ANCHOR_NONE")
            second:SetOwner(owner, "ANCHOR_NONE")
            local fill, anchor = cached and cachedFill or manager.SetItemTooltip, cached and cachedAnchor or manager.AnchorShoppingTooltips
            fill(manager, true)
            fill(manager, false)
            anchor(manager)
        end
        owner:SetScript("OnEnter", function() compare() end)
        owner:SetScript("OnLeave", function() manager:Clear(owner) end)
        ns.Hooks.install()
        return {
            ns = ns, owner = owner, first = first, second = second, manager = manager,
            compare = compare, flush = flush,
            root = function() world.postCalls[0][1](owner, data); owner:Show() end,
            hover = function(value) hovered = value end,
            visible = function()
                return { first:IsShown(), second:IsShown(), ns.ui.panels[first]:IsShown(), ns.ui.panels[second]:IsShown() }
            end,
            cleared = function() return clears, nativeHides end,
            beforeAnchors = function() return beforeAnchors end,
        }
    end

    local outside = setup(true, false)
    outside.compare()
    test.check("initial item-link comparisons can be filled before Pretty's root panel exists", outside.ns.ui.panels[outside.owner] == nil, true)
    outside.root()
    test.check("opening a sticky item outside hover immediately hides automatic comparisons", outside.visible(), { false, false, false, false })
    test.check("outside-hover reconciliation cancels the native comparison refresh timer", outside.owner.updateTooltipTimer == nil, true)
    test.check("outside-hover reconciliation clears the manager belonging to this sticky item", outside.manager.tooltip == nil, true)
    test.check("outside-hover reconciliation leaves the main item open", outside.ns.ui.panels[outside.owner]:IsShown(), true)
    outside.flush()
    test.check("deferred fill and hide work cannot reopen dismissed comparisons", outside.visible(), { false, false, false, false })
    outside.compare()
    test.check("outside-hover reconciliation waits until the comparison anchor transaction finishes", outside.beforeAnchors(), { true, true })
    test.check("a new automatic refresh outside hover is dismissed at the completion hook", outside.visible(), { false, false, false, false })
    local beforeClears = outside.cleared()
    outside.owner.updateTooltipTimer = 0
    outside.ns.Placement.refresh(outside.owner)
    test.check("outside hover cancels a zero countdown even with no visible comparisons",
        { outside.owner.updateTooltipTimer == nil, outside.cleared() == beforeClears }, { true, true })
    outside.hover(true)
    outside.owner:GetScript("OnEnter")(outside.owner)
    test.check("entering still requests comparisons after an idle countdown was cancelled", outside.visible(), { true, true, true, true })

    local inside = setup(true, true)
    inside.compare()
    inside.root()
    test.check("opening a sticky item already under the mouse preserves comparisons", inside.visible(), { true, true, true, true })
    test.check("inside-hover comparisons keep their active manager and timer", { inside.manager.tooltip == inside.owner, inside.owner.updateTooltipTimer }, { true, .2 })
    inside.hover(false)
    inside.ns.Placement.refresh(inside.owner)
    test.check("leaving Pretty's actual hover area dismisses comparisons", inside.visible(), { false, false, false, false })
    inside.hover(true)
    inside.owner:GetScript("OnEnter")(inside.owner)
    test.check("entering the sticky tooltip can show comparisons again", inside.visible(), { true, true, true, true })
    inside.hover(false)
    inside.owner:GetScript("OnLeave")(inside.owner)
    test.check("native leave handling still dismisses comparison panels", inside.visible(), { false, false, false, false })

    local dragging = setup(true, true)
    dragging.compare()
    dragging.root()
    dragging.owner:GetScript("OnDragStart")(dragging.owner)
    dragging.hover(false)
    dragging.ns.Placement.refresh(dragging.owner)
    test.check("clamping during an active drag does not dismiss comparisons outside geometric hover",
        dragging.visible(), { true, true, true, true })
    dragging.owner:GetScript("OnDragStop")(dragging.owner)
    test.check("releasing a drag outside hover still dismisses comparisons", dragging.visible(), { false, false, false, false })

    local cached = setup(true, false)
    cached.compare(true)
    cached.root()
    cached.flush()
    test.check("cached manager fills also dismiss comparisons outside the sticky panel", cached.visible(), { false, false, false, false })

    local native = setup(true, false)
    IsAltKeyDown = function() return true end
    native.compare()
    native.root()
    test.check("the original-tooltip key preserves Blizzard's native comparison visibility", { native.first:IsShown(), native.second:IsShown() }, { true, true })
    test.check("native-original presentation leaves Blizzard's comparison timer alone", native.owner.updateTooltipTimer, .2)

    local nonsticky = setup(false, false)
    nonsticky.compare()
    nonsticky.root()
    test.check("ordinary nonsticky tooltips keep their comparison visibility", nonsticky.visible(), { true, true, true, true })

    local fallback = setup(true, false)
    fallback.ns.setOption("itemPanels", false)
    fallback.compare()
    fallback.root()
    test.check("disabled Pretty item panels preserve native comparison behavior", { fallback.first:IsShown(), fallback.second:IsShown(), fallback.owner.updateTooltipTimer }, { true, true, .2 })
    TooltipComparisonManager = nil
end
