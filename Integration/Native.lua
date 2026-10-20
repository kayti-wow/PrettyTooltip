-- The game's tooltip under a panel: hidden, and sized to cover the panel, so
-- comparisons and screen clamping treat the pair as one; given back as it was
-- when the panel goes. Comparisons attach to the panels instead.
local _, ns = ...
local ui = ns.ui
if not ui then return end

local isSecret = ns.util.isSecret
local util = ns.util
local panels, isComparison, probe = ui.panels, ui.isComparison, ui.probe
local perf, tally, timed = ui.perf, ui.tally, ui.timed
local native = {}
ns.Native = native

local function retarget(tooltip, choose)
    if not util.canModify(tooltip) then return end
    local points, changed = util.framePoints(tooltip), false
    if not points then return end
    for _, point in ipairs(points) do
        local target = choose(point[2])
        if target ~= point[2] then changed = true end
        point[2] = target
    end
    if not changed then return end
    tooltip:ClearAllPoints()
    for _, anchor in ipairs(points) do
        tooltip:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
    end
end

-- Blizzard attaches comparisons to the hidden tooltips' edges, past the end
-- of a narrower panel; attach them to the panels instead.
native.anchoring = false
local function anchorToPanels(comparison)
    if native.anchoring then return end
    native.anchoring = true
    pcall(retarget, comparison, function(frame)
        local target = frame and panels[frame]
        if target and target:IsShown() then return target end
        return frame
    end)
    native.anchoring = false
end
anchorToPanels = probe("anchor comparison", anchorToPanels)

-- Blizzard anchors comparison tooltips, slides away from screen edges, and
-- clamps using the native frame's bounds, so the hidden frame must cover the
-- panel or the comparisons land on top of it.
local refitNative

-- Refits next frame, once the game has finished laying the tooltip out; this
-- one fits whatever size it finds.
local function recheckNextFrame(tooltip, panel)
    if panel.recheckPending then return end
    panel.recheckPending = true
    C_Timer.After(0, function()
        panel.recheckPending = false
        if panel:IsShown() and util.canModify(tooltip) and util.call(tooltip.IsShown, tooltip) then
            panel.forceFit = true
            refitNative(tooltip, panel)
            panel.forceFit = false
        end
    end)
end

local function fitNative(tooltip, panel)
    if not util.canModify(tooltip) then return end
    if not tooltip.SetPadding then return end
    local base = panel.nativeSize
    if not base then
        local right, bottom, left, top
        if tooltip.GetPadding then right, bottom, left, top = tooltip:GetPadding() end
        if isSecret(right) or isSecret(bottom) or isSecret(left) or isSecret(top) then return end
        base = { right = right or 0, bottom = bottom or 0, left = left or 0, top = top or 0 }
        panel.nativeSize = base
    end
    -- A hidden tooltip is fitted by the Show hook once Blizzard shows it.
    if not util.call(tooltip.IsShown, tooltip) then return end
    local width, height = util.number(tooltip:GetWidth()), util.number(tooltip:GetHeight())
    if not (width and height) then return end
    -- A refresh asks for several refits; only a changed size needs one.
    local start = perf.on and debugprofilestop()
    if panel.fittedWidth and math.abs(width - panel.fittedWidth) <= .5
        and math.abs(height - panel.fittedHeight) <= .5
        and math.abs(panel:GetWidth() - panel.fittedPanelWidth) <= .5
        and math.abs(panel:GetHeight() - panel.fittedPanelHeight) <= .5 then
        timed("refit part: size check (unchanged)", start)
        return
    end
    timed("refit part: size check (changed)", start)
    start = perf.on and debugprofilestop()
    tally("refit applied")
    -- GetPadding reports the applied padding and SetPadding resizes at once, so
    -- the natural size needs no layout pass to measure.
    if tooltip.GetPadding then
        local currentRight, currentBottom = tooltip:GetPadding()
        if isSecret(currentRight) or isSecret(currentBottom) then return end
        if type(currentRight) == "number" and type(currentBottom) == "number" then
            local panelWidth, panelHeight = panel:GetWidth(), panel:GetHeight()
            local naturalWidth = width - (currentRight - base.right)
            local naturalHeight = height - (currentBottom - base.bottom)
            -- Right after Show the game can report the size before it has laid
            -- out everything; a size below the largest seen for this item waits.
            local largestWidth, largestHeight = panel.naturalWidth or 0, panel.naturalHeight or 0
            panel.naturalWidth = math.max(largestWidth, naturalWidth)
            panel.naturalHeight = math.max(largestHeight, naturalHeight)
            if not panel.forceFit and (naturalWidth < largestWidth - .5 or naturalHeight < largestHeight - .5) then
                tally("refit skipped (smaller)")
                recheckNextFrame(tooltip, panel)
                return
            end
            local right = base.right + math.max(0, panelWidth - naturalWidth)
            local bottom = base.bottom + math.max(0, panelHeight - naturalHeight)
            if math.abs(right - currentRight) > .01 or math.abs(bottom - currentBottom) > .01 then
                tally("padding set")
                tooltip:SetPadding(right, bottom, base.left, base.top)
            end
            -- Reading the size back would make the game lay the tooltip out a
            -- second time this frame; a wrong guess fails the next size check.
            panel.fittedWidth = naturalWidth + (right - base.right)
            panel.fittedHeight = naturalHeight + (bottom - base.bottom)
            panel.fittedPanelWidth, panel.fittedPanelHeight = panelWidth, panelHeight
            timed("refit part: fast path", start)
            tally("refit fast")
            return
        end
    end
    start = perf.on and debugprofilestop()
    tooltip:SetPadding(base.right, base.bottom, base.left, base.top)
    tooltip:Show()
    width, height = util.number(tooltip:GetWidth()), util.number(tooltip:GetHeight())
    if not (width and height) then return end
    local right = base.right + math.max(0, panel:GetWidth() - width)
    local bottom = base.bottom + math.max(0, panel:GetHeight() - height)
    if right ~= base.right or bottom ~= base.bottom then
        tooltip:SetPadding(right, bottom, base.left, base.top)
        tooltip:Show()
    end
    panel.fittedWidth, panel.fittedHeight = util.number(tooltip:GetWidth()), util.number(tooltip:GetHeight())
    panel.fittedPanelWidth, panel.fittedPanelHeight = panel:GetWidth(), panel:GetHeight()
    timed("refit part: fallback", start)
