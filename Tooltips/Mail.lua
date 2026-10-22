-- Inbox summaries have no tooltip data type. Read their attachments from the
-- mail API and preserve price rows supplied by Auctionator and other addons.
local _, ns = ...
local ui, util = ns.ui, ns.util
if not ui then return end
local colors = ns.Palette.roles
local MAIL = "mail"

local function mailOwner(tooltip)
    local owner = util.call(tooltip.GetOwner, tooltip)
    if not util.canModify(owner) then return end
    local name = util.safeText(util.call(owner.GetName, owner))
    if name and name:match("^MailItem%d+Button$") then return owner end
end

local function mailKey(tooltip)
    local rows = ns.TooltipData.appendedRows(tooltip, {})
    if not rows then return end
    local owner = mailOwner(tooltip)
    local parts = { owner and util.number(owner.index) or "" }
    if owner and util.number(owner.index) then
        local items = ns.Game.mailAttachments(owner.index)
        if not items then return end
        for _, item in ipairs(items) do
            parts[#parts + 1] = item.link or item.name
            parts[#parts + 1] = item.count or ""
            parts[#parts + 1] = item.icon or ""
        end
    end
    for _, row in ipairs(rows) do
        parts[#parts + 1] = row.left
        parts[#parts + 1] = row.right
    end
    return table.concat(parts, "\031")
end

local function readMail(tooltip, _, game)
    local rows = ns.TooltipData.appendedRows(tooltip, {})
    if not rows or #rows == 0 then return end
    local owner = mailOwner(tooltip)
    local index = owner and util.number(owner.index)
    local attachments = index and game.mailAttachments(index) or {}
    if not attachments then return end
    local model = { name = ns.L["Mail contents"], attachments = {}, extras = {}, totals = {} }
    local current, separated
    local used = {}
    for number, row in ipairs(rows) do
        local id = row.left:match("|Hitem:(%d+)")
        if id then
            current = { link = row.left, prices = {} }
            for position, item in ipairs(attachments) do
                if not used[position] and tostring(item.id) == id then
                    current.count, current.icon = item.count, item.icon
                    used[position] = true
                    break
                end
            end
            current.icon = current.icon or game.itemIcon(tonumber(id))
            model.attachments[#model.attachments + 1] = current
            separated = false
        elseif util.trim(row.left) == "" and row.right == "" then
            separated = current ~= nil
        elseif separated and row.right ~= "" then
            model.totals[#model.totals + 1] = row
        elseif current then
            current.prices[#current.prices + 1] = row
        elseif number > 1 then
            model.extras[#model.extras + 1] = row
        end
    end
    -- Without Auctionator, Blizzard only supplies a heading for the bundle.
    if #model.attachments == 0 then
        for _, item in ipairs(attachments) do
            model.attachments[#model.attachments + 1] = {
                link = item.link or item.name, count = item.count, icon = item.icon, prices = {},
            }
        end
    end
    if #model.attachments == 0 then return end
    return model
end

local function mailView(model)
    local sections = {}
    local count = 0
    for _, item in ipairs(model.attachments) do
        if count and item.count then count = count + item.count else count = nil end
        local icon = item.icon and ("|T" .. item.icon .. ":20:20|t ") or ""
        local rows = { { left = icon .. item.link, right = item.count and ("\195\151 " .. item.count) or "",
            color = colors.title } }
        for _, price in ipairs(item.prices) do
            rows[#rows + 1] = { left = price.left, right = price.right,
                color = price.textColor or price.color or colors.caption,
                rightColor = price.rightColor or colors.detail, indent = 24 }
        end
        sections[#sections + 1] = { kind = "rows", rows = rows, style = ui.styleOf("mailPrices"), gap = 4,
            separator = { space = 6 } }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { kind = "rows", rows = model.extras, style = ui.styleOf("extras"), color = colors.detail, gap = 3 }
    end
    local header = { { text = model.name, style = ui.styleOf("mailTitle"), color = colors.title, gap = 4 } }
    if count then
        header[#header + 1] = { text = string.format(ns.L["%d items"], count),
            style = ui.styleOf("mailPrices"), color = colors.caption, gap = 4 }
    end
    return { tooltipType = MAIL, color = colors.neutral,
        icon = ns.option("iconMail") and "Interface\\Icons\\INV_Letter_15" or nil, iconSize = 36,
        header = header,
        sections = sections,
        footer = #model.totals > 0 and { rows = model.totals, style = ui.styleOf("mailPrices"), color = colors.detail, gap = 4 } or nil }
end

ui.mailModel = function(fields)
    fields.name = fields.name or ns.L["Mail contents"]
    fields.attachments, fields.extras, fields.totals = fields.attachments or {}, fields.extras or {}, fields.totals or {}
    return fields
end
ui.defineTooltipType(MAIL, { read = readMail, key = mailKey, option = "mailPanels", linesOnly = true,
    render = function(panel, tooltip, model) ui.renderView(panel, tooltip, mailView(model)) end })

-- Both Blizzard and Auctionator Show after filling; Auctionator may finish
-- asynchronously. Observe that completion rather than adding a sizing timer.
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if not ns.Hooks or not util.canModify(tooltip) or not tooltip:IsShown() then return end
    local owner = mailOwner(tooltip)
    if not owner then return end
    local data = util.call(tooltip.GetTooltipData, tooltip)
    if util.isSecret(data) then return end
    if type(data) == "table" then return end -- Single attachments keep item tooltips.
    ns.Hooks.renderLines(tooltip, MAIL, util.number(owner.index))
end)
