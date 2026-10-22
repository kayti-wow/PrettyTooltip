-- /ptip trace writes a tooltip's state each frame it changes and the calls
-- that change it, hidden values as "secret", and reports when its time is up.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "UI/Debug.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    local report, finish, scheduledSeconds
    ns.showReport = function(_, lines) report = lines end
    C_Timer.After = function(seconds, callback) scheduledSeconds, finish = seconds, callback end
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
    local traceFrame
    for _, object in ipairs(world.objects) do
        if object._scripts and object._scripts.OnUpdate then traceFrame = object end
    end
    local function tick() traceFrame:GetScript("OnUpdate")() end
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
    test.check("each trace identifies the selected layout at capture start", has("layout: pretty"), true)
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
    finish()

    -- Comparisons and their panels can be created after tracing starts. Watch
    -- their calls too, including a hide/show that ends before the next frame.
    ns.traceTooltips(7)
    local shopping = ShoppingTooltip1
    local hide = shopping.Hide
    local equipped = ns.ui.getPanel(shopping)
    equipped:Show()
    equipped.comparisonPending = true
    local linked = CreateFrame("GameTooltip", "ItemRefShoppingTooltip1", UIParent)
    local linkedSecond = CreateFrame("GameTooltip", "ItemRefShoppingTooltip2", UIParent)
    TooltipComparisonManager = {
        tooltip = GameTooltip,
        Initialize = function() end,
        SetItemTooltip = function() return true end,
        AnchorShoppingTooltips = function() end,
        Clear = function() end,
    }
    tick()
    equipped:SetShown(false)
    equipped:GetScript("OnHide")(equipped)
    equipped:SetShown(true)
    equipped:ClearAllPoints()
    equipped:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, 0)
    shopping:GetScript("OnTooltipCleared")(shopping)
    linked:SetShown(true)
    linkedSecond:SetShown(true)
    ShoppingTooltip2:SetShown(true)
    TooltipComparisonManager:Initialize(GameTooltip)
    TooltipComparisonManager:SetItemTooltip(true)
    TooltipComparisonManager:AnchorShoppingTooltips(true, false)
    TooltipComparisonManager:Clear(GameTooltip)
    debugstack = function()
        return '[string "@Interface\\AddOns\\PrettyTooltip\\UI\\Debug.lua"]:1: in function <...>\n'
            .. 'Interface\\AddOns\\Other\\Tooltip.lua:42: in function <...>\n'
    end
    shopping:SetAlpha(0)
    for _ = 1, 5000 do shopping:SetAlpha(0) end
    test.check("tracing does not replace the native Hide method", shopping.Hide == hide, true)
    finish()
    text = table.concat(report, "\n")
    test.check("transient equipped panel hides and shows are captured between frame samples",
        has("ShoppingTooltip1.panel:SetShown(false)") and has("ShoppingTooltip1.panel:SetShown(true)")
            and has("ShoppingTooltip1.panel OnHide"), true)
    test.check("equipped panel anchor changes and pending work are recorded",
        has("ShoppingTooltip1.panel:ClearAllPoints()") and has("ShoppingTooltip1.panel:SetPoint(TOPLEFT")
            and has("comparisonPending"), true)
    test.check("native clears are captured", has("ShoppingTooltip1 OnTooltipCleared"), true)
    test.check("chat-link comparison frames created during a trace are included",
        has("ItemRefShoppingTooltip1:SetShown(true)") and has("ItemRefShoppingTooltip2:SetShown(true)")
            and has("ShoppingTooltip2:SetShown(true)"), true)
    test.check("comparison recording uses the selected capture duration",
        scheduledSeconds == 7 and has("trace over 7 s"), true)
    test.check("comparison lifecycle hooks retain their method names",
        has("TooltipComparisonManager:Initialize(") and has("TooltipComparisonManager:SetItemTooltip(true")
            and has("TooltipComparisonManager:AnchorShoppingTooltips(true, false)")
            and has("TooltipComparisonManager:Clear("), true)
    test.check("zero-alpha spam cannot exhaust the event log",
        has("redundant zero-alpha calls omitted: 5000") and not has("event log capped"), true)
    test.check("Windows stack paths skip the trace helper and retain the actual caller",
        has("ShoppingTooltip1:SetAlpha(0.0)  from Other/Tooltip.lua:42:"), true)

    -- Hitting the event limit must not release the active session while its
    -- completion timer still owns the shared trace buffer.
    ns.traceTooltips(4)
    for _ = 1, 4100 do shopping:Show() end
    ns.traceTooltips(4)
    test.check("a capped event log still owns its trace until the timer finishes",
        started, "PrettyTooltip: a trace is already running.")
    shopping:Show()
    shopping.GetTop = function() return 777 end
    equipped:GetScript("OnHide")(equipped)
    TooltipComparisonManager:SetItemTooltip(false)
    tick()
    finish()
    text = table.concat(report, "\n")
    test.check("a capped trace keeps sampling frames and reports its limit",
        has("1 frames (event log capped at 4000 calls)") and has("pos 0.0,777.0")
            and has("frame samples and lifecycle events cover the full duration")
            and has("ShoppingTooltip1.panel OnHide") and has("TooltipComparisonManager:SetItemTooltip(false"), true)

    -- A zero-alpha native child can steal mouse focus in the middle of a
    -- sticky panel without changing either tooltip's geometry or alpha.
    local sticky = ItemRefTooltip
    sticky:SetAlpha(0)
    sticky.IsMouseOver = function() return true end
    local stickyPanel = ns.ui.getPanel(sticky)
    stickyPanel:EnableMouse(false)
    local invisible = CreateFrame("Button", "InvisibleStickyControl", sticky)
    invisible:SetSize(80, 40)
    invisible:SetAlpha(0)
    local foci = { sticky }
    GetMouseFoci = function() return foci end
    GetCursorPosition = function() return 900, 500 end
    ns.traceTooltips(4)
    tick()
    sticky:GetScript("OnEnter")(sticky)
    foci = { invisible, sticky }
    sticky:GetScript("OnLeave")(sticky)
    tick()
    tick()
    test.check("tracing does not add mouse handlers to a noninteractive panel",
        stickyPanel:GetScript("OnEnter") == nil and stickyPanel:GetScript("OnLeave") == nil, true)
    finish()
    text = table.concat(report, "\n")
    test.check("sticky enter and leave events include the mouse coordinates",
        has("ItemRefTooltip OnEnter") and has("ItemRefTooltip OnLeave") and has("cursor 900.0,500.0"), true)
    test.check("an invisible child taking mouse focus is identified with parent, opacity and bounds",
        has("InvisibleStickyControl parent ItemRefTooltip {shown  alpha 0.0") and has("size 80.0x40.0"), true)
    test.check("geometric hover remains visible independently of mouse focus", has("hover true"), true)
    test.check("unchanged mouse focus is not repeated each frame",
        select(2, text:gsub("frame %d+  mouse ", "")), 2)

    ns.traceTooltips(4)
    foci = { world.secret }
    tick()
    GetMouseFoci = function() return world.secretTable end
    tick()
    GetMouseFoci = nil
    GetMouseFocus = function() return invisible end
    tick()
    finish()
    text = table.concat(report, "\n")
    test.check("restricted focus objects and tables are redacted", has("restricted") and has("focus restricted"), true)
    test.check("clients with the older mouse focus API still identify the invisible control",
        has("InvisibleStickyControl parent ItemRefTooltip"), true)
    ns.traceTooltips(4)
    tick()
    ns.setOption("layout", "blizzard")
    finish()
    text = table.concat(report, "\n")
    test.check("the recorded Pretty mode belongs to capture start rather than report time",
        has("layout: pretty"), true)
end
