-- Draws a view: a plain table that says what a panel shows, which a tooltip
-- type's view function builds from its model. The width is fitted to what the
-- view holds, so measuring and drawing cannot disagree. Only what several
-- types share lives here; a part one type draws its own way is a custom
-- section in that type's file.
--
-- view = {
--     tooltipType = "aura",              backdrop and header settings by type
--     color, tint, strength,             the accent; the header's tint and its strength
--     gradient = { left, right },        a dual school's accent, drawn across
--     icon, iconSize,                    header lines start beside the icon
--     portrait = "mouseover",            a unit whose portrait fills the icon
--     badge, badgeColor,                 the level plate under the icon
--     header = {                         in order, beside the icon
--         { text = "Name", style = styles.auraName, color = TITLE, gap = 4 },
--         { text = "<Guild>", style, color, gap = 2,
--           after = { text = "Realm", style, color } },   a part in its own style, on the same line
--         { badges = { { "Buff", BLUE } }, style = styles.auraBadges, before = 1, gap = 4 },
--         { rows = { { left, right } }, style, color, gap = 3 },
--     },
--     tag = "EQUIPPED",                  the comparison's label above the panel
--     sections = {                       in order, below the header
--         { separator = { divider = GOLD } | { rule = color } | { space = 4 }  before = 8 sets the space
--               above a divider or rule; left out, it shows as much as below
--               | { caption = "Reagents", style, before = 4 },
--           kind = "prose", sentences = { ... }, style, color, numbers = "FFF6E4", gap = 5 },
--         { kind = "rows", rows = { { left, right, color, rightColor, indent } }, style, color, gap = 2,
--           wrap = true },             rows with nothing on the right wrap at prose width
--         { kind = "custom", draw = function(panel, y) return y end,
--           measure = function(panel) return width end },    measure is optional
--     },
--     footer = { rows = { ... }, style, color, gap = 4 },    the dark band at the bottom
--           or { draw = function(panel, y) return y end, measure = function(panel) return width end },
--     minWidth = 0,                      narrower than panels usually are, to fit the content
-- }
local _, ns = ...
local ui = ns.ui
if not ui then return end

local util = ns.util
local pad = ui.pad
local BADGE_SEPARATOR = " |cff" .. util.hex(ns.Palette.roles.caption) .. "\194\183|r "
local TRACK = { .16, .14, .13 }

-- Badges -----------------------------------------------------------------------

-- Badges read as one line, as the item's type and slot do: each word in its
-- badge's color, lightened to read on the dark header, between dim dots.
local function badgeText(list)
    local words = {}
    for index, badge in ipairs(list) do
        words[index] = "|cff" .. ns.Palette.numberCode(badge[2]) .. badge[1] .. "|r"
    end
    return table.concat(words, BADGE_SEPARATOR)
end

local function badgesWidth(panel, list, style)
    return ui.measureStyled(panel, badgeText(list), style)
end

-- A header line with a part after it: neither wraps, as the panel was fitted
-- to both, and the parts share a baseline.
local AFTER_SPACE = 4

local function pairedWidth(panel, item)
    return ui.measureStyled(panel, item.text, item.style) + AFTER_SPACE
        + ui.measureStyled(panel, item.after.text, item.after.style)
end

local function drawPaired(panel, item, x, y)
    local after = item.after
    local first = ui.measureStyled(panel, item.text, item.style)
    local tallest = math.max(item.style.size, after.style.size)
    local height = ui.styledAt(panel, item.text, x, y + tallest - item.style.size, first + 2, item.style, item.color)
    local second = ui.measureStyled(panel, after.text, after.style)
    local afterHeight = ui.styledAt(panel, after.text, x + first + AFTER_SPACE, y + tallest - after.style.size,
        second + 2, after.style, after.color)
    return math.max(height + tallest - item.style.size, afterHeight + tallest - after.style.size)
end

local function drawBadges(panel, list, x, y, style)
    local text = badgeText(list)
    -- The panel was fitted to the line, so it never wraps.
    return y + ui.styledAt(panel, text, x, y, ui.measureStyled(panel, text, style) + 2, style, ns.Palette.roles.detail)
