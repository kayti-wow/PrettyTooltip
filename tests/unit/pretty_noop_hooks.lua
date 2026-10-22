-- No-op callbacks must not force native layout through an access probe.
-- Calls that actually inspect or mutate the native frame still check access.
return function(test)
    local item = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Equipment" } } }
    local capture = { data = item, lines = { { left = { text = "Equipment" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = item, lines = capture.lines,
        comparisons = { capture },
    })
    local pending = {}
    C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, fn in ipairs(callbacks) do fn() end
    end
    local tooltip = world.main
    tooltip:SetSize(200, 100)
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    tooltip:Show()
    tooltip.GetPadding = function() return 0, 0, 0, 0 end
    tooltip.SetPadding = function() end
    local modelReads = 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, data) return data.id end,
        read = function() modelReads = modelReads + 1; return {} end,
        render = function(panel) panel:SetSize(200, 100); panel:Show() end,
    }
    ns.Hooks.install()
    world.postCalls[0][1](tooltip, item)
    flush()
    local panel = ns.ui.panels[tooltip]
    local getWidth, widthReads = tooltip.GetWidth, 0
    tooltip.GetWidth = function(self) widthReads = widthReads + 1; return getWidth(self) end
    for _ = 1, 20 do tooltip:SetAlpha(0) end
    test.check("repeated zero-alpha callbacks perform no native layout probes", widthReads, 0)
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 1, 0)
    test.check("external anchor changes still check native frame access", widthReads > 0, true)
    widthReads = 0
    tooltip:SetAlpha(.5)
    test.check("an external alpha change is checked once, without probing our recursive write", widthReads, 1)
    test.check("external alpha still updates the saved opacity and keeps native text hidden",
        { panel.nativeAlpha, tooltip:GetAlpha() }, { .5, 0 })

    local font = tooltip:GetLeftLine(1)
    local getText, polling, pollReads = font.GetText, false, 0
    font.GetText = function(self)
        if polling then pollReads = pollReads + 1 end
        return getText(self)
    end
    local tick = panel:GetScript("OnUpdate")
    for _ = 1, 10 do
        world.postCalls[0][1](tooltip, item)
        flush()
        polling = true
        tick(panel, .2)
        polling = false
    end
    test.check("completed refresh checks avoid redundant periodic fingerprint scans", pollReads, 0)
    polling = true
    tick(panel, .06)
    polling = false
    test.check("a tooltip without further handovers still receives its periodic scan", pollReads > 0, true)
    local before = modelReads
    font:SetText("Changed without a handover")
    tick(panel, .3)
    flush()
    test.check("quiet tooltips still redraw when an addon rewrites a line in place", modelReads, before + 1)

    local oldAlpha = tooltip.SetAlpha
    local mutations = 0
    tooltip.SetAlpha = function(...) mutations = mutations + 1; return oldAlpha(...) end
    tooltip.IsProtected = function() return true end
    tooltip:SetAlpha(.8)
    test.check("protected native frames receive no recursive cosmetic write", mutations, 1)
    tooltip.IsProtected = function() return false end
    test.check("secret alpha handling still fails closed", pcall(oldAlpha, tooltip, world.secret), true)
    test.check("secret alpha dismisses the replacement", panel:IsShown(), false)
end
