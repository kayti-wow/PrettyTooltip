-- Exercise the item extension callbacks through real reading, rendering, and
-- live fallback. No extension must preserve the ordinary model and layout.
return function(test)
    local LINE = { None = 0, ItemName = 1, ItemBinding = 2, ClientUpgrade = 99 }
    local data = { type = 0, id = 2000, quality = 1, lines = {
        { type = LINE.ItemName, lineIndex = 1, leftText = "Client item" },
        { type = LINE.None, lineIndex = 2, leftText = "+6 Intellect" },
        { type = LINE.ClientUpgrade, lineIndex = 3, leftText = "Myth 2/6" },
        { type = LINE.None, lineIndex = 4, leftText = "An unhandled line" },
    } }
    local capture = { enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = LINE },
        data = data, lines = {} }
    for index, line in ipairs(data.lines) do capture.lines[index] = { left = { text = line.leftText } } end
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, capture)
    local descriptor = ns.TooltipTypes[0]
    local function read(input) return descriptor.read(world.main, input or data, ns.Game) end
    local baseline = read()
    test.check("no extension allocates no Retail state", baseline.retail, nil)
    test.check("unrecognized client content uses normal extras", #baseline.extras, 2)
    local anchor = CreateFrame("Frame", nil, UIParent)
    local preview = ns.ui.renderPreview(anchor, baseline, 0)
    local baselineWidth, baselineHeight = preview:GetWidth(), preview:GetHeight()

    local events, completed = {}, {}
    local extension = {
        initModel = function(model)
            model.retail = {}
            events[#events + 1] = "init"
        end,
        readLine = function(model, line, context)
            events[#events + 1] = "read " .. context.lineNumber
            if line.type ~= LINE.ClientUpgrade then return false end
            model.retail.upgrade = context.text
            return true
        end,
        afterReadLine = function(model, line, context)
            events[#events + 1] = "after " .. context.lineNumber
            if line.type == LINE.None and context.lineNumber == 2 then model.primary[1].observedAfterReading = true end
        end,
        afterRead = function(model, context)
            events[#events + 1] = "complete"
            completed[#completed + 1] = model
            model.retail.complete = true
            test.check("completion receives no stale line context", context.lineNumber, nil)
        end,
        extendView = function(view, model, context)
            if not model.retail.upgrade then return end
            table.insert(view.header, 2, { id = "client.upgrade", text = model.retail.upgrade,
                style = context.styles.subtitle, color = { 1, 1, 1 }, gap = 4 })
        end,
    }
    descriptor.extension = extension
    local model = read()
    test.check("callbacks run around classification and completion", events,
        { "init", "after 1", "read 2", "after 2", "read 3", "after 3", "read 4", "after 4", "complete" })
    test.check("claimed client line stays out of shared extras", { model.retail.upgrade, #model.extras,
        model.extras[1].left }, { "Myth 2/6", 1, "An unhandled line" })
    test.check("post-line callbacks see the core's completed row", model.primary[1].observedAfterReading, true)
    test.check("native data is not decorated", data.lines[2].observedAfterReading, nil)
    local clone = ns.ui.itemModel({ name = "Sample", quality = 1 })
    test.check("sample models receive independent client state", clone.retail ~= model.retail, true)

    -- Each line's callbacks get a fresh context that reads the read's fields;
    -- state lasts the whole read; the completion sees none of a line's fields.
    local LINE_FIELDS = { "lineNumber", "lineModel", "originalText", "leftText", "text", "rightText", "added" }
    local seen, finished = {}, nil
    descriptor.extension = {
        afterReadLine = function(_, _, context)
            context.state.lines = (context.state.lines or 0) + 1
            seen[#seen + 1] = context
        end,
        afterRead = function(_, context) finished = context end,
    }
    read()
    local stale = {}
    for _, name in ipairs(LINE_FIELDS) do
        if finished[name] ~= nil then stale[#stale + 1] = name end
    end
    test.check("each line gets a fresh context", { #seen, seen[1] ~= seen[2], seen[2].lineNumber,
        seen[2].rootModel == finished.rootModel, seen[2].data == data }, { 4, true, 2, true, true })
    test.check("state lasts the whole read", finished.state.lines, 4)
    test.check("completion sees no line's fields", stale, {})
    descriptor.extension = extension

    -- A wide contribution must affect measurement, not merely draw over an
    -- already-sized panel. The ordinary view is unchanged when detached.
    model.retail.upgrade = string.rep("Long client upgrade ", 12)
    preview = ns.ui.renderPreview(anchor, model, 0)
    test.check("client view content participates in width fitting", preview:GetWidth() > baselineWidth, true)
    local found = false
    for _, font in ipairs(preview.pool) do
        if font:IsShown() and font:GetText() == model.retail.upgrade then found = true end
    end
    test.check("client contribution is drawn", found, true)
    descriptor.extension = nil
    preview = ns.ui.renderPreview(anchor, read(), 0)
    test.check("without extensions the original dimensions return",
        { preview:GetWidth(), preview:GetHeight() }, { baselineWidth, baselineHeight })

    descriptor.extension = extension
    completed = {}
    local nested = read({ type = 0, id = data.id, quality = 1, lines = {
        { type = LINE.ItemName, lineIndex = 1, leftText = "Plans: Client item" },
        { type = LINE.ItemName, lineIndex = 2, leftText = "\nCreated item" },
        { type = LINE.ClientUpgrade, lineIndex = 3, leftText = "Nested upgrade" },
    } })
    test.check("embedded items own separate extension state", nested.created.retail ~= nested.retail, true)
    test.check("client lines route to the embedded item", { nested.created.retail.upgrade,
        nested.retail.upgrade == nil }, { "Nested upgrade", true })
    test.check("embedded completion precedes root completion",
        { completed[1] == nested.created, completed[2] == nested }, { true, true })

    -- Use the live integration to prove partial client failures give control
    -- back to the native tooltip rather than leave a stale Pretty panel.
    C_Timer.After = function() end
    ns.Hooks.install()
    world.main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    world.main:Show()
    local post = world.postCalls[0][1]
    post(world.main, data)
    local panel = ns.ui.panels[world.main]
    test.check("client callbacks work through live presentation", panel:IsShown(), true)
    local readLine = extension.readLine
    extension.readLine = function() error("client read failed") end
    IsShiftKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("client read failure restores native presentation", { panel:IsShown(), world.main:GetAlpha() }, { false, 1 })
    extension.readLine = readLine
    post(world.main, data)
    extension.extendView = function() error("client view failed") end
    IsShiftKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    test.check("client view failure restores native presentation", { panel:IsShown(), world.main:GetAlpha() }, { false, 1 })
end
