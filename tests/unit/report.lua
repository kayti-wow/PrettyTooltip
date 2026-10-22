-- The diagnostic commands show their findings in a window of text to copy,
-- under a line naming the addon's version and the client.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "UI/Report.lua", "UI/Debug.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "1.2.0" or nil end }
    GetPhysicalScreenSize = function() return 1920, 1080 end
    ns.dumpPixel()
    local window = PrettyTooltipReport
    local lines = {}
    for line in (window.edit:GetText() .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    test.check("a diagnostic opens the report window", { window:IsShown(), window.title:GetText(), #lines },
        { true, "PrettyTooltip pixel", 2 })
    test.check("the report names the version and client", lines[1],
        "PrettyTooltip 1.2.0, client 1.60.1 (0), interface 16001, enUS")
    test.check("the findings follow", lines[2]:match("^Snapping with the addon's own math") ~= nil, true)

    -- Escape codes are shown as written, not drawn.
    ns.showReport("dump", { "1. |cffff0000Red|r" })
    test.check("escape codes are shown as written", window.edit:GetText():match("\n(.*)$"), "1. ||cffff0000Red||r")
end
