-- When panels read and draw: on the game's handover of a tooltip's data, on
-- refreshes, when lines are added or rewritten, and when the original-tooltip
-- key is pressed. The entry file installs them.
local _, ns = ...
local ui = ns.ui
if not (ui and ns.Native) then return end

local isSecret = ns.util.isSecret
local util = ns.util
local ITEM = Enum.TooltipDataType.Item
local TooltipTypes = ns.TooltipTypes
local panels, getPanel, isComparison, alignPanel = ui.panels, ui.getPanel, ui.isComparison, ui.alignPanel
local probe, tally = ui.probe, ui.tally
local native = ns.Native
local anchorToPanels, refitNative, refitUnlessPartial = native.anchorToPanels, native.refitNative, native.refitUnlessPartial
local restoreNative, showsDataType = native.restoreNative, native.showsDataType
local hooks = {}
ns.Hooks = hooks

local function showsOriginal(panel)
    local tooltipType = TooltipTypes[panel.dataType]
    return ns.originalKeyDown() or not (tooltipType and ns.option(tooltipType.option))
        or (tooltipType.lite and ns.option(tooltipType.lite))
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

local function update(tooltip, data)
    if not util.canModify(tooltip) then return end
    local panel = getPanel(tooltip)
    local tooltipType = TooltipTypes[panel.dataType]
    if showsOriginal(panel) or not tooltipType then restoreNative(tooltip); return end
    local ok, model = pcall(tooltipType.read, tooltip, data, ns.Game)
    if not ok or not model then restoreNative(tooltip); return end
    if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
    if not panel.nativeAlpha then restoreNative(tooltip); return end
    local rendered = pcall(tooltipType.render, panel, tooltip, model)
    if not rendered then restoreNative(tooltip); return end
    tally("refit from render")
    refitNative(tooltip, panel)
    panel.data = data
    local key, valid = keyOf(tooltipType, tooltip, data)
    if not valid then restoreNative(tooltip); return end
    if key ~= panel.key then panel.fullLines, panel.naturalWidth, panel.naturalHeight = nil, nil, nil end
    panel.key = key
    panel.lineCount = tooltip:NumLines()
    panel.fingerprint = not tooltipType.alwaysRedraw and fingerprint(tooltip, data) or nil
    tooltip:SetAlpha(0)
end
update = probe("update", update)

