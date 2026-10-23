-- Small helpers the other files share, as ns.util. Loads first. They read only
-- their arguments, apart from issecretvalue, the game's test for a value it
-- hides.
local _, ns = ...
local util = {}
ns.util = util

-- Whether this is retail's client, whose .toc alone loads the Retail/ folder,
-- Retail/Retail.lua first. Shared code does not ask: it reads what a client
-- contributes or extends (below, and Retail/Retail.lua). Tests and the package
-- check do.
function ns.IsRetail()
    return ns.Retail ~= nil
end

-- What a client's files add to a shared file's lists, registered before that
-- file loads (Retail/Data/Stats.lua's, before Data/Stats.lua): the shared file
-- reads them by its target's name, in the order they came. A client that
-- changes what a shared file does, rather than adding to its lists, does so
-- in a file loaded after it (Retail/Tooltips/ItemExtension.lua).
local contributed = {}
function ns.contribute(target, contribution)
    contributed[target] = contributed[target] or {}
    table.insert(contributed[target], contribution)
end
function ns.contributions(target)
    return contributed[target] or {}
end

-- Secret values and tables whose contents this addon cannot access must be
-- rejected before indexing, comparing, formatting, or doing arithmetic.
local secretValue = issecretvalue or function() return false end
local canAccessTable = canaccesstable
function util.isSecret(value)
    return secretValue(value) or (type(value) == "table" and canAccessTable and not canAccessTable(value)) or false
end
local isSecret = util.isSecret

-- A function's results as a table, with their count in n, nils included.
function util.pack(...)
    return { n = select("#", ...), ... }
end

-- Text ------------------------------------------------------------------------

function util.trim(text)
    return text:match("^%s*(.-)%s*$")
end

-- Chinese and Japanese full stops, exclamation and question marks, which end
-- a sentence without a space after them.
local WIDE_ENDS = { "\227\128\130", "\239\188\129", "\239\188\159" }

-- Where the first sentence from from on ends, and where the next one starts
-- less one. A sentence ends at . ! or ? followed by a space and a capital, so
-- decimals such as "1.5 sec" stay whole. Russian lower-case words after
-- abbreviations stay in the sentence; other non-ASCII letters count as capitals.
local function sentenceEnd(text, from)
    local stop, resume
    local position = from
    while true do
        local mark, spaces = text:find("[%.!?]%s+", position)
        if not mark then break end
        local after = text:byte(spaces + 1)
        local nextByte = text:byte(spaces + 2)
        local russianLower = (after == 208 and nextByte and nextByte >= 176 and nextByte <= 191)
            or (after == 209 and nextByte and (nextByte <= 143 or nextByte == 145))
        if after and not russianLower and (after >= 195 or text:sub(spaces + 1, spaces + 1):match("%u")) then
            stop, resume = mark, spaces
            break
        end
        position = spaces + 1
    end
    for _, wide in ipairs(WIDE_ENDS) do
        local start = text:find(wide, from, true)
        if start and start + #wide < #text and (not stop or start < stop) then
            stop, resume = start + #wide - 1, start + #wide - 1
        end
    end
    return stop, resume
end

function util.splitSentences(text)
    local sentences = {}
    for paragraph in (text:gsub("\r?\n", "|n") .. "|n"):gmatch("(.-)|n") do
        local from = 1
        while true do
            local stop, resume = sentenceEnd(paragraph, from)
            if not stop then break end
            sentences[#sentences + 1] = util.trim(paragraph:sub(from, stop))
            from = resume + 1
        end
        local rest = util.trim(paragraph:sub(from))
        if rest ~= "" then sentences[#sentences + 1] = rest end
    end
    return sentences
end

-- In capitals, as string.upper, which knows only ASCII letters, also for the
-- accented Latin letters and Russian Cyrillic. Korean and Chinese have no
-- capitals.
function util.upper(text)
    text = text:upper():gsub("\195([\160-\190])", function(byte)
        if byte == "\183" then return "\195\183" end
        return "\195" .. string.char(byte:byte() - 32)
    end)
    text = text:gsub("\197\147", "\197\146")
    text = text:gsub("\208([\176-\191])", function(byte)
        return "\208" .. string.char(byte:byte() - 32)
    end):gsub("\209([\128-\143])", function(byte)
        return "\208" .. string.char(byte:byte() + 32)
    end)
    return (text:gsub("\209\145", "\208\129"))
end

-- Case-insensitive school matching also needs Russian letters, which Lua's
-- string.lower leaves unchanged. Keep other scripts as string.lower does.
function util.lower(text)
    text = text:lower():gsub("\208([\144-\175])", function(byte)
        local value = byte:byte()
        if value < 160 then return "\208" .. string.char(value + 32) end
        return "\209" .. string.char(value - 32)
    end)
    return (text:gsub("\208\129", "\209\145"))
end

-- How long a line reads, in characters: a character of Chinese, Japanese, or
-- Korean, three bytes long, counts as two Latin letters, as it says about as
-- much, and every other character as one.
function util.width(text)
    local width = 0
    for lead in text:gmatch("[%z\1-\127\194-\244]") do
        width = width + (lead:byte() >= 224 and 2 or 1)
    end
    return width
end

-- Without color codes.
function util.uncolored(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Without color codes or inline textures.
function util.plainText(text)
    return (text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The game's own escapes; digits inside them (color codes, icon sizes, the
-- plural escape "|4hour:hrs;") must not be recolored.
local ESCAPES = { "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a", "|H.-|h", "|K.-|k", "|4[^;]*;",
    "|3%-%d+%b()", "|n" }

-- "1 |4hour:hrs;" picks its word from the nearest number before it, words
-- between allowed: "1 to 5 Combo |4Point:Points;". Coloring that number would
-- separate the two, so resolve the escape first: singular for 1. Russian has
-- three forms: 1/21, 2-4/22-24, and the rest (including 11-14).
local function pluralOf(number, space, forms)
    local one, few, many = forms:match("^([^:]*):([^:]*):(.*)$")
    local value = tonumber(number)
    if many then
        local last, hundred = value % 10, value % 100
        local form = (hundred < 11 or hundred > 14)
            and (last == 1 and one or (last >= 2 and last <= 4) and few) or many
        return number .. space .. (form or many)
    end
    one, many = forms:match("^([^:]*):(.*)$")
    if not one then return number .. space .. "|4" .. forms .. ";" end
    return number .. space .. (value == 1 and one or many)
end

-- Words between must start after a space, or a format's "%.3g |4..." would
-- take its 3 for the number.
local function resolvePlurals(text)
    text = text:gsub("(%d+)(%s*)|4([^;]*);", pluralOf)
    return (text:gsub("(%d+)(%s[^%d|]-)|4([^;]*);", pluralOf))
end

util.resolvePlurals = resolvePlurals

local function colorPlainNumbers(text, code)
    -- A number must start a word, so "x2" is left alone; a sentence's final
    -- period stays outside the color.
    return (text:gsub("%f[%w](%d+[.,]?%d*%%?)", function(number)
        local trailing = ""
        if number:sub(-1):match("[.,]") then number, trailing = number:sub(1, -2), number:sub(-1) end
        return "|cff" .. code .. number .. "|r" .. trailing
    end))
end

function util.colorNumbers(text, code)
    text = resolvePlurals(text)
    local out, plainStart, pos = {}, 1, 1
    while true do
        local bar = text:find("|", pos, true)
        if not bar then break end
        local escapeEnd
        for _, pattern in ipairs(ESCAPES) do
            local _, stop = text:find("^" .. pattern, bar)
            if stop then escapeEnd = stop break end
        end
        -- An escape this list does not know still protects its first character.
        escapeEnd = escapeEnd or math.min(bar + 1, #text)
        out[#out + 1] = colorPlainNumbers(text:sub(plainStart, bar - 1), code)
        out[#out + 1] = text:sub(bar, escapeEnd)
        plainStart, pos = escapeEnd + 1, escapeEnd + 1
    end
    out[#out + 1] = colorPlainNumbers(text:sub(plainStart), code)
    return table.concat(out)
end

-- Reading text the game printed from its own strings ------------------------------

-- Color codes carry no meaning, a no-break space (as French puts before a
-- colon) reads as a space, and |n is a line break.
local function normalized(text)
    text = util.uncolored(text):gsub("\194\160", " "):gsub("\226\128\175", " ")
    -- Tooltip data can retain the grammar control even when its font string
    -- shows the chosen word, as on Russian set bonuses.
    return (resolvePlurals(text):gsub("|n", "\n"))
end

local function escapePattern(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- What each conversion reads: "%s" any text, "%c" the sign the game passes
-- it, and the rest a number, with either separator (see util.parseNumber).
local NUMBER = "(%-?%d[%d%.,]*)"
local SIGN = "([%+%-])"
-- French "|2 " is "de " before a consonant and "d'" before a vowel.
local DE = { "de ", "d'", "d\226\128\153" }

-- A game string such as "Requires Level %d" as the patterns that read text
-- printed from it: one per choice its grammar escapes make ("|4hour:hours;",
-- Korean "|1으로부터;로부터;", French "|2 "), as patterns have no "or". order
-- holds, for each capture, the argument it is: "%2$s %1$d emplacements"
-- captures the second argument first.
local function compileFormat(format)
    -- Russian's |3-1(%s) declines the argument, leaving only the resulting
    -- word in the displayed tooltip. Capture that word without the control.
    local text = util.trim(normalized(format)):gsub("|3%-%d+%((.-)%)", "%1")
    local bodies, order, count = { "" }, {}, 0
    local function append(choices)
        local grown = {}
        for _, body in ipairs(bodies) do
            for _, choice in ipairs(choices) do grown[#grown + 1] = body .. choice end
        end
        bodies = grown
    end
    local pos = 1
    while pos <= #text do
        if text:sub(pos, pos) == "%" then
            local _, positional, index = text:find("^%%(%d+)%$", pos)
            local _, stop, kind = text:find("^[%-%+ #0]*%d*%.?%d*([%%sdicfgFu])", (positional or pos) + 1)
            if not stop or kind == "%" then
                append({ "%%" })
                pos = (stop or pos) + 1
            else
                local argument = tonumber(index) or #order + 1
                order[#order + 1] = argument
                count = math.max(count, argument)
                append({ kind == "s" and "(.-)" or kind == "c" and SIGN or NUMBER })
                pos = stop + 1
            end
        elseif text:find("^|4[^;]*;", pos) then
            local _, stop, forms = text:find("^|4([^;]*);", pos)
            local choices = {}
            for form in (forms .. ":"):gmatch("(.-):") do choices[#choices + 1] = escapePattern(form) end
            append(choices)
            pos = stop + 1
        elseif text:find("^|1[^;]*;[^;]*;", pos) then
            local _, stop, first, second = text:find("^|1([^;]*);([^;]*);", pos)
            append({ escapePattern(first), escapePattern(second) })
            pos = stop + 1
        elseif text:find("^|2", pos) then
            local _, stop = text:find("^|2 ?", pos)
            append(DE)
            pos = stop + 1
        else
            local stop = (text:find("[%%|]", pos + 1) or #text + 1) - 1
            append({ escapePattern(text:sub(pos, stop)) })
            pos = stop + 1
        end
    end
    local patterns = {}
    for index, body in ipairs(bodies) do patterns[index] = "^" .. body .. "$" end
    return { patterns = patterns, bodies = bodies, order = order, count = count }
end

local compiledFormats = {}
local function compiled(format)
    local found = compiledFormats[format]
    if not found then
        found = compileFormat(format)
        compiledFormats[format] = found
    end
    return found
end

-- What the game's string format filled in to print text, in the order of its
-- arguments: util.unformat("Durability 34 / 100", DURABILITY_TEMPLATE) gives
-- "34", "100". true when it matches and has nothing to fill in; nil when the
-- text was not printed from it. Colors and the space around the text do not count.
function util.unformat(text, format)
    -- A language can word one line in more than one way: { "...", "..." }.
    if type(format) == "table" then
        for _, each in ipairs(format) do
            local found = util.pack(util.unformat(text, each))
            if found[1] ~= nil then return unpack(found, 1, found.n) end
        end
        return
    end
    if type(text) ~= "string" or type(format) ~= "string" then return end
    local parsed = compiled(format)
    text = util.trim(normalized(text))
    for _, pattern in ipairs(parsed.patterns) do
        local found = { text:match(pattern) }
        if found[1] then
            if parsed.count == 0 then return true end
            local values = {}
            for index, argument in ipairs(parsed.order) do values[argument] = found[index] end
            return unpack(values, 1, parsed.count)
        end
    end
end

-- Where text printed from a format appears inside a longer text, from init
-- on, as string.find answers: where it starts and stops, then what the
-- format filled in, in the order of its arguments. lead is a Lua pattern
-- for what may come before it ("^" for nothing, "" for anything). The text
-- is read as it is, colors and all, so the positions are its own.
function util.findFormat(text, format, init, lead)
    if type(text) ~= "string" or type(format) ~= "string" then return end
    local parsed = compiled(format)
    for _, body in ipairs(parsed.bodies) do
        local found = { text:find((lead or "") .. body, init or 1) }
        if found[1] then
            local values = {}
            for index, argument in ipairs(parsed.order) do values[argument] = found[index + 2] end
            return found[1], found[2], unpack(values, 1, parsed.count)
        end
    end
end

-- The game's string format printed with values as text, kept as they were
-- printed: util.fill(SPELL_DURATION_SEC, "2.5") gives "2.5 sec", where
-- string.format would give "2.5" a precision of its own. A plural escape
-- takes the form its number asks for.
function util.fill(format, ...)
    local values, next = { ... }, 0
    local text = format:gsub("%%([%d%$%-%+ #%.]*)([%%sdicfgFu])", function(spec, kind)
        if kind == "%" then return "%" end
        local index = tonumber(spec:match("^(%d+)%$"))
        if not index then
            next = next + 1
            index = next
        end
        return tostring(values[index] or "")
    end)
    return resolvePlurals(text)
end

-- Whether the text opens with a label the game puts first, as "Use:". Colors
-- and the space around the label do not count.
function util.startsWith(text, label)
    if type(text) ~= "string" or type(label) ~= "string" then return false end
    label = util.trim(normalized(label))
    return label ~= "" and normalized(text):sub(1, #label) == label
end

-- A number as the client printed it. group is the client's group separator
-- (LARGE_NUMBER_SEPERATOR): "," on enUS, "." on deDE, none on frFR. Only a
-- group separator before three digits is one; any other "." or "," is the
-- decimal point, so "1.5" that Lua printed on a German client reads too.
function util.parseNumber(text, group)
    if type(text) ~= "string" then return end
    local number = text:match("^%s*([%+%-]?[%d%.,]*%d)%s*$")
    if not number then return end
    if group == "." or group == "," then
        number = number:gsub("%" .. group .. "(%d%d%d)%f[^%d]", "%1")
    end
    return tonumber((number:gsub(",", ".")))
end

-- Values the game may hide ------------------------------------------------------

-- The value, or nil when the game hides it.
function util.readable(value)
    if isSecret(value) then return nil end
    return value
end

-- The value when it is a number the game did not hide, else nil.
function util.number(value)
    if not isSecret(value) and type(value) == "number" then return value end
end

-- A line's text: "" for none, nil when hidden or not text.
function util.safeText(value)
    if isSecret(value) then return nil end
    if value == nil then return "" end
    if type(value) ~= "string" then return nil end
    return value
end

-- Calls fn and gives back up to four of its results; nothing when fn is
-- missing, fails, or any of them is hidden.
function util.call(fn, ...)
    if isSecret(fn) or type(fn) ~= "function" then return end
    for index = 1, select("#", ...) do
        if isSecret(select(index, ...)) then return end
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or isSecret(a) or isSecret(b) or isSecret(c) or isSecret(d) then return end
    return a, b, c, d
end

-- Cosmetic integrations leave forbidden and protected native frames alone,
-- including outside combat: adopting one can make later cleanup restricted.
-- pcall contains API errors; it does not make a protected operation secure.
local function restrictedFrame(frame, method)
    local getter = frame[method]
    if isSecret(getter) then return true end
    if getter ~= nil then
        if type(getter) ~= "function" then return true end
        local ok, restricted = pcall(getter, frame)
        return not ok or isSecret(restricted) or type(restricted) ~= "boolean" or restricted
    end
    return false
end
function util.canModify(frame)
    if isSecret(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata") then return false end
    if restrictedFrame(frame, "IsForbidden") or restrictedFrame(frame, "IsProtected") then return false end
    -- A frame can inherit a forbidden layout from the frame it is anchored to
    -- without IsForbidden saying so, and then every call on it fails; reading
    -- its width is a call allowed to fail. A width that is only hidden is not a
    -- restriction: in combat the game hides a tooltip's size along with its text.
    local getWidth = frame.GetWidth
    if isSecret(getWidth) then return false end
    if type(getWidth) == "function" and not pcall(getWidth, frame) then return false end
    return true
end

-- Anchor snapshots are replayed later, so every component must be readable.
function util.framePoints(frame)
    if not util.canModify(frame) then return end
    local count = util.number((util.call(frame.GetNumPoints, frame)))
    if not count then return end
    local points = {}
    for index = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
        if not ok or isSecret(point) or isSecret(relative) or isSecret(relativePoint)
            or isSecret(x) or isSecret(y) or type(point) ~= "string" or type(relativePoint) ~= "string"
            or type(x) ~= "number" or type(y) ~= "number" then return end
        points[index] = { point, relative, relativePoint, x, y }
    end
    return points
end

-- Colors ------------------------------------------------------------------------

-- A color from the game (r, g, and b fields) as a plain { r, g, b }; nil when
-- hidden or not a color.
function util.rgb(color)
    if isSecret(color) or type(color) ~= "table" then return end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    return { r, g, b }
end

-- "RRGGBB" for a { r, g, b } color, each part capped at 1.
function util.hex(color)
    local function byte(value) return math.floor(math.min(1, value) * 255 + .5) end
    return string.format("%02X%02X%02X", byte(color[1]), byte(color[2]), byte(color[3]))
end
