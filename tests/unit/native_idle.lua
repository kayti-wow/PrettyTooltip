-- A cold native presentation must not adopt Pretty's panels or geometry
-- hooks. Hidden details prepare on demand using the latest handover.
return function(test)
    local text = "Equip: Increases healing done by up to 20 and damage done by up to 10 for all magical spells and effects."
    local lines = { { left = { text = "Equipment" } }, { left = { text = text } } }
    local initial = { type = 0, id = 1, lines = {
        { type = 22, lineIndex = 1, leftText = "Equipment" },
        { type = 0, lineIndex = 2, leftText = text },
    } }
    local fixture = { enums = { TooltipDataType = { Item = 0 },
        TooltipDataLineType = { None = 0, ItemName = 22 } },
        data = initial, lines = lines, comparisons = { { data = initial, lines = lines }, { data = initial, lines = lines } },
        shiftUp = true }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua", "Integration/ItemLite.lua", "Integration/Details.lua" }, fixture)
    ns.setOption("itemPanels", false)
    local tooltips = { world.main, ShoppingTooltip1, ShoppingTooltip2 }
    local anchorReads, paddingWrites = 0, 0
    for _, tooltip in ipairs(tooltips) do
        tooltip:SetSize(500, 100)
        tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
        tooltip:Show()
        local point = tooltip.GetPoint
        tooltip.GetPoint = function(self, ...) anchorReads = anchorReads + 1; return point(self, ...) end
        tooltip.GetPadding = function() return 0, 0, 0, 0 end
        tooltip.SetPadding = function() paddingWrites = paddingWrites + 1 end
        tooltip.GetMinimumWidth = function() return 0 end
        tooltip.SetMinimumWidth = function() end
    end
    TooltipComparisonManager = {
        tooltip = { shoppingTooltips = { tooltips[2], tooltips[3] } },
        SetItemTooltip = function() end,
        AnchorShoppingTooltips = function() end,
    }
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local reads, detailReads, keys = 0, 0, 0
    local kind = ns.TooltipTypes[0]
    local read, detail, key = kind.read, kind.readDetails, kind.key
    kind.read = function(...) reads = reads + 1; return read(...) end
    kind.readDetails = function(...) detailReads = detailReads + 1; return detail(...) end
    kind.key = function(...) keys = keys + 1; return key(...) end
    ns.ItemLite.register()
    ns.Hooks.install()
    ns.Details.register()
    local handovers = 0
    local function fill(tooltip, id)
        local cleared = tooltip:GetScript("OnTooltipCleared")
        if cleared then cleared(tooltip) end
        tooltip:GetLeftLine(1):SetText("Equipment")
        tooltip:GetLeftLine(2):SetText(text)
        local data = { type = 0, id = id, lines = initial.lines }
        tooltip._data = data
        world.postCalls[0][1](tooltip, data)
        handovers = handovers + 1
        tooltip:Show()
        tooltip:SetShown(true)
        tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    end
    local function refresh(id)
        fill(tooltips[1], id or 1)
        for _ = 1, 4 do fill(tooltips[2], 2); fill(tooltips[3], 3) end
    end
    for _ = 1, 25 do refresh() end
    test.check("cold native refreshes never allocate Pretty panels", next(ns.ui.panels), nil)
    test.check("hidden details and Pretty readers remain idle", { detailReads, reads, keys }, { 0, 0, 0 })
    test.check("native refreshes need no anchor snapshots, padding writes or timers",
        { anchorReads, paddingWrites, #pending }, { 0, 0, 0 })
    test.check("the shared post-call still receives every handover", { handovers, #world.postCalls[0] }, { 225, 1 })
    test.check("native wording still applies while Pretty and details stay idle",
        tooltips[1]:GetLeftLine(2):GetText(), ns.Stats.itemWording(text, false, true, true).lite)
    local function details(tooltip)
        for _, child in ipairs(tooltip._children) do
            if child._kind == "Frame" and child._shown then
                for _, font in ipairs(child._children) do
                    if font._kind == "FontString" and font._shown then return font:GetText() end
                end
            end
        end
    end
    refresh(7)
    fixture.shiftUp = nil
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("requesting details prepares all three tooltips in the same event", detailReads, 3)
    test.check("on-demand details use the latest handover", details(tooltips[1]), "Item ID: 7")
    local before = detailReads
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    test.check("releasing the key hides details immediately", details(tooltips[1]), nil)
    fixture.shiftUp = nil
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("repeated key toggles reuse rows until the next handover", detailReads, before)
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    refresh(8)
    local shown = tooltips[1].IsShown
    tooltips[1].IsForbidden = function() return true end
    tooltips[1].IsShown = function() error("must not inspect a now-forbidden tooltip") end
    fixture.shiftUp = nil
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("on-demand preparation rechecks frame permissions", detailReads - before, 2)
    tooltips[1].IsForbidden = function() return false end
    tooltips[1].IsShown = shown
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    tooltips[1]:Hide()
    tooltips[1]:GetScript("OnHide")(tooltips[1])
    tooltips[1]:Show()
    before = detailReads
    fixture.shiftUp = nil
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("hiding discards queued native details even if the frame reappears", detailReads, before)
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    refresh(9)
    for _, tooltip in ipairs(tooltips) do world.postCalls[0][1](tooltip, world.secret) end
    before = detailReads
    fixture.shiftUp = nil
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("invalid data cannot revive previously stored details", detailReads, before)
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)

    refresh(10)
    IsAltKeyDown = function() return true end
    fixture.shiftUp = nil
    before = detailReads
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("the original modifier keeps deferred details unprepared", detailReads, before)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("releasing original prepares requested details immediately", detailReads - before, 3)
    fixture.shiftUp = true
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)

    ns.setOption("itemPanels", true)
    refresh()
    flush(); flush()
    test.check("enabling Pretty after native startup creates all three panels", {
        ns.ui.shownPanel(tooltips[1]) ~= nil, ns.ui.shownPanel(tooltips[2]) ~= nil,
        ns.ui.shownPanel(tooltips[3]) ~= nil }, { true, true, true })
    ns.setOption("itemPanels", false)
    refresh()
    flush(); flush()
    test.check("switching back to native releases panel ownership and restores alpha", {
        ns.ui.shownPanel(tooltips[1]), ns.ui.shownPanel(tooltips[2]), ns.ui.shownPanel(tooltips[3]),
        tooltips[1]:GetAlpha(), tooltips[2]:GetAlpha(), tooltips[3]:GetAlpha() }, { nil, nil, nil, 1, 1, 1 })
    local beforeReads, beforeKeys = reads, keys
    anchorReads, paddingWrites = 0, 0
    for _ = 1, 10 do refresh() end
    test.check("hooks left from Pretty perform no native geometry or restore work", {
        reads - beforeReads, keys - beforeKeys, anchorReads, paddingWrites, #pending }, { 0, 0, 0, 0, 0 })
    ns.setOption("itemPanels", true)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("a modifier event can reactivate existing panels without a new refill", {
        ns.ui.shownPanel(tooltips[1]) ~= nil, ns.ui.shownPanel(tooltips[2]) ~= nil,
        ns.ui.shownPanel(tooltips[3]) ~= nil }, { true, true, true })
    TooltipComparisonManager = nil
end
