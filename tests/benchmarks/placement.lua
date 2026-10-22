-- Placement workloads for placement.py. Geometry and engine layout are Lua
-- stand-ins: elapsed times measure this harness, never WoW's C++ frame layout.
return function(makeWorld, sources, scenario)
    local sticky = scenario == "sticky comparisons" or scenario == "sticky dragging"
    local comparing = scenario ~= "single" and scenario ~= "closed"
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Item" } } }
    local world = makeWorld({ tooltip = sticky and "ItemRefTooltip" or "GameTooltip", data = data,
        lines = { { left = { text = "Item" } } }, comparisons = {
            { tooltip = sticky and "ItemRefShoppingTooltip1" or "ShoppingTooltip1", data = data },
            { tooltip = sticky and "ItemRefShoppingTooltip2" or "ShoppingTooltip2", data = data },
        } }, { TooltipDataType = { Item = 0 } }, function() end)
    local ns = {}
    for _, name in ipairs({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }) do
        assert(loadstring(sources[name], "@" .. name))("PrettyTooltip", ns)
    end
    local stats
    local function count(name)
        if stats then stats[name] = (stats[name] or 0) + 1 end
    end
    local function fractions(point)
        return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5,
            point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
    end
    local function rectangle(frame)
        local factor = frame:GetEffectiveScale()
        local width, height = frame:GetWidth() * factor, frame:GetHeight() * factor
        if frame == UIParent then return 0, height, width, height end
        if frame:GetNumPoints() == 0 then return end
        local horizontal, vertical = frame._points[1], frame._points[1]
        for _, point in ipairs(frame._points) do
            if point[1]:find("LEFT") or point[1]:find("RIGHT") then horizontal = point end
            if point[1]:find("TOP") or point[1]:find("BOTTOM") then vertical = point end
        end
        local function anchor(point)
            local x, y, w, h = rectangle(point[2] or UIParent)
            if not x then return end
            local fx, fy = fractions(point[3])
            return x + fx * w + point[4] * factor, y - (1 - fy) * h + point[5] * factor
        end
        local x = anchor(horizontal)
        local _, y = anchor(vertical)
        if not x or not y then return end
        local fx = fractions(horizontal[1])
        local _, fy = fractions(vertical[1])
        local left, top = x - fx * width, y + (1 - fy) * height
        if frame:IsClampedToScreen() then
            local a, b, c, d = frame:GetClampRectInsets()
            local screenWidth, screenHeight = UIParent:GetWidth() * UIParent:GetEffectiveScale(),
                UIParent:GetHeight() * UIParent:GetEffectiveScale()
            left = math.max(-a * factor, math.min(screenWidth - width - b * factor, left))
            top = math.max(height - d * factor, math.min(screenHeight - c * factor, top))
        end
        return left, top, width, height
    end
    local function geometry(frame, panel)
        if frame._benchmarkGeometry then return end
        frame._benchmarkGeometry = true
        frame.GetLeft = function(self) local x = rectangle(self); return x and x / self:GetEffectiveScale() end
        frame.GetTop = function(self) local x, y = rectangle(self); return x and y / self:GetEffectiveScale() end
        frame.GetRight = function(self) local x, _, w = rectangle(self); return x and (x + w) / self:GetEffectiveScale() end
        frame.GetBottom = function(self) local x, y, _, h = rectangle(self); return x and (y - h) / self:GetEffectiveScale() end
        frame.GetScaledRect = function(self)
            local x, y, w, h = rectangle(self)
            if x then return x, y - h, w, h end
        end
        local setPoint, clear = frame.SetPoint, frame.ClearAllPoints
        frame.SetPoint = function(self, point, ...)
            count(panel and "panel anchors" or "native/source anchors")
            for index = #self._points, 1, -1 do
                if self._points[index][1] == point then table.remove(self._points, index) end
            end
            return setPoint(self, point, ...)
        end
        frame.ClearAllPoints = function(self) clear(self) end
    end
    for _, object in ipairs(world.objects) do geometry(object) end
    local owner = world.main
    if sticky then
        local close = CreateFrame("Button", nil, owner)
        geometry(close)
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -2, -2)
        owner.CloseButton = close
    end
    local first, second = _G[sticky and "ItemRefShoppingTooltip1" or "ShoppingTooltip1"],
        _G[sticky and "ItemRefShoppingTooltip2" or "ShoppingTooltip2"]
    owner.shoppingTooltips = { first, second }
    local source = CreateFrame("Frame", nil, UIParent)
    geometry(source)
    source:SetSize(1, 1)
    source:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 900, 700)
    owner:SetPoint("TOPLEFT", source, "TOPLEFT", 0, 0)
    for index, tooltip in ipairs({ owner, first, second }) do
        tooltip._baseWidth, tooltip._baseHeight, tooltip._padding = 230, 90, { 0, 0, 0, 0 }
        tooltip._prettyWidth = index == 1 and 260 or index == 2 and 310 or 190
        local function resize(self)
            self:SetSize(self._baseWidth + self._padding[1], self._baseHeight + self:NumLines() * 14 + self._padding[2])
        end
        tooltip.GetPadding = function(self) return unpack(self._padding) end
        tooltip.SetPadding = function(self, a, b, c, d)
            count("padding writes")
            self._padding = { a or 0, b or 0, c or 0, d or 0 }
            resize(self)
        end
        local function show(self)
            self._shown = true
            -- Blizzard recalculates natural padding when it shows a tooltip;
            -- simulate the reset, without pretending to time its C++ layout.
            self._padding = { 0, 0, 0, 0 }
            resize(self)
        end
        tooltip.Show = show
        tooltip.SetShown = function(self, shown) if shown then show(self) else self._shown = false end end
        tooltip.SetOwner = function(self)
            self:ClearAllPoints()
            local cleared = self:GetScript("OnTooltipCleared")
            if cleared then cleared(self) end
        end
        tooltip:Show()
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(tooltip) count("reads"); return { rows = tooltip:NumLines(), width = tooltip._prettyWidth } end,
        render = function(panel, tooltip, model)
            count("renders")
            geometry(panel, true)
            panel.IsMouseOver = function() return true end
            panel:SetSize(model.width, 50 + model.rows * 22)
            if sticky and tooltip == owner and not panel.close then
                panel.close = CreateFrame("Button", nil, panel)
                geometry(panel.close)
                panel.close:SetSize(20, 20)
                panel.close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
            end
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    TooltipComparisonManager = {
        tooltip = owner,
        SetItemTooltip = function(_, primary)
            local tooltip = primary and first or second
            tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
            tooltip:AddLine("Equipped", 1, 1, 1)
            world.postCalls[0][1](tooltip, data)
            tooltip:Show()
            tooltip:AddLine("+5 Strength", 1, 1, 1)
            tooltip:AddLine("-2 Stamina", 1, 1, 1)
            return true
        end,
        AnchorShoppingTooltips = function()
            first:SetShown(true)
            second:SetShown(true)
            first:SetPoint("TOP", owner, "TOP", 0, 0)
            second:SetPoint("TOP", owner, "TOP", 0, 0)
            first:SetPoint("RIGHT", owner, "LEFT", 0, 0)
            second:SetPoint("TOPRIGHT", first, "TOPLEFT", 0, 0)
        end,
    }
    ns.Hooks.install()
    world.postCalls[0][1](owner, data)
    owner:Show()
    local function compare()
        for _, tooltip in ipairs({ first, second }) do tooltip:SetOwner(owner, "ANCHOR_NONE") end
        TooltipComparisonManager:SetItemTooltip(true)
        TooltipComparisonManager:SetItemTooltip(false)
        TooltipComparisonManager:AnchorShoppingTooltips()
    end
    if comparing then compare() end
    flush()
    if scenario == "sticky dragging" then owner:GetScript("OnDragStart")(owner) end
    local drivers = {}
    for _, object in ipairs(world.objects) do
        if object ~= ns.ui.panels[owner] and object ~= ns.ui.panels[first] and object ~= ns.ui.panels[second]
            and object:GetScript("OnUpdate") then drivers[#drivers + 1] = object end
    end
    if scenario == "closed" then
        owner:Hide()
        owner:GetScript("OnHide")(owner)
        flush()
    end
    local frame = 0
    local function run(frames)
        for _ = 1, frames do
            frame = frame + 1
            if scenario == "moving comparisons" then
                source:ClearAllPoints()
                source:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 900 + frame % 40, 700)
            end
            if scenario == "sticky dragging" then
                -- The engine moves the native frame before the drag-only input
                -- callback. Keep this motion away from a side-change boundary.
                local point = owner._points[1]
                point[4] = (frame % 40) / owner:GetEffectiveScale()
            end
            if scenario == "refills" then
                data.id = data.id + 1
                world.postCalls[0][1](owner, data)
                owner:Show()
            end
            if comparing and (scenario == "refills" or frame % 12 == 0) then compare() end
            for _, driver in ipairs(drivers) do
                local callback = driver:GetScript("OnUpdate")
                if callback then callback(driver, 1 / 60) end
            end
            for tooltip, panel in pairs(ns.ui.panels) do
                if tooltip:IsShown() and panel:IsShown() and panel:GetScript("OnUpdate") then
                    panel:GetScript("OnUpdate")(panel, 1 / 60)
                end
            end
            flush()
        end
    end
    return {
        run = run,
        validate = function()
            local main = ns.ui.panels[owner]
            if scenario == "closed" then
                assert(not owner:IsShown() and not main:IsShown(), "closed workload left a tooltip visible")
                return
            end
            assert(main:IsShown() and main:GetNumPoints() > 0 and owner:GetAlpha() == 0, "main tooltip did not settle")
            if comparing then
                for _, tooltip in ipairs({ first, second }) do
                    local panel = ns.ui.panels[tooltip]
                    assert(tooltip:IsShown() and panel:IsShown() and panel:GetNumPoints() > 0,
                        "comparison workload lost a panel")
                    assert(not panel.comparisonPending and not panel.restorePending, "comparison fill did not complete")
                end
            end
        end,
        collect = function() collectgarbage("collect") end,
        counts = function(frames)
            stats = {}
            run(frames)
            local result = stats
            stats = nil
            return result
        end,
        allocation = function(frames)
            collectgarbage("collect")
            collectgarbage("stop")
            local before = collectgarbage("count")
            local ok, problem = pcall(run, frames)
            local allocated = collectgarbage("count") - before
            collectgarbage("restart")
            if not ok then error(problem) end
            return allocated / frames
        end,
    }
end
