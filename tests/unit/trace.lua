-- /ptip trace writes a tooltip's state each frame it changes and the calls
-- that change it, hidden values as "secret", and reports when its time is up.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "UI/Debug.lua" }, { enums = { TooltipDataType = { Item = 0 } } })
    local report, finish
    ns.showReport = function(_, lines) report = lines end
    C_Timer.After = function(_, callback) finish = callback end
    debugstack = function()
        return "[C]: in function 'SetAlpha'\nInterface/AddOns/Test/Test.lua:12: in function <...>\n"
    end
    print = function() end
    local tooltip = world.main
    tooltip:Show()
    tooltip:SetAlpha(1)
    local top = 200
    tooltip.GetTop = function() return top end

    ns.traceTooltips(4)
    local tick
    for _, object in ipairs(world.objects) do
        if object._scripts and object._scripts.OnUpdate then tick = object._scripts.OnUpdate end
    end
    tick()
    tooltip:SetAlpha(0)
    tick()
    tick()
    top = 210
    tick()
    tooltip:SetAlpha(world.secret)
    tick()
    finish()

    local text = table.concat(report, "\n")
    local function has(fragment) return text:find(fragment, 1, true) ~= nil end
    test.check("each change is written once, a frame with none is not",
        select(2, text:gsub("frame %d+  GameTooltip  ", "")), 4)
    test.check("position changes are reported even when size and anchors stay the same", has("pos 0.0,210.0"), true)
    test.check("calls are written with the line that made them",
        has("GameTooltip:SetAlpha(0.0)  from Test/Test.lua:12: in function <...>"), true)
    test.check("hidden values read secret", has("GameTooltip:SetAlpha(secret)"), true)
    test.check("the summary counts no faults when the panel never showed",
        { report[2], report[3] }, { "  the game's tooltip visible under a panel: 0 frames, 0 of them in combat",
            "  a panel shown without its tooltip: 0 frames" })
    local before = #report
    ns.traceTooltips(4)
    test.check("once it reports, a new trace can start", report ~= nil and finish ~= nil and before > 0, true)
    local started
    print = function(text) started = text end
    ns.traceTooltips(4)
    test.check("but not two at once", started, "PrettyTooltip: a trace is already running.")
end
