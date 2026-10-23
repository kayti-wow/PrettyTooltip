-- Refill both native comparisons four times, as in the client capture.
-- Reuse pure wording, but always bind the current native font strings.
return function(test)
    local text = "Equip: Increases healing done by up to 20 and damage done by up to 10 for all magical spells and effects."
    local capture = { data = { type = 0, id = 1 }, lines = {
        { left = { text = "Equipment" } }, { left = { text = text } },
    } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/ItemLite.lua",
        "Integration/Details.lua" }, {
        enums = { TooltipDataType = { Item = 0 },
            TooltipDataLineType = { None = 0, ItemName = 22, ItemSpellTriggerOnProc = 23 } },
        data = capture.data, lines = capture.lines, comparisons = { capture, capture },
    })
    ns.setOption("itemPanels", false)
    ns.setOption("disenchant", false)
    local parse = ns.Stats.itemWording
    local expected = parse(text, false, true, true).lite
    local parses, reads = 0, 0
    ns.Stats.itemWording = function(...)
        parses = parses + 1
        return parse(...)
    end
    ns.TooltipTypes[0].read = function() reads = reads + 1; error("native details must not read a full item") end
    ns.Game.itemType = function() error("ID-only details must not request disenchant metadata") end
    ns.ItemLite.register()
    ns.Details.register()
    local tooltips = { world.main, ShoppingTooltip1, ShoppingTooltip2 }
    local callbacks = 0
    local function fill(tooltip, id)
        local cleared = tooltip:GetScript("OnTooltipCleared")
        if cleared then cleared(tooltip) end
        tooltip:GetLeftLine(1):SetText("Equipment")
        tooltip:GetLeftLine(2):SetText(text)
        -- Fresh tables and line indices are not part of the wording cache.
        local data = { type = 0, id = id, lines = {
            { type = 22, lineIndex = 1, leftText = "Equipment" },
            { type = 0, lineIndex = 2, leftText = text },
        } }
        world.postCalls[0][1](tooltip, data)
        callbacks = callbacks + 1
        tooltip:Show()
    end
    local function refresh()
        fill(tooltips[1], 1)
        for _ = 1, 4 do fill(tooltips[2], 2); fill(tooltips[3], 3) end
    end
    refresh()
    test.check("nine native handovers parse each distinct line once", { callbacks, parses, reads }, { 9, 2, 0 })
    for _ = 1, 24 do refresh() end
    test.check("25 refreshes reuse positive and negative wording results", { callbacks, parses, reads }, { 225, 2, 0 })
    test.check("all three native tooltips still receive the shortened text", {
        tooltips[1]:GetLeftLine(2):GetText(), tooltips[2]:GetLeftLine(2):GetText(), tooltips[3]:GetLeftLine(2):GetText(),
    }, { expected, expected, expected })
    local ids = {}
    for index, tooltip in ipairs(tooltips) do
        for _, child in ipairs(tooltip._children) do
            if child._kind == "Frame" and child._shown then
                for _, font in ipairs(child._children) do
                    if font._kind == "FontString" and font._shown then ids[index] = font:GetText() end
                end
            end
        end
    end
    test.check("native details still show the current item ID on every tooltip", ids,
        { "Item ID: 1", "Item ID: 2", "Item ID: 3" })

    local tooltip = tooltips[2]
    tooltip:AddLine(text)
    local fresh = tooltip:GetLeftLine(3)
    world.postCalls[0][1](tooltip, { type = 0, id = 2, lines = {
        { type = 0, lineIndex = 3, leftText = text },
    } })
    test.check("cached text binds a replacement font string and its new index", { fresh:GetText(), parses }, { expected, 2 })

    local wording = ns.TooltipData.itemWording
    local before = parses
    wording({ type = 23, leftText = text })
    wording({ type = 23, leftText = text })
    test.check("proc and non-proc versions have separate reusable entries", parses - before, 1)
    before = parses
    for _, line in ipairs({ world.secret, world.secretTable, { leftText = world.secret },
        { leftText = text, rightText = world.secret }, { leftText = text, type = world.secret },
        { leftText = text, rightText = "Speed 2.00" } }) do
        test.check("unreadable and two-column lines cannot hit the cache", wording(line), nil)
    end
    test.check("rejected lines never reach stat parsing", parses, before)

    ns.setOption("statColors", false)
    local plain = wording({ type = 0, leftText = text })
    test.check("color settings invalidate existing cached wording", plain, parse(text, false, false, true))
    ns.setOption("statMarkers", false)
    test.check("marker settings invalidate existing cached wording", wording({ type = 0, leftText = text }),
        parse(text, false, false, false))
    before = parses
    ns.setElementSetting("stats", "color", { 1, 0, 0 })
    wording({ type = 0, leftText = text })
    test.check("custom style changes invalidate the wording cache", parses - before, 1)

    ns.setOption("statColors", true)
    ns.setOption("statMarkers", true)
    local original = wording({ type = 0, leftText = text })
    ns.setOption("statColorHealing", { 1, 0, 0 })
    local recolored = wording({ type = 0, leftText = text })
    test.check("a category color edit matches a fresh transformation", recolored, parse(text, false, true, true))
    test.check("a category color edit changes the cached output", recolored.lite ~= original.lite, true)
    local effect = "Chance on hit: Deals 40 Fire damage."
    local originalEffect = wording({ type = 23, leftText = effect })
    ns.setOption("schoolColorFire", { 0, 1, 0 })
    local recoloredEffect = wording({ type = 23, leftText = effect })
    test.check("a school color edit matches a fresh transformation", recoloredEffect, parse(effect, true, true, true))
    test.check("a school color edit changes the cached proc output", recoloredEffect.lite ~= originalEffect.lite, true)
    ns.resetStyles()
    test.check("resetting custom colors restores the original cached wording", wording({ type = 0, leftText = text }), original)
    local changedText = text:gsub("20", "25", 1)
    local changedWording = wording({ type = 0, leftText = changedText })
    test.check("changed amounts match a fresh transformation", changedWording, parse(changedText, false, true, true))
    test.check("changed amounts cannot reuse the previous amount's text", changedWording.lite ~= original.lite, true)

    for index = 1, 600 do wording({ leftText = "Unchanged line " .. index }) end
    before = parses
    wording({ type = 0, leftText = text })
    wording({ type = 0, leftText = text })
    test.check("bounded storage evicts old entries and still reuses new ones", parses - before, 1)

    -- Detail metadata can change without an item ID change. Keep those API
    -- answers fresh rather than caching an incomplete load or an auction price.
    ns.setOption("disenchant", true)
    local level, quality, value = nil, nil, 1
    local requested
    local game = {
        itemType = function(item) requested = item; return { classID = 2, equipLoc = "INVTYPE_2HWEAPON", id = 1 } end,
        itemInfo = function() return { quality = quality } end,
        itemLevel = function() return level end,
    }
    ns.disenchantFor = function(_, q, l) return q and l and { value = value, quality = q, level = l } or nil end
    ns.provideData("disenchant")
    local detail = ns.TooltipTypes[0].readDetails
    tooltip.GetItem = function() return "Equipment", "item:1" end
    tooltip.NumLines = function() error("native details must not walk text") end
    tooltip.GetLeftLine = function() error("native details must not walk text") end
    test.check("unloaded disenchant metadata is not invented", detail(tooltip, { id = 1 }, game).disenchant, nil)
    level, quality = 30, 3
    test.check("a later metadata load is observed for the same ID", detail(tooltip, { id = 1 }, game).disenchant,
        { value = 1, quality = 3, level = 30 })
    value = 2
    test.check("updated disenchant values are not cached", detail(tooltip, { id = 1 }, game).disenchant.value, 2)
    detail(tooltip, { id = 2 }, game)
    test.check("a recipe uses its own ID when GetItem names the crafted item", requested, 2)
end
