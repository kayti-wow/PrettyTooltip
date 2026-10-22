-- Plan a whole tooltip group's placement without reading or moving game frames.
-- Inputs and output rectangles all use the same bottom-origin coordinate space.
local _, ns = ...
local PlacementPlan = {}
ns.PlacementPlan = PlacementPlan

local min, max = math.min, math.max

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function size(value)
    return finite(value) and value > 0
end

local function validSide(side)
    return side == nil or side == "left" or side == "right"
end

local function rectangle(left, top, width, height)
    return {
        left = left,
        right = left + width,
        top = top,
        bottom = top - height,
        width = width,
        height = height
    }
end

local function finiteRectangle(rect)
    return finite(rect.left) and finite(rect.right) and finite(rect.top) and finite(rect.bottom)
end

local function clamp(value, lower, upper)
    return max(lower, min(upper, value))
end

-- Returns nil and a reason for incomplete/invalid geometry. Callers can keep
-- their last completed placement and retry on a later geometry notification.
function PlacementPlan.solve(input)
    if type(input) ~= "table" then return nil, "missing input" end
    local main, comparisons, screen = input.main, input.comparisons or {}, input.screen
    if type(main) ~= "table" or not finite(main.left) or not finite(main.top)
        or not size(main.width) or not size(main.height) then
        return nil, "invalid main rectangle"
    end
    if type(screen) ~= "table" or not finite(screen.left) or not finite(screen.right)
        or not finite(screen.top) or not finite(screen.bottom)
        or screen.right <= screen.left or screen.top <= screen.bottom then
        return nil, "invalid screen rectangle"
    end
    if type(comparisons) ~= "table" then return nil, "invalid comparison list" end
    local gap = input.gap or 0
    if not finite(gap) or gap < 0 then return nil, "invalid gap" end
    if not validSide(input.previousSide) or not validSide(input.preferredSide) then
        return nil, "invalid side"
    end

    local ids, comparisonWidth, height = {}, 0, main.height
    for _, comparison in ipairs(comparisons) do
        if type(comparison) ~= "table" or not size(comparison.width) or not size(comparison.height)
            or (type(comparison.id) ~= "string" and not finite(comparison.id))
            or ids[comparison.id] then
            return nil, "invalid comparison rectangle or id"
        end
        ids[comparison.id] = true
        comparisonWidth = comparisonWidth + gap + comparison.width
        height = max(height, comparison.height)
    end

    local width = main.width + comparisonWidth
    local screenWidth, screenHeight = screen.right - screen.left, screen.top - screen.bottom
    if not finite(width) or not finite(height) or not finite(screenWidth) or not finite(screenHeight) then
        return nil, "geometry overflow"
    end
    local leftSpace = main.left - screen.left
    local rightSpace = screen.right - main.left - main.width
    local fits = {
        left = leftSpace >= comparisonWidth and rightSpace >= 0,
        right = rightSpace >= comparisonWidth and leftSpace >= 0,
    }
    local side
    if input.previousSide and fits[input.previousSide] then
        side = input.previousSide
    elseif input.preferredSide and fits[input.preferredSide] then
        side = input.preferredSide
    elseif fits.left ~= fits.right then
        side = fits.left and "left" or "right"
    elseif leftSpace ~= rightSpace then
        side = leftSpace > rightSpace and "left" or "right"
    else
        side = input.previousSide or input.preferredSide or "left"
    end

    local left = main.left
    if width <= screenWidth then
        -- Slide the complete group once; each panel keeps its spacing/order.
        local groupLeft = side == "left" and left - comparisonWidth or left
        groupLeft = clamp(groupLeft, screen.left, screen.right - width)
        left = side == "left" and groupLeft + comparisonWidth or groupLeft
    elseif main.width <= screenWidth then
        -- An oversized group cannot fit. Keep the main tooltip usable, with
        -- comparisons extending beyond the chosen side rather than overlapping.
        left = clamp(left, screen.left, screen.right - main.width)
    else
        left = screen.left
    end
    local top = height <= screenHeight and clamp(main.top, screen.bottom + height, screen.top) or screen.top
    local plan = {
        main = rectangle(left, top, main.width, main.height),
        comparisons = {},
        side = side,
        overflow = { horizontal = width > screenWidth, vertical = height > screenHeight },
    }

    if side == "left" then
        local edge = left
        for _, comparison in ipairs(comparisons) do
            edge = edge - gap - comparison.width
            plan.comparisons[comparison.id] = rectangle(edge, top, comparison.width, comparison.height)
        end
    else
        local edge = left + main.width
        -- Match Blizzard's visual order: secondary nearest the main tooltip
        -- on the right; primary nearest on the left.
        for index = #comparisons, 1, -1 do
            local comparison = comparisons[index]
            edge = edge + gap
            plan.comparisons[comparison.id] = rectangle(edge, top, comparison.width, comparison.height)
            edge = edge + comparison.width
        end
    end
    local groupLeft = side == "left" and left - comparisonWidth or left
    plan.bounds = rectangle(groupLeft, top, width, height)
    if not finiteRectangle(plan.main) or not finiteRectangle(plan.bounds) then
        return nil, "geometry overflow"
    end
    for _, comparison in pairs(plan.comparisons) do
        if not finiteRectangle(comparison) then return nil, "geometry overflow" end
    end
    return plan
end
