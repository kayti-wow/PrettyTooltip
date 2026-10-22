-- Retiring native-based Pretty placement must preserve Blizzard layout,
-- its detail padding, and the original-tooltip modifier.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Equipment" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua", "Integration/Details.lua", "UI/Commands.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = data,
        lines = { { left = { text = "Equipment" } } },
    })
    local tooltip, pending, writes = world.main, {}, 0
    local padding, minimum = { 0, 4, 0, 0 }, 100
    tooltip:SetSize(200, 100)
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 400, 600)
    tooltip.GetPadding = function() return unpack(padding) end
    tooltip.SetPadding = function(_, ...) writes = writes + 1; padding = { ... } end
    tooltip.GetMinimumWidth = function() return minimum end
    tooltip.SetMinimumWidth = function(_, value) minimum = value end
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", detailKeys = { "showIDs" },
        key = function(_, item) return item.id end,
        read = function(_, item) return { id = item.id } end,
        details = function(model) return { { left = "Item ID: " .. model.id } } end,
        render = function(panel, native)
            panel:SetSize(260, 180)
            panel:Show()
            ns.ui.alignPanel(panel, native)
        end,
    }
    ns.Hooks.install()
    ns.Details.register()
    ns.Commands.register()
    local function fill()
        for _, callback in ipairs(world.postCalls[0]) do callback(tooltip, data) end
        tooltip:Show()
        flush()
    end
    fill()
    local panel = ns.ui.panels[tooltip]
    test.check("Pretty placement leaves native dimensions and padding intact",
        { panel:IsShown(), tooltip:GetWidth(), tooltip:GetHeight(), writes, padding[2] }, { true, 200, 100, 0, 4 })
    test.check("the legacy placement switch and fitting API are gone",
        { ns.Placement.setEnabled == nil, ns.Native.refitNative == nil, ns.Native.anchorToPanels == nil },
        { true, true, true })

    ns.setOption("layout", "blizzard")
    fill()
    local block
    for _, child in ipairs({ tooltip:GetChildren() }) do
        if child:IsShown() then block = child end
    end
    test.check("Blizzard layout keeps the native tooltip visible and Pretty hidden",
        { tooltip:GetAlpha(), panel:IsShown(), block ~= nil }, { 1, false, true })
    test.check("Blizzard-layout details still reserve their own padding", writes > 0 and padding[2] > 4, true)
    test.check("Blizzard layout keeps the native source anchor", { tooltip:GetPoint(1) },
        { "TOPLEFT", UIParent, "BOTTOMLEFT", 400, 600 })
    SlashCmdList.PRETTYTOOLTIP("placement native")
    test.check("the retired diagnostic cannot change the selected layout", ns.option("layout"), "blizzard")

    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("the original modifier returns detail padding and hides the owned block",
        { padding[2], minimum, block:IsShown(), tooltip:GetAlpha() }, { 4, 100, false, 1 })
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("releasing the original modifier restores Blizzard-layout details", block:IsShown() and padding[2] > 4, true)

    ns.setOption("layout", "pretty")
    fill()
    test.check("switching back to Pretty releases detail padding without fitting native dimensions",
        { panel:IsShown(), tooltip:GetAlpha(), padding[2], minimum, tooltip:GetWidth(), tooltip:GetHeight() },
        { true, 0, 4, 100, 200, 100 })
    ns.setOption("itemPanels", false)
    fill()
    test.check("an unstyled type still uses native layout and details",
        { panel:IsShown(), tooltip:GetAlpha(), block:IsShown(), padding[2] > 4 }, { false, 1, true, true })
end
