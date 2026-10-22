-- Pretty owns dimensions and side selection. Frame anchors carry movement;
-- columns share horizontal space but clamp vertically on their own.
local _, ns = ...
local ui, util = ns.ui, ns.util
if not ui then return end

local placement = { strategy = "frame anchors" }
ns.Placement = placement
local solve = ui.probe("placement plan", ns.PlacementPlan.solve)
local roots = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })
local dragFrame = CreateFrame("Frame") -- No OnUpdate while tooltips are stationary.

local function scale(frame)
    local value = util.number((util.call(frame.GetEffectiveScale, frame)))
    if value and value > 0 then return value end
end

local function rect(frame)
    -- Relative anchors may be protected action buttons. Read their geometry
    -- through guarded calls; never mutate those source frames.
    if util.isSecret(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata")
        or util.call(frame.IsForbidden, frame) == true then return end
    -- GetScaledRect is already in screen pixels. Validate every component
    -- before converting its bottom edge to the top edge used by placement.
    local left, bottom, width, height = util.call(frame.GetScaledRect, frame)
    left, bottom = util.number(left), util.number(bottom)
    width, height = util.number(width), util.number(height)
    if not (left and bottom and width and height) then return end
    return left, bottom + height, width, height
end

local function dragPosition(state)
    local drag = state.drag
    if not drag then return end
    local left, top = rect(state.tooltip)
    if left then return drag.left + left - drag.nativeLeft, drag.top + top - drag.nativeTop end
end

local function fractions(point)
    local x = point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5
    local y = point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
    return x, y
end

local function rootState(tooltip)
    local state = roots[tooltip]
    if not state then
        state = { tooltip = tooltip, members = {} }
        roots[tooltip] = state
    end
    return state
end

local function bind(owner, index, tooltip)
    local previous = owners[tooltip]
    if previous and previous ~= owner and roots[previous] then
        roots[previous].collecting = false
        for oldIndex, member in pairs(roots[previous].members) do
            if member == tooltip then roots[previous].members[oldIndex] = nil end
        end
    end
    owners[tooltip], rootState(owner).members[index] = owner, tooltip
end

local function ownerOf(tooltip)
    if type(tooltip.GetName) ~= "function" then return end
    if not ui.isComparison(tooltip) then return tooltip end
    local name = util.call(tooltip.GetName, tooltip)
    local index = type(name) == "string" and tonumber(name:match("(%d)$"))
    local manager = util.readable(TooltipComparisonManager)
    local owner = type(manager) == "table" and util.readable(manager.tooltip)
    if util.canModify(owner) then
        local tooltips = util.readable(owner.shoppingTooltips)
        if type(tooltips) == "table" then
            for memberIndex, candidate in ipairs(tooltips) do
                if candidate == tooltip then
                    bind(owner, memberIndex, tooltip)
                    return owner
                end
            end
        end
    end
    owner = util.call(tooltip.GetOwner, tooltip)
    if not (owner and ui.panels[owner]) then owner = owners[tooltip] end
    if not (owner and ui.panels[owner]) and type(name) == "string" then
        owner = name:find("^ItemRef") and ItemRefTooltip or GameTooltip
    end
    if owner and ui.panels[owner] then
        if index then
            bind(owner, index, tooltip)
            return owner
        end
    end
end

function placement.owns(tooltip)
    local panel = ui.panels[tooltip]
    return panel ~= nil and not panel.nativeOnly and not panel.parked
end

-- Offsets are in the native frame's units; relative anchors use their own
-- effective scale. The Pretty size replaces the native size in this equation.
local function sourceRect(state, panel, parentScale)
    local tooltip = state.tooltip
    local points = state.points
    if not points then
        points = util.framePoints(tooltip)
        state.points = points
    end
    local panelScale, nativeScale = scale(panel), scale(tooltip)
    local width, height = util.number(panel:GetWidth()), util.number(panel:GetHeight())
    if not (panelScale and nativeScale and width and height and width > 0 and height > 0) then return end
    width, height = width * panelScale, height * panelScale
    local left, top
    if state.drag then
        left, top = dragPosition(state)
        if not left then return end
    elseif state.manual then
        left, top = state.manual.left * parentScale, state.manual.top * parentScale
    elseif points and #points > 0 then
        local horizontal, vertical = points[1], points[1]
        for _, point in ipairs(points) do
            if point[1]:find("LEFT") or point[1]:find("RIGHT") then horizontal = point end
            if point[1]:find("TOP") or point[1]:find("BOTTOM") then vertical = point end
        end
        local function anchor(point)
            local target = point[2] or UIParent
            local x, y, w, h = rect(target)
            if not x then return end
            local fx, fy = fractions(point[3])
            return x + fx * w + point[4] * nativeScale,
                y - (1 - fy) * h + point[5] * nativeScale
        end
        local x = anchor(horizontal)
        local _, y = anchor(vertical)
        if not (x and y) then return end
        local fx = fractions(horizontal[1])
        local _, fy = fractions(vertical[1])
        left, top = x - fx * width, y + (1 - fy) * height
    else
        left, top = rect(tooltip)
        if not left then return end
    end
    return { left = left / parentScale, top = top / parentScale,
        width = width / parentScale, height = height / parentScale }
end

local function anchor(panel, points)
    local kept = panel:GetNumPoints() == #points
    local epsilon = ui.pixel(panel) * .01
    for index, wanted in ipairs(points) do
        local point, relative, relativePoint, x, y = panel:GetPoint(index)
        if point ~= wanted[1] or relative ~= wanted[2] or relativePoint ~= wanted[3]
            or type(x) ~= "number" or type(y) ~= "number"
            or math.abs(x - wanted[4]) >= epsilon or math.abs(y - wanted[5]) >= epsilon then kept = false end
    end
    if kept then
        ui.tally("placement anchors kept")
        return true
    end
    panel:ClearAllPoints()
    for _, point in ipairs(points) do panel:SetPoint(unpack(point)) end
    ui.tally("placement anchor writes")
    return true
end

local function setClamp(panel, left, right, top, bottom, enabled)
    local insets = panel.placementInsets
    if not insets or insets[1] ~= left or insets[2] ~= right or insets[3] ~= top or insets[4] ~= bottom then
        panel:SetClampRectInsets(left, right, top, bottom)
        panel.placementInsets = { left, right, top, bottom }
        ui.tally("placement clamp changes")
    end
    if panel:IsClampedToScreen() ~= enabled then panel:SetClampedToScreen(enabled) end
end

local function anchorMain(state, panel, plan, main, parentScale)
    local panelScale, nativeScale = scale(panel), scale(state.tooltip)
    if not (panelScale and nativeScale) then return false end
    local points = {}
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    if state.drag then
        points = state.drag.points
    elseif state.manual or main.width > screenWidth or main.height > screenHeight then
        local position = state.manual or plan.main
        points[1] = { "TOPLEFT", UIParent, "BOTTOMLEFT", position.left * parentScale / panelScale,
            position.top * parentScale / panelScale }
    elseif state.points and #state.points > 0 then
        -- Replay the source's constraints at Pretty's scale. A TOP/RIGHT pair
        -- constrains separate axes; do not turn two corners into a stretched view.
        local horizontal, vertical = state.points[1], state.points[1]
        for _, point in ipairs(state.points) do
            if point[1]:find("LEFT") or point[1]:find("RIGHT") then horizontal = point end
            if point[1]:find("TOP") or point[1]:find("BOTTOM") then vertical = point end
        end
        for index, point in ipairs(horizontal == vertical and { horizontal } or { horizontal, vertical }) do
            local own = point[1]
            if horizontal ~= vertical then
                own = index == 1 and (own:find("RIGHT") and "RIGHT" or "LEFT")
                    or (own:find("BOTTOM") and "BOTTOM" or "TOP")
            end
            points[#points + 1] = { own, point[2] or UIParent, point[3],
                ui.snap(panel, point[4] * nativeScale / panelScale), ui.snap(panel, point[5] * nativeScale / panelScale) }
        end
    else
        points[1] = { "TOPLEFT", state.tooltip, "TOPLEFT", 0, 0 }
    end
    local comparisonWidth = plan.bounds.width - main.width
    local ratio = parentScale / panelScale
    local left = not plan.overflow.horizontal and plan.side == "left" and -comparisonWidth * ratio or 0
    local right = not plan.overflow.horizontal and plan.side == "right" and comparisonWidth * ratio or 0
    local ownLeft, ownRight, top, bottom = ui.clampInsets(panel)
    local clamped = main.width <= screenWidth and main.height <= screenHeight
    setClamp(panel, left + ownLeft, right + ownRight, top, bottom, clamped)
    return anchor(panel, points)
end

local function syncMouse(tooltip, panel)
    if tooltip ~= ItemRefTooltip or not tooltip.SetHitRectInsets then return end
    local x, y, w, h = rect(tooltip)
    local px, py, pw, ph = rect(panel)
    local factor = scale(tooltip)
    if not (x and px and factor) then return end
    if not panel.placementMouse then
        local a, b, c, d = util.call(tooltip.GetHitRectInsets, tooltip)
        if not (util.number(a) and util.number(b) and util.number(c) and util.number(d)) then return end
        panel.placementMouse = { a, b, c, d }
    end
    local left, right = (px - x) / factor, (x + w - px - pw) / factor
    local top, bottom = (y - py) / factor, (py - ph - y + h) / factor
    local previous = panel.placementHitRect
    if not previous or math.abs(previous[1] - left) > .01 or math.abs(previous[2] - right) > .01
        or math.abs(previous[3] - top) > .01 or math.abs(previous[4] - bottom) > .01 then
        tooltip:SetHitRectInsets(left, right, top, bottom)
        ui.tally("placement hit rect writes")
        if previous then
            previous[1], previous[2], previous[3], previous[4] = left, right, top, bottom
        else
            panel.placementHitRect = { left, right, top, bottom }
        end
    end
    return x, y
end

local function anchorCloseButton(tooltip, panel)
    if tooltip ~= ItemRefTooltip or not panel.close or panel.placementClose then return end
    -- Keep the invisible native close control over the visible X, rather than
    -- leaving another mouse target at the native tooltip's old corner.
    local close = util.readable(tooltip.CloseButton) or util.readable(_G.ItemRefCloseButton)
    if util.canModify(close) then
        local points = util.framePoints(close)
        if points and #points > 0 then
            panel.placementClose = { button = close, points = points }
            close:ClearAllPoints()
            close:SetPoint("CENTER", panel.close, "CENTER", 0, 0)
        end
    end
end

local function dismissOutsideComparisons(tooltip, panel)
    if tooltip ~= ItemRefTooltip or ns.originalKeyDown()
        or util.call(panel.IsMouseOver, panel) ~= false then return end
    local state = roots[tooltip]
    if state and state.drag then return end
    tooltip.updateTooltipTimer = nil
    local tooltips = util.readable(tooltip.shoppingTooltips)
    if type(tooltips) ~= "table" then return end
    if state then state.dismissing = true end
    local hidden = false
    for _, comparison in ipairs(tooltips) do
        if util.canModify(comparison) and util.call(comparison.IsShown, comparison) == true then
            comparison:Hide()
            local view = ui.panels[comparison]
            if view then view:Hide() end
            hidden = true
        end
    end
    local manager = util.readable(TooltipComparisonManager)
    if hidden and type(manager) == "table" then util.call(manager.Clear, manager, tooltip) end
    if state then state.dismissing = nil end
    if not hidden then return end
    return true
end

function placement.refresh(tooltip)
    if not util.canModify(tooltip) then return false end
    local owner = ownerOf(tooltip)
    if not util.canModify(owner) then return false end
    local state, panel = rootState(owner), ui.panels[owner]
    if state.running or state.collecting or not (panel and panel:IsShown() and placement.owns(owner))
        or panel.restorePending or panel.contentPending or not util.call(owner.IsShown, owner) then return false end
    local parentScale = scale(UIParent)
    if not parentScale then return false end
    local main = sourceRect(state, panel, parentScale)
    local width, height = util.number(UIParent:GetWidth()), util.number(UIParent:GetHeight())
    if not (main and width and height and width > 0 and height > 0) then return false end
    local comparisons, visible = {}, {}
    for index, native in pairs(state.members) do
        local comparison = ui.panels[native]
        if comparison and comparison:IsShown() and placement.owns(native) and util.call(native.IsShown, native) then
            if comparison.comparisonPending or comparison.restorePending then return false end
            local factor = scale(comparison)
            if not factor then return false end
            local insets = { ui.clampInsets(comparison) }
            comparisons[#comparisons + 1] = { id = index, width = (comparison:GetWidth() + insets[2]) * factor / parentScale,
                height = comparison:GetHeight() * factor / parentScale }
            visible[index] = { panel = comparison, insets = insets }
        end
    end
    table.sort(comparisons, function(a, b) return a.id < b.id end)
    local anchorType = util.call(owner.GetAnchorType, owner)
    local preferred = type(anchorType) == "string" and (anchorType:find("LEFT") and "left"
        or anchorType:find("RIGHT") and "right") or nil
    local plan = solve({ main = main, comparisons = comparisons,
        screen = { left = 0, bottom = 0, right = width, top = height }, previousSide = state.side,
        preferredSide = preferred })
    if not plan then return false end
    state.running = true
    local ok, applied = pcall(function()
        if not anchorMain(state, panel, plan, main, parentScale) then return false end
        local neighbour, neighbourRight = panel, select(2, ui.clampInsets(panel))
        for position = 1, #comparisons do
            local index = comparisons[plan.side == "left" and position or #comparisons - position + 1].id
            local comparison, insets = visible[index].panel, visible[index].insets
            setClamp(comparison, insets[1], insets[2], insets[3], insets[4], true)
            local offset = 0
            if plan.side == "left" then offset = -insets[2]
            elseif neighbourRight > 0 then offset = neighbourRight * scale(neighbour) / scale(comparison) end
            -- Separate vertical and horizontal constraints, as Blizzard does:
            -- a tall neighbour's clamping must not lift a shorter comparison.
            anchor(comparison, { { "TOP", panel, "TOP", 0, 0 },
                { plan.side == "left" and "RIGHT" or "LEFT", neighbour,
                    plan.side == "left" and "LEFT" or "RIGHT", offset, 0 } })
            comparison.comparisonAnchorPending = nil
            comparison.side = plan.side == "left" and "RIGHT" or "LEFT"
            neighbour, neighbourRight = comparison, insets[2]
        end
        if syncMouse(owner, panel) then anchorCloseButton(owner, panel) end
        return true
    end)
    state.running = false
    if not ok or not applied then ns.Native.restoreNative(owner); return false end
    state.side, state.plan = plan.side, plan
    -- The game's initial fill can show comparisons before ItemRef's OnEnter.
    -- Check the finished Pretty bounds, then commit without comparisons in
    -- this same callback; no OnLeave or later frame is needed to dismiss them.
    if dismissOutsideComparisons(owner, panel) then return placement.refresh(owner) end
    return true
end
placement.refresh = ui.probe("placement refresh", placement.refresh)

function placement.align(_, tooltip, force)
    if not placement.owns(tooltip) then return false end
    if force and not ui.isComparison(tooltip) then rootState(tooltip).points = util.framePoints(tooltip) end
    return placement.refresh(tooltip)
end

function placement.observe(tooltip, dataType)
    -- Native-only refills can use cached manager functions, bypassing their
    -- completion hooks. They must not leave a Pretty transaction open when
    -- the original-tooltip key is released.
    if ns.originalKeyDown() or not placement.owns(tooltip) then return end
    local owner = ownerOf(tooltip)
    if owner then
        local state = rootState(owner)
        if not state.points then state.points = util.framePoints(owner) end
        if ui.isComparison(tooltip) and dataType == Enum.TooltipDataType.Item
            and ns.Hooks and ns.Hooks.comparisonsBatched() then state.collecting = true end
    end
end

function placement.beginComparisons(owner)
    if ns.originalKeyDown() or not util.canModify(owner) then return end
    local state = rootState(owner)
    if not state.points then state.points = util.framePoints(owner) end
    state.collecting = true
    local members = util.readable(owner.shoppingTooltips)
    if type(members) == "table" then
        for index, tooltip in ipairs(members) do
            if util.canModify(tooltip) then
                bind(owner, index, tooltip)
            end
        end
    end
end

function placement.finishComparisons(owner)
    if not util.canModify(owner) then return end
    rootState(owner).collecting = false
    return placement.refresh(owner)
end

function placement.finish(tooltip)
    local owner = ownerOf(tooltip)
    if owner then return placement.finishComparisons(owner) end
end

function placement.moved(tooltip)
    if not placement.owns(tooltip) then return end
    local owner = ownerOf(tooltip)
    if not owner then return end
    local state = rootState(owner)
    if not ui.isComparison(tooltip) and not state.collecting and not state.drag then
        state.points, state.manual = util.framePoints(tooltip), nil
    end
    return placement.refresh(owner)
end

function placement.ownerChanged(tooltip)
    if ui.isComparison(tooltip) then return end
    local state = rootState(tooltip)
    state.points, state.side, state.collecting, state.awaitingOwner = nil, nil, false, true
    state.drag, state.manual = nil, nil
    if tooltip == ItemRefTooltip then dragFrame:SetScript("OnUpdate", nil) end
end

function placement.hidden(tooltip)
    if not ui.isComparison(tooltip) then
        if tooltip == ItemRefTooltip then dragFrame:SetScript("OnUpdate", nil) end
        local state = roots[tooltip]
        if state and state.drag then
            state.drag, state.manual, state.points, state.awaitingOwner = nil, nil, nil, true
        end
        return
    end
    local owner = ownerOf(tooltip)
    local state = owner and roots[owner]
    if state and not state.dismissing then return placement.refresh(owner) end
end

function placement.shown(tooltip)
    if not ui.isComparison(tooltip) then
        local state = rootState(tooltip)
        if state.awaitingOwner and not state.collecting then
            state.points, state.awaitingOwner = util.framePoints(tooltip), false
        end
    end
    return placement.refresh(tooltip)
end

function placement.release(tooltip, panel)
    if panel.placementMouse and util.canModify(tooltip) then
        pcall(tooltip.SetHitRectInsets, tooltip, unpack(panel.placementMouse))
    end
    local close = panel.placementClose
    if close and util.canModify(close.button) then
        pcall(function()
            close.button:ClearAllPoints()
            for _, point in ipairs(close.points) do close.button:SetPoint(unpack(point)) end
        end)
    end
    panel.placementMouse, panel.placementHitRect, panel.placementInsets = nil, nil, nil
    panel.placementClose = nil
    panel:SetClampRectInsets(0, 0, 0, 0)
    panel:SetClampedToScreen(true)
    if tooltip == ItemRefTooltip then dragFrame:SetScript("OnUpdate", nil) end
    if not ui.isComparison(tooltip) then roots[tooltip] = nil end
end

function placement.hookInput(tooltip)
    if tooltip ~= ItemRefTooltip then return end
    tooltip:HookScript("OnDragStart", function()
        if not placement.owns(tooltip) then return end
        local panel = ui.panels[tooltip]
        local left, top = rect(panel)
        if not (panel:IsShown() and left) then return end
        local nativeLeft, nativeTop = rect(tooltip)
        local factor = scale(panel)
        if not (nativeLeft and factor) then return end
        local state = rootState(tooltip)
        state.drag = { left = left, top = top,
            nativeLeft = nativeLeft, nativeTop = nativeTop,
            points = { { "TOPLEFT", tooltip, "TOPLEFT", (left - nativeLeft) / factor, (top - nativeTop) / factor } } }
        anchor(panel, state.drag.points)
        -- The native frame still receives sticky hover/drag input. Only its
        -- hit rectangle needs following during a drag; anchors move the views.
        dragFrame:SetScript("OnUpdate", ui.probe("sticky drag input", function()
            if not (state.drag and placement.owns(tooltip) and tooltip:IsShown()) then
                dragFrame:SetScript("OnUpdate", nil)
                return
            end
            local nativeX = syncMouse(tooltip, panel)
            -- Let anchors carry normal motion. Reconsider the side only when
            -- this drag crosses the space needed by its current comparisons.
            local plan, parentScale = state.plan, scale(UIParent)
            if nativeX and plan and parentScale then
                local desiredLeft = (nativeX + state.drag.left - state.drag.nativeLeft) / parentScale
                local right = UIParent:GetWidth() - desiredLeft - plan.main.width
                local needed = plan.bounds.width - plan.main.width
                if needed > 0 and ((state.side == "left" and desiredLeft < needed and right >= needed)
                    or (state.side == "right" and right < needed and desiredLeft >= needed)) then placement.refresh(tooltip) end
            end
        end))
    end)
    tooltip:HookScript("OnDragStop", function()
        local state = rootState(tooltip)
        if not state.drag then return end
        -- Freeze the actual view after the engine normalizes native anchors.
        -- Its dimensions never enter the saved position's anchor equation.
        local left, top = rect(ui.panels[tooltip])
        local parentScale = scale(UIParent)
        if left and parentScale then state.manual = { left = left / parentScale, top = top / parentScale } end
        dragFrame:SetScript("OnUpdate", nil)
        state.drag, state.points = nil, util.framePoints(tooltip)
        placement.refresh(tooltip)
    end)
end