end

function refitNative(tooltip, panel)
    if not util.canModify(tooltip) then return end
    if panel.fitting then return end
    panel.fitting = true
    pcall(fitNative, tooltip, panel)
    panel.fitting = false
    -- A tooltip anchored by its bottom moves its top as it is fitted.
    pcall(ui.alignPanel, panel, tooltip)
end
refitNative = probe("refit hidden tooltip", refitNative)

-- Each refresh re-sets a shown tooltip with the item's lines, then adds the
-- comparison lines; fitting the shorter step would set the padding twice, a
-- full layout each. A tooltip shorter than the most lines it has shown for this
-- item keeps its padding, and is checked next frame in case the lines never come.
local function refitUnlessPartial(tooltip, panel)
    if not util.canModify(tooltip) then return end
    local lines = util.number((util.call(tooltip.NumLines, tooltip)))
    if not lines then return end
    panel.fullLines = math.max(panel.fullLines or 0, lines)
    if lines < panel.fullLines then
        tally("refit skipped (partial)")
        recheckNextFrame(tooltip, panel)
        return
    end
    refitNative(tooltip, panel)
end

-- Panels drawn from another addon's lines have no data type; their lines
-- last until the tooltip is cleared.
local function showsDataType(tooltip, panel)
    if not util.canModify(tooltip) then return false end
    if not panel.dataType then return false end
    if panel.data and panel.data.fromLines then return true end
    return util.call(tooltip.IsTooltipType, tooltip, panel.dataType) == true
end

local function releaseNative(tooltip, panel)
    if not util.canModify(tooltip) then return end
    local base = panel.nativeSize
    panel.nativeSize, panel.fittedWidth = nil, nil
    -- After a hide or a switch to other content the game has already reset
    -- the size, and the tooltip's new owner may have set its own padding.
    if base and util.call(tooltip.IsShown, tooltip) and showsDataType(tooltip, panel) then
        tooltip:SetPadding(base.right, base.bottom, base.left, base.top)
        tooltip:Show()
    end
end

-- A world unit's tooltip fades out once the mouse leaves the unit, and the
-- panel fades in its place. The game sets its fade's alpha itself, past the
-- SetAlpha hook, so only the panel's OnUpdate holds the hidden tooltip at
-- zero: a faded panel stays shown, at zero alpha, until the game hides its
-- tooltip. Hiding the tooltip here instead would run the game's OnHide code as
-- this addon, tainting the tooltip for the game's later use of it, in combat
-- or out of it.
local FADE_TIME = .5

local function stopFade(panel)
    panel.fadePending = false
    if not panel.fade then return end
    panel.fade:Stop()
    panel:SetAlpha(1)
end

local function fadeOut(tooltip)
    if not util.canModify(tooltip) then return end
    local panel = panels[tooltip]
    if not (panel and panel:IsShown() and panel.nativeAlpha and util.call(tooltip.IsShown, tooltip)) then return end
    if not panel.fade then
        local fade = panel:CreateAnimationGroup()
        local alpha = fade:CreateAnimation("Alpha")
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(0)
        alpha:SetDuration(FADE_TIME)
        fade:SetToFinalAlpha(true)
        fade:SetScript("OnFinished", function()
            -- Still fading, the game's tooltip needs the panel's OnUpdate.
            if panel.fadePending and util.call(tooltip.IsShown, tooltip) then return end
            panel:Hide()
            panel:SetAlpha(1)
        end)
        panel.fade = fade
    end
    panel.fade:Play()
    -- Until the game hides its tooltip, or new content arrives.
    panel.fadePending = true
    tooltip:SetAlpha(0)
end
fadeOut = probe("fade out", fadeOut)

local function isFading(panel)
    return panel.fade and panel.fade:IsPlaying() or false
end

local function restoreNative(tooltip)
    if isSecret(tooltip) or not tooltip then return end
    local panel = panels[tooltip]
    if not panel then return end
    panel.restorePending = false
    pcall(releaseNative, tooltip, panel)
    -- A panel still fading is left to its fade; a faded one goes now.
    if panel.fadePending and isFading(panel) then
        panel.fadePending = false
    else
        stopFade(panel)
        panel:Hide()
    end
    panel.fullLines, panel.naturalWidth, panel.naturalHeight = nil, nil, nil
    if panel.nativeAlpha and util.canModify(tooltip) then
        tooltip:SetAlpha(panel.nativeAlpha)
        panel.nativeAlpha = nil
    end
    for comparison in pairs(panels) do
        if isComparison(comparison) then
            pcall(retarget, comparison, function(frame)
                return frame == panel and tooltip or frame
            end)
        end
    end
end

native.anchorToPanels = anchorToPanels
native.refitNative = refitNative
native.refitUnlessPartial = refitUnlessPartial
native.restoreNative = restoreNative
native.fadeOut = fadeOut
native.isFading = isFading
native.stopFade = stopFade
native.showsDataType = showsDataType
