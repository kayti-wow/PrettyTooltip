-- Native wording and Pretty models consume original input on separate paths.
-- Count parsing and native writes across real readers, refreshes and switches.
return function(test)
    local combined = "Equip: Increases healing done by up to 20 and damage done by up to 10 for all magical spells and effects."
    local data = { type = 0, id = 1, lines = {
        { type = 22, lineIndex = 1, leftText = "Test Item" },
        { type = 0, lineIndex = 2, leftText = combined },
    } }
    local capture = { data = data, lines = {
        { left = { text = "Test Item" } }, { left = { text = combined } },
    } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua", "Integration/ItemLite.lua" }, {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 22 } },
        data = data, lines = capture.lines, comparisons = { capture, capture },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local nativeParses, modelParses, reads, writes, wraps = 0, 0, 0, 0, 0
    local reading = false
    local transform = ns.Stats.itemWording
    ns.Stats.itemWording = function(...)
        if reading then modelParses = modelParses + 1 else nativeParses = nativeParses + 1 end
        return transform(...)
    end
    local read = ns.TooltipTypes[0].read
    ns.TooltipTypes[0].read = function(...)
        reads = reads + 1
        reading = true
        local model = read(...)
        reading = false
        return model
    end
    local tooltips = { world.main, ShoppingTooltip1, ShoppingTooltip2 }
    local setters = {}
    for _, tooltip in ipairs(tooltips) do
        tooltip:SetSize(500, 100)
        tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        tooltip:Show()
        for index = 1, 2 do
            local font = tooltip:GetLeftLine(index)
            local setText, setWrap = font.SetText, font.SetWordWrap
            setters[font] = setText
            font.SetText = function(self, text) writes = writes + 1; return setText(self, text) end
            font.SetWordWrap = function(self, value) wraps = wraps + 1; return setWrap(self, value) end
        end
    end
    ns.ItemLite.register()
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    local function fill()
        -- Blizzard supplies fresh original text before the shared post-call.
        for _, tooltip in ipairs(tooltips) do
            for index, line in ipairs(data.lines) do
                local font = tooltip:GetLeftLine(index)
                setters[font](font, line.leftText)
            end
            post(tooltip, data)
            tooltip:Show()
        end
        flush()
        flush()
    end
    fill()
    test.check("Pretty alone parses the original lines for all three models",
        { reads, modelParses, nativeParses, writes, wraps }, { 3, 2, 0, 0, 0 })
    for _ = 1, 5 do fill() end
    test.check("cached Pretty refreshes do not repeat either parsing path",
        { reads, modelParses, nativeParses, writes, wraps }, { 3, 2, 0, 0, 0 })
    test.check("Pretty still displays all three panels", {
        ns.ui.shownPanel(world.main) ~= nil, ns.ui.shownPanel(ShoppingTooltip1) ~= nil,
        ns.ui.shownPanel(ShoppingTooltip2) ~= nil }, { true, true, true })

    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    fill()
    test.check("Pretty's original modifier never activates native rewriting",
        { nativeParses, writes, world.main:GetLeftLine(2):GetText(), ns.ui.shownPanel(world.main) == nil },
        { 0, 0, combined, true })
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("returning from original reuses the model without native rewriting",
        { reads, modelParses, nativeParses, writes, ns.ui.shownPanel(world.main) ~= nil }, { 3, 2, 0, 0, true })

    ns.setOption("itemPanels", false)
    fill()
    local lite = transform(combined, false, true, true).lite
    test.check("disabling item panels selects only native lite processing",
        { reads, modelParses, nativeParses, writes, wraps, world.main:GetLeftLine(2):GetText(),
            ns.ui.shownPanel(world.main) == nil }, { 3, 2, 2, 3, 3, lite, true })
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("native lite still restores the original on the modifier", world.main:GetLeftLine(2):GetText(), combined)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("native lite switches back without reparsing", { nativeParses, world.main:GetLeftLine(2):GetText() }, { 2, lite })

    ns.setOption("itemPanels", true)
    writes, wraps = 0, 0
    fill()
    local prettyReads, prettyParses = reads, modelParses
    test.check("switching back to Pretty discards native bindings without rewriting",
        { nativeParses, writes, wraps, world.main:GetLeftLine(2):GetText(), ns.ui.shownPanel(world.main) ~= nil },
        { 2, 0, 0, combined, true })
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("old lite bindings cannot rewrite Pretty on later key events",
        { reads, modelParses, nativeParses, writes }, { prettyReads, prettyParses, 2, 0 })

    ns.setOption("layout", "blizzard")
    fill()
    test.check("Blizzard layout selects native wording even with the item flag on",
        { reads, modelParses, nativeParses, world.main:GetLeftLine(2):GetText(), ns.ui.shownPanel(world.main) == nil },
        { prettyReads, prettyParses, 4, lite, true })
    ns.setOption("layout", "pretty")
    test.check("the Pretty route safely rejects invalid tooltips before touching lines", pcall(post, nil, data), true)
end
