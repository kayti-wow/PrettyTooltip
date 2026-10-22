-- The details a panel shows, on the game's own tooltip wherever it shows
-- instead: in the Blizzard layout, and for a type not restyled. The original-
-- tooltip key leaves the game's tooltip as it was.
--
-- They are the addon's own font strings in room the tooltip leaves at its
-- bottom, as the game makes room for an embedded item: bottom padding, and a
-- minimum width. The game's lines are never added to, so the details key
-- shows and hides them at once, in combat too, without the game filling the
-- tooltip again.
local _, ns = ...
if not ns.TooltipTypes then return end
local util = ns.util
local isSecret = util.isSecret
local TooltipTypes = ns.TooltipTypes
local DETAIL_COLOR = ns.Palette.roles.detail
ns.Details = {}
local registered = false

-- The game's own inset from a tooltip's edges to its lines.
local INSET = 10
-- Above the details, as a blank line would leave.
local GAP = 8
local LINE_GAP = 2
local COLUMN_GAP = 16
-- Every detail whose setting is on; the key decides whether they show.
local ALL = { allDetails = true }

local states = setmetatable({}, { __mode = "k" })

local function number(value)
    if isSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- The room the tooltip has without the details: what it has now, unless that
-- is still what the details set, or cannot be read, when the game has just
-- cleared it.
local function baseOf(tooltip, state)
    local right, bottom, left, top = util.call(tooltip.GetPadding, tooltip)
    local minWidth = number((util.call(tooltip.GetMinimumWidth, tooltip)))
    right, bottom, left, top = number(right), number(bottom), number(left), number(top)
    local base, applied = state.base, state.applied
    if not (right and bottom and left and top and minWidth) then
        return base or { right = 0, bottom = 0, left = 0, top = 0, minWidth = 0 }
    end
    local fresh = { right = right, bottom = bottom, left = left, top = top, minWidth = minWidth }
    if not (applied and base) then return fresh end
    -- The game clears the padding on show but keeps the width, so each is
    -- told apart from the details' own on its own.
    if math.abs(bottom - applied.bottom) < .01 then
        fresh.right, fresh.bottom, fresh.left, fresh.top = base.right, base.bottom, base.left, base.top
    end
    if math.abs(minWidth - applied.minWidth) < .01 then fresh.minWidth = base.minWidth end
    return fresh
end

-- keepPadding: the game clears the padding itself, as on hide.
local function giveBack(tooltip, state, keepPadding)
    state.block:Hide()
    local base = state.base
    state.base, state.applied = nil, nil
    if not (base and util.canModify(tooltip)) then return end
    pcall(tooltip.SetMinimumWidth, tooltip, base.minWidth)
    if not keepPadding then pcall(tooltip.SetPadding, tooltip, base.right, base.bottom, base.left, base.top) end
end

local function fontAt(state, side, index)
    local list = state[side]
    local font = list[index]
    if not font then
        font = state.block:CreateFontString(nil, "ARTWORK", "GameTooltipText")
        font:SetRoundLayoutToNearestPixel(true)
        if font.SetWordWrap then font:SetWordWrap(false) end
        font:SetJustifyH(side == "rights" and "RIGHT" or "LEFT")
        list[index] = font
    end
    return font
end

