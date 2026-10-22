-- Geometry invariants for Pretty-owned placement. No game frames are involved.
return function(test)
    local ns = test.load({ "Core/TooltipPlacement.lua" })
    local solve = ns.PlacementPlan.solve
    local function input(left, top)
        return {
            main = { left = left or 400, top = top or 500, width = 200, height = 150 },
            comparisons = {
                { id = 1, width = 120, height = 240 },
                { id = 2, width = 140, height = 100 },
            },
            screen = { left = 0, bottom = 0, right = 1000, top = 600 },
            gap = 5,
        }
    end
    local function geometry(plan)
        return { plan.main.left, plan.main.top, plan.comparisons[1].left, plan.comparisons[2].left,
            plan.bounds.left, plan.bounds.right, plan.bounds.bottom, plan.bounds.top }
    end

    local initial = input()
    initial.preferredSide = "left"
    local plan = solve(initial)
    test.check("left comparisons use primary nearest main and secondary outermost", geometry(plan),
        { 400, 500, 275, 130, 130, 600, 260, 500 })
    test.check("placement does not mutate input", initial.main, { left = 400, top = 500, width = 200, height = 150 })

    initial.preferredSide = "right"
    plan = solve(initial)
    test.check("right comparisons use secondary nearest main and primary outermost", geometry(plan),
        { 400, 500, 750, 605, 400, 870, 260, 500 })

    initial.previousSide = "left"
    test.check("previous side wins while it still fits", solve(initial).side, "left")
    initial.main.left = 100
    test.check("previous side switches when space is lost", solve(initial).side, "right")
    initial.main.left = 700
    test.check("a preferred side cannot force offscreen placement", solve(initial).side, "left")

    local crowded = input(350, 500)
    crowded.screen.right = 600
    plan = solve(crowded)
    test.check("the side with more available space wins when only it fits", { plan.side, plan.main.left }, { "left", 350 })
    crowded.main.left = 220
    plan = solve(crowded)
    test.check("group slides as a whole when neither side initially fits", geometry(plan),
        { 270, 500, 145, 0, 0, 470, 260, 500 })
    test.check("fitting group slide keeps all panels in bounds", plan.overflow, { horizontal = false, vertical = false })

    local bottom = input(400, 100)
    plan = solve(bottom)
    test.check("vertical clamp accounts for tallest comparison", { plan.main.top, plan.bounds.bottom }, { 240, 0 })
    bottom.main.top = 900
    test.check("vertical clamp accounts for the top screen edge", solve(bottom).main.top, 600)

    local offsetScreen = input(1200, 800)
    offsetScreen.screen = { left = 1000, right = 2000, bottom = 200, top = 900 }
    offsetScreen.previousSide = "left"
    plan = solve(offsetScreen)
    test.check("placement works in a translated coordinate system", { plan.side, plan.main.left, plan.bounds.left },
        { "right", 1200, 1200 })

    local oversized = input(25, 200)
    oversized.screen.right = 300
    oversized.screen.top = 180
    oversized.previousSide = "right"
    plan = solve(oversized)
    test.check("oversized group keeps main visible and reports unavoidable overflow",
        { plan.side, plan.main.left, plan.main.top, plan.overflow },
        { "right", 25, 180, { horizontal = true, vertical = true } })
    test.check("oversized group still separates comparisons", plan.comparisons[1].left - plan.comparisons[2].right, 5)
    oversized.main.width = 400
    test.check("oversized main has a deterministic screen edge", solve(oversized).main.left, 0)

    local single = input(400, 500)
    single.comparisons[2] = nil
    single.preferredSide = "right"
    test.check("single comparison is adjacent on either side", solve(single).comparisons[1].left, 605)
    single.comparisons = {}
    single.main.left = -20
    test.check("main without comparisons still clamps", solve(single).main.left, 0)

    -- Check boundary positions, scales (already expressed in a common space),
    -- and both side preferences through properties rather than saved examples.
    local invariants = true
    for _, scale in ipairs({ 0.65, 1, 1.5, 2 }) do
        for _, left in ipairs({ -200, 0, 100, 350, 700, 1000, 1400 }) do
            for _, side in ipairs({ "left", "right" }) do
                local value = input(left, 100)
                value.preferredSide = side
                value.main.left, value.main.top = value.main.left * scale, value.main.top * scale
                value.main.width, value.main.height = value.main.width * scale, value.main.height * scale
                value.screen.right, value.screen.top = value.screen.right * scale, value.screen.top * scale
                value.gap = value.gap * scale
                for _, comparison in ipairs(value.comparisons) do
                    comparison.width, comparison.height = comparison.width * scale, comparison.height * scale
                end
                local result = solve(value)
                local tolerance = 0.000001
                invariants = invariants and result.bounds.left >= -tolerance
                    and result.bounds.right <= value.screen.right + tolerance
                    and result.bounds.bottom >= -tolerance and result.bounds.top <= value.screen.top + tolerance
                local primary, secondary = result.comparisons[1], result.comparisons[2]
                if result.side == "left" then
                    invariants = invariants and secondary.right <= primary.left and primary.right <= result.main.left
                else
                    invariants = invariants and result.main.right <= secondary.left and secondary.right <= primary.left
                end
            end
        end
    end
    test.check("group bounds and nonoverlap hold across edges and scales", invariants, true)

    for _, value in ipairs({ 0, -1, math.huge, -math.huge, 0 / 0, "200" }) do
        local invalid = input()
        invalid.main.width = value
        test.check("reject invalid main width " .. tostring(value), solve(invalid), nil)
    end
    local invalid = input()
    invalid.comparisons[2].id = 1
    test.check("reject duplicate comparison ids", solve(invalid), nil)
    invalid = input()
    invalid.gap = -1
    test.check("reject negative gaps", solve(invalid), nil)
    invalid = input()
    invalid.screen.right = invalid.screen.left
    test.check("reject empty screen", solve(invalid), nil)
    invalid = input()
    invalid.main.left, invalid.main.width = 1e308, 1e308
    invalid.screen.left, invalid.screen.right = 1e308, 1.5e308
    test.check("reject coordinate arithmetic overflow", solve(invalid), nil)
end
