-- Inbox summaries keep mail quantities and addon prices through late fills;
-- single-item tooltips and unrelated owners remain with their existing types.
return function(test)
    local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Mail.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }
    local ns, world = test.load(files, { enums = { TooltipDataType = { Item = 0 } },
        lines = { { left = { text = "Multiple items (2)" } } } })
    local tooltip, pending = world.main, {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending; pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local owner = CreateFrame("CheckButton", "MailItem4Button", UIParent)
    owner.index = 4
    tooltip.GetOwner = function() return owner end
    tooltip.GetTooltipData = function() return nil end
    local count = 9
    GetInboxItem = function(index, slot)
        if index ~= 4 then return end
        if slot == 1 then return "Crab", 2682, 123, count end
        if slot == 2 then return "Ore", 249391, 456, 5 end
    end
    GetInboxItemLink = function(_, slot)
        if slot == 1 then return "|cffffffff|Hitem:2682|h[Crab]|h|r" end
        if slot == 2 then return "|cff1eff00|Hitem:249391|h[Ore]|h|r" end
    end
    ns.Hooks.install()
    local descriptor = ns.TooltipTypes.mail
    local model = descriptor.read(tooltip, {}, ns.Game)
    test.check("Blizzard's heading is expanded from the mail API", #model.attachments, 2)
    test.check("quantities and icons come from each attachment", { model.attachments[1].count,
        model.attachments[2].count, model.attachments[1].icon }, { 9, 5, 123 })
    tooltip:Show(); flush()
    local panel = ns.ui.panels[tooltip]
    test.check("mail completion draws a Pretty panel", { panel:IsShown(), tooltip:GetAlpha(), panel.dataType },
        { true, 0, "mail" })

    -- Auctionator appends these later, after resolving its database keys.
    tooltip:AddLine(GetInboxItemLink(4, 1))
    tooltip:AddDoubleLine("Vendor (9)", "2s25c")
    tooltip:AddDoubleLine("Auction (9)", "8s73c")
    tooltip:AddLine(GetInboxItemLink(4, 2))
    tooltip:AddDoubleLine("Another addon's price", "5s45c")
    tooltip:AddLine("  ")
    tooltip:AddDoubleLine("Total: 14 items", "14s18c")
    tooltip:Show(); flush()
    model = descriptor.read(tooltip, {}, ns.Game)
    test.check("late pricing does not duplicate API attachment rows", #model.attachments, 2)
    test.check("stack labels and prices are preserved", model.attachments[1].prices[2].left, "Auction (9)")
    test.check("other addons' attachment rows survive", model.attachments[2].prices[1].left, "Another addon's price")
    test.check("the bundle total becomes a footer", model.totals[1].right, "14s18c")
    local before = descriptor.key(tooltip)
    count = 8
    test.check("quantity changes invalidate an otherwise identical summary", descriptor.key(tooltip) ~= before, true)
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1); flush()
    test.check("the original modifier restores native mail", { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0); flush()
    test.check("releasing the modifier resumes the mail panel", panel:IsShown(), true)
    ns.setOption("mailPanels", false)
    tooltip:Show(); flush()
    test.check("Mail's Restyle switch restores the native summary", { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
    ns.setOption("mailPanels", true)
    ns.setOption("layout", "blizzard")
    tooltip:Show(); flush()
    test.check("Blizzard layout retains the original mail tooltip", { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
    ns.setOption("layout", "pretty")
    tooltip:Show(); flush()
    test.check("Pretty layout can resume mail rendering", panel:IsShown(), true)
    tooltip:Hide(); tooltip:GetScript("OnHide")(tooltip); flush()
    test.check("native dismissal also dismisses the mail panel", panel:IsShown(), false)

    tooltip.GetTooltipData = function() return { type = 0 } end
    tooltip:Show(); flush()
    test.check("single attachments keep structured item handling", panel:IsShown(), false)
    tooltip.GetTooltipData = function() return nil end
    owner = CreateFrame("Button", "UnrelatedButton", UIParent)
    tooltip:Show(); flush()
    test.check("similar text on another control is not claimed as mail", panel:IsShown(), false)
    local original = GetInboxItem
    GetInboxItem = function() return world.secret end
    test.check("restricted attachment metadata falls back without partial data", ns.Game.mailAttachments(4), nil)
    GetInboxItem = original
end
