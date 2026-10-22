-- The harness's two entry points. fixture() runs one captured tooltip through
-- the addon as the game would: loads its files in the .toc's order, lets the
-- item rewrite change the data, reads it with its tooltip type's reader, and renders
-- the model, returning the output text and the harness's notes. unit() runs
-- a file of checks against parts of the addon loaded on their own.
local main = {}

local function notesCollector()
    local notes, seen = {}, {}
    local function report(kind, message)
        local line = kind .. ": " .. message
        if not seen[line] then
            seen[line] = true
            notes[#notes + 1] = line
        end
    end
    return notes, report
end

-- Loads the named addon files into a fresh world and returns the namespace.
local function loadAddon(files, sources)
    local ns = {}
    for _, file in ipairs(files) do
        -- A test's own chunk in place of a file, as a language file would load.
        local chunk, problem = file, nil
        if type(file) ~= "function" then chunk, problem = loadstring(sources[file], "@" .. file) end
        if not chunk then error(problem, 0) end
        local ok, failure = xpcall(function() chunk("PrettyTooltip", ns) end, debug.traceback)
        if not ok then error("loading " .. tostring(file) .. ": " .. failure, 0) end
    end
    return ns
end

local function number(value)
    if type(value) ~= "number" then return tostring(value) end
    if value == math.floor(value) then return string.format("%d", value) end
    return string.format("%.4g", value)
end

local function quote(text)
    return (string.format("%q", text):gsub("\\\n", "\\n"))
end

-- What a render drew: each shown font string and texture under the panel, in
-- the order they were made, with where they sit. Places relative to the
-- panel's top left read "at x,y", y counting down.
local function drawn(panel)
    local function name(object)
        if object == panel then return "panel" end
        if object == nil then return "parent" end
        return object._name or object._kind
    end
    local function place(object)
        local point = object._points[1]
        if not point then return "unplaced" end
        local anchor, relativeTo, relativePoint, x, y = point[1], point[2], point[3], point[4], point[5]
        if relativeTo == panel and anchor == "TOPLEFT" and relativePoint == "TOPLEFT" then
            return "at " .. number(x) .. "," .. number(-y)
        end
        return anchor .. " " .. name(relativeTo) .. " " .. relativePoint .. " " .. number(x) .. "," .. number(y)
    end
    local out = { "panel " .. number(panel._width) .. " x " .. number(panel._height) }
    local function walk(object)
        for _, child in ipairs(object._children) do
            -- The panel measures text in a string of its own, never drawn.
            if child._shown and child ~= panel.measure then
                local color = child._color
                local rgb = number(color[1]) .. "," .. number(color[2]) .. "," .. number(color[3])
                if child._kind == "FontString" and child._text and child._text ~= "" then
                    out[#out + 1] = "text " .. place(child) .. " w=" .. number(child._width)
                        .. " size=" .. number(child._font.size) .. " rgb=" .. rgb .. " "
                        .. (issecretvalue and issecretvalue(child._text) and "<secret>" or quote(child._text))
                elseif child._kind == "Texture" and child._texture ~= nil then
                    local texture = tostring(child._texture):gsub("^.*\\", "")
                    out[#out + 1] = "texture " .. place(child) .. " " .. number(child._width) .. "x"
                        .. number(child._height) .. " rgb=" .. rgb .. "," .. number(color[4]) .. " " .. texture
                end
                walk(child)
            end
        end
    end
    walk(panel)
    return table.concat(out, "\n")
end

-- The counts of one phase, largest first, as "name count" lines.
local function profileText(label, counts)
    local names = {}
    local total = 0
    for name, count in pairs(counts) do
        names[#names + 1] = name
        if not name:find(",") then total = total + count end
    end
    table.sort(names, function(a, b)
        if counts[a] ~= counts[b] then return counts[a] > counts[b] end
        return a < b
    end)
    local out = { string.format("%s: %d frame calls", label, total) }
    for _, name in ipairs(names) do out[#out + 1] = string.format("  %-28s %d", name, counts[name]) end
    return table.concat(out, "\n")
end

-- Builds the world, loads the addon, then assigns its saved variables and
-- fires its event, as at login.
local function startAddon(fixture, enums, files, sources, makeWorld, report, settings)
    local world = makeWorld(fixture, enums, report)
    local ns = loadAddon(files, sources)
    if ns.keptAuras then
        for _, entry in ipairs(world.tooltips) do ns.keptAuras[entry.tooltip] = entry.capture.aura end
    end
    local saved = {}
    for key, value in pairs(settings or {}) do saved[key] = value end
    PrettyTooltipDB = saved
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    return world, ns
end

-- A model, then what the panel drew of it.
local function describe(label, ns, model, dataType, serialize, world, profiles)
    local text = { "== " .. label .. " model" }
    if not model then
        text[#text + 1] = "(none: the game's own tooltip shows instead)"
        return table.concat(text, "\n")
    end
    text[#text + 1] = serialize.dump(model)
    local anchor = CreateFrame("Frame", nil, UIParent)
    -- The panel is made on the first render; the profile counts a later one,
    -- as the game draws again and again into the same panel.
    if profiles then ns.ui.renderPreview(anchor, model, dataType) world.counts = {} end
    local rendered, panel = xpcall(function() return ns.ui.renderPreview(anchor, model, dataType) end,
        debug.traceback)
    if not rendered then error(label .. ": rendering failed: " .. panel, 0) end
    if profiles then
        profiles[#profiles + 1] = profileText(label .. " render", world.counts)
        world.counts = nil
    end
    text[#text + 1] = "== " .. label .. " render"
    text[#text + 1] = drawn(panel)
    return table.concat(text, "\n")
end

-- The game's own tooltip, line by line, as it shows after every post-call.
local function nativeLines(label, tooltip)
    local out = { "== " .. label .. " as the game shows it" }
    for index = 1, tooltip:NumLines() do
        local left, right = tooltip._left[index], tooltip._right[index]
        local function shown(font)
            if not (font and font._shown) then return nil end
            if issecretvalue(font._text) then return "(hidden)" end
            return font._text
        end
        local text = shown(left) or ""
        local rightText = shown(right)
        if rightText and rightText ~= "" then text = text .. "  ||  " .. rightText end
        out[#out + 1] = string.format("%2d %q", index, text)
    end
    -- Frames of the addon's own inside the tooltip, as the details are: their
    -- text row by row, top first.
    for _, child in ipairs(tooltip._children or {}) do
        if child._kind == "Frame" and child._shown then
            local rows, order = {}, {}
            for _, font in ipairs(child._children) do
                local point = font._points[1]
                if font._kind == "FontString" and font._shown and point then
                    local y = point[5]
                    if not rows[y] then rows[y], order[#order + 1] = {}, y end
                    table.insert(rows[y], font._text or "")
                end
            end
            table.sort(order, function(a, b) return a > b end)
            if #order > 0 then out[#out + 1] = "   below the lines:" end
            for _, y in ipairs(order) do out[#out + 1] = string.format("   %q", table.concat(rows[y], "  ||  ")) end
        end
    end
    return table.concat(out, "\n")
end

-- options.settings: saved settings to run with. options.native: describe the
-- game's own tooltip after every post-call, instead of the panel, as for lite
-- mode, which leaves the game's tooltip showing. options.profile: also return
-- the frame calls reading and rendering made.
function main.fixture(fixture, enums, files, sources, serialize, makeWorld, options)
    options = options or {}
    local profiles = options.profile and {} or nil
    local notes, report = notesCollector()
    local world, ns = startAddon(fixture, enums, files, sources, makeWorld, report, options.settings)

    local sections = {}
    local function run(label, tooltip, capture)
        if capture.linesAs == "mail" and capture.owner then
            local owner = CreateFrame("CheckButton", capture.owner.name, UIParent)
            owner.index = capture.owner.index
            tooltip:SetOwner(owner, "ANCHOR_NONE")
        end
        local data = capture.data
        -- Filled with lines alone by a frame the addon knows: linesAs names
        -- the type it is drawn as, from its lines, as Hooks.renderLines does.
        if not data and capture.linesAs and enums.TooltipDataType then
            data = { type = enums.TooltipDataType[capture.linesAs] or capture.linesAs, lines = {}, fromLines = true }
        end
        if not data then
            sections[#sections + 1] = "== " .. label .. "\n(filled by an addon with lines alone; not replayed yet)"
            return
        end
        -- The game gives each line its place on the tooltip as it draws them;
        -- lines the rewrite replaced get theirs back.
        local places = {}
        for index, line in ipairs(data.lines or {}) do places[index] = line.lineIndex end
        for _, preCall in ipairs(world.preCalls[data.type] or {}) do preCall(tooltip, data) end
        for index, line in ipairs(data.lines or {}) do
            if line.lineIndex == nil then line.lineIndex = places[index] end
        end
        if options.native then
            for _, postCall in ipairs(world.postCalls[data.type] or {}) do
                local ok, failure = xpcall(function() postCall(tooltip, data) end, debug.traceback)
                if not ok then error(label .. ": a post-call failed: " .. failure, 0) end
            end
            sections[#sections + 1] = nativeLines(label, tooltip)
            return
        end
        local tooltipType = ns.TooltipTypes and ns.TooltipTypes[data.type]
        if not tooltipType then
            sections[#sections + 1] = "== " .. label .. "\n(no panel for this type of tooltip)"
            return
        end
        if profiles then world.counts = {} end
        local ok, model = xpcall(function() return tooltipType.read(tooltip, data, ns.Game) end, debug.traceback)
        if not ok then error(label .. ": reading failed: " .. model, 0) end
        if profiles then
            profiles[#profiles + 1] = profileText(label .. " read", world.counts)
            world.counts = nil
        end
        sections[#sections + 1] = describe(label, ns, model, data.type, serialize, world, profiles)
    end

    run("tooltip", world.main, fixture)
    for index, comparison in ipairs(world.comparisons) do
        run("comparison " .. index, comparison, fixture.comparisons[index])
    end
    return table.concat(sections, "\n\n") .. "\n", notes, table.concat(profiles or {}, "\n")
end

-- Every sample the style editor shows, each as a model and what the panel
-- drew of it, named "<type>-<label>". Covers every tooltip type without a capture.
function main.samples(enums, files, sources, serialize, makeWorld, settings)
    local notes, report = notesCollector()
    local world, ns = startAddon({}, enums, files, sources, makeWorld, report, settings)
    local results = {}
    for _, typeKey in ipairs(ns.editorSamples.order) do
        local tooltipType = ns.editorSamples.tooltipTypes[typeKey]
        for _, sample in ipairs(tooltipType.samples) do
            local name = typeKey .. "-" .. sample.label:lower():gsub("[^%w]+", "-")
            local built, model = xpcall(sample.build, debug.traceback)
            if not built then error(name .. ": building the sample failed: " .. model, 0) end
            results[#results + 1] = { name = name,
                text = describe("sample", ns, model, tooltipType.dataType, serialize, world) .. "\n" }
        end
    end
    return results, notes
end

-- Records each line of the addon's files that runs, into hits[source][line].
function main.track(hits)
    debug.sethook(function(_, line)
        local source = debug.getinfo(2, "S").source
        if source:sub(1, 1) == "@" then
            local lines = hits[source]
            if not lines then
                lines = {}
                hits[source] = lines
            end
            lines[line] = true
        end
    end, "l")
end

-- check(name, got, expected): got and expected are compared as dumped text.
-- tocs: each .toc's files in load order, as test.tocs.forever and test.tocs.retail.
-- enums: the game's enums from harness/enums.lua, as test.enums, to load with.
function main.unit(testSource, testName, sources, serialize, makeWorld, tocs, enums)
    local results = {}
    local notes, report = notesCollector()
    local test = { tocs = tocs, enums = enums }
    -- Loads the named addon files with a world answering from fixture's calls.
    function test.load(files, fixture)
        local world = makeWorld(fixture or {}, fixture and fixture.enums or {}, report)
        local ns = loadAddon(files, sources)
        if ns.keptAuras then
            for _, entry in ipairs(world.tooltips) do ns.keptAuras[entry.tooltip] = entry.capture.aura end
        end
        return ns, world
    end
    -- A list of shared files as retail's .toc loads them: Retail/Retail.lua
    -- first, and each other file in Retail/ just before the file after it in
    -- that .toc, when the list has that file. Retail/Data/Schools.lua, which
    -- replaces Forever's own schools, only when the list names it. A language's
    -- file, which that .toc lists for its clients alone, brings Retail/Locale's.
    function test.retail(files)
        local before, waiting = {}, {}
        for _, file in ipairs(tocs.retail) do
            if file:match("^Retail/") then
                waiting[#waiting + 1] = file
            else
                before[file], waiting = waiting, {}
            end
        end
        local list = { "Retail/Retail.lua" }
        for _, file in ipairs(files) do
            if file:match("^Locale/") and sources["Retail/" .. file] then list[#list + 1] = "Retail/" .. file end
            for _, retail in ipairs(before[file] or {}) do
                if retail ~= "Retail/Retail.lua" and retail ~= "Retail/Data/Schools.lua" then list[#list + 1] = retail end
            end
            list[#list + 1] = file
        end
        return list
    end
    function test.check(name, got, expected)
        local gotText = type(got) == "table" and serialize.dump(got) or tostring(got)
        local expectedText = type(expected) == "table" and serialize.dump(expected) or tostring(expected)
        results[#results + 1] = { name = name, ok = gotText == expectedText, got = gotText, expected = expectedText }
    end
    local chunk, problem = loadstring(testSource, "@" .. testName)
    if not chunk then error(problem, 0) end
    local ok, failure = xpcall(function() chunk()(test) end, debug.traceback)
    if not ok then error(failure, 0) end
    return results, notes
end

return main