end

-- Live parts: updated ten times a second while their panel shows ---------------

-- Each shown panel's update, at most one; a redraw clears it.
local live = setmetatable({}, { __mode = "k" })

local ticker = CreateFrame("Frame")
local elapsedSince = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < .1 then return end
    elapsedSince = 0
    for panel, update in pairs(live) do
        if panel:IsShown() then update() else live[panel] = nil end
    end
end)

local function setLive(panel, update)
    live[panel] = update
end

-- A bar's dark track across the panel at y, and its fill, for the caller to
-- size and color.
local function drawTrack(panel, y, height)
    local bar = ui.acquireTexture(panel, nil, 0)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -y)
    bar:SetSize(panel.width - 2 * pad(), height)
    bar:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], 1)
    local fill = ui.acquireTexture(panel, nil, 1)
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT")
    fill:SetHeight(height)
    return fill
end

-- Sections -------------------------------------------------------------------------

local FOOTER_TOP = 9

local function indentOf(view)
    return view.icon and view.iconSize + 10 or 0
end

-- The widest thing the view holds, plus the panel's padding, within the limits.
local function fitWidth(panel, view)
    local indent, need = indentOf(view), 0
    local function consider(width) if width > need then need = width end end
    for _, item in ipairs(view.header) do
        if item.text and item.after then
            consider(pairedWidth(panel, item) + indent)
        elseif item.text then
            consider(ui.measureStyled(panel, item.text, item.style) + indent)
        elseif item.badges and #item.badges > 0 then
            consider(badgesWidth(panel, item.badges, item.style) + indent)
        elseif item.rows then
            for _, row in ipairs(item.rows) do consider(ui.rowWidth(panel, row, item.style) + indent) end
        end
    end
    for _, section in ipairs(view.sections) do
        if section.kind == "prose" then
            for _, sentence in ipairs(section.sentences) do
                consider(math.min(ui.measureStyled(panel, sentence, section.style), ui.PROSE_WIDTH))
            end
        elseif section.kind == "custom" then
            if section.measure then consider(section.measure(panel)) end
        elseif section.kind == "rows" then
            for _, row in ipairs(section.rows) do
                local width = ui.rowWidth(panel, row, section.style)
                if section.wrap and (not row.right or row.right == "") then width = math.min(width, ui.PROSE_WIDTH) end
                consider(width + (row.indent or 0))
            end
        end
    end
    local footer = view.footer
    if footer and footer.measure then consider(footer.measure(panel)) end
    for _, row in ipairs(footer and footer.rows or {}) do
        consider(ui.rowWidth(panel, row, footer.style))
    end
    return math.max(view.minWidth or ui.minWidth(), math.min(ui.MAX_WIDTH, math.ceil(need + 2 * pad())))
end

-- The space a divider shows below its line, and a rule: one after a section
-- shows as much above its line, counting in what the section's last row left
-- under its letters. A separator's own before overrides it.
local DIVIDER_SPACE, RULE_SPACE = 13, 9

local function drawSeparator(panel, y, separator, after)
    if not separator then return y end
    local before = separator.before
    if before == nil and after and panel.rowTail then
        -- A divider draws its line 5 below where it starts.
        before = separator.divider and DIVIDER_SPACE - 5 - panel.rowTail or RULE_SPACE - panel.rowTail
    end
    if separator.divider then return ui.divider(panel, y, separator.divider, before) end
    if separator.rule then return ui.rule(panel, y, separator.rule, before) end
    if separator.caption then
        return ui.caption(panel, y + (separator.before or 0), separator.caption, separator.style, separator.color)
    end
    return y + (separator.space or 0)
end

local DRAW = {
    prose = function(panel, y, section)
        for _, sentence in ipairs(section.sentences) do
            local text = section.numbers and util.colorNumbers(sentence, section.numbers) or sentence
            y = ui.drawRow(panel, { left = text }, y, section.style, section.color, 0, section.gap)
        end
        return y
    end,
    rows = function(panel, y, section)
        for _, row in ipairs(section.rows) do
            y = ui.drawRow(panel, row, y, section.style, section.color, row.indent or 0, section.gap)
        end
        return y
    end,
    custom = function(panel, y, section)
        return section.draw(panel, y)
    end,
}

