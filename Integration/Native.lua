-- Native tooltip visibility, fade parking, and input restoration while Pretty
-- panels own their size and placement. Blizzard-layout details are separate.
local _, ns = ...
local ui = ns.ui
if not ui then return end

local isSecret = ns.util.isSecret
local util = ns.util
local panels, probe = ui.panels, ui.probe
local native = {}
ns.Native = native

-- ItemRefTooltip remains mouse-enabled for comparison hover and dragging.
-- Its invisible child buttons (such as DungeonJournal's source-line button)
-- must not intercept mouse input through the replacement panel.
local function suppressChildMouse(tooltip, panel)
    if tooltip ~= ItemRefTooltip or not (panel.nativeAlpha and panel:IsShown()) then return end
    if not util.canModify(tooltip) then return end
    local ok, children = pcall(function() return { tooltip:GetChildren() } end)
    if not ok then return end
    -- The Pretty X forwards Click to this button; it must remain enabled.
    local close = util.readable(tooltip.CloseButton) or util.readable(_G.ItemRefCloseButton)
    for _, child in ipairs(children) do
        if child ~= close and util.canModify(child) and util.call(child.IsMouseEnabled, child) == true
            and pcall(child.EnableMouse, child, false) then
            panel.nativeMouse = panel.nativeMouse or {}
            panel.nativeMouse[child] = true
        end
    end
end

local function restoreChildMouse(panel)
    local saved = panel.nativeMouse
    panel.nativeMouse = nil
    for child in pairs(saved or {}) do
        if util.canModify(child) then pcall(child.EnableMouse, child, true) end
    end
end

-- Panels drawn from another addon's lines have no data type; their lines
-- last until the tooltip is cleared. A type drawn in another's place (an
-- imbue's, in its weapon's) shows while the tooltip is of that other type.
local function showsDataType(tooltip, panel)
    if not util.canModify(tooltip) then return false end
    if not panel.dataType then return false end
    if panel.data and panel.data.fromLines then return true end
    local tooltipType = ns.TooltipTypes[panel.dataType]
    local dataType = tooltipType and tooltipType.claims or panel.dataType
    return util.call(tooltip.IsTooltipType, tooltip, dataType) == true
end

-- Another addon can take a shown tooltip out of sight by moving it into a
-- hidden frame, as EllesmereUI's Show Tooltips setting does in combat. The
-- panel's host follows the tooltip's parent, so the panel hides and returns
-- with the tooltip, its own state kept for when it does.
local function followParent(tooltip, panel)
    local parent = util.readable(util.call(tooltip.GetParent, tooltip))
    panel.host:SetShown(not (parent and util.call(parent.IsVisible, parent) == false))
end

-- In OnHide: the tooltip is still shown, only its parent went out of sight.
local function hiddenByParent(tooltip)
    return util.call(tooltip.IsShown, tooltip) == true
end

-- A world unit's tooltip fades out once the mouse leaves the unit, the game
-- setting its alpha every frame, past the SetAlpha hook. Move it off screen
-- while it fades, and hide our panel immediately.

-- Off the screen, where a fading tooltip goes so its alpha no longer matters.
local PARKED = -10000

-- Moves a fading tooltip off the screen, saving its anchors for reuse.
-- Hiding the tooltip instead would run its OnHide under the addon's taint.
local function park(tooltip, panel)
    if panel.parked then return true end
    local clamped = util.call(tooltip.IsClampedToScreen, tooltip)
    local points = util.framePoints(tooltip)
    if type(clamped) ~= "boolean" or not points or #points == 0 then return false end
    panel.parked = { clamped = clamped, points = points }
    return pcall(function()
        if clamped then tooltip:SetClampedToScreen(false) end
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", PARKED, PARKED)
    end)
end

-- GetPoint need not return the offsets exactly as set, so the parked anchor is
-- known by being far off the screen.
local function isParkedPoint(point)
    return point[1] == "TOPRIGHT" and point[3] == "BOTTOMLEFT"
        and point[4] < PARKED / 2 and point[5] < PARKED / 2
end

-- An owner or content refresh can reuse the parked anchor. Restore ours only
-- while it is still parked; the game or another addon may already have moved it.
-- A shown tooltip keeps its points through SetOwner, so the game's own anchor
-- can land beside the parked one, stretching the tooltip to zero height.
local function unpark(tooltip)
    local panel = panels[tooltip]
    local parked = panel and panel.parked
    if not parked or not util.canModify(tooltip) then return end
    local points = util.framePoints(tooltip)
    if not points then return end
    local kept = {}
    for _, point in ipairs(points) do
        if not isParkedPoint(point) then kept[#kept + 1] = point end
    end
    if #kept < #points then
        if #kept == 0 then kept = parked.points end
        local restored = pcall(function()
            tooltip:ClearAllPoints()
            for _, anchor in ipairs(kept) do tooltip:SetPoint(unpack(anchor)) end
        end)
        if not restored then return end
    end
    panel.parked = nil
    if parked.clamped then pcall(tooltip.SetClampedToScreen, tooltip, true) end
    pcall(ui.alignPanel, panel, tooltip)
end

local function fadeOut(tooltip)
    if not util.canModify(tooltip) then return end
    local panel = panels[tooltip]
    if not (panel and panel:IsShown() and panel.nativeAlpha and util.call(tooltip.IsShown, tooltip)) then return end
    -- The game sets a fading tooltip's alpha itself, past the SetAlpha hook,
    -- so it would show through the panel.
    panel:Hide()
    park(tooltip, panel)
end
fadeOut = probe("fade out", fadeOut)

local function restoreNative(tooltip)
    if isSecret(tooltip) or not tooltip then return end
    local panel = panels[tooltip]
    if not panel then return end
    ns.Placement.release(tooltip, panel)
    panel.contentPending = nil
    panel.comparisonPending, panel.comparisonAnchorPending = nil, nil
    panel.comparisonFitPending = nil
    panel.restorePending = false
    panel:Hide()
    ns.Placement.hidden(tooltip)
    if panel.nativeAlpha and util.canModify(tooltip) then
        tooltip:SetAlpha(panel.nativeAlpha)
        panel.nativeAlpha = nil
    end
    restoreChildMouse(panel)
end

native.suppressChildMouse = suppressChildMouse
native.restoreNative = restoreNative
native.fadeOut = fadeOut
native.unpark = unpark
native.followParent = followParent
native.hiddenByParent = hiddenByParent
native.isParked = function(tooltip)
    local panel = panels[tooltip]
    return panel ~= nil and panel.parked ~= nil
end
native.showsDataType = showsDataType
