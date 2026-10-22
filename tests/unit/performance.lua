-- Profiling must count nested work once, preserve function behavior, and
-- describe the actual capture interval and selected layout.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua",
        "Integration/Native.lua", "Integration/Placement.lua", "UI/Debug.lua", "UI/Commands.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    local now, timers, report, messages = 0, {}, nil, {}
    debugprofilestop = function() return now end
    C_Timer.After = function(seconds, callback) timers[#timers + 1] = { seconds = seconds, callback = callback } end
    print = function(message) messages[#messages + 1] = message end
    ns.showReport = function(_, lines) report = table.concat(lines, "\n") end
    ns.Commands.register()
    SlashCmdList.PRETTYTOOLTIP("perf 10")
    test.check("perf accepts a selected capture duration", timers[1].seconds, 10)
    ns.perfCapture(1)
    test.check("a running capture cannot be overwritten by another timer", #timers, 1)
    local frame
    for _, object in ipairs(world.objects) do if object:GetScript("OnUpdate") then frame = object end end
    for _ = 1, 100 do frame:GetScript("OnUpdate")() end
    local inner = ns.ui.probe("inner", function() now = now + 2; return "ok", nil, 7 end)
    local outer = ns.ui.probe("outer", function()
        now = now + 1
        local a, b, c = inner()
        now = now + 1
        return a, b, c
    end)
    local a, b, c = outer()
    test.check("profiling preserves nil-containing return tuples", { a, b == nil, c }, { "ok", true, 7 })
    test.check("inclusive rows retain inner and outer durations", { ns.ui.perf.time.inner, ns.ui.perf.time.outer }, { 2, 4 })
    test.check("instrumented total counts nested work only once", ns.ui.perf.total, 4)
    test.check("maximum call durations use the same milliseconds as totals", ns.ui.perf.max.outer, 4)
    local failing = ns.ui.probe("failure", function() now = now + 1; error("profiled failure") end)
    local ok, failure = pcall(failing)
    test.check("profiled errors propagate and restore nesting depth", { ok, ns.ui.perf.depth, failure:find("profiled failure", 1, true) ~= nil },
        { false, 0, true })
    now = 10500
    ns.setOption("layout", "blizzard")
    timers[1].callback()
    local function has(text) return report:find(text, 1, true) ~= nil end
    test.check("report uses actual elapsed time rather than requested duration", has("over 10.500 s (requested 10 s)"), true)
    test.check("report snapshots layout at capture start", has("layout pretty"), true)
    test.check("report identifies the frame-anchored implementation", has("placement strategy: frame anchors"), true)
    test.check("a mode switch invalidates the comparison explicitly", has("Layout changed during capture"), true)
    test.check("report includes frames and elapsed-normalized call rates", has("100 frames, 9.5 frames/s") and has("outer: 1 calls (0.1/s)"), true)
    test.check("report includes average and peak call cost", has("4000.00 us/call, 4000.00 us max"), true)
    test.check("report distinguishes aggregate work from overlapping rows", has("instrumented work: 5.000 ms total") and has("do not add rows"), true)
    test.check("capture stops its frame counter and profiling", { ns.ui.perf.on, frame:GetScript("OnUpdate") == nil }, { false, true })
    SlashCmdList.PRETTYTOOLTIP("perf")
    test.check("perf retains its five-second default", timers[2].seconds, 5)
    now = now + 5000
    timers[2].callback()
    SlashCmdList.PRETTYTOOLTIP("perf 99")
    test.check("perf duration is bounded to thirty seconds", timers[3].seconds, 30)
    now = now + 30000
    timers[3].callback()
    SlashCmdList.PRETTYTOOLTIP("perf 0")
    test.check("perf duration is at least one second", timers[4].seconds, 1)
    now = now + 1000
    timers[4].callback()
    local before = ns.ui.perf.calls.outer
    outer()
    test.check("disabled profiling leaves counters idle", ns.ui.perf.calls.outer, before)
end
