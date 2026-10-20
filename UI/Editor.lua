-- The /ptip style editor: a live sample panel and the controls for its parts.
local _, ns = ...
local ui = ns.ui
local L, fillText = ns.L, ns.util.fill
if not (ui and ui.renderPreview) then
    return
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH = 820
-- The window keeps one height; the controls column scrolls within it.
local EDITOR_HEIGHT = 720
-- Below the controls column: a gap, then the buttons along the bottom.
local BUTTONS_SPACE = 50
local PREVIEW_TOP = 118
local PREVIEW_WIDTH = 460
-- Room around the panel for its rarity halo and the Equipped tag above it.
local PREVIEW_MARGIN = 26
local SCROLL_STEP = 40
local CONTROLS_X = PREVIEW_WIDTH + 34
local CONTROLS_WIDTH = WIDTH - CONTROLS_X - 18
local CONTROLS_TOP = PREVIEW_TOP + 10
local LABEL_WIDTH = 86
-- Resets have their own gutter, so a changed label never runs into its icon.
local FIELD_WIDTH = CONTROLS_WIDTH - LABEL_WIDTH - 24
local SIZE_MIN, SIZE_MAX = 8, 30
local MENU_ROWS, MENU_ROW_HEIGHT = 12, 20
local BACKGROUND = { .055, .045, .05 }
local FIELD = { .10, .085, .085 }
local FIELD_HOVER = { .16, .13, .12 }
local LINE = { .32, .26, .19 }
local GOLD = { .93, .80, .52 }
local RESET_ICON = "Interface\\Buttons\\UI-RefreshButton"
local skin = ns.EditorSkin.create()
local BACKDROP_STYLES = {
    { text = "Automatic" },
    { value = "native", text = "Blizzard border" },
    { value = "flat", text = "Flat" },
    { value = "dialogue", text = "DialogueUI" },
}
local OUTLINES = {
    { value = "NONE", text = "None" },
    { value = "OUTLINE", text = "Outline" },
    { value = "THICKOUTLINE", text = "Thick outline" },
}

-- The samples, from UI/Samples.lua, for the types this client has.
local TOOLTIP_TYPES, TYPE_ORDER = {}, {}
for _, sampleType in ipairs(ns.editorSampleTypes and ns.editorSampleTypes() or {}) do
    TOOLTIP_TYPES[sampleType.key] = sampleType
    TYPE_ORDER[#TYPE_ORDER + 1] = sampleType.key
end
-- For tests/: every tooltip type's samples, in the editor's order.
ns.editorSamples = { tooltipTypes = TOOLTIP_TYPES, order = TYPE_ORDER }
local MAX_SAMPLES = 0
for _, tooltipType in pairs(TOOLTIP_TYPES) do MAX_SAMPLES = math.max(MAX_SAMPLES, #tooltipType.samples) end

-- Building blocks -----------------------------------------------------------

local function fill(parent, layer, color, alpha)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return tex
end

local function background(frame, color, alpha)
    local tex = fill(frame, "BACKGROUND", color, alpha)
    tex:SetAllPoints()
    return tex
end

local function outline(frame, color, alpha)
    local edges = {}
    for index, points in ipairs({
        { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" },
    }) do
        local edge = fill(frame, "BORDER", color, alpha)
        edge:SetPoint(points[1])
        edge:SetPoint(points[2])
        if index <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[index] = edge
    end
    return edges
end

local function text(parent, template, value)
    local font = parent:CreateFontString(nil, "ARTWORK", template)
    font:SetJustifyH("LEFT")
    if value then font:SetText(L[value]) end
    return font
end

-- A string given a font file keeps it through SetFontObject.
local function plainFont(font)
    local path, size, flags = GameFontHighlightSmall:GetFont()
    ui.setFont(font, path, size, flags)
end

local function editorButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    local parts = skin.templateParts(button)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    local edges = outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall", label)
    button.label:SetPoint("CENTER")
    local paint = skin:button(button, button.bg, edges, parts)
    button:SetScript("OnEnter", function(self) self.hovered = true paint() end)
    button:SetScript("OnLeave", function(self) self.hovered = false paint() end)
    button:SetScript("OnClick", onClick)
    function button:SetSelected(selected)
        self.selected = selected
        paint()
    end
    return button
end

local function editorTab(parent, label, width, onClick)
    local tab = CreateFrame("Button", nil, parent, "MinimalTabTemplate")
    tab:SetWidth(width)
    tab.label = tab.Text
    tab.label:SetText(L[label])
    skin:tab(tab, background(tab, FIELD), outline(tab, LINE))
    tab:SetScript("OnClick", onClick)
    return tab
end

-- The window -----------------------------------------------------------------

local editor = CreateFrame("Frame", "PrettyTooltipEditor", UIParent)
editor:SetWidth(WIDTH)
editor:SetPoint("CENTER")
-- Below the color picker, which the editor opens.
editor:SetFrameStrata("HIGH")
editor:SetToplevel(true)
editor:SetClampedToScreen(true)
editor:EnableMouse(true)
editor:SetMovable(true)
editor:RegisterForDrag("LeftButton")
editor:SetScript("OnDragStart", editor.StartMoving)
editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
editor:Hide()
tinsert(UISpecialFrames, "PrettyTooltipEditor")
skin:surface(editor, background(editor, BACKGROUND), outline(editor, LINE), true)

-- The native border is a child frame; its title bar covers regions drawn on
-- the editor itself. Keep the title above it in either appearance.
local titleContainer = CreateFrame("Frame", nil, editor)
titleContainer:SetPoint("TOPLEFT")
titleContainer:SetPoint("TOPRIGHT")
titleContainer:SetHeight(32)
titleContainer:SetFrameLevel(editor:GetFrameLevel() + 2)
local heading = text(titleContainer, "GameFontNormalLarge", "PrettyTooltip Style Editor")
heading:SetPoint("TOPLEFT", 16, -14)
local subheading = text(editor, "GameFontDisableSmall",
    "Click any part of the sample to restyle it. Tooltips use the new look the next time they open.")
subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
skin:bind(function(native)
    -- Leave room inside the native frame for the scrollbar's arrow buttons.
    editor:SetWidth(WIDTH + (native and 16 or 0))
    heading:ClearAllPoints()
    heading:SetFontObject(native and "GameFontNormal" or "GameFontNormalLarge")
    if native then heading:SetPoint("TOP", 0, -5) else heading:SetPoint("TOPLEFT", 16, -14) end
    subheading:ClearAllPoints()
    if native then subheading:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -34)
    else subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4) end
end)

-- The controls column scrolls, so the window keeps its size whatever the
-- tooltip type shown has to set.
local column = CreateFrame("ScrollFrame", nil, editor)
column:SetPoint("TOPLEFT", CONTROLS_X, -CONTROLS_TOP)
column:SetSize(CONTROLS_WIDTH, EDITOR_HEIGHT - CONTROLS_TOP - BUTTONS_SPACE)
column:SetClipsChildren(true)
local content = CreateFrame("Frame", nil, column)
content:SetSize(CONTROLS_WIDTH, 1)
column:SetScrollChild(content)
local columnBar = CreateFrame("Slider", nil, editor)
columnBar:SetOrientation("VERTICAL")
columnBar:SetPoint("TOPLEFT", column, "TOPRIGHT", 6, 0)
columnBar:SetPoint("BOTTOMLEFT", column, "BOTTOMRIGHT", 6, 0)
columnBar:SetWidth(6)
columnBar:SetValueStep(1)
local columnTrack = fill(columnBar, "BACKGROUND", LINE, .6)
columnTrack:SetAllPoints()
columnBar:SetThumbTexture(WHITE)
local columnThumb = columnBar:GetThumbTexture()
columnThumb:SetWidth(6)
columnThumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
columnBar:Hide()
columnBar:SetScript("OnValueChanged", function(_, offset) column:SetVerticalScroll(math.floor(offset + .5)) end)
skin:scrollbar(columnBar, columnTrack, 6, SCROLL_STEP)
column:EnableMouseWheel(true)
column:SetScript("OnMouseWheel", function(_, delta)
    if columnBar:IsShown() then columnBar:SetValue(columnBar:GetValue() - delta * SCROLL_STEP) end
end)

local state = { tooltipType = "item", sample = 1, selected = "title", saved = {} }
local controls = {}
local refresh, refreshLookup

local function samples()
    return TOOLTIP_TYPES[state.tooltipType].samples
end

local function switchTooltipType(tooltipType)
    if tooltipType == state.tooltipType then return end
    state.saved[state.tooltipType] = { sample = state.sample, selected = state.selected, lookup = state.lookup }
    local saved = state.saved[tooltipType] or {}
    state.tooltipType = tooltipType
    state.sample = saved.sample or 1
    state.selected = saved.selected or TOOLTIP_TYPES[tooltipType].first
    state.lookup = saved.lookup
    refresh()
end

-- The sample ----------------------------------------------------------------

local host = CreateFrame("Frame", nil, editor)
host:SetPoint("TOPLEFT", 16, -PREVIEW_TOP)
host:SetWidth(PREVIEW_WIDTH)
host:SetClipsChildren(true)
skin:surface(host, background(host, { .02, .016, .02 }), outline(host, LINE, .8))
-- Stands in for the game's tooltip; the panel pins itself to it.
local anchor = CreateFrame("Frame", nil, host)
anchor:SetSize(1, 1)
anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -PREVIEW_MARGIN)
local typeTabs = {}
for index, tooltipType in ipairs(TYPE_ORDER) do
    local tab = editorTab(editor, TOOLTIP_TYPES[tooltipType].label, 64, function() switchTooltipType(tooltipType) end)
    tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", (index - 1) * 68, 34)
    typeTabs[tooltipType] = tab
