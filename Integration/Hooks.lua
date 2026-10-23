-- When panels read and draw: on the game's handover of a tooltip's data, on
-- refreshes, when lines are added or rewritten, and when the original-tooltip
-- key is pressed. The entry file installs them.
local _, ns = ...
local ui = ns.ui
if not ui then return end
local placement = ns.Placement

local isSecret = ns.util.isSecret
local util = ns.util
local TooltipTypes = ns.TooltipTypes
local panels, getPanel, isComparison = ui.panels, ui.getPanel, ui.isComparison
local probe, tally = ui.probe, ui.tally
local native = ns.Native
local restoreNative, showsDataType = native.restoreNative, native.showsDataType
local hooks = {}
ns.Hooks = hooks
local batchComparisons = false

local function showsOriginal(panel)
    local tooltipType = TooltipTypes[panel.dataType]
    return ns.originalKeyDown() or not (tooltipType and ns.restyles(tooltipType.option))
end

-- What the tooltip shows, as one string; nil when a line cannot be read.
local function fingerprint(tooltip, data)
    if isSecret(data) or type(data) ~= "table" or isSecret(data.lines) then return end
    local parts = { ns.settingsVersion or 0, isComparison(tooltip) and 1 or 0,
        ns.detailsKeyDown() and 1 or 0 }
    local name = tooltip:GetName()
    for index = 1, tooltip:NumLines() do
        local left = tooltip:GetLeftLine(index)
        local right = tooltip.GetRightLine and tooltip:GetRightLine(index)
            or (name and _G[name .. "TextRight" .. index])
        for _, font in ipairs({ left, right }) do
            if font and font:IsShown() then
                local text = font:GetText()
                local r, g, b = font:GetTextColor()
                if isSecret(text) or isSecret(r) or isSecret(g) or isSecret(b)
                    or (text ~= nil and type(text) ~= "string") or type(r) ~= "number"
                    or type(g) ~= "number" or type(b) ~= "number" then return end
                parts[#parts + 1] = text or ""
                parts[#parts + 1] = r
                parts[#parts + 1] = g
                parts[#parts + 1] = b
            end
        end
    end
    -- Sell prices are drawn by a money frame, not as text.
    for _, line in ipairs(data.lines or {}) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.price) then return end
        if line.price ~= nil and type(line.price) ~= "number" then return end
        if line.price then parts[#parts + 1] = line.price end
    end
    return table.concat(parts, "\031")
end

local function keyOf(tooltipType, tooltip, data)
    local ok, key = pcall(tooltipType.key, tooltip, data)
    if ok and not isSecret(key) then return key, true end
end

-- The type that draws this tooltip in its data type's place, while it is
-- restyled: an imbue's, for the weapon tooltip its buff button shows.
local function claimantOf(dataType, tooltip, data)
    for claimant, tooltipType in pairs(TooltipTypes) do
        if tooltipType.claims == dataType and ns.restyles(tooltipType.option) then
            local ok, claimed = pcall(tooltipType.claim, tooltip, data)
            if ok and claimed then return claimant end
        end
    end
    return dataType
end

local function update(tooltip, data, model)
    if not util.canModify(tooltip) or native.isParked(tooltip) then return end
    local panel = getPanel(tooltip)
    local tooltipType = TooltipTypes[panel.dataType]
    if showsOriginal(panel) or not tooltipType then restoreNative(tooltip); return end
    panel.nativeOnly = nil
    local ok = true
    if not model then ok, model = pcall(tooltipType.read, tooltip, data, ns.Game) end
    if not ok or not model then restoreNative(tooltip); return end
    if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
    if not panel.nativeAlpha then restoreNative(tooltip); return end
    -- Content extension callbacks belong inside descriptor.read/render, under
    -- their existing failure handling. Native alpha, fitting, input, and
    -- comparison lifecycle remain owned by this integration and ns.Native.
    native.followParent(tooltip, panel)
    local rendered = pcall(tooltipType.render, panel, tooltip, model)
    if not rendered then restoreNative(tooltip); return end
    tally("placement from render")
    placement.refresh(tooltip)
    panel.data = data
    local key, valid = keyOf(tooltipType, tooltip, data)
    if not valid then restoreNative(tooltip); return end
    panel.key = key
    if panel.dataType == Enum.TooltipDataType.Item then
        panel.model, panel.modelDataType = model, panel.dataType
        panel.modelVersion, panel.modelDetailsShown = ns.settingsVersion or 0, ns.detailsKeyDown()
    else
        panel.model = nil
    end
    panel.renderedDataType = panel.dataType
    panel.lineCount = tooltip:NumLines()
    panel.fingerprint = not tooltipType.alwaysRedraw and fingerprint(tooltip, data) or nil
    panel.elapsed = 0
    tooltip:SetAlpha(0)
    native.suppressChildMouse(tooltip, panel)
end
update = probe("update", update)

local function finishTooltip(tooltip, panel, data, token)
    if not util.canModify(tooltip) or panel.refreshToken ~= token or not util.call(tooltip.IsShown, tooltip)
        or not showsDataType(tooltip, panel) then return end
    local pending = panel.contentPending
    panel.contentPending = nil
    -- A producer can signal completion synchronously; the fallback then sees
    -- the same fingerprint and leaves the finished view alone next frame.
    local key, valid = keyOf(TooltipTypes[panel.dataType], tooltip, data)
    if valid and key == panel.key and panel.renderedDataType == panel.dataType and panel:IsShown()
        and panel.fingerprint and panel.fingerprint == fingerprint(tooltip, data) then
        panel.elapsed = 0
        tally("render skipped")
        if pending and placement.owns(tooltip) then placement.shown(tooltip) end
        return
    end
    update(tooltip, data)
end

local auctionHouseHooked, auctionLoadFrame
local function installAuctionHouseHook()
    if auctionHouseHooked then return true end
    local auction = util.readable(_G.AuctionHouseUtil)
    if type(auction) ~= "table" or type(auction.SetAuctionHouseTooltip) ~= "function" then return false end
    auctionHouseHooked = true
    -- Price rows hide/refill every .2 s, appending seller/duration rows after
    -- the item post-call. Finish before the producer returns: bottom anchors
    -- otherwise show the short item for a frame and jump as those rows arrive.
    hooksecurefunc(auction, "SetAuctionHouseTooltip", probe("auction content ready", function(owner)
        local tooltip = GameTooltip
        if not util.canModify(tooltip) or not util.canModify(owner) then return end
        local panel = panels[tooltip]
        if not panel or panel.nativeOnly or panel.restorePending or not panel.data
            or panel.dataType ~= Enum.TooltipDataType.Item
            or util.readable(util.call(tooltip.GetOwner, tooltip)) ~= owner then return end
        if not pcall(finishTooltip, tooltip, panel, panel.data, panel.refreshToken) then restoreNative(tooltip) end
    end))
    if auctionLoadFrame then
        auctionLoadFrame:UnregisterEvent("ADDON_LOADED")
        auctionLoadFrame:SetScript("OnEvent", nil)
    end
    return true
end

local function hasAuctionCompletion(tooltip)
    if not auctionHouseHooked or tooltip ~= GameTooltip then return false end
    local owner = util.readable(util.call(tooltip.GetOwner, tooltip))
    local row = util.readable(_G.AuctionHouseItemListLineMixin)
    -- Only the list row uses SetAuctionHouseTooltip. Its icon has an
    -- independent item fill and must keep the normal immediate render.
    return util.canModify(owner) and type(row) == "table" and type(row.GetRowData) == "function"
        and util.readable(owner.GetRowData) == row.GetRowData
end

-- The comparison manager fills the item, shows it, then appends the delta
-- rows. Read the completed content after SetItemTooltip and commit the group
-- after the manager's final SetShown and anchor callbacks.
local function finishComparison(tooltip, panel, deferFit)
    if not panel.comparisonPending then return end
    if not util.canModify(tooltip) or native.isParked(tooltip) or panel.restorePending or not tooltip:IsShown()
        or not showsDataType(tooltip, panel) or showsOriginal(panel) then
        panel.comparisonPending = nil
        panel.comparisonFitPending = nil
        return
    end
    local key, valid = keyOf(TooltipTypes[panel.dataType], tooltip, panel.data)
    if valid and panel:IsShown() and panel.renderedDataType == panel.dataType and key == panel.key
        and panel.fingerprint and panel.fingerprint == util.call(fingerprint, tooltip, panel.data) then
        tally("render skipped")
    else
        -- Deferred work also runs outside the protected reader/renderer;
        -- native font strings can become unreadable while it is queued.
        if not pcall(update, tooltip, panel.data) then restoreNative(tooltip); return end
    end
    panel.comparisonPending = nil
    if panel:IsShown() then
        panel.elapsed = 0
        panel.comparisonFitPending = true
        if not deferFit then
            panel.comparisonFitPending = nil
            placement.refresh(tooltip)
        end
    end
end

-- Each Pretty comparison group is committed by its owner; native comparison
-- anchors are never retargeted to a replacement panel.
local function finishComparisonAnchors()
    for tooltip, panel in pairs(panels) do
        if panel.comparisonAnchorPending and panel:IsShown() and util.canModify(tooltip) and isComparison(tooltip) then
            placement.finish(tooltip)
        end
    end
end

-- Shared Blizzard UI can become available after this addon's startup. Retry
-- on data handover until the manager is ready, then leave its hooks in place.
local function installComparisonHooks()
    if batchComparisons or not ns.restyles("itemPanels") then return end
    local manager = TooltipComparisonManager
    if isSecret(manager) or type(manager) ~= "table" or type(manager.SetItemTooltip) ~= "function"
        or type(manager.AnchorShoppingTooltips) ~= "function" then return end
    batchComparisons = true
    hooksecurefunc(manager, "SetItemTooltip", probe("comparison content ready", function(self, isPrimary)
        if not ns.restyles("itemPanels") then return end
        if isSecret(isPrimary) or type(isPrimary) ~= "boolean" then return end
        local owner = self.tooltip
        if not util.canModify(owner) then return end
        local tooltips = owner.shoppingTooltips
        if isSecret(tooltips) or type(tooltips) ~= "table" then return end
        local tooltip = tooltips[isPrimary and 1 or 2]
        if not util.canModify(tooltip) then return end
        local panel = panels[tooltip]
        placement.beginComparisons(owner)
        if panel then finishComparison(tooltip, panel, true) end
    end))
    -- Commit Pretty anchors after Blizzard finishes its own anchor sequence.
    hooksecurefunc(manager, "AnchorShoppingTooltips", probe("comparison anchors ready", function(self)
        placement.finishComparisons(self.tooltip)
    end))
end

function hooks.comparisonsBatched() return batchComparisons end

-- Keep the previous panel across a clear while its native tooltip is still
-- shown. Hides dismiss the panel immediately; native cleanup waits until no
-- new item post-call replaces it in that frame.
local function scheduleRestore(tooltip)
    local panel = panels[tooltip]
    if not panel or panel.nativeOnly then return end
    if panel.data and panel.data.fromLines then panel.data = nil end
    panel.restorePending = true
    panel.contentPending = nil
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    C_Timer.After(0, function()
        if panel.refreshToken == token and panel.restorePending then
            restoreNative(tooltip)
        end
    end)
end

local function onTooltipData(dataType, tooltip, data)
    if not util.canModify(tooltip) then return end
    if isSecret(data) or type(data) ~= "table" or isSecret(data.lines) or type(data.lines) ~= "table" then
        restoreNative(tooltip)
        return
    end
    -- The editor reads this one itself.
    if tooltip.prettyTooltipScanner then return end
    -- A type drawn in this one's place (an imbue's, for its weapon) goes by its own setting.
    dataType = claimantOf(dataType, tooltip, data)
    -- A native presentation needs no panel, geometry hooks, or restore work.
    -- Existing hooks stay installed across settings changes but become idle.
    if not ns.restyles(TooltipTypes[dataType].option) then
        local panel = panels[tooltip]
        if panel then
            if not panel.nativeOnly then
                panel.nativeOnly = true
                native.unpark(tooltip)
                restoreNative(tooltip)
            end
            panel.dataType, panel.data = dataType, data
            panel.refreshToken = (panel.refreshToken or 0) + 1
        end
        return
    end
    installComparisonHooks()
    installAuctionHouseHook()
    native.unpark(tooltip)
    local panel = getPanel(tooltip)
    panel.nativeOnly = nil
    placement.observe(tooltip, dataType)
    local previousKey, previousDataType = panel.key, panel.dataType
    local key, valid = keyOf(TooltipTypes[dataType], tooltip, data)
    if not valid then restoreNative(tooltip); return end
    panel.dataType = dataType
    panel.data = data
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    panel.restorePending = false
    panel.contentPending = nil
    if not panel.hooked then
        placement.hookInput(tooltip)
        tooltip:HookScript("OnHide", function(hidden)
            if panel.nativeOnly then return end
            if native.hiddenByParent(hidden) then
                native.followParent(hidden, panel)
                return
            end
            -- Keep native cleanup deferred, but never draw the old panel at
            -- an anchor reset by an action button's hide/clear sequence.
            panel:Hide()
            scheduleRestore(hidden)
            placement.hidden(hidden)
        end)
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        -- Every refresh re-shows the tooltip at its natural size and full
        -- opacity. Waiting for the next OnUpdate lets one frame of it draw.
        local function onNativeShown(shown)
            if panel.nativeOnly then return end
            if not util.canModify(shown) then return end
            native.followParent(shown, panel)
            tally(isComparison(shown) and "show hook (comparison)" or "show hook")
            if panel.restorePending or panel.comparisonPending or panel.contentPending then
                if panel.nativeAlpha then shown:SetAlpha(0) end
                return
            end
            if placement.owns(shown) then
                panel.comparisonFitPending = nil
                placement.shown(shown)
                if panel.nativeAlpha then shown:SetAlpha(0) end
                native.suppressChildMouse(shown, panel)
            end
        end
        onNativeShown = probe("native shown", onNativeShown)
        hooksecurefunc(tooltip, "Show", function(shown)
            onNativeShown(shown)
        end)
        -- The comparison manager re-shows its tooltips with SetShown, which
        -- resets them the same way but never goes through Show.
        hooksecurefunc(tooltip, "SetShown", function(shown, visible)
            if not isSecret(visible) and visible then onNativeShown(shown) end
        end)
        tooltip:HookScript("OnShow", function(shown) onNativeShown(shown) end)
        -- Observe external native anchors without rewriting them. The Pretty
        -- backend commits its own owner/neighbour constraints.
        hooksecurefunc(tooltip, "SetPoint", function(moved)
            if panel.nativeOnly or not util.canModify(moved) then return end
            if placement.owns(moved) then placement.moved(moved) end
        end)
        if tooltip.SetAnchorType then
            hooksecurefunc(tooltip, "SetAnchorType", function(moved)
                if placement.owns(moved) then placement.moved(moved) end
            end)
        end
        hooksecurefunc(tooltip, "SetAlpha", function(faded, alpha)
            if panel.nativeOnly or panel.settingAlpha then return end
            if not isSecret(alpha) and alpha == 0 then return end
            if not util.canModify(faded) then return end
            if isSecret(alpha) or type(alpha) ~= "number" then
                panel.nativeAlpha = nil
                restoreNative(faded)
                return
            end
            if not (panel.nativeAlpha and panel:IsShown()) then return end
            panel.nativeAlpha = alpha
            panel.settingAlpha = true
            pcall(faded.SetAlpha, faded, 0)
            panel.settingAlpha = false
        end)
        -- Hooked after follow cursor's, which stops following first.
        if tooltip.FadeOut then
            hooksecurefunc(tooltip, "FadeOut", function(faded)
                if not panel.nativeOnly then native.fadeOut(faded) end
            end)
        end
        hooksecurefunc(tooltip, "SetOwner", function(owned)
            if panel.nativeOnly then return end
            native.unpark(owned)
            placement.ownerChanged(owned)
        end)
        -- A faded tooltip stays off the screen while hidden by its parent;
        -- EllesmereUI's modifier would otherwise reveal it at its old anchor.
        tooltip:HookScript("OnHide", function(hidden)
            if not native.hiddenByParent(hidden) then native.unpark(hidden) end
        end)
        panel.hooked = true
        panel:SetScript("OnUpdate", probe("panel update", function(self, elapsed)
            if not util.canModify(tooltip) then self:Hide(); return end
            local alpha = util.number((util.call(tooltip.GetAlpha, tooltip)))
            if self.nativeAlpha and not alpha then
                self.nativeAlpha = nil
                restoreNative(tooltip)
                return
            end
            if self.nativeAlpha and alpha ~= 0 then
                tooltip:SetAlpha(0)
            end
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed < .25 then return end
            self.elapsed = 0
            -- Lines added, or rewritten in place, as the talent window does
            -- after the game fills the tooltip.
            local function changed()
                return not self.comparisonPending and not self.restorePending and not self.contentPending
                    and tooltip:IsShown() and self.data and (tooltip:NumLines() ~= self.lineCount
                    or (self.fingerprint and self.fingerprint ~= fingerprint(tooltip, self.data)))
            end
            if changed() then
                C_Timer.After(0, function()
                    if showsDataType(tooltip, self) and changed() then update(tooltip, self.data) end
                end)
            end
        end))
    end
    if showsOriginal(panel) then
        panel.comparisonPending = nil
        restoreNative(tooltip)
        return
    end
    if batchComparisons and isComparison(tooltip) and dataType == Enum.TooltipDataType.Item then
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        panel.comparisonFitPending = nil
        panel.comparisonPending = true
        if not panel.comparisonCheckQueued then
            panel.comparisonCheckQueued = true
            -- A fallback for direct fills, and a check for rows appended by
            -- addons after the manager's post-hook. Keep only one per frame.
            C_Timer.After(0, function()
                panel.comparisonCheckQueued = nil
                if panel.comparisonPending or panel.comparisonFitPending or (util.canModify(tooltip) and panel:IsShown()
                    and panel.fingerprint and panel.fingerprint ~= util.call(fingerprint, tooltip, panel.data)) then
                    panel.comparisonPending = true
                    finishComparison(tooltip, panel)
                    panel.comparisonAnchorPending = true
                    if placement.owns(tooltip) then
                        placement.finish(tooltip)
                    else
                        finishComparisonAnchors()
                    end
                end
            end)
        end
        return
    end
    -- Auction rows have a synchronous completion callback after their extra
    -- lines. Hide the native item now, but read/render only the completed fill.
    -- The existing fallback also handles a caller bypassing that producer.
    if dataType == Enum.TooltipDataType.Item and hasAuctionCompletion(tooltip) then
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        panel.contentPending = true
        tally("partial render deferred")
    -- Other first renders show the new item promptly. On refresh, retain the
    -- complete old panel until other addons have appended their rows.
    elseif not panel:IsShown() or dataType ~= previousDataType or (key and key ~= previousKey) then
        update(tooltip, data)
    else
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        tally("unchanged item handover")
        placement.refresh(tooltip)
    end
    C_Timer.After(0, function()
        finishTooltip(tooltip, panel, data, token)
    end)
end
onTooltipData = probe("tooltip data", onTooltipData)

local installed = false
function hooks.install()
    if installed then return end
    installed = true
    installComparisonHooks()
    if not installAuctionHouseHook() then
        auctionLoadFrame = CreateFrame("Frame")
        auctionLoadFrame:RegisterEvent("ADDON_LOADED")
        auctionLoadFrame:SetScript("OnEvent", function(_, _, name)
            if name == "Blizzard_AuctionHouseUI" then installAuctionHouseHook() end
        end)
    end
    -- A type drawn from lines alone has no data for the game to hand over.
    for dataType, tooltipType in pairs(TooltipTypes) do
        if not tooltipType.linesOnly then
            ns.Processor.onData("panel", dataType, function(tooltip, data)
                onTooltipData(dataType, tooltip, data)
            end)
        end
    end
    -- A client's extension of a tooltip type can hook the game itself, as
    -- retail's flight map pins do (descriptor.extension.install).
    for _, tooltipType in pairs(TooltipTypes) do
        local extension = tooltipType.extension
        if extension and extension.install then extension.install() end
    end

    -- The original-tooltip key swaps the panel for the game's tooltip; Shift
    -- shows or hides the details.
    ns.Processor.onKey("panel", function(key)
        if not (ns.isOriginalKey(key) or ns.isDetailsKey(key)) then return end
        for tooltip, panel in pairs(panels) do
            if util.canModify(tooltip) and tooltip:IsShown() and showsDataType(tooltip, panel) then
                if showsOriginal(panel) then
                    restoreNative(tooltip)
                elseif panel.data then
                    local model
                    -- Other addons' Alt-only rows remain until the next
                    -- native refill. Resume our last item model immediately;
                    -- the normal data/line hooks still read fresh models.
                    if ns.isOriginalKey(key) and panel.dataType == Enum.TooltipDataType.Item
                        and panel.model and panel.modelDataType == panel.dataType
                        and panel.modelVersion == (ns.settingsVersion or 0)
                        and panel.modelDetailsShown == ns.detailsKeyDown() then
                        local currentKey, valid = keyOf(TooltipTypes[panel.dataType], tooltip, panel.data)
                        if valid and currentKey and currentKey == panel.key
                            and util.call(fingerprint, tooltip, panel.data) then
                            model = panel.model
                        end
                    end
                    update(tooltip, panel.data, model)
                end
            end
        end
        if ns.isOriginalKey(key) and not ns.originalKeyDown() then
            -- Restore the whole pair in this event. The native tooltip can be
            -- wider than its panel, so waiting for the manager leaves a gap.
            for tooltip, panel in pairs(panels) do
                if util.canModify(tooltip) and tooltip:IsShown() and panel:IsShown() and isComparison(tooltip) then
                    panel.comparisonAnchorPending = true
                end
            end
            finishComparisonAnchors()
        end
    end)
end

-- Draws a tooltip type from a tooltip another addon filled with lines alone.
function hooks.renderLines(tooltip, dataType, id)
    onTooltipData(dataType, tooltip, { type = dataType, id = id, lines = {}, fromLines = true })
end
