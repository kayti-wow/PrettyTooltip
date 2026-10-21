-- Follow cursor. A tooltip type left off is never touched, so addons that place
-- tooltips themselves keep doing so.
local _, ns = ...
ns.Cursor = {}
local util = ns.util
local registered = false

local OFFSET = 16
local placing = false
local wasClamped
-- A frame of the addon's that sits at the cursor; GameTooltip hangs from it
-- while following, so the game moves both in the same frame. Anchored to,
-- never parented: GameTooltip keeps its own parent, strata, and visibility.
local tracker
local trackedX, trackedY, anchoredPoint, anchoredHeight

-- Kept on screen, every resize of the larger hidden tooltip near an edge would
-- shift the panel; the panel keeps itself on screen instead.
local function unclamp()
    if wasClamped ~= nil then return end
    local clamped = util.call(GameTooltip.IsClampedToScreen, GameTooltip)
    if type(clamped) ~= "boolean" then return end
    if pcall(GameTooltip.SetClampedToScreen, GameTooltip, false) then wasClamped = clamped end
end

local function reclamp()
    if wasClamped == nil then return end
    if not util.canModify(GameTooltip) then return end
    if pcall(GameTooltip.SetClampedToScreen, GameTooltip, wasClamped) then wasClamped = nil end
end

local function snap(region, value)
    return ns.ui and ns.ui.snap and ns.ui.snap(region, value) or value
end

-- Moves the tracker to the cursor, on whole pixels, so the tooltip and the
-- panel hanging from it stay sharp; only when the cursor has moved.
local function moveTracker()
    local x, y = GetCursorPosition()
    local scale = util.number(UIParent:GetEffectiveScale())
    x, y = util.number(x), util.number(y)
    if not (x and y and scale and scale > 0) then return false end
    if x == trackedX and y == trackedY then return true end
    trackedX, trackedY = x, y
    tracker:ClearAllPoints()
    tracker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", snap(UIParent, x / scale), snap(UIParent, y / scale))
    return true
end

-- The panel hangs from the hidden tooltip's top, and refreshes briefly resize
-- that tooltip; anchoring its top the panel's height above the cursor keeps the
-- panel still. Anchored again only when that height changes. The game's own
-- tooltip is placed by its bottom instead, as its height can be hidden from
-- addons (a secret value) when its text is.
local function place()
    if not util.canModify(GameTooltip) then return false end
    local panel = ns.ui and ns.ui.shownPanel(GameTooltip)
    local point, height = "BOTTOMLEFT", 0
    if panel then
        local scale = util.number(GameTooltip:GetEffectiveScale())
        local panelHeight = util.number(panel:GetHeight())
        local panelScale = util.number(panel:GetEffectiveScale())
        if not (scale and scale > 0 and panelHeight and panelScale and panelScale > 0) then return false end
        point, height = "TOPLEFT", panelHeight * panelScale / scale
        unclamp()
    else
        reclamp()
    end
    if anchoredPoint == point and anchoredHeight and math.abs(height - anchoredHeight) < .01 then return true end
    placing = true
    local ok = pcall(function()
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint(point, tracker, "BOTTOMLEFT", snap(GameTooltip, OFFSET),
            snap(GameTooltip, OFFSET + height))
    end)
    placing = false
    if not ok then
        anchoredPoint, anchoredHeight = nil, nil
        return false
    end
    anchoredPoint, anchoredHeight = point, height
    -- Cursor placement replaces the default anchor. Release the old panel
    -- hold's geometry immediately, while Native can still defer its size fit.
    if panel then pcall(ns.ui.alignPanel, panel, GameTooltip, true) end
    return true
end

