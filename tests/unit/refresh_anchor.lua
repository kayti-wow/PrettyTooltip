-- Character slots refill the same bottom-anchored tooltip every .2 s. The
-- PTR feedback hook calls Show before the item post-call, with extra height
-- that disappears by the final Show. The visible panel must stay steady.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Boots" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = data,
        lines = { { left = { text = "Boots" } } },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local tooltip = world.main
    local owner = CreateFrame("Frame", "CharacterFeetSlot", UIParent)
    local height, bottom, vertical = 206.9, 100, 1
    local padding, writes = { 0, 0, 0, 0 }, {}
    tooltip.GetPadding = function() return unpack(padding) end
    tooltip.SetPadding = function(self, right, below, left, top)
        padding = { right, below, left, top }
        writes[#writes + 1] = below
        self:SetSize(254.4 + right, height + below)
    end
    tooltip.Show = function(self)
        self._shown = true
        self:SetSize(254.4 + padding[1], height + padding[2])
    end
    tooltip.GetTop = function(self) return bottom + self:GetHeight() * vertical end
    tooltip.GetBottom = function(self) return bottom + self:GetHeight() * (vertical - 1) end
    tooltip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    tooltip:Show()
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function() return {} end,
        render = function(panel, native)
            panel:SetSize(268.9, 302.8)
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    post(tooltip, data)
    flush()
    local panel = ns.ui.panels[tooltip]
    -- Resolve the panel's vertical anchor against the fake tooltip's actual
    -- top/bottom/centre, instead of the harness's fixed frame coordinates.
    local function panelTop()
        local _, target, point, _, y = panel:GetPoint(1)
        if target == UIParent then return y end
        local base = point:find("TOP") and tooltip:GetTop()
            or point:find("BOTTOM") and tooltip:GetBottom() or (tooltip:GetTop() + tooltip:GetBottom()) / 2
        return base + y * panel:GetEffectiveScale() / tooltip:GetEffectiveScale()
    end
    local stable = panelTop()
    local minimum, maximum = stable, stable
    local function observe()
        minimum, maximum = math.min(minimum, panelTop()), math.max(maximum, panelTop())
    end
    writes = {}
    for _ = 1, 20 do
        tooltip:SetOwner(owner, "ANCHOR_RIGHT")
        tooltip:GetScript("OnTooltipCleared")(tooltip)
        -- Early Show from Blizzard_PTRFeedback, before our item post-call.
        height = 231.3
        tooltip:Show()
        observe()
        post(tooltip, data)
        observe()
        -- Final Show has the normal item height again.
        height = 206.9
        tooltip:Show()
        observe()
        flush()
        observe()
    end
    test.check("repeated early shows do not change padding", #writes, 0)
    test.check("the panel stays steady throughout every refill", maximum - minimum < .01, true)
    test.check("the completed tooltip keeps the original fit", math.abs(padding[2] - 95.9) < .01, true)
    test.check("the completed panel follows the tooltip again",
        { select(2, panel:GetPoint(1)) == tooltip, (select(3, panel:GetPoint(1))) }, { true, "TOPLEFT" })

    -- A clear can start a refresh without SetOwner, as action buttons do.
    minimum, maximum = stable, stable
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    height = 231.3
    tooltip:Show()
    observe()
    post(tooltip, data)
    height = 206.9
    tooltip:Show()
    observe()
    flush()
    observe()
    test.check("same-owner clears also hold the panel steady", maximum - minimum < .01, true)

    -- A genuinely taller new tooltip must still fit after its complete fill.
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    data.id = 2
    height = 350
    tooltip:Show()
    post(tooltip, data)
    tooltip:Show()
    flush()
    test.check("new items can change the completed native bounds", tooltip:GetHeight(), 350)

    -- Holding must use the native frame's anchor edge and scale conversion.
    for _, entry in ipairs({ { "BOTTOMRIGHT", 1, .75 }, { "TOPLEFT", 0, 1.25 }, { "RIGHT", .5, .75 } }) do
        ns.Native.restoreNative(tooltip)
        tooltip:ClearAllPoints()
        tooltip:SetPoint(entry[1], owner, "TOPRIGHT", 0, 0)
        vertical, height = entry[2], 206.9
        panel:SetScale(entry[3])
        tooltip:SetScale(1.25)
        tooltip:Show()
        post(tooltip, data)
        flush()
        local originalTop = panelTop()
        tooltip:SetOwner(owner, "ANCHOR_RIGHT")
        tooltip:GetScript("OnTooltipCleared")(tooltip)
        height = 231.3
        tooltip:Show()
        test.check(entry[1] .. ": scaled panels hold their top during an early show",
            math.abs(panelTop() - originalTop) < .01, true)
        post(tooltip, data)
        height = 206.9
        tooltip:Show()
        flush()
        test.check(entry[1] .. ": the completed fit preserves the scaled position",
            math.abs(panelTop() - originalTop) < .01, true)
    end

    -- A cancelled refresh must not consume a later refresh's pending fit.
    ns.Native.restoreNative(tooltip)
    panel:SetScale(1)
    tooltip:SetScale(1)
    vertical, height = 1, 206.9
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    tooltip:Show()
    post(tooltip, data)
    flush()
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    ns.Native.restoreNative(tooltip)
    post(tooltip, data)
    C_Timer.After(0, function()
        height = 231.3
        tooltip:SetSize(254.4 + padding[1], height + padding[2])
    end)
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    flush()
    test.check("a cancelled fit cannot complete the newer refresh before its layout finishes",
        math.abs(tooltip:GetHeight() - 302.8) < .01, true)

    local getPoint = tooltip.GetPoint
    tooltip.GetPoint = function() error("restricted anchor") end
    local readable = pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
    tooltip.GetPoint = getPoint
    test.check("an unreadable anchor cannot escape the SetOwner hook", readable, true)
    test.check("a failed hold leaves no pending fit", panel.refreshPending, nil)

    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    flush()
    test.check("hiding during a refill cannot revive the panel", panel:IsShown(), false)
end