end
local sampleTabs = {}
for index = 1, MAX_SAMPLES do
    local tab = editorButton(editor, "", 56, function()
        state.sample, state.lookup = index, nil
        refresh()
    end)
    tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", (index - 1) * 60, 6)
    sampleTabs[index] = tab
end

local overlay = CreateFrame("Frame", nil, host)
overlay:SetAllPoints()
overlay:EnableMouse(true)
local failure = text(overlay, "GameFontRedSmall")
failure:SetPoint("TOPLEFT", 12, -12)
failure:SetWidth(PREVIEW_WIDTH - 24)
local hint = text(overlay, "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 10, 8)

local scrollBar = CreateFrame("Slider", nil, host)
scrollBar:SetOrientation("VERTICAL")
scrollBar:SetPoint("TOPRIGHT", -3, -3)
scrollBar:SetPoint("BOTTOMRIGHT", -3, 3)
scrollBar:SetWidth(8)
scrollBar:SetValueStep(1)
local scrollTrack = fill(scrollBar, "BACKGROUND", LINE, .6)
scrollTrack:SetAllPoints()
scrollBar:SetThumbTexture(WHITE)
local scrollThumbTexture = scrollBar:GetThumbTexture()
scrollThumbTexture:SetWidth(8)
scrollThumbTexture:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
scrollBar:Hide()
local scrolledFor

local function scrollTo(offset)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -PREVIEW_MARGIN + offset)
end
scrollBar:SetScript("OnValueChanged", function(_, offset) scrollTo(math.floor(offset + .5)) end)
skin:scrollbar(scrollBar, scrollTrack, 8, SCROLL_STEP)
skin:bind(function(native)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", native and -12 or -3, native and -8 or -3)
    scrollBar:SetPoint("BOTTOMRIGHT", native and -12 or -3, native and 8 or 3)
end)
overlay:EnableMouseWheel(true)
overlay:SetScript("OnMouseWheel", function(_, delta)
    if scrollBar:IsShown() then scrollBar:SetValue(scrollBar:GetValue() - delta * SCROLL_STEP) end
end)
local highlights = {}
local hovered

local function preview()
    return anchor.prettyTooltipPreview
end

local function hasPart(key)
    local panel = preview()
    for _, hit in ipairs(panel and panel.hits or {}) do
        if hit.key == key then return true end
    end
    return false
end

