-- Settings-page presentation and registration. The shared API lives in Core/Settings.lua.
local _, ns = ...
local setOption = ns.setOption
local L = ns.L

local page, category
ns.Options = {}

-- Called by the entry file after saved settings arrive.
function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "PrettyTooltip"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local controls = {}

    local function refreshControls()
        for _, control in ipairs(controls) do control.refresh() end
    end

    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("PrettyTooltip")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText(L["A full reskin of tooltips. Changes apply the next time a tooltip opens."])

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(180, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText(L["Open the style editor"])

    -- Explanations show on hover, which keeps the page short.
    local function explain(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[title], 1, 1, 1)
            GameTooltip:AddLine(L[text], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    explain(editorButton, "Style editor", "The look of every kind of tooltip, with a live sample: fonts, "
        .. "sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, "
        .. "as disenchant results, the spell power breakdown, and the health bar. Also /ptip.")
    -- Opens over the settings window, which is left as it is: closing it from
    -- here would run its code under the addon's taint.
    editorButton:SetScript("OnClick", function()
        if ns.openEditor then ns.openEditor() end
    end)

    -- Two columns: the types of tooltip on the left, the other settings on the right.
    local COLUMNS_TOP = -100
    local leftColumn = { x = 16, y = COLUMNS_TOP }
    local rightColumn = { x = 440, y = COLUMNS_TOP }

    local function section(column, text)
        local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", column.x, column.y)
        header:SetText(L[text])
        column.y = column.y - 24
    end

    section(leftColumn, "Restyled Tooltips")
    for index, heading in ipairs({ "Restyle", "Follow cursor" }) do
        local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", leftColumn.x + 244 + (index - 1) * 90, leftColumn.y)
        label:SetText(L[heading])
    end
    leftColumn.y = leftColumn.y - 16

    -- The Blizzard layout restyles no kind, so a kind's own box has no say then.
    local function typeBox(x, key, title, text, followsLayout)
        local button = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        button:SetSize(24, 24)
        button:SetPoint("TOPLEFT", x, leftColumn.y + 4)
        if key then
            button:SetScript("OnClick", function(self) setOption(key, self:GetChecked() and true or false) end)
            if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
            button.refresh = function()
                button:SetChecked(ns.option(key))
                if followsLayout then button:SetEnabled(ns.option("layout") ~= "blizzard") end
            end
            controls[#controls + 1] = button
        else
            button:Disable()
            -- A disabled button takes no hover unless told to; its tooltip still shows.
            if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
        end
        explain(button, title, text)
    end

    for _, tooltipType in ipairs(ns.TOOLTIP_TYPES) do
        local label = page:CreateFontString(nil, "ARTWORK",
            tooltipType.restyle and "GameFontHighlight" or "GameFontDisable")
        label:SetPoint("TOPLEFT", leftColumn.x + 8, leftColumn.y - 1)
        label:SetText(L[tooltipType.label])
        typeBox(leftColumn.x + 254, tooltipType.restyle, L["Restyle " .. tooltipType.label:lower()], tooltipType.restyle
            and "Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip, with the details "
                .. "modifier's rows added to it."
            or "Not restyled yet; this kind keeps the game's own tooltip.", true)
        typeBox(leftColumn.x + 354, tooltipType.cursor, "Follow cursor", "Shows this kind's tooltip at the cursor "
            .. "when the game would put it in its default corner; bags and other panels keep theirs. Off, "
            .. "its position is left to the game and other addons.")
        leftColumn.y = leftColumn.y - 22
    end

    -- A choice of values for one setting, each { value, label, note }, as radio
    -- buttons down the column.
    local function radios(column, choices, current, pick)
        for _, choice in ipairs(choices) do
            local value, label, note = choice[1], choice[2], choice[3]
            local button = CreateFrame("CheckButton", nil, page, "UIRadioButtonTemplate")
            button:SetPoint("TOPLEFT", column.x + 8, column.y)
            local caption = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            caption:SetPoint("LEFT", button, "RIGHT", 6, 0)
            caption:SetText(L[label])
            button:SetHitRectInsets(0, -(caption:GetStringWidth() + 8), 0, 0)
            button:SetScript("OnClick", function()
                pick(value)
                refreshControls()
            end)
            button.refresh = function() button:SetChecked(current() == value) end
            controls[#controls + 1] = button
            explain(button, label, note)
            column.y = column.y - 22
        end
        column.y = column.y - 12
    end

    local function optionRadios(column, key, choices)
        radios(column, choices, function() return ns.option(key) end, function(value) setOption(key, value) end)
    end

    section(rightColumn, "Layout Style")
    optionRadios(rightColumn, "layout", {
        { "pretty", "PrettyTooltip", "Draw the PrettyTooltip panel for each kind turned on under Restyled Tooltips." },
        { "blizzard", "Blizzard", "Keep the game's own tooltips. Item Equip effects are shortened, and the details "
            .. "modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs." },
    })

    section(rightColumn, "Default Tooltip Modifier")
    optionRadios(rightColumn, "originalKey", {
        { "CTRL", "Ctrl", "Hold Ctrl to see the game's own tooltip instead of the panel." },
        { "ALT", "Alt", "Hold Alt to see the game's own tooltip instead of the panel." },
        { "NONE", "Never", "Never show the game's own tooltip in place of the panel." },
    })

    section(rightColumn, "Tooltip Details Modifier")
    optionRadios(rightColumn, "detailsKey", {
        { "SHIFT", "Shift", "Hold Shift to see disenchant results, the spell power breakdown and rates, gathering "
            .. "contents, and IDs. Each can still be turned off in the style editor." },
        { "ALWAYS", "Always Show", "Always show disenchant results, the spell power breakdown and rates, gathering "
            .. "contents, and IDs, as each one's setting in the style editor allows." },
    })

    section(rightColumn, "Follow cursor")
    local combatBox = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    combatBox:SetSize(24, 24)
    combatBox:SetPoint("TOPLEFT", rightColumn.x + 8, rightColumn.y + 4)
    local combatLabel = combatBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    combatLabel:SetPoint("LEFT", combatBox, "RIGHT", 6, 0)
    combatLabel:SetText(L["Disable in combat"])
    combatBox:SetHitRectInsets(0, -(combatLabel:GetStringWidth() + 8), 0, 0)
    combatBox:SetScript("OnClick", function(self)
        setOption("cursorDisableInCombat", self:GetChecked() and true or false)
    end)
    combatBox.refresh = function() combatBox:SetChecked(ns.option("cursorDisableInCombat")) end
    controls[#controls + 1] = combatBox
    explain(combatBox, "Disable in combat",
        "Use the default tooltip position during combat, then resume following the cursor afterward.")
    rightColumn.y = rightColumn.y - 34

    section(rightColumn, "Style Editor Appearance")
    radios(rightColumn, {
        { "native", "Blizzard", "Use the game's settings frame borders and controls." },
        { "flat", "Flat", "Use the flat editor appearance." },
    }, ns.editorStyle, function(value)
        setOption("editorStyle", value)
        if ns.refreshEditorStyle then ns.refreshEditorStyle() end
    end)

    section(rightColumn, "Global scale")
    local scaleSlider = CreateFrame("Slider", nil, page, "MinimalSliderTemplate")
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetPoint("TOPLEFT", rightColumn.x + 12, rightColumn.y)
    -- Leave room for the percentage inside the right column. The template
    -- supplies the track and thumb; custom artwork here would overlap it.
    scaleSlider:SetSize(160, 19)
    scaleSlider:SetMinMaxValues(50, 150)
    scaleSlider:SetValueStep(1)
    if scaleSlider.SetObeyStepOnDrag then scaleSlider:SetObeyStepOnDrag(true) end
    local scaleValue = scaleSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)
    scaleSlider:SetScript("OnValueChanged", function(self, percent)
        if self.updating then return end
        percent = math.floor(percent + .5)
        setOption("tooltipScale", percent ~= 100 and percent / 100 or nil)
        scaleValue:SetText(percent .. "%")
    end)
    scaleSlider.refresh = function()
        scaleSlider.updating = true
        local percent = math.floor(ns.tooltipScale() * 100 + .5)
        scaleSlider:SetValue(percent)
        scaleValue:SetText(percent .. "%")
        scaleSlider.updating = false
    end
    controls[#controls + 1] = scaleSlider
    explain(scaleSlider, "Global scale", "Scales every PrettyTooltip panel, including text, icons, spacing, and bars. "
        .. "100% is the default. Individual text settings are preserved.")

    page:SetScript("OnShow", refreshControls)
    -- Hooks the settings window calls on canvas pages: when it shows them, and
    -- from its Defaults button.
    page.OnRefresh = refreshControls
    page.OnDefault = function()
        ns.resetOptions()
        if ns.refreshEditorStyle then ns.refreshEditorStyle() end
        refreshControls()
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, page.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
    refreshControls()
end

-- The game's settings window does not open in combat; the player is told so
-- instead of nothing happening. True when it opened.
function ns.openSettings()
    if InCombatLockdown() then
        print(L["PrettyTooltip: the options cannot open during combat. Try again once it ends."])
        return false
    end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
    return true
end
