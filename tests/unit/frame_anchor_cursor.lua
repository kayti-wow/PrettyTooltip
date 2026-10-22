-- The existing cursor tracker should move a whole Pretty tooltip through
-- engine anchors, without running placement again for each mouse movement.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Item" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua",
        "Integration/Cursor.lua" }, { enums = { TooltipDataType = { Item = 0 } }, data = data,
        lines = { { left = { text = "Item" } } } })
    local function fractions(point)
        return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5,
            point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
    end
    local function box(frame)
        local width, height = frame:GetWidth(), frame:GetHeight()
        if frame == UIParent then return 0, height, width, height end
        local point, target, relative, x, y = frame:GetPoint(1)
        if not point then return end
        local left, top, w, h = box(target or UIParent)
        if not left then return end
        local fx, fy = fractions(point)
        local tx, ty = fractions(relative)
        left, top = left + tx * w + x - fx * width, top - (1 - ty) * h + y + (1 - fy) * height
        if frame:IsClampedToScreen() then
            local a, b, c, d = frame:GetClampRectInsets()
            left = math.max(-a, math.min(UIParent:GetWidth() - width - b, left))
            top = math.max(height - d, math.min(UIParent:GetHeight() - c, top))
        end
        return left, top, width, height
    end
    local function geometry(frame)
        frame.GetLeft = function(self) return box(self) end
        frame.GetTop = function(self) local _, y = box(self); return y end
        frame.GetRight = function(self) local x, _, w = box(self); return x and x + w end
        frame.GetBottom = function(self) local _, y, _, h = box(self); return y and y - h end
        local setPoint = frame.SetPoint
        frame.SetPoint = function(self, ...)
            self:ClearAllPoints()
            return setPoint(self, ...)
        end
    end
    for _, frame in ipairs(world.objects) do geometry(frame) end
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local tooltip = world.main
    local paddingWrites = 0
    tooltip:SetSize(230, 70)
    tooltip.SetPadding = function() paddingWrites = paddingWrites + 1 end
    tooltip.SetOwner = function(self)
        local clear = self:GetScript("OnTooltipCleared")
        if clear then clear(self) end
    end
    GameTooltip_SetDefaultAnchor = function(self, owner)
        self:SetOwner(owner, "ANCHOR_NONE")
        self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(_, item) return { id = item.id } end,
        render = function(panel, native, model)
            geometry(panel)
            panel:SetSize(260, model.id == 1 and 100 or 140)
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    local x, y = 500, 100
    GetCursorPosition = function() return x, y end
    ns.setOption("cursorItems", true)
    ns.Hooks.install()
    ns.Cursor.register()
    local tracker = world.objects[#world.objects]
    geometry(tracker)
    test.check("the cursor tracker uses native pixel rounding", tracker:GetRoundLayoutToNearestPixel(), true)
    local function tick() tracker:GetScript("OnUpdate")() end
    local function show(id)
        GameTooltip_SetDefaultAnchor(tooltip, UIParent)
        data.id = id
        world.postCalls[0][1](tooltip, data)
        tooltip:Show()
        tick()
        flush()
    end
    show(1)
    local panel = ns.ui.panels[tooltip]
    test.check("Pretty attaches to the cursor tracker's anchor", select(2, panel:GetPoint(1)) == tracker, true)
    test.check("the frame-anchored tooltip starts above the cursor", { panel:GetLeft(), panel:GetBottom() }, { 516, 116 })
    ns.ui.perf.calls, ns.ui.perf.time, ns.ui.perf.max = {}, {}, {}
    ns.ui.perf.total, ns.ui.perf.depth, ns.ui.perf.on = 0, 0, true
    x, y = x + 40, y + 30
    tick()
    ns.ui.perf.on = false
    test.check("engine anchors carry cursor movement immediately", { panel:GetLeft(), panel:GetBottom() }, { 556, 146 })
    test.check("cursor motion does not recalculate Pretty placement", ns.ui.perf.calls["placement plan"] or 0, 0)
    show(2)
    test.check("changing content height preserves the cursor gap", { panel:GetLeft(), panel:GetBottom(), panel:GetHeight() }, { 556, 146, 140 })
    ns.setOption("cursorItems", false)
    tick()
    test.check("disabling cursor following restores the original source anchor",
        { select(2, panel:GetPoint(1)) == UIParent, (select(3, panel:GetPoint(1))) }, { true, "BOTTOMRIGHT" })
    test.check("frame anchoring never changes native padding or parent", { paddingWrites, tooltip:GetParent() == UIParent }, { 0, true })
end