local function partAtCursor()
    local panel = preview()
    if not (panel and panel:IsShown() and panel.hits) then return end
    local x, y = GetCursorPosition()
    local scale = overlay:GetEffectiveScale()
    x, y = x / scale, y / scale
    for _, hit in ipairs(panel.hits) do
        local region = hit.region
        local left, right = region:GetLeft(), region:GetRight()
        local top, bottom = region:GetTop(), region:GetBottom()
        if left and region:IsShown() and x >= left - 2 and x <= right + 2
            and y <= top + 1 and y >= bottom - 1 then
            return hit.key
        end
    end
end

local function paintHighlights()
    for _, tex in ipairs(highlights) do tex:Hide() end
    local panel = preview()
    if not (panel and panel.hits) then return end
    local used = 0
    for _, hit in ipairs(panel.hits) do
        local selected = hit.key == state.selected
        if selected or hit.key == hovered then
            used = used + 1
            local tex = highlights[used]
            if not tex then
                tex = overlay:CreateTexture(nil, "OVERLAY")
                tex:SetTexture(WHITE)
                highlights[used] = tex
            end
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", hit.region, "TOPLEFT", -3, 2)
            tex:SetPoint("BOTTOMRIGHT", hit.region, "BOTTOMRIGHT", 3, -2)
            if selected then
                tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .16)
            else
                tex:SetVertexColor(1, 1, 1, .07)
            end
            tex:Show()
        end
    end
end

local function showHint()
    local element = hovered and ns.ELEMENT_BY_KEY[hovered]
    hint:SetText(element and fillText(L["%s: click to edit"], L[element.label])
        or L["Click any part of the sample to edit it."])
end

overlay:SetScript("OnUpdate", function(self)
    local key = self:IsMouseOver() and partAtCursor() or nil
    if key == hovered then return end
    hovered = key
    paintHighlights()
    showHint()
end)

-- The editor's lookup by ID reads this hidden tooltip; it never gets a panel.
local scanner
local function previewByID(target, dataType, id)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PrettyTooltipScanner", UIParent, "GameTooltipTemplate")
        scanner.prettyTooltipScanner = true
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    if dataType == Enum.TooltipDataType.Item then scanner:SetItemByID(id) else scanner:SetSpellByID(id) end
    local data = scanner:GetTooltipData()
    local tooltipType = ns.TooltipTypes[dataType]
    local ok, model = pcall(tooltipType.read, scanner, data, ns.Game)
    scanner:Hide()
    if not (ok and model) then return end
    return ui.renderPreview(target, model, dataType)
end

-- Uncached items are requested; GET_ITEM_INFO_RECEIVED redraws.
local function lookupProblem(tooltipType, id)
    if tooltipType.dataType ~= Enum.TooltipDataType.Item or not C_Item then return end
    if C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(id) == false then
        return fillText(L["There is no item with ID %s."], id)
    end
    if C_Item.GetItemInfo and not C_Item.GetItemInfo(id) then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return fillText(L["Loading item %s..."], id)
    end
end

local function drawSample()
    local tooltipType = TOOLTIP_TYPES[state.tooltipType]
    local problem = state.lookup and lookupProblem(tooltipType, state.lookup)
    if not problem then
        local ok, panel = pcall(function()
            if state.lookup then return previewByID(anchor, tooltipType.dataType, state.lookup) end
            return ui.renderPreview(anchor, tooltipType.samples[state.sample].build(), tooltipType.dataType)
        end)
        if not ok then
            problem = fillText(L["The sample failed to draw: %s"], tostring(panel))
        elseif not panel then
            problem = fillText(L["Nothing to show for %s ID %s."], L[tooltipType.noun], state.lookup)
        end
    end
    failure:SetText(problem or "")
    local shown = preview()
    if shown then
        shown:SetShown(problem == nil)
        overlay:SetFrameLevel(shown:GetFrameLevel() + 20)
        scrollBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
    end
    local showing = state.tooltipType .. ":" .. state.sample .. ":" .. tostring(state.lookup)
    local offset = showing == scrolledFor and scrollBar:GetValue() or 0
    scrolledFor = showing
    local sampleHeight = (shown and shown:IsShown()) and shown:GetHeight() + 2 * PREVIEW_MARGIN or 0
    local range = math.max(0, math.ceil(sampleHeight - host:GetHeight()))
    scrollBar:SetMinMaxValues(0, range)
    scrollBar:SetShown(range > 0)
    if range > 0 then
        scrollThumbTexture:SetHeight(math.max(24, scrollBar:GetHeight() * host:GetHeight() / sampleHeight))
    end
    offset = math.min(offset, range)
    scrollBar:SetValue(offset)
    scrollBar:UpdateScrollMetrics(host:GetHeight(), sampleHeight)
    scrollTo(offset)
end

local function selectPart(key)
    state.selected = key
    -- The part's settings head the column.
    columnBar:SetValue(0)
    if not hasPart(key) and not state.lookup then
        for index = 1, #samples() do
            if index ~= state.sample then
                state.sample = index
                drawSample()
                if hasPart(key) then break end
            end
        end
    end
    refresh()
end

overlay:SetScript("OnMouseDown", function()
    if hovered then selectPart(hovered) end
end)

-- Dropdowns ------------------------------------------------------------------

local catcher = CreateFrame("Button", nil, editor)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:EnableMouse(true)
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
local menu = CreateFrame("Frame", nil, catcher)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:EnableMouseWheel(true)
skin:surface(menu, background(menu, { .07, .06, .06 }), outline(menu, LINE))
local scrollThumb = fill(menu, "ARTWORK", GOLD, .5)
scrollThumb:SetWidth(2)
menu.rows = {}

local function closeMenu()
    catcher:Hide()
    menu.owner = nil
end
catcher:SetScript("OnClick", closeMenu)

