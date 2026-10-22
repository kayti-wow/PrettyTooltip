-- A stand-in for the game, enough to load the addon and run its readers and
-- renderers outside it. Frames, font strings, and textures keep what is set on
-- them and answer what is asked; methods it does not know do nothing. Game
-- functions answer from the fixture's recorded calls, and report() hears of
-- every call it has no answer for. Text is measured with fixed metrics (half
-- the font size per character), so rendered layouts are the same every run.
--
-- Returns the world: the fixture's tooltips and the callbacks the addon gave
-- TooltipDataProcessor.
local stringsSet = {}

return function(fixture, enums, report, strings)
    local world = { preCalls = {}, postCalls = {}, tooltips = {}, objects = {} }

    -- Values the game hid are marked { __secret = true } in a capture. They
    -- come back as one opaque value that issecretvalue knows, and that, like
    -- the game's, cannot be compared, counted, or joined to text.
    local function refuse() error("attempt to use a secret value", 2) end
    local SECRET = setmetatable({}, { __index = refuse, __newindex = refuse, __concat = refuse,
        __add = refuse, __sub = refuse, __mul = refuse, __div = refuse, __lt = refuse, __le = refuse,
        __len = refuse, __unm = refuse, __call = refuse, __tostring = refuse })
    local SECRET_TABLE = setmetatable({}, { __index = refuse, __newindex = refuse })
    local function unmark(value, seen)
        if type(value) ~= "table" or seen[value] then return value end
        if rawget(value, "__secret") == true then return SECRET end
        if rawget(value, "__secretTable") == true then return SECRET_TABLE end
        seen[value] = true
        for key, item in pairs(value) do value[key] = unmark(item, seen) end
        return value
    end
    unmark(fixture, {})
    issecretvalue = function(value) return value == SECRET end
    canaccesstable = function(value) return value ~= SECRET and value ~= SECRET_TABLE end
    world.secret, world.secretTable = SECRET, SECRET_TABLE
    -- The comparisons' answers join the tooltip's: the game is the same game.
    local calls = {}
    for _, capture in ipairs({ fixture, unpack(fixture.comparisons or {}) }) do
        for name, byArgs in pairs(capture.calls or {}) do
            calls[name] = calls[name] or {}
            for key, results in pairs(byArgs) do calls[name][key] = results end
        end
    end

    local function noop() end
    local function pack(...) return { n = select("#", ...), ... } end

    -- Frames, font strings, and textures -----------------------------------

    local Object = {}
    -- Names that start like a method: one the stand-in does not know is the
    -- game's, doing nothing here. Other names, as a frame's CloseButton, are
    -- children the frame does not have.
    local VERBS = { "Set", "Get", "Is", "Has", "Can", "Enable", "Disable", "Register", "Unregister", "Clear",
        "Hook", "Raise", "Lower", "Lock", "Unlock", "Start", "Stop", "Play", "Add", "Remove", "Update",
        "Refresh", "Reset", "Toggle", "Release", "Apply", "Insert", "Scroll", "Click", "Fade", "Adjust",
        "Highlight" }
    local function isMethodName(key)
        if type(key) ~= "string" then return false end
        for _, verb in ipairs(VERBS) do
            local after = key:sub(#verb + 1, #verb + 1)
            if key:sub(1, #verb) == verb and (after == "" or after:match("[%u%d]")) then return true end
        end
        return false
    end
    -- While world.counts is a table, every method called on a frame is
    -- counted by name, for --profile.
    local function tally(name)
        if world.counts then world.counts[name] = (world.counts[name] or 0) + 1 end
    end
    world.tally = tally
    local meta = {
        __index = function(_, key)
            local method = Object[key]
            if not method and isMethodName(key) then method = noop end
            if method and world.counts then
                return function(...)
                    tally(key)
                    return method(...)
                end
            end
            return method
        end,
    }

    local function new(kind, name, parent)
        local object = setmetatable({
            _kind = kind, _name = name, _parent = parent, _shown = true, _points = {}, _scripts = {},
            _children = {}, _width = 0, _height = 0, _alpha = 1, _level = 1, _strata = "MEDIUM",
            _font = { path = "Fonts\\FRIZQT__.TTF", size = 12, flags = "" }, _color = { 1, 1, 1, 1 },
        }, meta)
        if parent and parent._children then table.insert(parent._children, object) end
        world.objects[#world.objects + 1] = object
        if type(name) == "string" then
            if parent and parent._name then name = name:gsub("%$parent", parent._name) end
            object._name = name
            _G[name] = object
        end
        return object
    end
    world.new = new

    -- Only listeners registered when the event starts receive it.
    function world.fireEvent(event, ...)
        local listeners = {}
        for _, object in ipairs(world.objects) do
            if object:IsEventRegistered(event) and object._scripts.OnEvent then
                listeners[#listeners + 1] = object
            end
        end
        for _, object in ipairs(listeners) do object._scripts.OnEvent(object, event, ...) end
    end

    -- What the eye sees of a string: links and colors gone, textures counted.
    local function visible(text)
        local textures = 0
        text = tostring(text or "")
        text = text:gsub("|T.-|t", function() textures = textures + 1 return "" end)
        text = text:gsub("|A.-|a", function() textures = textures + 1 return "" end)
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        text = text:gsub("|4([^:;]*):[^;]*;", "%1"):gsub("|n", "\n")
        return text, textures
    end

    local function widthOf(text, size)
        local plain, textures = visible(text)
        local widest = 0
        for line in (plain .. "\n"):gmatch("(.-)\n") do
            -- UTF-8 continuation bytes do not start a character.
            local characters = #(line:gsub("[\128-\191]", ""))
            widest = math.max(widest, characters * size * 0.5)
        end
        return widest + textures * size
    end

    local function heightOf(object)
        local size = object._font.size
        local plain = visible(object._text)
        local lines = 0
        for line in (plain .. "\n"):gmatch("(.-)\n") do
            local width = widthOf(line, size)
            if object._width > 0 and width > object._width then
                lines = lines + math.ceil(width / object._width)
            else
                lines = lines + 1
            end
        end
        return lines * math.floor(size * 1.15 + .5)
    end

    function Object:GetObjectType() return self._kind end
    function Object:IsObjectType(kind) return self._kind == kind end
    function Object:GetName() return self._name end
    function Object:GetParent() return self._parent end
    function Object:GetRegions()
        local regions = {}
        for _, object in ipairs(self._children) do
            if object._kind == "Texture" or object._kind == "FontString" then regions[#regions + 1] = object end
        end
        return unpack(regions)
    end
    function Object:GetChildren()
        local frames = {}
        for _, object in ipairs(self._children) do
            if object._kind ~= "Texture" and object._kind ~= "FontString"
                and object._kind ~= "MaskTexture" and object._kind ~= "AnimationGroup"
                and object._kind ~= "Animation" then frames[#frames + 1] = object end
        end
        return unpack(frames)
    end
    function Object:SetParent(parent) self._parent = parent end
    function Object:Show() self._shown = true end
    function Object:Hide() self._shown = false end
    function Object:SetShown(shown) self._shown = not not shown end
    function Object:IsShown() return self._shown end
    function Object:IsForbidden() return self._forbidden == true end
    function Object:IsProtected() return self._protected == true end
    function Object:IsVisible()
        local object = self
        while object do
            if not object._shown then return false end
            object = object._parent
        end
        return true
    end
    function Object:SetPoint(point, relativeTo, relativePoint, x, y)
        if type(relativeTo) == "number" then
            relativeTo, relativePoint, x, y = self._parent, point, relativeTo, relativePoint
        elseif relativeTo == nil then
            relativeTo, relativePoint = self._parent, point
        end
        if type(relativeTo) == "string" then relativeTo = _G[relativeTo] end
        if type(relativePoint) == "number" then relativePoint, x, y = point, relativePoint, x end
        table.insert(self._points, { point, relativeTo, relativePoint or point, x or 0, y or 0 })
    end
    function Object:SetAllPoints(relativeTo)
        self._points = { { "TOPLEFT", relativeTo or self._parent, "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", relativeTo or self._parent, "BOTTOMRIGHT", 0, 0 } }
    end
    function Object:ClearAllPoints() self._points = {} end
    function Object:GetNumPoints() return #self._points end
    function Object:GetPoint(index)
        local point = self._points[index or 1]
        if point then return point[1], point[2], point[3], point[4], point[5] end
    end
    function Object:SetSize(width, height) self._width, self._height = width or 0, height or 0 end
    function Object:SetWidth(width) self._width = width or 0 end
    function Object:SetHeight(height) self._height = height or 0 end
    function Object:GetWidth()
        if self._kind == "FontString" and self._width == 0 then return widthOf(self._text, self._font.size) end
        return self._width
    end
    function Object:GetHeight()
        if self._kind == "FontString" and self._height == 0 then return heightOf(self) end
        return self._height
    end
    function Object:GetSize() return self:GetWidth(), self:GetHeight() end
    -- Record the native layout policy; pixel rasterization belongs to the game.
    function Object:SetRoundLayoutToNearestPixel(enabled) self._roundLayout = enabled end
    function Object:GetRoundLayoutToNearestPixel() return self._roundLayout == true end
    function Object:SetClampedToScreen(clamped) self._clamped = not not clamped end
    function Object:IsClampedToScreen() return self._clamped or false end
    function Object:SetClampRectInsets(left, right, top, bottom) self._clampRectInsets = { left, right, top, bottom } end
    function Object:GetClampRectInsets() return unpack(self._clampRectInsets or { 0, 0, 0, 0 }) end
    function Object:SetHitRectInsets(left, right, top, bottom) self._hitRectInsets = { left, right, top, bottom } end
    function Object:GetHitRectInsets() return unpack(self._hitRectInsets or { 0, 0, 0, 0 }) end
    function Object:GetLeft() return 0 end
    function Object:GetRight() return self:GetWidth() end
    function Object:GetTop() return 0 end
    function Object:GetBottom() return -self:GetHeight() end
    function Object:GetScaledRect()
        local left, bottom = self:GetLeft(), self:GetBottom()
        if left == nil or bottom == nil then return end
        local factor = self:GetEffectiveScale()
        return left * factor, bottom * factor, self:GetWidth() * factor, self:GetHeight() * factor
    end
    function Object:SetScale(scale) self._scale = scale end
    function Object:GetEffectiveScale()
        return self:GetScale() * (self._parent and self._parent:GetEffectiveScale() or 1)
    end
    function Object:GetScale() return self._scale or 1 end
    function Object:SetAlpha(alpha) self._alpha = alpha end
    function Object:GetAlpha() return self._alpha end
    function Object:SetFrameLevel(level) self._level = level end
    function Object:GetFrameLevel() return self._level end
    function Object:SetFrameStrata(strata) self._strata = strata end
    function Object:GetFrameStrata() return self._strata end
    function Object:IsMouseOver() return false end
    function Object:EnableMouse(enabled) self._mouseEnabled = enabled end
    function Object:IsMouseEnabled() return self._mouseEnabled ~= false end
    function Object:SetScript(event, handler) self._scripts[event] = handler end
    function Object:GetScript(event) return self._scripts[event] end
    function Object:HookScript(event, handler)
        local previous = self._scripts[event]
        self._scripts[event] = previous and function(...) previous(...) handler(...) end or handler
    end
    function Object:RegisterEvent(event) self._events = self._events or {} self._events[event] = true end
    function Object:UnregisterEvent(event) if self._events then self._events[event] = nil end end
    function Object:IsEventRegistered(event) return self._events ~= nil and self._events[event] == true end
    function Object:CreateFontString(name, _, template)
        local font = new("FontString", name, self)
        if template then font:SetFontObject(template) end
        return font
    end
    function Object:CreateTexture(name) return new("Texture", name, self) end
    function Object:CreateMaskTexture(name) return new("MaskTexture", name, self) end
    function Object:CreateAnimationGroup(name) return new("AnimationGroup", name, self) end
    function Object:CreateAnimation(_, name) return new("Animation", name, self) end

    -- Text, on font strings and the buttons that carry one.
    function Object:SetText(text)
        -- The game takes text, a number, or nil, and errors on anything else.
        local kind = type(text)
        if kind ~= "string" and kind ~= "number" and kind ~= "nil" and not (issecretvalue and issecretvalue(text)) then
            error("bad argument #1 to 'SetText' (Usage: self:SetText([text]))", 2)
        end
        if text == self._text then tally("SetText, same text") end
        self._text = text
    end
    function Object:GetText() return self._text end
    function Object:SetFormattedText(format, ...) self._text = format:format(...) end
    function Object:SetFont(path, size, flags)
        local font = self._font
        if font.path == path and font.size == size and font.flags == (flags or "") then
            tally("SetFont, same font")
        end
        self._font = { path = path, size = size, flags = flags or "" }
        return true
    end
    function Object:GetFont() return self._font.path, self._font.size, self._font.flags end
    function Object:SetFontObject(font)
        if type(font) == "string" then font = _G[font] end
        if type(font) == "table" and font._font then
            self._font = { path = font._font.path, size = font._font.size, flags = font._font.flags }
        end
    end
    function Object:SetTextColor(r, g, b, a) self._color = { r, g, b, a or 1 } end
    function Object:GetTextColor() return self._color[1], self._color[2], self._color[3], self._color[4] end
    function Object:SetJustifyH(justify) self._justifyH = justify end
    function Object:GetStringWidth() return widthOf(self._text, self._font.size) end
    function Object:GetUnboundedStringWidth() return widthOf(self._text, self._font.size) end
    function Object:GetStringHeight() return heightOf(self) end

    -- Textures.
    function Object:SetTexture(path) self._texture = path end
    function Object:GetTexture() return self._texture end
    function Object:SetAtlas(atlas) self._texture = "atlas:" .. tostring(atlas) end
    function Object:SetDesaturated(desaturated) self._desaturated = desaturated or nil end
    function Object:SetColorTexture(r, g, b, a) self._texture, self._color = "color", { r, g, b, a or 1 } end
    -- Kept for unit checks; the outputs do not print it.
    function Object:SetVertexColor(r, g, b, a) self._color, self._gradient = { r, g, b, a or 1 }, nil end
    function Object:SetGradient(orientation, from, to)
        self._gradient = { orientation, { from:GetRGBA() }, { to:GetRGBA() } }
    end
    function Object:GetVertexColor() return self._color[1], self._color[2], self._color[3], self._color[4] end
    function Object:SetTexCoord(...) self._coords = { ... } end

    -- Widgets: what a value or child is asked for back after it is set.
    local function child(self, field, kind)
        if not self[field] then self[field] = new(kind, nil, self) end
        return self[field]
    end
    function Object:SetMinMaxValues(low, high) self._min, self._max = low, high end
    function Object:GetMinMaxValues() return self._min or 0, self._max or 0 end
    function Object:SetValue(value) self._value = value end
    function Object:GetValue() return self._value or 0 end
    function Object:SetValueStep(step) self._valueStep = step end
    function Object:GetValueStep() return self._valueStep or 0 end
    function Object:SetThumbTexture(path) child(self, "_thumb", "Texture"):SetTexture(path) end
    function Object:GetThumbTexture() return child(self, "_thumb", "Texture") end
    function Object:SetScrollChild(scrollChild) self._scrollChild = scrollChild end
    function Object:GetScrollChild() return self._scrollChild end
    function Object:SetVerticalScroll(offset) self._scroll = offset end
    function Object:GetVerticalScroll() return self._scroll or 0 end
    function Object:GetVerticalScrollRange() return 0 end
    function Object:SetChecked(checked) self._checked = not not checked end
    function Object:GetChecked() return self._checked or false end
    function Object:Enable() self._enabled = true end
    function Object:Disable() self._enabled = false end
    function Object:SetEnabled(enabled) self._enabled = not not enabled end
    function Object:IsEnabled() return self._enabled ~= false end
    function Object:GetFontString() return child(self, "_fontString", "FontString") end
    function Object:GetNormalTexture() return child(self, "_normal", "Texture") end
    function Object:GetHighlightTexture() return child(self, "_highlight", "Texture") end
    function Object:GetPushedTexture() return child(self, "_pushed", "Texture") end
    function Object:GetDisabledTexture() return child(self, "_disabled", "Texture") end
    function Object:GetCheckedTexture() return child(self, "_checkedTexture", "Texture") end
    function Object:HasFocus() return false end
    function Object:GetNumber() return tonumber(self._text) or 0 end

    -- Tooltips: the fixture's, which answer from what was captured.
    function Object:NumLines() return self._lines and #self._lines or 0 end
    function Object:GetLeftLine(index) return self._left and self._left[index] end
    function Object:GetRightLine(index) return self._right and self._right[index] end
    function Object:GetTooltipData() return self._data end
    function Object:IsTooltipType(dataType) return self._data ~= nil and self._data.type == dataType end
    function Object:GetOwner() return UIParent end
    function Object:GetProcessingTooltipInfo() return nil end

    -- A recorded answer for a call, or nil and a report.
    local function argKey(...)
        local keys = {}
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            keys[index] = type(value) == "table" and "self" or tostring(value)
        end
        return table.concat(keys, ",")
    end

    local function answer(name, calls, ...)
        local key = argKey(...)
        local results = calls[name] and calls[name][key]
        if not results then
            report("missing", name .. "(" .. key .. ")")
            return
        end
        return unpack(results, 1, results.n or #results)
    end

    -- The captured lines as font strings, named as the game names them.
    local function fontLine(tooltip, side, index, state)
        local font = new("FontString", tooltip._name .. "Text" .. side .. index, tooltip)
        if state then
            font._text = state.text
            local color = state.color or {}
            font._color = { color[1] or 1, color[2] or 1, color[3] or 1, 1 }
            font._shown = state.shown ~= false
        else
            font._shown = false
        end
        return font
    end

    -- Lines addon code adds, after the ones the game drew.
    local function addLine(tooltip, left, right, leftColor, rightColor)
        tooltip._lines, tooltip._left, tooltip._right = tooltip._lines or {}, tooltip._left or {}, tooltip._right or {}
        local index = #tooltip._lines + 1
        local line = { left = { text = left, color = leftColor }, right = right and { text = right, color = rightColor } }
        tooltip._lines[index] = line
        tooltip._left[index] = fontLine(tooltip, "Left", index, line.left)
        tooltip._right[index] = fontLine(tooltip, "Right", index, line.right)
    end
    function Object:AddLine(text, r, g, b) addLine(self, text, nil, { r, g, b }) end
    function Object:AddDoubleLine(left, right, r, g, b, r2, g2, b2)
        addLine(self, left, right, { r, g, b }, { r2, g2, b2 })
    end

    local function tooltipFrom(name, capture)
        local tooltip = _G[name] or new("GameTooltip", name, nil)
        tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
        for index, line in ipairs(capture.lines or {}) do
            tooltip._lines[index] = line
            tooltip._left[index] = fontLine(tooltip, "Left", index, line.left)
            tooltip._right[index] = fontLine(tooltip, "Right", index, line.right)
        end
        tooltip._data = capture.data
        local captured = capture.calls or {}
        tooltip.GetItem = function(...) return answer("tooltip:GetItem", captured, ...) end
        tooltip.GetSpell = function(...) return answer("tooltip:GetSpell", captured, ...) end
        tooltip.GetUnit = function(...) return answer("tooltip:GetUnit", captured, ...) end
        world.tooltips[#world.tooltips + 1] = { tooltip = tooltip, capture = capture }
        return tooltip
    end

    -- Game functions ---------------------------------------------------------

    -- Functions every client the addon runs on has, answered from the fixture.
    local ALWAYS = {
        "C_Item.GetItemInfo", "C_Item.GetItemIconByID", "C_Item.GetItemCount", "C_Item.IsEquippedItem",
        "C_AddOns.GetAddOnInfo", "UnitExists", "UnitGUID", "UnitName", "UnitIsPlayer", "UnitLevel",
        "UnitClass", "UnitRace", "UnitFactionGroup", "UnitIsAFK", "UnitIsDND", "UnitCreatureType",
        "UnitClassification", "UnitIsPVP", "UnitIsDeadOrGhost", "UnitIsTapDenied", "UnitHealth",
        "UnitHealthMax", "UnitReaction", "UnitIsUnit", "GetGuildInfo", "GetQuestDifficultyColor",
        "GetSpellBonusDamage", "GetSpellBonusHealing",
    }
    -- Functions some clients lack; a fixture says which its client had, or,
    -- from before it did, has those it recorded answers for.
    local OPTIONAL = {
        "GetInboxItem", "GetInboxItemLink",
        "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo", "UnitTokenFromGUID",
        "UnitEffectiveLevel", "GetSpellInfo", "GetSpellTexture", "C_Item.GetItemInfoInstant",
        "C_Item.GetDetailedItemLevelInfo", "C_Item.GetItemNameByID", "C_Spell.GetSpellTexture",
        "C_Spell.GetSpellName", "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetAuraDataByAuraInstanceID",
        "C_QuestLog.IsOnQuest", "C_QuestLog.IsQuestFlaggedCompleted", "GetMacroInfo", "GetMacroIndexByName",
        "GetNumMacros", "GetMacroSpell", "GetMacroItem", "GetPetActionInfo",
    }

    local function install(path, fn)
        local container, last = _G, nil
        for part in path:gmatch("[^.]+") do
            if last then
                container[last] = container[last] or {}
                container = container[last]
            end
            last = part
        end
        container[last] = fn
    end

    for _, path in ipairs(ALWAYS) do
        install(path, function(...) return answer(path, calls, ...) end)
    end
    for _, path in ipairs(OPTIONAL) do
        local has
        if fixture.present then has = fixture.present[path] else has = calls[path] ~= nil end
        if has then install(path, function(...) return answer(path, calls, ...) end) end
    end
    -- An item location cannot be saved; the capture keeps the stack's count by GUID.
    local hasStacks
    if fixture.present then
        hasStacks = fixture.present["C_Item.GetItemLocation"] and fixture.present["C_Item.GetStackCount"]
    else
        hasStacks = calls.stackCount ~= nil
    end
    if hasStacks then
        install("C_Item.GetItemLocation", function(guid) return { guid = guid } end)
        install("C_Item.GetStackCount", function(location)
            return answer("stackCount", calls, location and location.guid)
        end)
    end
    -- Money is left to the addon's own formatting, which needs no game answer.
    if not fixture.present or fixture.present.BreakUpLargeNumbers ~= false then
        BreakUpLargeNumbers = function(value)
            local text = tostring(math.floor(value))
            local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
            return (formatted:gsub("^,", ""))
        end
    end

    -- The game's short names for the standard library.
    tinsert, tremove, format, strlower, strupper = table.insert, table.remove, string.format, string.lower,
        string.upper
    wipe = function(t) for key in pairs(t) do t[key] = nil end return t end
    strtrim = function(text) return (text:match("^%s*(.-)%s*$")) end
    strsplit = function(separator, text)
        local parts = {}
        for part in (text .. separator):gmatch("(.-)" .. separator:gsub("%p", "%%%0")) do parts[#parts + 1] = part end
        return unpack(parts)
    end

    Enum = enums
    GetLocale = function() return fixture.client and fixture.client.locale or "enUS" end
    GetBuildInfo = function()
        local client = fixture.client or {}
        return client.version or "1.60.1", client.build or "0", "", 16001
    end
    GetTime = function() return 1000 end
    debugprofilestop = function() return 0 end
    GetCursorPosition = function() return 0, 0 end
    IsAltKeyDown, IsControlKeyDown = noop, noop
    -- Fixtures draw as with Shift held, so their outputs show every detail;
    -- a test sets fixture.shiftUp to see them hidden.
    IsShiftKeyDown = function() return fixture.shiftUp ~= true end
    InCombatLockdown = noop
    SetPortraitTexture = noop
    PlaySound = noop
    HideUIPanel, ShowUIPanel = noop, noop
    ChatEdit_InsertLink = noop
    SetItemRef = noop
    GameTooltip_SetDefaultAnchor = noop
    print = function(...)
        local parts = {}
        for index = 1, select("#", ...) do parts[index] = tostring((select(index, ...))) end
        report("print", table.concat(parts, " "))
    end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    NUM_CHAT_WINDOWS = 1
    SlashCmdList = {}
    SLASH_PRETTYTOOLTIP1, SLASH_PRETTYTOOLTIP2 = nil, nil
    UISpecialFrames = {}
    PrettyTooltipDB = nil
    RAID_CLASS_COLORS = {}
    CUSTOM_CLASS_COLORS = nil
    for class, color in pairs({
        WARRIOR = { .78, .61, .43 }, PALADIN = { .96, .55, .73 }, HUNTER = { .67, .83, .45 },
        ROGUE = { 1, .96, .41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, .44, .87 }, MAGE = { .25, .78, .92 },
        WARLOCK = { .53, .53, .93 }, DRUID = { 1, .49, .04 },
    }) do
        RAID_CLASS_COLORS[class] = { r = color[1], g = color[2], b = color[3] }
    end

    -- The game's own strings in the fixture's language, from tests/locales
    -- (strings holds each file's source by locale). The previous world's are
    -- cleared first, so one language's never linger into the next.
    for key in pairs(stringsSet) do _G[key] = nil end
    stringsSet = {}
    world.gameStrings = {}
    local locale = GetLocale()
    local source = strings and (strings[locale] or strings.enUS)
    if source then
        local chunkName = "@tests/locales/" .. (strings[locale] and locale or "enUS") .. ".lua"
        world.gameStrings = assert(loadstring(source, chunkName))()
        for key, value in pairs(world.gameStrings) do
            _G[key] = value
            stringsSet[key] = true
        end
    end

    CreateFrame = function(kind, name, parent, template)
        local frame = new(kind, name, parent)
        frame._template = template
        -- Only the decorative regions used by the editor; no template scripts.
        if template == "UIPanelButtonTemplate" then
            for _, part in ipairs({ "Left", "Middle", "Right" }) do
                frame[part] = new("Texture", nil, frame)
                frame[part]:SetTexture("panel-button-" .. part)
            end
        elseif template == "UISliderTemplate" or template == "InsetFrameTemplate" then
            frame.NineSlice = new("Frame", nil, frame)
            if template == "InsetFrameTemplate" then
                frame.Bg = new("Texture", nil, frame)
                frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
            end
        elseif template == "FlatPanelBackgroundTemplate" then
            frame.TopSection = new("Texture", nil, frame)
        elseif template == "MinimalTabTemplate" then
            for _, part in ipairs({ "Left", "Middle", "Right" }) do frame[part] = new("Texture", nil, frame) end
            frame.Text = new("FontString", nil, frame)
            function frame:OnSelected(selected)
                self.Left:SetAtlas(selected and "Options_Tab_Active_Left" or "Options_Tab_Left")
                self.Middle:SetAtlas(selected and "Options_Tab_Active_Middle" or "Options_Tab_Middle")
                self.Right:SetAtlas(selected and "Options_Tab_Active_Right" or "Options_Tab_Right")
                self.Text:SetPoint("BOTTOM", 0, selected and 6 or 4)
            end
            function frame:SetSelected(selected) self.selected = selected self:OnSelected(selected) end
            frame:SetSelected(false)
        elseif template == "MinimalSliderTemplate" then
            for _, part in ipairs({ "Left", "Middle", "Right" }) do
                frame[part] = new("Texture", nil, frame)
                frame[part]:SetAtlas("Minimal_SliderBar_" .. part)
            end
            frame:SetThumbTexture("minimal-slider-thumb")
        elseif template == "MinimalScrollBar" then
            frame.Track = new("Frame", nil, frame)
            frame.Track.Thumb = new("Button", nil, frame.Track)
            frame.Back = new("Button", nil, frame)
            frame.Forward = new("Button", nil, frame)
            frame._percentage, frame._visiblePercentage, frame._panPercentage = 0, 0, .1
            local callbacks = {}
            function frame:RegisterCallback(event, callback, owner) callbacks[event] = { callback, owner } end
            local function update()
                local scrollable = frame._visiblePercentage > 0 and frame._visiblePercentage < 1
                frame.Back:SetEnabled(scrollable and frame._percentage > 0)
                frame.Forward:SetEnabled(scrollable and frame._percentage < 1)
                frame.Track.Thumb:SetShown(scrollable)
            end
            function frame:SetVisibleExtentPercentage(value) self._visiblePercentage = value update() end
            function frame:GetVisibleExtentPercentage() return self._visiblePercentage end
            function frame:SetPanExtentPercentage(value) self._panPercentage = value end
            function frame:SetScrollPercentage(value)
                self._percentage = math.max(0, math.min(1, value))
                update()
                local callback = callbacks.OnScroll
                if callback then callback[1](callback[2], self._percentage) end
            end
            function frame:GetScrollPercentage() return self._percentage end
            frame.Back:SetScript("OnMouseDown", function()
                frame:SetScrollPercentage(frame._percentage - frame._panPercentage)
            end)
            frame.Forward:SetScript("OnMouseDown", function()
                frame:SetScrollPercentage(frame._percentage + frame._panPercentage)
            end)
        end
        return frame
    end
    CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a or 1,
            GetRGBA = function(self) return self.r, self.g, self.b, self.a end,
            GetRGB = function(self) return self.r, self.g, self.b end }
    end
    -- The atlases the addon draws, as WoW Forever 1.60.1 reports them: fixed
    -- client data, like the enums, so no capture records them.
    local atlases = {
        ["ui-hud-unitframe-target-portraiton-boss-gold"] =
            { width = 100, height = 100, coords = { 0.001953, 0.392578, 0.001953, 0.392578 } },
        ["ui-hud-unitframe-target-portraiton-boss-gold-winged"] =
            { width = 110, height = 90, coords = { 0.001953, 0.431641, 0.396484, 0.748047 } },
        ["ui-hud-unitframe-target-portraiton-boss-rare-silver"] =
            { width = 100, height = 100, coords = { 0.396484, 0.787109, 0.001953, 0.392578 } },
        ["ui-hud-unitframe-target-portraiton-boss-rare-silver-winged"] =
            { width = 109, height = 88, coords = { 0.435547, 0.861328, 0.396484, 0.742188 } },
    }
    C_Texture = {
        GetAtlasInfo = function(name)
            local atlas = type(name) == "string" and atlases[name:lower()]
            if not atlas then return end
            local coords = atlas.coords
            return { file = 8244544, width = atlas.width, height = atlas.height,
                leftTexCoord = coords[1], rightTexCoord = coords[2], topTexCoord = coords[3],
                bottomTexCoord = coords[4] }
        end,
    }
    C_Timer = {
        After = function() end,
        NewTimer = function() return { Cancel = noop } end,
        NewTicker = function() return { Cancel = noop } end,
    }
    hooksecurefunc = function(target, method, hook)
        if type(target) == "string" then
            target, method, hook = _G, target, method
        end
        local original = target[method] or noop
        rawset(target, method, function(...)
            local results = pack(original(...))
            hook(...)
            return unpack(results, 1, results.n)
        end)
    end
    TooltipDataProcessor = {
        AddTooltipPreCall = function(dataType, fn)
            world.preCalls[dataType] = world.preCalls[dataType] or {}
            table.insert(world.preCalls[dataType], fn)
        end,
        AddTooltipPostCall = function(dataType, fn)
            world.postCalls[dataType] = world.postCalls[dataType] or {}
            table.insert(world.postCalls[dataType], fn)
        end,
    }

    -- Frames the addon finds at load.
    UIParent = new("Frame", "UIParent", nil)
    UIParent:SetSize(1920, 1080)
    for _, fontName in ipairs({ "GameFontNormal", "GameFontNormalLarge", "GameFontNormalSmall",
        "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable", "GameFontDisableSmall",
        "GameFontRedSmall", "GameTooltipText", "GameTooltipHeaderText" }) do
        local font = new("Font", fontName, nil)
        font._font = { path = "Fonts\\FRIZQT__.TTF", size = fontName:find("Large") and 16
            or fontName:find("Small") and 10 or fontName:find("Header") and 14 or 12, flags = "" }
    end
    ColorPickerFrame = new("Frame", "ColorPickerFrame", UIParent)
    ChatFrame1 = new("ScrollingMessageFrame", "ChatFrame1", UIParent)
    for _, tooltipName in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        new("GameTooltip", tooltipName, UIParent)
    end
    -- The game's nine-slice borders: a layout gives a frame a piece per corner
    -- and edge, and a center. GameTooltip wears the tooltip layout, in grey.
    local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
    NineSliceUtil = {
        ApplyLayoutByName = function(frame, layout)
            if layout ~= "TooltipDefaultLayout" and layout ~= "ButtonFrameTemplateNoPortrait" then
                error("no layout " .. tostring(layout))
            end
            frame._layout = layout
            for _, piece in ipairs(PIECES) do
                frame[piece] = frame[piece] or frame:CreateTexture(piece)
                frame[piece]._texture = "tooltip-" .. piece
                frame[piece]._width, frame[piece]._height = piece:find("Edge") and 0 or 16, piece:find("Edge") and 0 or 16
            end
        end,
    }
    GameTooltip.NineSlice = { layoutType = "TooltipDefaultLayout",
        GetBorderColor = function() return .8, .8, .8, 1 end }

    -- The captured tooltip, and the comparisons beside it.
    world.main = tooltipFrom(fixture.tooltip or "GameTooltip", fixture)
    world.comparisons = {}
    for index, comparison in ipairs(fixture.comparisons or {}) do
        world.comparisons[index] = tooltipFrom(comparison.tooltip or ("ShoppingTooltip" .. index), comparison)
    end
    return world
end
