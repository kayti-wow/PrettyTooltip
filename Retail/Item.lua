-- Retail's item lines: where an item comes from (Heroic, Mythic), its upgrade
-- level, crafted quality, and transmogrification, its gems and sockets, and
-- the primary stats another specialization greys. Tooltips/Item.lua reads
-- and draws them through these on retail.
local _, ns = ...
local util = ns.util
local isSecret, safeText, plainText, unformat = util.isSecret, util.safeText, util.plainText, util.unformat
local add, colorOf = ns.TooltipData.add, ns.TooltipData.colorOf
local LINE = Enum and Enum.TooltipDataLineType or {}
local item = {}
ns.Retail.Item = item

-- Each line in the game's color unless the editor sets one.
local SOURCE_COLOR = { .12, 1, .12 }
local UPGRADE_COLOR = { .90, .80, .55 }
local TRANSMOG_COLOR = { 1, .50, 1 }
local CRAFTED_COLOR = { .90, .85, .74 }
-- A crafting reagent's quality icon, against its line's text.
local REAGENT_QUALITY_SCALE = 1.6
local GEM_COLOR = { .90, .85, .74 }
-- A gem's own enchantment, as the game draws it: indented, in gold.
local GEM_ENCHANT_COLOR = { 1, .82, 0 }
local GEM_ENCHANT_INDENT = 20
-- A primary stat another specialization uses, as retail's tooltip greys it.
local INACTIVE_STAT_COLOR = { .50, .50, .50 }

-- Reading ----------------------------------------------------------------------

-- Retail writes some colors with spaces for zeros, as "|cFF 0FF 0Mythic+":
-- read as the color it means, not as text.
function item.repairedColors(text)
    return (text:gsub("|c([%x ][%x ][%x ][%x ][%x ][%x ][%x ][%x ])", function(code)
        return "|c" .. code:gsub(" ", "0")
    end))
end

-- Whether a profession's name is in a requirement's, as a word: retail's for
-- one expansion's part of it, "Midnight Blacksmithing". professions holds the
-- client's names, as keys.
function item.isExpansionProfession(name, professions)
    for profession in pairs(professions) do
        local start, stop = name:find(profession, 1, true)
        if start and not name:sub(start - 1, start - 1):match("%a") and not name:sub(stop + 1, stop + 1):match("%a") then
            return true
        end
    end
    return false
end

