-- Flight map nodes as a panel: the node's name and zone, and what the flight
-- costs, or that you are there. The game fills this tooltip with lines alone,
-- so the type has no data type of its own and is drawn from the lines.
local _, ns = ...
local ui = ns.ui
if not (ui and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local trim = util.trim
local TAXI = "taxi"
local EXTRAS_RULE = { .50, .50, .54 }
local PRICE_LABEL = { .88, .78, .60 }
local HERE_COLOR = { .45, .85, .45 }
local COPPER = { gold = 10000, silver = 100, copper = 1 }

-- "2|A:coin-silver…|a 97|A:coin-copper…|a", or the coin textures, as copper.
local function copperOf(text)
    local total, found = 0, false
    for amount, coin in text:gmatch("(%d+)%s*|A:coin%-(%a+)") do
        if COPPER[coin:lower()] then total, found = total + tonumber(amount) * COPPER[coin:lower()], true end
    end
    for amount, coin in text:gmatch("(%d+)%s*|TInterface\\MoneyFrame\\UI%-(%a+)Icon") do
        if COPPER[coin:lower()] then total, found = total + tonumber(amount) * COPPER[coin:lower()], true end
    end
    return found and total or nil
end

local function taxiKey(tooltip)
    local parts = {}
    for index = 1, tooltip:NumLines() do
        local font = tooltip:GetLeftLine(index)
        local text = font and util.safeText(font:GetText())
        if not text then return end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "\n")
end

local function readTaxi(tooltip)
    local rows = tooltipData.appendedRows(tooltip, {})
    if not rows or #rows == 0 then return end
    local first = trim(util.plainText(rows[1].left))
    if first == "" then return end
    local name, zone = first:match("^(.-),%s*(.+)$")
    local model = { name = name or first, zone = zone, extras = {} }
    local here = TAXINODEYOUAREHERE or "You are here"
    local addExtra = tooltipData.extrasAdder(model.extras)
    for index = 2, #rows do
        local row = rows[index]
        local copper = copperOf(row.left)
        if copper and not model.cost then
            model.cost = copper
        elseif trim(util.plainText(row.left)) == here then
            model.current = true
        else
            addExtra(row)
        end
    end
    return model
end

local function taxiView(model)
    local badges = {}
    if model.zone then badges[1] = { model.zone, colors.caption } end
    if model.current then badges[#badges + 1] = { ns.L["You are here"], HERE_COLOR } end
    local header = { { text = model.name, style = ui.styleOf("objectTitle"), color = colors.title, gap = 4 } }
    if #badges > 0 then header[2] = { badges = badges, style = ui.styleOf("objectKind"), before = 1, gap = 4 } end
    local sections = {}
    if #model.extras > 0 then
        sections[1] = { separator = { rule = EXTRAS_RULE, before = 8 }, kind = "rows", rows = model.extras,
            style = ui.styleOf("extras"), color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local footer = model.cost and { rows = { { left = ns.L["Cost"], right = ui.formatMoney(model.cost) } },
        style = ui.styleOf("objectPrices"), color = PRICE_LABEL, gap = 4 }
    return { tooltipType = "object", color = colors.neutral, header = header, sections = sections,
        footer = footer, minWidth = 0 }
end

local function renderTaxi(panel, tooltip, model)
    ui.renderView(panel, tooltip, taxiView(model))
end

ui.taxiModel = function(fields)
    fields.extras = fields.extras or {}
    return fields
end
-- No game data type: Hooks.install registers nothing, the flight map's hook draws it.
ui.defineTooltipType(TAXI, { read = readTaxi, render = renderTaxi, key = taxiKey, option = "taxiPanels",
    linesOnly = true })

-- The classic flight map: a node's button fills GameTooltip with its lines.
local hooked = false
local function hookTaxi()
    if hooked or not TaxiNodeOnButtonEnter then return end
    hooked = true
    hooksecurefunc("TaxiNodeOnButtonEnter", function()
        if ns.Hooks and util.canModify(GameTooltip) and GameTooltip:IsShown() and GameTooltip:NumLines() > 0 then
            ns.Hooks.renderLines(GameTooltip, TAXI)
        end
    end)
end
hookTaxi()
if not hooked then
    -- The flight map can load with its own addon.
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(self)
        hookTaxi()
        if hooked then self:UnregisterEvent("ADDON_LOADED") end
    end)
end
