-- The game's own tooltip gets the panel's details while their key is held: in
-- the Blizzard layout and for a type not restyled, never under a panel or with
-- the original-tooltip key held. They are the addon's own text in room the
-- tooltip leaves at its bottom, so the key shows and hides them at once, in
-- combat too, and the game's lines are never added to.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
        data = { type = 0, id = 1307, quality = 1, lines = {
            { type = 1, lineIndex = 1, leftText = "Gold Pickup Schedule" },
            { type = 2, lineIndex = 2, leftText = "Soulbound" },
        } },
        lines = { { left = { text = "Gold Pickup Schedule" } }, { left = { text = "Soulbound" } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Details.lua" }, capture)
    ns.Details.register()

    -- The room a tooltip leaves, as the game keeps it.
    local function roomOf(tooltip)
        tooltip._room = { padding = { 0, 0, 0, 0 }, minWidth = 0 }
        tooltip.GetPadding = function(self) return unpack(self._room.padding) end
        tooltip.SetPadding = function(self, ...) self._room.padding = { ... } end
        tooltip.GetMinimumWidth = function(self) return self._room.minWidth end
        tooltip.SetMinimumWidth = function(self, width) self._room.minWidth = width end
    end
    local tooltip = world.main
    roomOf(tooltip)
    tooltip:Show()

    -- The details' text, top first, while they show; nil while they do not.
    local function details(shown)
        for _, child in ipairs(shown._children) do
            if child._kind == "Frame" and child._shown then
                local texts = {}
                for _, font in ipairs(child._children) do
                    if font._kind == "FontString" and font._shown then texts[#texts + 1] = font._text end
                end
                return texts
            end
        end
    end
    local function fill(filled)
        filled = filled or tooltip
        local cleared = filled:GetScript("OnTooltipCleared")
        if cleared then cleared(filled) end
        world.postCalls[0][1](filled, capture.data)
    end
    local function key(name, down) world.fireEvent("MODIFIER_STATE_CHANGED", name, down and 1 or 0) end

    fill()
    test.check("under a panel the game's tooltip is left alone", details(tooltip), nil)
    ns.setOption("layout", "blizzard")
    fill()
    test.check("the Blizzard layout shows the ID below the lines", details(tooltip), { "Item ID: 1307" })
    local rounded = true
    for _, child in ipairs({ tooltip:GetChildren() }) do
        rounded = rounded and child:GetRoundLayoutToNearestPixel()
        for _, region in ipairs({ child:GetRegions() }) do
            rounded = rounded and region:GetRoundLayoutToNearestPixel()
        end
    end
    test.check("owned details and their text use native pixel rounding", rounded, true)
    test.check("rounding owned details leaves the native tooltip policy alone", tooltip:GetRoundLayoutToNearestPixel(), false)
    test.check("the game's lines are not added to", tooltip:NumLines(), 2)
    local height = tooltip._room.padding[2]
    test.check("the tooltip leaves room at its bottom", height > 0, true)
    test.check("and is at least as wide as the details", tooltip._room.minWidth > 0, true)
    -- The game's OnShow clears the padding as it shows the tooltip.
    tooltip._room.padding = { 0, 0, 0, 0 }
    tooltip:Show()
    test.check("the details take their room again once the game shows the tooltip", tooltip._room.padding[2], height)
    local shows = 0
    hooksecurefunc(tooltip, "Show", function() shows = shows + 1 end)

    capture.shiftUp = true
    key("LSHIFT", false)
    test.check("releasing Shift hides them at once", details(tooltip), nil)
    test.check("and gives the room back", { tooltip._room.padding[2], tooltip._room.minWidth }, { 0, 0 })
    InCombatLockdown = function() return true end
    capture.shiftUp = nil
    key("LSHIFT", true)
    test.check("Shift shows them again, in combat too", details(tooltip), { "Item ID: 1307" })
    test.check("in the same room", tooltip._room.padding[2], height)
    InCombatLockdown = function() return false end
    IsAltKeyDown = function() return true end
    key("LALT", true)
    test.check("the original-tooltip key shows the game's tooltip as it was", details(tooltip), nil)
    IsAltKeyDown = function() return false end
    key("LALT", false)
    test.check("and releasing it brings them back", details(tooltip), { "Item ID: 1307" })
    key("LCTRL", true)
    test.check("other keys change nothing", details(tooltip), { "Item ID: 1307" })
    test.check("no key shows the tooltip again, which would run the game's OnShow", shows, 0)

    capture.shiftUp = true
    fill()
    test.check("a tooltip filled without Shift has them ready", details(tooltip), nil)
    capture.shiftUp = nil
    key("LSHIFT", true)
    test.check("for the key to show", details(tooltip), { "Item ID: 1307" })

    -- The game takes room of its own while it fills, as for an embedded item.
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    tooltip._room.padding = { 0, 4, 0, 0 }
    world.postCalls[0][1](tooltip, capture.data)
    test.check("room the tooltip already had is kept under the details", tooltip._room.padding[2], 4 + height)
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    test.check("a refill gives the details' room back", { details(tooltip), tooltip._room.padding[2] }, { nil, 4 })
    tooltip._room.padding = { 0, 0, 0, 0 }
    tooltip._room.minWidth = 300
    fill()
    test.check("a wider minimum the game set is kept", tooltip._room.minWidth, 300)
    tooltip._room.padding = { 0, 0, 0, 0 }
    tooltip:GetScript("OnHide")(tooltip)
    test.check("on hide the game clears the padding; the minimum width is given back",
        { details(tooltip), tooltip._room.padding[2], tooltip._room.minWidth }, { nil, 0, 300 })

    ns.setOption("layout", "pretty")
    ns.setOption("itemPanels", false)
    tooltip:Show()
    fill()
    test.check("a type not restyled gets them too", details(tooltip), { "Item ID: 1307" })

    -- The comparison manager clears a comparison, then fills it with append.
    local comparison = CreateFrame("GameTooltip", "ShoppingTooltip1", UIParent)
    roomOf(comparison)
    comparison.GetProcessingTooltipInfo = function() return { append = true } end
    comparison:Show()
    fill(comparison)
    test.check("a comparison gets them", details(comparison), { "Item ID: 1307" })
    capture.shiftUp = true
    key("LSHIFT", false)
    test.check("and Shift hides them there too", { details(comparison), details(tooltip) }, { nil, nil })
    capture.shiftUp = nil

    PrettyTooltipDB = { itemLite = true }
    ns.migrateOptions()
    test.check("1.3's lite mode becomes items not restyled", { PrettyTooltipDB.itemPanels, PrettyTooltipDB.itemLite },
        { false, nil })
    PrettyTooltipDB = { itemLite = false }
    ns.migrateOptions()
    test.check("lite mode off leaves items restyled", { PrettyTooltipDB.itemPanels, PrettyTooltipDB.itemLite }, { nil, nil })
end