-- Some tooltip owners clear or briefly hide the tooltip while refreshing the
-- same item. Keep the previous panel for that frame, and only tear it down if
-- no new item post-call replaces it.
local function scheduleRestore(tooltip)
    local panel = panels[tooltip]
    if not panel then return end
    if panel.data and panel.data.fromLines then panel.data = nil end
    panel.restorePending = true
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
    local panel = getPanel(tooltip)
    -- New content over a panel fading or faded out, even the same unit's, starts afresh.
    if panel.fadePending or native.isFading(panel) then
        native.stopFade(panel)
        panel:Hide()
    end
    local previousKey, previousDataType = panel.key, panel.dataType
    local key, valid = keyOf(TooltipTypes[dataType], tooltip, data)
    if not valid then restoreNative(tooltip); return end
    panel.dataType = dataType
    panel.data = data
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    panel.restorePending = false
    if not panel.hooked then
        tooltip:HookScript("OnHide", scheduleRestore)
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        -- Every refresh re-shows the tooltip at its natural size and full
        -- opacity. Waiting for the next OnUpdate lets one frame of it draw.
        local function onNativeShown(shown, source)
            if not util.canModify(shown) then return end
            tally(isComparison(shown) and "show hook (comparison)" or "show hook")
            if not (panel.nativeSize and panel:IsShown()) then return end
            tally("refit from " .. source)
            refitUnlessPartial(shown, panel)
            -- Comparisons are anchored after they are shown, so align here.
            pcall(alignPanel, panel, shown)
            if isComparison(shown) then pcall(anchorToPanels, shown) end
            local alpha = util.number((util.call(shown.GetAlpha, shown)))
            if panel.nativeAlpha and alpha and alpha ~= 0 then
                shown:SetAlpha(0)
            end
        end
        hooksecurefunc(tooltip, "Show", function(shown)
            if not panel.fitting then onNativeShown(shown, "Show") end
        end)
        -- The comparison manager re-shows its tooltips with SetShown, which
        -- resets them the same way but never goes through Show.
        hooksecurefunc(tooltip, "SetShown", function(shown, visible)
            if not isSecret(visible) and visible and not panel.fitting then onNativeShown(shown, "SetShown") end
        end)
        tooltip:HookScript("OnShow", function(shown) onNativeShown(shown, "OnShow") end)
        -- The comparison code anchors a comparison after showing it, a point at
        -- a time; it belongs beside the panels, not the hidden tooltips under
        -- them, and its panel pinned to the edge those points place.
        hooksecurefunc(tooltip, "SetPoint", function(moved)
            if not util.canModify(moved) then return end
            if not native.anchoring and panel:IsShown() and isComparison(moved) then
                tally("re-anchor after SetPoint")
                anchorToPanels(moved)
                pcall(alignPanel, panel, moved)
            end
        end)
        hooksecurefunc(tooltip, "SetAlpha", function(faded, alpha)
            if not util.canModify(faded) then return end
            if isSecret(alpha) or type(alpha) ~= "number" then
                panel.nativeAlpha = nil
                restoreNative(faded)
                return
            end
            if panel.settingAlpha or alpha == 0 then return end
            if not (panel.nativeAlpha and panel:IsShown()) then return end
            panel.nativeAlpha = alpha
            panel.settingAlpha = true
            pcall(faded.SetAlpha, faded, 0)
            panel.settingAlpha = false
        end)
        if tooltip.FadeOut then hooksecurefunc(tooltip, "FadeOut", native.fadeOut) end
        panel.hooked = true
        panel:SetScript("OnUpdate", function(self, elapsed)
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
                return tooltip:IsShown() and self.data and (tooltip:NumLines() ~= self.lineCount
                    or (self.fingerprint and self.fingerprint ~= fingerprint(tooltip, self.data)))
            end
            if changed() then
                C_Timer.After(0, function()
                    if showsDataType(tooltip, self) and changed() then update(tooltip, self.data) end
                end)
            end
        end)
    end
    if showsOriginal(panel) then
        restoreNative(tooltip)
        return
    end
    -- The first render shows the new item promptly. On refresh, retain the
    -- complete old panel until other addons have appended their rows.
    if not panel:IsShown() or dataType ~= previousDataType or (key and key ~= previousKey) then
        update(tooltip, data)
    else
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        tally("refit from same item's data")
        refitUnlessPartial(tooltip, panel)
    end
    C_Timer.After(0, function()
        if util.canModify(tooltip) and panel.refreshToken == token and util.call(tooltip.IsShown, tooltip)
            and showsDataType(tooltip, panel) then
            -- The game re-sets shown tooltips often, comparisons most; a panel
            -- already showing the same text needs no new render.
            if panel:IsShown() and panel.fingerprint and panel.fingerprint == fingerprint(tooltip, data) then
                tally("render skipped")
                return
            end
            update(tooltip, data)
        end
    end)
end
onTooltipData = probe("tooltip data", onTooltipData)

-- Items first: the item rewrite is installed before them, and follow cursor
-- after every type.
local installed = false
function hooks.install()
    if installed then return end
    installed = true
    local order = {}
    -- A type drawn from lines alone has no data for the game to hand over.
    for dataType, tooltipType in pairs(TooltipTypes) do
        if dataType ~= ITEM and not tooltipType.linesOnly then order[#order + 1] = dataType end
    end
    table.sort(order)
    if TooltipTypes[ITEM] then table.insert(order, 1, ITEM) end
    for _, dataType in ipairs(order) do
        TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
            onTooltipData(dataType, tooltip, data)
        end)
    end

    local modifier = CreateFrame("Frame")
    modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
    -- The original-tooltip key swaps the panel for the game's tooltip; Shift
    -- shows or hides the details.
    modifier:SetScript("OnEvent", function(_, _, key)
        if not (ns.isOriginalKey(key) or ns.isDetailsKey(key)) then return end
        for tooltip, panel in pairs(panels) do
            if util.canModify(tooltip) and tooltip:IsShown() and showsDataType(tooltip, panel) then
                if showsOriginal(panel) then
                    restoreNative(tooltip)
                elseif panel.data then
                    update(tooltip, panel.data)
                end
            end
        end
    end)
end

-- Draws a tooltip type from a tooltip another addon filled with lines alone.
function hooks.renderLines(tooltip, dataType, id)
    onTooltipData(dataType, tooltip, { type = dataType, id = id, lines = {}, fromLines = true })
end
