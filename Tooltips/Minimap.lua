-- The minimap's tooltip as a panel: the blips under the cursor, one name each.
-- Herbs and ore show the skill they need, in its skill-up color; players are
-- in their class color.
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
-- The game's mark for a blip above or below you.
local ARROW = "|T[^|]*PositionArrows[^|]*|t"
local skillColor = ns.Palette.skillUpColor

-- A blip's name, and what is known of it: a node's skill, its meta
-- on the line's right side in metaColor; or a player's class color.
local function readBlip(text, game)
    local name = trim(util.plainText(text))
    if name == "" then return end
    local blip = { name = name, arrow = text:match(ARROW) }
    local node = ns.gatheringNode and ns.gatheringNode(name)
    if node then
        blip.meta = node.skill .. " " .. node.level
        blip.metaColor = skillColor(node.level, game.skill(node.skill))
    else
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

local function withArrow(blip)
    return blip.arrow and (blip.name .. " " .. blip.arrow) or blip.name
end

local function blipRow(blip)
    return { left = withArrow(blip), right = blip.meta or "", color = blip.color or colors.title,
        rightColor = blip.metaColor or colors.caption }
end

-- A list, a row each, as narrow as its longest row.
local function minimapView(model)
    local rows = {}
    for index, blip in ipairs(model.blips) do rows[index] = blipRow(blip) end
    local sections = { { kind = "rows", rows = rows, style = ui.styleOf("objectDetails"), color = colors.title, gap = 3 } }
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