local function fillMenu()
    local items, offset = menu.items, menu.offset
    local current = menu.owner.current()
    for index = 1, MENU_ROWS do
        local row = menu.rows[index]
        local item = items[index + offset]
        if item then
            row.item = item
            if item.font then
                ui.setFont(row.label, item.font, 13)
            else
                plainFont(row.label)
            end
            row.label:SetText(L[item.text])
            if item.value == current then
                row.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                row.label:SetTextColor(.90, .87, .80)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    local shown = math.min(#items, MENU_ROWS)
    if #items > MENU_ROWS then
        local track = shown * MENU_ROW_HEIGHT - 4
        local length = math.max(12, track * MENU_ROWS / #items)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2,
            -2 - (track - length) * offset / (#items - MENU_ROWS))
        scrollThumb:SetHeight(length)
        scrollThumb:Show()
    else
        scrollThumb:Hide()
    end
    menu:SetHeight(shown * MENU_ROW_HEIGHT + 4)
end

for index = 1, MENU_ROWS do
    local row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * MENU_ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", -6, -2 - (index - 1) * MENU_ROW_HEIGHT)
    local glow = fill(row, "HIGHLIGHT", GOLD, .12)
    glow:SetAllPoints()
    row.label = text(row, "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetPoint("RIGHT", -4, 0)
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local owner = menu.owner
        closeMenu()
        owner.pick(self.item.value)
        refresh()
    end)
    menu.rows[index] = row
end

menu:SetScript("OnMouseWheel", function(_, delta)
    local last = math.max(0, #menu.items - MENU_ROWS)
    menu.offset = math.max(0, math.min(last, menu.offset - delta))
    fillMenu()
end)

local function openMenu(owner)
    local items = owner.items()
    menu.owner, menu.items, menu.offset = owner, items, 0
    for index, item in ipairs(items) do
        if item.value == owner.current() then
            menu.offset = math.max(0, math.min(index - 1, #items - MENU_ROWS))
            break
        end
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(owner:GetWidth())
    catcher:Show()
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    fillMenu()
end

-- items() lists { value, text, font }; current() is the chosen value, nil for
-- the default; pick(value) saves a choice.
local function dropdown(width, items, current, pick)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    local edges = outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -20, 0)
    button.label:SetWordWrap(false)
    local arrow = text(button, "GameFontNormalSmall", "v")
    arrow:SetPoint("RIGHT", -8, 0)
    skin:field(button, button.bg, edges, arrow)
    button.items, button.current, button.pick = items, current, pick
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(FIELD_HOVER[1], FIELD_HOVER[2], FIELD_HOVER[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(FIELD[1], FIELD[2], FIELD[3], 1)
    end)
    button:SetScript("OnClick", function(self)
        if menu.owner == self then closeMenu() else openMenu(self) end
    end)
    button.refresh = function()
        local value, shown = current(), nil
        for _, item in ipairs(items()) do
            if item.value == value then shown = item break end
        end
        if shown and shown.font then
            ui.setFont(button.label, shown.font, 13)
        else
            plainFont(button.label)
        end
        button.label:SetText(shown and L[shown.text] or fillText(L["%s (not installed)"], tostring(value)))
    end
    controls[#controls + 1] = button
    return button
end

local function fontItems(defaultText)
    local items = { { text = defaultText } }
    for _, name in ipairs(ns.fontNames()) do
        items[#items + 1] = { value = name, text = name, font = ns.fontPath(name) }
    end
    return items
end

-- Other controls -------------------------------------------------------------

local function slider(width, current, set, low, high, suffix)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(width, 22)
    local bar = CreateFrame("Slider", nil, holder, "MinimalSliderTemplate")
    local parts = skin.templateParts(bar)
    bar:SetOrientation("HORIZONTAL")
    bar:SetPoint("LEFT", 0, 0)
    bar:SetSize(width - 46, 16)
    bar:SetMinMaxValues(low or SIZE_MIN, high or SIZE_MAX)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    local track = fill(bar, "BACKGROUND", LINE)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    local value = text(holder, "GameFontHighlight")
    value:SetPoint("RIGHT", 0, 0)
    value:SetJustifyH("RIGHT")
    bar:SetScript("OnValueChanged", function(self, number)
        if self.updating then return end
        number = math.floor(number + .5)
        if number ~= current() then
            set(number)
            refresh()
        end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta) end)
    local updateSteppers = skin:slider(bar, track, parts)
    skin:bind(function(native)
        value:SetFontObject(native and "GameFontNormal" or "GameFontHighlight")
    end)
    holder.refresh = function()
        bar.updating = true
        bar:SetValue(current())
        bar.updating = false
        updateSteppers()
        value:SetText(current() .. (suffix or ""))
    end
    controls[#controls + 1] = holder
    return holder
end

-- Both color picker interfaces; cancelling restores the saved color.
local function pickColor(start, apply, restore)
    local function changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply({ r, g, b })
        refresh()
    end
    local function cancelled()
        restore()
        refresh()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = start[1], g = start[2], b = start[3], hasOpacity = false,
            swatchFunc = changed, cancelFunc = cancelled,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r = start[1], g = start[2], b = start[3] }
        ColorPickerFrame.func = changed
        ColorPickerFrame.cancelFunc = cancelled
        ColorPickerFrame:SetColorRGB(start[1], start[2], start[3])
        ShowUIPanel(ColorPickerFrame)
    end
end

local function selectedElement()
    return ns.ELEMENT_BY_KEY[state.selected]
end

local function colorControl()
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(FIELD_WIDTH, 22)
    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT")
    outline(swatch, LINE)
    local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
    chip:SetPoint("TOPLEFT", 3, -3)
    chip:SetPoint("BOTTOMRIGHT", -3, 3)
    local status = text(holder, "GameFontHighlightSmall")
    status:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    local automatic = editorButton(holder, "Automatic", 80, function()
        ns.setElementSetting(state.selected, "color", nil)
        refresh()
    end)
    automatic:SetPoint("RIGHT")
    swatch:SetScript("OnClick", function()
        local key = state.selected
        local saved = ns.elementSetting(key, "color")
        local start = type(saved) == "table" and saved or ns.ELEMENT_BY_KEY[key].color
        pickColor(start,
            function(color) ns.setElementSetting(key, "color", color) end,
            function() ns.setElementSetting(key, "color", saved) end)
    end)
    holder.refresh = function()
        local saved = ns.elementSetting(state.selected, "color")
        local custom = type(saved) == "table"
        local color = custom and saved or selectedElement().color
        chip:SetVertexColor(color[1], color[2], color[3], custom and 1 or .35)
        status:SetText(custom and L["Custom"] or L["Automatic"])
        automatic:SetShown(custom)
    end
    controls[#controls + 1] = holder
    return holder
end

local function checkbox(label, key, description, isAvailable)
    local button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    button:SetSize(22, 22)
    if isAvailable then button:SetMotionScriptsWhileDisabled(true) end
    local caption = text(button, "GameFontHighlightSmall", label)
    caption:SetPoint("LEFT", button, "RIGHT", 2, 1)
    button:SetHitRectInsets(0, -(caption:GetStringWidth() + 6), 0, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[label], 1, 1, 1)
        GameTooltip:AddLine(L[description], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A key can depend on the tooltip type shown.
    local function keyOf() return type(key) == "function" and key() or key end
    button:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        ns.setOption(keyOf(), nil)
        if ns.option(keyOf()) ~= checked then ns.setOption(keyOf(), checked) end
        refresh()
    end)
    button.refresh = function()
        button:SetChecked(ns.option(keyOf()))
        local available = not isAvailable or isAvailable()
        button:SetEnabled(available)
        caption:SetFontObject(available and "GameFontHighlightSmall" or "GameFontDisableSmall")
        if available and ns.savedOption(keyOf()) ~= nil then caption:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
    end
    controls[#controls + 1] = button
    return button
end

-- Looking up by ID -------------------------------------------------------------

local function applyLookup(entry)
    local tooltipType = state.tooltipType
    local id = entry:match("^%s*(%d+)%s*$")
    for _, candidate in ipairs(TYPE_ORDER) do
        local linked = entry:match(TOOLTIP_TYPES[candidate].noun .. ":(%d+)")
        if linked then id, tooltipType = linked, candidate break end
    end
    if tooltipType ~= state.tooltipType then switchTooltipType(tooltipType) end
    state.lookup = id and tonumber(id) or nil
    refresh()
end

local lookupLabel = text(editor, "GameFontHighlightSmall")
lookupLabel:SetPoint("BOTTOMLEFT", host, "TOPRIGHT", 18, 11)
local lookupBox = CreateFrame("EditBox", nil, editor)
lookupBox:SetSize(CONTROLS_WIDTH - LABEL_WIDTH - 70, 22)
lookupBox:SetPoint("BOTTOMLEFT", host, "TOPRIGHT", 18 + LABEL_WIDTH, 6)
skin:field(lookupBox, background(lookupBox, FIELD), outline(lookupBox, LINE))
lookupBox:SetFontObject("GameFontHighlightSmall")
lookupBox:SetTextInsets(8, 8, 0, 0)
lookupBox:SetAutoFocus(false)
lookupBox:SetMaxLetters(255)
local lookupPlaceholder = text(lookupBox, "GameFontDisableSmall", "ID, or shift-click a link")
lookupPlaceholder:SetPoint("LEFT", 8, 0)
lookupBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyLookup(self:GetText())
end)
lookupBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    refresh()
end)
lookupBox:SetScript("OnEditFocusGained", function() lookupPlaceholder:Hide() end)
lookupBox:SetScript("OnEditFocusLost", function(self)
    lookupPlaceholder:SetShown(self:GetText() == "")
end)
local lookupClear = editorButton(editor, "Clear", 62, function()
    state.lookup = nil
    refresh()
end)
lookupClear:SetPoint("LEFT", lookupBox, "RIGHT", 8, 0)

if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if lookupBox:HasFocus() and type(link) == "string" then
            lookupBox:ClearFocus()
            applyLookup(link)
        end
    end)
end

refreshLookup = function()
    local hidden = TOOLTIP_TYPES[state.tooltipType].noLookup == true
    lookupLabel:SetShown(not hidden)
    lookupBox:SetShown(not hidden)
    lookupLabel:SetText(L[TOOLTIP_TYPES[state.tooltipType].label:sub(1, -2) .. " ID"])
    if not lookupBox:HasFocus() then
        lookupBox:SetText(state.lookup and tostring(state.lookup) or "")
        lookupPlaceholder:SetShown(state.lookup == nil)
    end
    lookupClear:SetShown(state.lookup ~= nil and not hidden)
end

-- The controls column ----------------------------------------------------------

-- The column lists, in order, the part selected, what every tooltip shares,
-- what the tooltip type shown keeps for itself, and what only that type has.
-- Each entry is a frame of its own; one with shown() appears only while it
-- says so, and the column lays out the entries shown on every refresh.
local entries = {}

local function entry(height, shown)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(CONTROLS_WIDTH, height)
    entries[#entries + 1] = { holder = holder, height = height, shown = shown }
    return holder, entries[#entries]
end

-- shown() for an entry of some tooltip types alone.
local function forTypes(...)
    local wanted = {}
    for _, tooltipType in ipairs({ ... }) do wanted[tooltipType] = true end
    return function() return wanted[state.tooltipType] == true end
end

-- title is text, or a function giving it, for one that names the type shown.
local function section(title, shown, first)
    local top = first and 0 or 8
    local holder = entry(top + 26, shown)
    local label = text(holder, "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, -top)
    local rule = fill(holder, "ARTWORK", LINE)
    rule:SetPoint("TOPLEFT", 0, -top - 16)
    rule:SetSize(CONTROLS_WIDTH, 1)
    controls[#controls + 1] = {
        refresh = function() label:SetText(L[type(title) == "function" and title() or title]) end,
    }
end

-- What a row's reset button clears: saved gives the stored value, nil while
-- the setting is at its default.
local function partSetting(field)
    return {
        saved = function() return ns.elementSetting(state.selected, field) end,
        reset = function() ns.setElementSetting(state.selected, field, nil) end,
    }
end

-- key can be a function, for a setting kept per tooltip type.
local function optionSetting(key)
    local function keyOf() return type(key) == "function" and key() or key end
    return {
        saved = function() return ns.savedOption(keyOf()) end,
        reset = function() ns.setOption(keyOf(), nil) end,
    }
end

-- A label, the control beside it, and, once the setting is changed, the label
-- in gold with a button to put it back.
local function row(label, control, setting, shown, stacked)
    local holder = entry(stacked and 54 or 30, shown)
    local caption = text(holder, "GameFontHighlightSmall", label)
    caption:SetPoint("TOPLEFT", 0, -5)
    control:SetParent(holder)
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", stacked and 0 or LABEL_WIDTH, stacked and -24 or 0)
    if not setting then return end
    local button = CreateFrame("Button", nil, holder)
    button:SetSize(16, 16)
    button:SetPoint("TOPRIGHT", holder, "TOPLEFT", CONTROLS_WIDTH, -3)
    button:SetNormalTexture(RESET_ICON)
    button:SetHighlightTexture(RESET_ICON, "ADD")
    button:SetScript("OnClick", function()
        setting.reset()
        refresh()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Reset to default"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    controls[#controls + 1] = {
        refresh = function()
            local changed = setting.saved() ~= nil
            button:SetShown(changed)
            if changed then caption:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else caption:SetTextColor(1, 1, 1) end
        end,
    }
end

-- Checkboxes two to a line, each { label, key, description, shown }: those
-- shown close up, so a type's own come out without gaps.
local function toggles(list, shown)
    local holder, item = entry(0, shown)
    local boxes = {}
    for index, toggle in ipairs(list) do
        local box = checkbox(toggle[1], toggle[2], toggle[3], toggle[5])
        box:SetParent(holder)
        boxes[index] = { box = box, shown = toggle[4] }
    end
    -- The height is what the boxes shown take, so it is worked out at layout.
    item.layout = function()
        local count = 0
        for _, entryBox in ipairs(boxes) do
            local visible = not entryBox.shown or entryBox.shown()
            entryBox.box:SetShown(visible)
            if visible then
                local side = count % 2
                entryBox.box:ClearAllPoints()
                entryBox.box:SetPoint("TOPLEFT", side * (CONTROLS_WIDTH / 2), -math.floor(count / 2) * 26)
                count = count + 1
            end
        end
        return count > 0 and math.ceil(count / 2) * 26 + 4 or 0
    end
end

-- The part selected ------------------------------------------------------------

section("Selected Part", nil, true)
local pickerHolder = entry(26)
local partPicker = dropdown(CONTROLS_WIDTH, function()
    local items = {}
    for _, element in ipairs(ns.ELEMENTS) do
        local tooltipType = element.tooltipType or "item"
        if tooltipType == state.tooltipType or tooltipType == "shared" then
            items[#items + 1] = { value = element.key, text = element.label }
        end
    end
    return items
end, function() return state.selected end, function(key) selectPart(key) end)
partPicker:SetParent(pickerHolder)
partPicker:SetPoint("TOPLEFT")
local noteHolder = entry(28)
local partNote = text(noteHolder, "GameFontDisableSmall")
partNote:SetPoint("TOPLEFT")
partNote:SetWidth(CONTROLS_WIDTH)
partNote:SetHeight(24)
partNote:SetJustifyV("TOP")

row("Font", dropdown(FIELD_WIDTH, function()
    return fontItems(selectedElement().title and "Name font" or "Text font")
end, function()
    return ns.elementSetting(state.selected, "font")
end, function(name)
    ns.setElementSetting(state.selected, "font", name)
end), partSetting("font"))

row("Size", slider(FIELD_WIDTH, function()
    return ns.elementSetting(state.selected, "size") or selectedElement().size
end, function(size)
    ns.setElementSetting(state.selected, "size", size ~= selectedElement().size and size or nil)
end), partSetting("size"))

row("Color", colorControl(), partSetting("color"))

row("Outline", dropdown(FIELD_WIDTH, function()
    local items = { { text = "Same as global settings" } }
    for _, item in ipairs(OUTLINES) do items[#items + 1] = item end
    return items
end, function()
    return ns.elementSetting(state.selected, "outline")
end, function(value)
    ns.setElementSetting(state.selected, "outline", value)
end), partSetting("outline"))

-- The part's default is saved as no setting.
local allCaps = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
allCaps:SetSize(22, 22)
local allCapsLabel = text(allCaps, "GameFontHighlightSmall", "All caps")
allCapsLabel:SetPoint("LEFT", allCaps, "RIGHT", 2, 1)
allCaps:SetHitRectInsets(0, -(allCapsLabel:GetStringWidth() + 6), 0, 0)
allCaps:SetScript("OnClick", function(self)
    local checked = self:GetChecked() and true or false
    if checked == (selectedElement().title == true) then
        ns.setElementSetting(state.selected, "caps", nil)
    else
        ns.setElementSetting(state.selected, "caps", checked)
    end
    refresh()
end)
allCaps.refresh = function()
    local caps = ns.elementSetting(state.selected, "caps")
    if caps == nil then caps = selectedElement().title == true end
    allCaps:SetChecked(caps)
end
controls[#controls + 1] = allCaps
row("Letters", allCaps, partSetting("caps"))

local resetHolder = entry(32)
local resetPart = editorButton(resetHolder, "Reset this part", 120, function()
    ns.resetElement(state.selected)
    refresh()
end)
resetPart:SetPoint("TOPLEFT", LABEL_WIDTH, 0)

-- Color groups share picker, cancel, and reset behavior. Their swatches
-- sit below the label, clear of its reset button.
local function hexColor(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- note, if given, says why the colors shown may not be the ones chosen.
local function colorSwatches(list, prefix, colorOf, note)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(CONTROLS_WIDTH, 22)
    local chips = {}
    for index, choice in ipairs(list) do
        local key = prefix .. choice.key
        local swatch = CreateFrame("Button", nil, holder)
        swatch:SetSize(22, 22)
        swatch:SetPoint("LEFT", (index - 1) * 28, 0)
        outline(swatch, LINE)
        local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
        chip:SetPoint("TOPLEFT", 3, -3)
        chip:SetPoint("BOTTOMRIGHT", -3, 3)
        swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        swatch:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                ns.setOption(key, nil)
                refresh()
                return
            end
            local saved = ns.savedOption(key)
            pickColor(colorOf(choice.key) or ns.Palette.roles.neutral,
                function(color) ns.setOption(key, color) end,
                function() ns.setOption(key, saved) end)
        end)
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[choice.label], 1, 1, 1)
            GameTooltip:AddLine(L["Click to choose its color; right-click for the default."], nil, nil, nil, true)
            local why = note and note()
            if why then GameTooltip:AddLine(why, 1, .82, 0, true) end
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
        chips[choice.key] = chip
    end
    holder.refresh = function()
        for key, chip in pairs(chips) do
            local color = colorOf(key) or ns.Palette.roles.neutral
            chip:SetVertexColor(color[1], color[2], color[3], 1)
        end
    end
    controls[#controls + 1] = holder
    return holder
end

local function colorGroupSetting(list, prefix)
    return {
        saved = function()
            for _, choice in ipairs(list) do
                if ns.savedOption(prefix .. choice.key) ~= nil then return true end
            end
        end,
        reset = function()
            for _, choice in ipairs(list) do ns.setOption(prefix .. choice.key, nil) end
        end,
    }
end

-- Every tooltip ------------------------------------------------------------------

section("All Tooltips")
row("Text font", dropdown(FIELD_WIDTH, function()
    return fontItems("Game default")
end, function() return ns.option("bodyFont") end, function(name)
    ns.setOption("bodyFont", name)
end), optionSetting("bodyFont"))
row("Name font", dropdown(FIELD_WIDTH, function()
    local locale = GetLocale()
    return fontItems(locale ~= "koKR" and locale ~= "zhCN" and locale ~= "zhTW"
        and ns.Game.addonInstalled("EllesmereUI") and "Expressway Bold (EllesmereUI)"
        or "Game default")
end, function() return ns.option("titleFont") end, function(name)
    ns.setOption("titleFont", name)
end), optionSetting("titleFont"))
row("Outline", dropdown(FIELD_WIDTH, function() return OUTLINES end, function()
    return ns.option("outline")
end, function(value)
    ns.setOption("outline", value ~= "NONE" and value or nil)
end), optionSetting("outline"))
-- A scale on every part's own size, in steps of 5%; the default is saved as no setting.
row("Text size", slider(FIELD_WIDTH, function()
    return math.floor(ns.option("fontScale") * 100 + .5)
end, function(percent)
    percent = math.floor(percent / 5 + .5) * 5
    ns.setOption("fontScale", percent ~= 100 and percent / 100 or nil)
end, 80, 150, "%"), optionSetting("fontScale"))
-- Automatic draws the game's tooltip border, flat beside EllesmereUI, and
-- DialogueUI's art while that addon is installed.
row("Panel style", dropdown(FIELD_WIDTH, function() return BACKDROP_STYLES end, function()
    return ns.option("backdropStyle")
end, function(value)
    ns.setOption("backdropStyle", value)
end), optionSetting("backdropStyle"))

-- Shared by every tooltip type. The default is saved as no setting.
local function panelSize(key, low, high)
    return slider(FIELD_WIDTH, function() return ns.option(key) end, function(value)
        ns.setOption(key, nil)
        if ns.option(key) ~= value then ns.setOption(key, value) end
    end, low, high)
end
row("Padding", panelSize("padding", 8, 32), optionSetting("padding"))
row("Min width", panelSize("minWidth", 120, 400), optionSetting("minWidth"))
toggles({
    { "Icon on the right", "iconRight",
        "Moves the item or spell icon, and the item level badge under it, to the right of the name." },
    { "Tint the panel", "qualityTint",
        "Washes the panel in the item's quality color, or the spell's school or resource. Off, "
            .. "every panel is neutral; the name keeps its quality color." },
    { "Separators", "separators",
        "The gold dividers between sections and the thin rules above other addons' rows. Off, "
            .. "they are hidden along with the space around them." },
})
row("School colors", colorSwatches(ns.Palette.SCHOOLS, "schoolColor", ns.Palette.school),
    colorGroupSetting(ns.Palette.SCHOOLS, "schoolColor"), nil, true)

-- The tooltip type shown -----------------------------------------------------------

-- Settings kept per tooltip type, named for the one shown.
local function bandKey(edge)
    return function() return "header" .. edge .. "Alpha" .. ns.TYPE_SUFFIX[state.tooltipType] end
end
local function typeKey(name)
    return function() return name .. ns.TYPE_SUFFIX[state.tooltipType] end
end

section(function() return fillText(L["%s Panel"], L[TOOLTIP_TYPES[state.tooltipType].label]) end)
toggles({
    { "Show icon", typeKey("icon"), "The icon or portrait in the header, for the kind of tooltip shown." },
})

-- A default value is saved as no setting, so it keeps following the backdrop.
local function bandOpacity(edge)
    local key = bandKey(edge)
    -- What the tooltip type shows with no setting of its own.
    local function fallback() return ns.option("header" .. edge .. "Alpha") or ui.defaultHeaderAlpha() end
    return slider(FIELD_WIDTH, function()
        return math.floor((ns.headerAlpha(state.tooltipType, edge) or ui.defaultHeaderAlpha()) * 100 + .5)
    end, function(percent)
        local alpha = percent / 100
        ns.setOption(key(), math.abs(alpha - fallback()) > .001 and alpha or nil)
    end, 0, 100, "%")
end
row("Band top", bandOpacity("Top"), optionSetting(bandKey("Top")))
row("Band bottom", bandOpacity("Bottom"), optionSetting(bandKey("Bottom")))

-- The default opacity is saved as no setting.
local function typeOpacity(name, default)
    local key = typeKey(name)
    return slider(FIELD_WIDTH, function()
        return math.floor((ns.option(key()) or default) * 100 + .5)
    end, function(percent)
        ns.setOption(key(), math.abs(percent / 100 - default) > .001 and percent / 100 or nil)
    end, 0, 100, "%")
end
row("Backdrop", typeOpacity("backdropAlpha", ns.BACKDROP_ALPHA), optionSetting(typeKey("backdropAlpha")))
row("Glow", typeOpacity("glowAlpha", 1), optionSetting(typeKey("glowAlpha")))

-- What only the type shown has ---------------------------------------------------------

local DETAILS = { item = "Item Details", spell = "Spell Details", unit = "Unit Details", object = "Object Details",
    quest = "Quest Details" }
section(function() return DETAILS[state.tooltipType] end, function() return DETAILS[state.tooltipType] ~= nil end)
local items, spells, units = forTypes("item"), forTypes("spell"), forTypes("unit")
-- The spell power rows read spell descriptions, which not every language's reading covers yet.
local function coefficients() return ns.Locale.features.coefficients == true end
toggles({
    { "Quest parchment", "questParchment", "DialogueUI's brown parchment for quest tooltips, Quest Items, "
        .. "and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed.",
        forTypes("item", "quest"), function() return ns.Game.addonInstalled("DialogueUI") end },
    { "Level badge", "itemLevelBadge", "The item level on a plate under the icon, for equipment.", items },
    { "Level badge", "unitLevelBadge",
        "The level on a plate under the portrait. Off, the level stays in the info line.", units },
    { "Stat markers", "statMarkers", "The small diamond before each stat; enchants use a green one.", items },
    { "Stat colors", "statColors",
        "Each kind of stat in its color below, and the school colors. Off, every stat is parchment.", items },
    { "Lite tooltips", "itemLite", "Keep the game's own item tooltip, with its Equip effects shortened, "
        .. "as +1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit "
        .. "effects in their stat colors. Hold the modifier for the full wording. The panel's item settings, "
        .. "such as disenchant results, do not apply.", items },
    { "Disenchant", "disenchant", "Green, blue, and purple armor and weapons list what they disenchant into, "
        .. "with each result's chance and the Enchanting it needs; with Auctionator, the expected value.", items },
    { "Sell price", "sellPrice", "The vendor price in the footer; for a stack, the price of one and of the "
        .. "whole stack.", items },
    { "Spell power", "spellPower", "Under the description, each amount's spell power coefficient and its "
        .. "split into base and spell power. No game API has coefficients: they come from Forever's client "
        .. "data, and ones marked ~ are estimates.", spells, coefficients },
    { "Rates", "spellRates", "Under the spell power breakdown, the average a cast deals or heals per second "
        .. "and per mana. Per second, what lands at once counts over the cast time (instants as the 1.5 sec "
        .. "global cooldown) and what comes over time over its duration. Crits and talents do not count.", spells,
        coefficients },
    { "Health bar", "unitHealthBar", "The game's own health bar at the bottom of player and NPC panels. The "
        .. "game fills it, so it stays live without the addon reading health, which WoW Forever keeps from "
        .. "addons.", units },
    { "Gathering", "gatheringLoot", "What a herb or ore node holds: its yield over all the times it can be "
        .. "gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead "
        .. "creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. "
        .. "From Classic's loot tables.", forTypes("object", "unit") },
    { "IDs", "showIDs", "The item's, spell's, or NPC's ID at the bottom of its panel, under other addons' rows.",
        forTypes("item", "spell", "unit") },
})

row("Stat colors", colorSwatches(ns.Stats.CATEGORIES, "statColor", function(key)
    return hexColor((ns.Stats.categoryColors(key)))
end), colorGroupSetting(ns.Stats.CATEGORIES, "statColor"), items, true)
row("Class colors", colorSwatches(ns.Palette.CLASSES, "classColor", ns.Palette.classColor, function()
    if ns.Palette.addonClassColors() then
        return L["Your class colors addon sets these; the colors chosen here apply without it."]
    end
end),
    colorGroupSetting(ns.Palette.CLASSES, "classColor"), units, true)

-- Lays out the entries shown, top to bottom, and sizes the scroll to them.
local function layoutColumn()
    local y = 0
    for _, item in ipairs(entries) do
        local visible = not item.shown or item.shown()
        local height = visible and (item.layout and item.layout() or item.height) or 0
        if height > 0 then
            item.holder:ClearAllPoints()
            item.holder:SetPoint("TOPLEFT", 0, -y)
            item.holder:SetHeight(height)
            item.holder:Show()
            y = y + height
        else
            item.holder:Hide()
        end
    end
    content:SetHeight(y + 8)
    local range = math.max(0, math.ceil(y + 8 - column:GetHeight()))
    columnBar:SetMinMaxValues(0, range)
    columnBar:SetShown(range > 0)
    if range > 0 then
        columnThumb:SetHeight(math.max(24, columnBar:GetHeight() * column:GetHeight() / (y + 8)))
    end
    columnBar:SetValue(math.min(columnBar:GetValue(), range))
    columnBar:UpdateScrollMetrics(column:GetHeight(), y + 8)
    column:SetVerticalScroll(math.min(columnBar:GetValue(), range))
end

editor:SetHeight(EDITOR_HEIGHT)
host:SetHeight(EDITOR_HEIGHT - PREVIEW_TOP - 16)

local resetAll = editorButton(editor, "Reset all fonts and colors", 170, function()
    ns.resetStyles()
    refresh()
end)
resetAll:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", CONTROLS_X, 16)
local moreOptions = editorButton(editor, "More options", 100, function()
    if ns.openSettings() then editor:Hide() end
end)
moreOptions:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -18, 16)

-- Wiring ---------------------------------------------------------------------

refresh = function()
    drawSample()
    for tooltipType, tab in pairs(typeTabs) do tab:SetSelected(tooltipType == state.tooltipType) end
    for index, tab in ipairs(sampleTabs) do
        local sample = samples()[index]
        tab:SetShown(sample ~= nil)
        if sample then
            tab.label:SetText(L[sample.label])
            tab:SetSelected(not state.lookup and index == state.sample)
        end
    end
    refreshLookup()
    partNote:SetText(L[selectedElement().note or ""])
    layoutColumn()
    for _, control in ipairs(controls) do control.refresh() end
    paintHighlights()
    showHint()
end

function ns.refreshEditorStyle()
    closeMenu()
    skin:refresh()
end

editor:SetScript("OnShow", function() ns.refreshEditorStyle() refresh() end)
editor:SetScript("OnHide", closeMenu)
editor:RegisterEvent("GET_ITEM_INFO_RECEIVED")
editor:RegisterEvent("QUEST_DATA_LOAD_RESULT")
editor:SetScript("OnEvent", function(_, event, id, success)
    if not editor:IsShown() then return end
    if ns.util.isSecret(id) or ns.util.isSecret(success) then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if state.tooltipType == "item" and id == state.lookup then refresh() end
    elseif event == "QUEST_DATA_LOAD_RESULT" and success and state.tooltipType == "quest" then
        local sample = samples()[state.sample]
        if sample and sample.questID == id then refresh() end
    end
end)

function ns.openEditor()
    editor:Show()
    editor:Raise()
end