function ns.Cursor.register()
    if registered then return end
    local TYPES = Enum and Enum.TooltipDataType
    if not (ns.Processor.available() and TYPES and ns.TOOLTIP_TYPES) then return end
    registered = true
    tracker = CreateFrame("Frame", nil, UIParent)
    tracker:SetSize(1, 1)
    tracker:Hide()
    local follower = tracker
    local function forgetPlacement()
        trackedX, trackedY, anchoredPoint, anchoredHeight = nil, nil, nil, nil
    end

    -- Only default-anchored tooltips follow, as with EllesmereUI; bags re-anchor
    -- theirs on every refresh.
    local defaultAnchored = false
    local cursorKey, originalPoints
    local function stop()
        follower:Hide()
        forgetPlacement()
        reclamp()
        cursorKey, originalPoints = nil, nil
    end
    -- A fading tooltip moved off the screen (Integration/Native.lua) stays
    -- there, shown, after its fade; moving or clamping it would bring it back
    -- into view. Native restores its saved anchors when it is reused.
    local function parked()
        return ns.Native ~= nil and ns.Native.isParked(GameTooltip)
    end
    local function restoreAnchor(keepPanel)
        follower:Hide()
        forgetPlacement()
        if not util.canModify(GameTooltip) then return end
        if parked() then
            originalPoints = nil
            return
        end
        reclamp()
        if not originalPoints then return end
        -- A tooltip being hidden keeps its panel for a frame; it stays where it
        -- stands rather than following the tooltip back to its own anchor.
        local panel = ns.ui and ns.ui.shownPanel(GameTooltip)
        local hiding = not util.call(GameTooltip.IsShown, GameTooltip)
        if panel and (hiding or keepPanel) then pcall(ns.ui.pinPanel, panel) end
        -- Restore without SetOwner, which can clear the tooltip's content.
        local points = originalPoints
        local ok = pcall(function()
            GameTooltip:ClearAllPoints()
            for _, point in ipairs(points) do GameTooltip:SetPoint(unpack(point)) end
        end)
        if not ok then return end
        originalPoints = nil
        if panel and not hiding and not keepPanel then pcall(ns.ui.alignPanel, panel, GameTooltip) end
    end
    local function refresh(allowHidden)
        if not util.canModify(GameTooltip) or parked() then follower:Hide(); return end
        local follows = (allowHidden or util.call(GameTooltip.IsShown, GameTooltip))
            and defaultAnchored and cursorKey and ns.option(cursorKey)
            and not (ns.option("cursorDisableInCombat") and InCombatLockdown())
        if follows then
            if not follower:IsShown() and not originalPoints then
                originalPoints = util.framePoints(GameTooltip)
                if not originalPoints or #originalPoints == 0 then return end
            end
            -- Shown and placed at the cursor before the tooltip hangs from it.
            follower:Show()
            if not (moveTracker() and place()) then restoreAnchor() end
        elseif follower:IsShown() then
            -- Keep the cursor preference for combat ending.
            restoreAnchor()
        end
    end
    follower:SetScript("OnUpdate", function() refresh() end)
    follower:RegisterEvent("PLAYER_REGEN_DISABLED")
    follower:RegisterEvent("PLAYER_REGEN_ENABLED")
    follower:SetScript("OnEvent", function() refresh() end)

    hooksecurefunc(GameTooltip, "SetOwner", function()
        defaultAnchored = false
        stop()
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
        if tooltip == GameTooltip then defaultAnchored = true end
    end)

    -- The game re-places a default tooltip when it refreshes; undone at once.
    hooksecurefunc(GameTooltip, "SetPoint", function()
        if follower:IsShown() and not placing then
            anchoredHeight = nil
            refresh()
        end
    end)

    -- Return to the real anchor before Native saves it for parking. Saving
    -- our tracker instead would lose the default position on the next hover.
    if GameTooltip.FadeOut then
        hooksecurefunc(GameTooltip, "FadeOut", function(self)
            if util.canModify(self) and follower:IsShown() then restoreAnchor(true) end
        end)
    end

    -- Cleared before every new content, so a tooltip type left off is not dragged along.
    GameTooltip:HookScript("OnTooltipCleared", function()
        -- A refresh can reuse the same owner and anchor. Restore before
        -- forgetting it, so its next handover cannot save our cursor position.
        restoreAnchor()
        stop()
    end)
    GameTooltip:HookScript("OnHide", stop)

    for _, tooltipType in ipairs(ns.TOOLTIP_TYPES) do
        for _, typeName in ipairs(tooltipType.types) do
            local dataType = TYPES[typeName]
            if dataType then
                ns.Processor.onData("cursor", dataType, function(tooltip)
                    if tooltip == GameTooltip then
                        cursorKey = tooltipType.cursor
                        refresh(true)
                    end
                end)
            end
        end
    end
end