-- "Upgrade Level: Myth 2/6" as "Myth 2/6", in the game's own short wording.
local function upgradeOf(text)
    local track, level, most = unformat(text, ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
    if track and tonumber(level) and tonumber(most) then
        return util.fill(ITEM_UPGRADE_DROPDOWN_LEVEL_FORMAT_STRING, track, level, most)
    end
    level, most = unformat(text, ITEM_UPGRADE_TOOLTIP_FORMAT)
    if tonumber(level) and tonumber(most) then return util.fill(ITEM_UPGRADE_DROPDOWN_LEVEL_FORMAT, level, most) end
end

-- The color a line's text opens with, as a panel color; nil without one.
local function openingColor(text)
    local code = text:match("^%s*|c%x%x(%x%x%x%x%x%x)")
    if not code then return end
    local r, g, b = tonumber(code:sub(1, 2), 16), tonumber(code:sub(3, 4), 16), tonumber(code:sub(5, 6), 16)
    return colorOf({ r = r / 255, g = g / 255, b = b / 255 })
end

-- What an item is transmogrified to: "Transmogrified to:" and the appearance,
-- on the line after it or the same one; "" when the next line names it.
local function transmogOf(text)
    local header = type(TRANSMOGRIFIED_HEADER) == "string" and util.trim(TRANSMOGRIFIED_HEADER) or ""
    local plain = util.trim(plainText(text))
    if header == "" or plain:sub(1, #header) ~= header then return end
    local rest = plain:sub(#header + 1):gsub("|n", "\n")
    return util.trim((rest:gsub("%s+", " ")))
end

-- A socket's icon: the gem in it, else the game's empty socket of its kind.
local function socketIcon(line)
    local gem = not isSecret(line.gemIcon) and line.gemIcon or nil
    if type(gem) == "number" or type(gem) == "string" then return gem end
    local kind = not isSecret(line.socketType) and line.socketType or nil
    if type(kind) == "string" and kind ~= "" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. kind end
end

-- The line the reader took before this one: the one before it with a line index.
local function lineBefore(lines, index)
    for at = index - 1, 1, -1 do
        local line = lines[at]
        if isSecret(line) or type(line) ~= "table" or isSecret(line.lineIndex) then return end
        if line.lineIndex then return line end
    end
end

-- Whether the line before this one is "Transmogrified to:" alone, so this
-- one names the appearance.
local function afterTransmogHeader(lines, index)
    local before = lineBefore(lines, index)
    if not before then return false end
    local left, right = safeText(before.leftText), safeText(before.rightText)
    return left ~= nil and right == "" and transmogOf(util.trim(item.repairedColors(left))) == ""
end

-- Whether the line after this one is the item level, as under a source.
local function levelFollows(lines, index)
    local after = lines[index + 1]
    return LINE.ItemLevel ~= nil and not isSecret(after) and type(after) == "table" and not isSecret(after.type)
        and after.type == LINE.ItemLevel
end

local function addSocket(m, text, right)
    m.sockets = m.sockets or {}
    add(m.sockets, text, right)
    return m.sockets[#m.sockets]
end

-- Reads a line of retail's into m, the item or the one a recipe creates: its
-- upgrade level, a socket, gem, or socket bonus, its crafted quality, or its
-- transmogrification. Whether the line was one. left and trimmed are the
-- line's text as the panel words it, original as the game did, if it differs.
function item.readLine(m, line, data, lineNumber, left, right, trimmed, original)
    local lineType = line.type
    local plain = plainText(trimmed)
    if afterTransmogHeader(data.lines, lineNumber) and trimmed ~= "" and right == "" then
        m.transmog = util.trim(plain)
    elseif (LINE.ItemUpgradeLevel and lineType == LINE.ItemUpgradeLevel) or upgradeOf(plain) then
        m.upgrade = upgradeOf(plain) or trimmed
    elseif LINE.GemSocket and lineType == LINE.GemSocket then
        -- A gem's stat in its stat color, without the stat marker; an empty
        -- socket as the game words it.
        local text = ns.Stats.styleStat(util.trim(original or left), ns.option("statColors"), false)
        local row = addSocket(m, text, right)
        row.icon, row.color = socketIcon(line), colorOf(line.leftColor)
    elseif LINE.GemSocketEnchantment and lineType == LINE.GemSocketEnchantment then
        local row = addSocket(m, left, right)
        row.indent, row.color = GEM_ENCHANT_INDENT, GEM_ENCHANT_COLOR
    elseif right == "" and type(ITEM_SOCKETABLE) == "string" and util.trim(plain) == ITEM_SOCKETABLE then
        -- "<Shift Right Click to Socket>", with the sockets, unless turned off.
        if ns.option("socketHint") then addSocket(m, left, "").color = colorOf(line.leftColor) end
    elseif right == "" and unformat(plain, ITEM_SOCKET_BONUS) then
        -- Green while every socket matches, grey before.
        addSocket(m, original or left, "").color = colorOf(line.leftColor)
    elseif (LINE.ProfessionCraftingQuality and lineType == LINE.ProfessionCraftingQuality)
        or (right == "" and unformat(plain, PROFESSIONS_CRAFTING_QUALITY)) then
        m.craftingQuality = trimmed
    elseif right == "" and transmogOf(trimmed) then
        -- Without the appearance, the next line names it.
        local appearance = transmogOf(trimmed)
        if appearance ~= "" then m.transmog = appearance end
    elseif right == "" and unformat(plain, TRANSMOGRIFIED_ENCHANT) then
        m.illusion = util.trim(plain)
    else
        return false
    end
    return true
end

-- Retail names where an item comes from between its name and level: Heroic,
-- Mythic. Whether the line was that.
function item.readSource(m, line, data, lineNumber, right, trimmed)
    local lineType = line.type
    if right ~= "" or trimmed == "" or not (lineType == nil or (LINE.None ~= nil and lineType == LINE.None)) then
        return false
    end
    local before = lineBefore(data.lines, lineNumber)
    if not (before and before.type == LINE.ItemName and levelFollows(data.lines, lineNumber)) then return false end
    m.source = util.trim(plainText(trimmed))
    m.sourceColor = openingColor(trimmed) or colorOf(line.leftColor)
    return true
end

-- A primary stat another specialization uses, grey, as the game draws it.
function item.addInactiveStat(rows, text, right)
    add(rows, ns.Retail.Stats.inactiveStat(text, ns.option("statMarkers")), right)
    rows[#rows].color, rows[#rows].inactive = INACTIVE_STAT_COLOR, true
end

-- Drawing ----------------------------------------------------------------------

-- Retail sends its quality icons at 20 px; a line's icon is its text's height.
local function fitAtlases(text, size)
    if type(text) ~= "string" then return text end
    size = math.floor((size or 12) + .5)
    return (text:gsub("|A:([^:|]+)[^|]*|a", function(atlas)
        return "|A:" .. atlas .. ":" .. size .. ":" .. size .. ":0:0|a"
    end))
end

-- Copies of rows with their quality icons at the style's size.
function item.fittedRows(rows, style)
    local fitted = {}
    for index, row in ipairs(rows or {}) do
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        copy.left = fitAtlases(row.left, style.size)
        fitted[index] = copy
    end
    return fitted
end

-- The primary stats, an inactive one grey even under a stats color set in the editor.
function item.drawPrimary(panel, rows, y, style, color)
    local inactiveStyle = setmetatable({ color = false }, { __index = style })
    for _, row in ipairs(rows) do
        y = ns.ui.drawRow(panel, row, y, row.inactive and inactiveStyle or style, color)
    end
    return y
end

-- A socket's icon is a little larger than its text, and drawn apart from it:
-- an icon in the text sits on its baseline and hangs below, leaving the text
-- high. Apart, it is centered on the line, and the text starts after it.
local SOCKET_ICON_GAP = 4

local function socketIconSize(style)
    return math.floor((style.size or 12) * 1.25 + .5)
end

-- Where a socket's text starts: past its icon, when it has one.
local function socketIndent(row, style)
    local indent = row.indent or 0
    if row.icon then indent = indent + socketIconSize(style) + SOCKET_ICON_GAP end
    return indent
end

function item.socketsWidth(panel, sockets, style)
    local need = 0
    for _, row in ipairs(sockets) do
        need = math.max(need, ns.ui.rowWidth(panel, row, style) + socketIndent(row, style))
    end
    return need
end

function item.drawSockets(panel, sockets, y, style)
    local ui = ns.ui
    for _, row in ipairs(sockets) do
        if row.icon then
            local size = socketIconSize(style)
            -- The line is the text's size and 2 tall (Panel/Layout.lua's textAt).
            local top = y + (style.size + 2 - size) / 2
            local icon = ui.acquireTexture(panel, row.icon, 1)
            icon:SetPoint("TOPLEFT", panel, "TOPLEFT", ui.pad() + (row.indent or 0), -ui.snap(panel, top))
            icon:SetSize(size, size)
        end
        y = ui.drawRow(panel, row, y, style, GEM_COLOR, socketIndent(row, style), 3)
    end
    return y
end

-- The header's lines: where the item comes from, under its name.
function item.addSource(header, model, styles)
    if not model.source then return end
    header[#header + 1] = { text = model.source, style = styles.itemSource, color = model.sourceColor or SOURCE_COLOR,
        gap = 4 }
end

-- Its upgrade level and crafted quality, under its slot.
function item.addUpgrade(header, model, styles)
    if model.upgrade then
        header[#header + 1] = { text = model.upgrade, style = styles.itemUpgrade, color = UPGRADE_COLOR, gap = 4 }
    end
    if model.craftingQuality then
        -- Gear's icon sits in its line at the text's height; a reagent's
        -- quality is what its line is for, so its icon is larger.
        local size = styles.craftingQuality.size * (model.equippable and 1 or REAGENT_QUALITY_SCALE)
        header[#header + 1] = { text = fitAtlases(model.craftingQuality, size),
            style = styles.craftingQuality, color = CRAFTED_COLOR,
            gap = 4 }
    end
end

-- What it is transmogrified to, under its binding and level.
function item.addLooks(header, model, styles)
    local looks = {}
    if model.transmog then looks[#looks + 1] = { left = util.trim(TRANSMOGRIFIED_HEADER) .. " " .. model.transmog, right = "" } end
    if model.illusion then looks[#looks + 1] = { left = model.illusion, right = "" } end
    if #looks > 0 then
        header[#header + 1] = { rows = looks, style = styles.itemTransmog, color = TRANSMOG_COLOR, gap = 3 }
    end
end
