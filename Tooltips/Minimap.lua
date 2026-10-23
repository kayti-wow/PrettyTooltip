-- The minimap's tooltip as a panel: the blips under the cursor, one name each.
-- Herbs and ore show the skill they need, in its skill-up color; players are
-- in their class color; a name the game greys (indoors, or on another floor)
-- stays grey; and the game's arrow for a blip above or below you lines up on
-- the right.
local _, ns = ...
local ui = ns.ui
local MINIMAP = Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover
if not (ui and MINIMAP and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local EXTRAS_RULE = { .50, .50, .54 }
-- The game's mark for a blip above or below you: one half of its arrows
-- file, at no size of its own.
local ARROW = "|T[^|]*PositionArrows[^|]*|t"
local ARROW_COORDS = "PositionArrows:%-?%d+:%-?%d+:%-?%d+:%-?%d+:(%d+:%d+:%d+:%d+:%d+:%d+)|t"
local ARROW_FILE = "Interface\\Minimap\\Minimap-PositionArrows"
local skillColor = ns.Palette.skillUpColor

-- The color the game wrote the name in, as the grey of a blip indoors or
-- on another floor; nil for none.
local function nameColor(text)
    local code = text:match("^%s*|c%x%x(%x%x%x%x%x%x)")
    if not code then return end
    return { tonumber(code:sub(1, 2), 16) / 255, tonumber(code:sub(3, 4), 16) / 255, tonumber(code:sub(5, 6), 16) / 255 }
end

-- A blip's name, and what is known of it: a node's skill, its meta
-- on the line's right side in metaColor; the color the game wrote it in, or
-- else a player's class color; and the game's arrow, when it is above or below.
local function readBlip(text, game)
    local arrow = text:match(ARROW)
    local rest = text:gsub(ARROW, "")
    local name = trim(util.plainText(rest))
    if name == "" then return end
    local blip = { name = name, arrow = arrow, color = nameColor(rest) }
    local node = ns.gatheringNode and ns.gatheringNode(name)
    if node then
        blip.meta = node.skill .. " " .. node.level
        blip.metaColor = skillColor(node.level, game.skill(node.skill))
    elseif not blip.color then
        local _, classFile = game.playerClass(name)
        blip.color = ns.Palette.classColor(classFile, game)
    end
    return blip
end

local function minimapKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local parts = {}
    for _, line in ipairs(data.lines) do
        if isSecret(line) or type(line) ~= "table" then return end
        local text = safeText(line.leftText)
        if not text then return end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "\n")
end

local function readMinimap(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { blips = {}, extras = {}, lineIndices = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local text = safeText(line.leftText)
            if not text then return end
            model.lineIndices[line.lineIndex] = true
            -- Blips close together share a line, one name each.
            for part in (text:gsub("|n", "\n") .. "\n"):gmatch("(.-)\n") do
                model.blips[#model.blips + 1] = readBlip(part, game)
            end
        end
    end
    if #model.blips == 0 then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    tooltipData.addExtras(model.extras, appended)
    return model
end

-- The game's arrow at the text's size, the half of the file it shows; as
-- the game wrote it when that cannot be read.
local function arrowAt(arrow, size)
    local coords = arrow:match(ARROW_COORDS)
    if not coords then return arrow end
    size = math.floor(size + .5)
    return "|T" .. ARROW_FILE .. ":" .. size .. ":" .. size .. ":0:0:" .. coords .. "|t"
end

-- The name on the left; on the right, a node's skill and the arrow, which
-- line up down the list whether or not every blip has one.
local function blipRow(blip, size)
    local right = blip.meta or ""
    if blip.arrow then right = (right ~= "" and (right .. " ") or "") .. arrowAt(blip.arrow, size) end
    return { left = blip.name, right = right, color = blip.color or colors.title,
        rightColor = blip.metaColor or colors.caption }
end

-- A list, a row each, as narrow as its longest row.
local function minimapView(model)
    local style = ui.styleOf("objectDetails")
    local rows = {}
    for index, blip in ipairs(model.blips) do rows[index] = blipRow(blip, style.size) end
    local sections = { { kind = "rows", rows = rows, style = style, color = colors.title, gap = 3 } }
    if #model.extras > 0 then
        sections[2] = { separator = { rule = EXTRAS_RULE }, kind = "rows", rows = model.extras,
            style = ui.styleOf("extras"), color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return { tooltipType = "object", color = colors.neutral, header = {}, sections = sections, minWidth = 0 }
end

local function renderMinimap(panel, tooltip, model)
    ui.renderView(panel, tooltip, minimapView(model))
end

ui.defineTooltipType(MINIMAP, { read = readMinimap, render = renderMinimap, key = minimapKey,
    option = "minimapPanels" })