-- Draws the rows into the tooltip's block, hidden, and measures them.
local function draw(state, rows)
    local y, width = GAP, 0
    for index, row in ipairs(rows) do
        local left, right = fontAt(state, "lefts", index), fontAt(state, "rights", index)
        left:SetText(row.left)
        left:SetTextColor(unpack(row.color or DETAIL_COLOR))
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", state.block, "TOPLEFT", 0, -y)
        left:Show()
        local rowWidth = left:GetStringWidth()
        local height = left:GetStringHeight()
        if row.right and row.right ~= "" then
            right:SetText(row.right)
            right:SetTextColor(unpack(row.rightColor or row.color or DETAIL_COLOR))
            right:ClearAllPoints()
            right:SetPoint("TOPRIGHT", state.block, "TOPRIGHT", 0, -y)
            right:Show()
            rowWidth = rowWidth + COLUMN_GAP + right:GetStringWidth()
            height = math.max(height, right:GetStringHeight())
        else
            right:Hide()
        end
        width = math.max(width, rowWidth)
        y = y + height + (index < #rows and LINE_GAP or 0)
    end
    for _, side in ipairs({ "lefts", "rights" }) do
        for index = #rows + 1, #state[side] do state[side][index]:Hide() end
    end
    state.width, state.height = math.ceil(width), math.ceil(y)
    state.block:SetHeight(state.height)
end

local function wanted(state)
    return not ns.originalKeyDown() and ns.detailsKeyDown()
        and not ns.restyles(TooltipTypes[state.dataType].option)
end

-- Takes room for the details while they show and gives it back otherwise.
-- SetPadding resizes the tooltip at once, so it needs no Show, which would run
-- the game's OnShow under the addon's taint; it comes last, after the width.
local function apply(tooltip, state)
    if not (state.rows and wanted(state)) then
        if state.base and util.canModify(tooltip) then giveBack(tooltip, state, false) end
        return
    end
    if not util.canModify(tooltip) then return end
    local base = baseOf(tooltip, state)
    local minWidth = math.max(base.minWidth, state.width + 2 * INSET)
    local bottom = base.bottom + state.height
    state.base, state.applied = base, { bottom = bottom, minWidth = minWidth }
    tooltip:SetMinimumWidth(minWidth)
    tooltip:SetPadding(base.right, bottom, base.left, base.top)
    state.block:Show()
end

local function stateOf(tooltip)
    local state = states[tooltip]
    if state then return state end
    local block = CreateFrame("Frame", nil, tooltip)
    block:SetRoundLayoutToNearestPixel(true)
    block:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", INSET, INSET)
    block:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -INSET, INSET)
    block:Hide()
    state = { block = block, lefts = {}, rights = {} }
    states[tooltip] = state
    -- The game's OnShow clears the padding (GameTooltip_CalculatePadding), so
    -- the details take their room again once the game has shown the tooltip.
    local function shown(visible)
        if state.rows then pcall(apply, visible, state) end
    end
    hooksecurefunc(tooltip, "Show", shown)
    hooksecurefunc(tooltip, "SetShown", function(toggled, visible)
        if not isSecret(visible) and visible then shown(toggled) end
    end)
    -- The game clears its padding on hide, but not on a refill.
    tooltip:HookScript("OnHide", function(hidden)
        state.rows, state.data = nil, nil
        giveBack(hidden, state, true)
    end)
    tooltip:HookScript("OnTooltipCleared", function(cleared)
        state.rows, state.data = nil, nil
        giveBack(cleared, state, false)
    end)
    return state
end

local function anyOn(tooltipType)
    for _, key in ipairs(tooltipType.detailKeys) do
        if ns.option(key) then return true end
    end
    return false
end

-- Retain the latest handover while hidden. Read and draw only when requested,
-- in the modifier event itself, so toggling details never waits for a refill.
local function prepare(tooltip, state)
    local tooltipType = TooltipTypes[state.dataType]
    if state.rows and state.version == (ns.settingsVersion or 0) then return end
    state.rows = nil
    if not anyOn(tooltipType) then return end
    local ok, model = pcall(tooltipType.readDetails or tooltipType.read, tooltip, state.data, ns.Game)
    if not ok or not model then return end
    local built, rows = pcall(tooltipType.details, model, ALL)
    if not built or not rows or #rows == 0 then return end
    if not pcall(draw, state, rows) then return end
    state.rows, state.version = rows, ns.settingsVersion or 0
end

local function onTooltipData(dataType, tooltip, data)
    local tooltipType = TooltipTypes[dataType]
    if ns.restyles(tooltipType.option) or not anyOn(tooltipType) then
        local state = not isSecret(tooltip) and states[tooltip]
        if state then
            state.rows, state.data = nil, nil
            if state.base and util.canModify(tooltip) then giveBack(tooltip, state, false) end
        end
        return
    end
    if not util.canModify(tooltip) or tooltip.prettyTooltipScanner then return end
    if isSecret(data) or type(data) ~= "table" then
        local state = states[tooltip]
        if state then
            state.rows, state.data = nil, nil
            if state.base then giveBack(tooltip, state, false) end
        end
        return
    end
    local state = stateOf(tooltip)
    state.rows, state.data, state.dataType = nil, data, dataType
    if wanted(state) then prepare(tooltip, state) end
    pcall(apply, tooltip, state)
end

-- Called once by the entry file.
function ns.Details.register()
    if registered then return end
    if not ns.Processor.available() then return end
    registered = true
    for dataType, tooltipType in pairs(TooltipTypes) do
        if tooltipType.details then
            ns.Processor.onData("details", dataType, function(tooltip, data)
                onTooltipData(dataType, tooltip, data)
            end)
        end
    end

    ns.Processor.onKey("details", function(key)
        if not (ns.isDetailsKey(key) or ns.isOriginalKey(key)) then return end
        for tooltip, state in pairs(states) do
            if state.data and util.canModify(tooltip) and util.call(tooltip.IsShown, tooltip) then
                if wanted(state) then prepare(tooltip, state) end
                pcall(apply, tooltip, state)
            end
        end
    end)
end