-- The panel ---------------------------------------------------------------------

local function renderView(panel, tooltip, view)
    -- Client view contributors must finish before this call: both measurement
    -- and drawing below consume the same completed view (including additions).
    -- Whatever a tooltip type lent the panel goes back before anything is drawn.
    if panel.release then panel.release(panel) end
    local scale = ns.tooltipScale()
    if panel:GetScale() ~= scale then panel:SetScale(scale) end
    panel:Show()
    ui.clearPool(panel)
    live[panel] = nil
    -- Whole pixels, so the edges away from the aligned corner are on pixels too.
    panel.width = ui.snap(panel, fitWidth(panel, view))
    panel:SetWidth(panel.width)
    local headerMin = ui.drawChrome(panel, tooltip, {
        tooltipType = view.tooltipType,
        quest = view.tooltipType == "quest" or view.questItem,
        color = view.color,
        tint = view.tint,
        strength = view.strength,
        icon = view.icon,
        iconSize = view.iconSize,
        badge = view.badge,
        badgeColor = view.badgeColor,
        gradient = view.gradient,
        tag = view.tag,
    })
    if view.portrait and SetPortraitTexture then pcall(SetPortraitTexture, panel.icon, view.portrait) end

    local indent = indentOf(view)
    local leftIndent, rightIndent = ui.headerInsets(indent)
    local inner = panel.width - 2 * pad()
    local y = ui.titleTop()
    for _, item in ipairs(view.header) do
        if item.text and item.after then
            y = y + drawPaired(panel, item, pad() + leftIndent, y) + item.gap
        elseif item.text then
            y = y + ui.styledAt(panel, item.text, pad() + leftIndent, y, inner - indent, item.style, item.color)
                + item.gap
        elseif item.badges and #item.badges > 0 then
            y = drawBadges(panel, item.badges, pad() + leftIndent, y + (item.before or 0), item.style) + item.gap
        elseif item.rows then
            for _, row in ipairs(item.rows) do
                y = ui.drawRow(panel, row, y, item.style, item.color, leftIndent, item.gap, rightIndent)
            end
        end
    end
    local footer = view.footer
    local hasFooter = footer and (footer.draw or #footer.rows > 0)
    if #view.header > 0 or view.icon then
        -- A header alone ends as far below its last line as its first is from the top.
        local alone = #view.sections == 0 and not hasFooter
        y = math.max(alone and y or y + 6, headerMin)
        panel.header:SetHeight(y - panel.inset)
    else
        -- Sections alone, as the minimap's list: as much room above as below.
        y = pad() - 2
        panel.header:SetHeight(0)
    end

    -- The header's rows are not a section's: the first separator follows the band.
    panel.rowTail = nil
    for index, section in ipairs(view.sections) do
        y = drawSeparator(panel, y, section.separator, index > 1)
        y = DRAW[section.kind](panel, y, section)
    end
    if hasFooter then
        y = y + FOOTER_TOP
        if footer.draw then
            y = footer.draw(panel, y)
        else
            for _, row in ipairs(footer.rows) do
                y = ui.drawRow(panel, row, y, footer.style, footer.color, 0, footer.gap)
            end
        end
    end
    ui.finishPanel(panel, tooltip, y)
end

-- The row naming what the panel shows by its ID, while IDs show.
function ui.idRow(panel, format, id)
    if id and ns.showsDetail("showIDs", panel) then return { left = util.fill(format, id), right = "" } end
end

-- Other addons' rows, then the ID row.
function ui.withID(panel, extras, format, id)
    local idRow = ui.idRow(panel, format, id)
    if not idRow then return extras end
    local rows = {}
    for index, row in ipairs(extras) do rows[index] = row end
    rows[#rows + 1] = idRow
    return rows
end

ui.renderView = renderView
ui.RULE_SPACE = RULE_SPACE
ui.setLive, ui.drawTrack = setLive, drawTrack
ui.drawBadges, ui.badgesWidth = drawBadges, badgesWidth
