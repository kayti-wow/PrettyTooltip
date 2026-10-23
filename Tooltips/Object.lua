-- World objects (herbs, ore, chests, quest objects) as a panel.
local _, ns = ...
local ui = ns.ui
local OBJECT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
if not (ui and OBJECT and ui.renderView) then
    return
end

local util = ns.util
local L = ns.L
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, trim = util.isSecret, util.trim
local LINE = Enum.TooltipDataLineType or {}
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local DETAIL_COLOR = colors.detail
local UNMET_COLOR = colors.unmet
local QUEST_GOLD = colors.quest
local PRICE_LABEL = { .88, .78, .60 }
local EXTRAS_RULE = { .50, .50, .54 }
local PARTS = { "objectTitle", "objectKind", "objectDetails", "objectLoot", "objectQuests", "objectPrices",
    "extras" }

local SKILLS = {
    Herbalism = { label = L["Herb"], color = { .36, .78, .32 }, icon = "Interface\\Icons\\Trade_Herbalism" },
    Mining = { label = L["Mining node"], color = { .85, .55, .30 }, icon = "Interface\\Icons\\Trade_Mining" },
    Lockpicking = { label = LOCKED, color = { .85, .72, .35 }, icon = "Interface\\Icons\\INV_Misc_Key_03" },
    Fishing = { label = L["Fishing pool"], color = { .35, .65, .95 }, icon = "Interface\\Icons\\Trade_Fishing" },
}
local QUEST = { label = L["Quest object"], color = QUEST_GOLD, icon = "Interface\\Icons\\INV_Misc_Note_01" }
-- Each skill's name as the client words it, which its lines print
-- ("Bergbau"), and the other way round.
local SKILL_NAMES, SKILL_KEYS = {}, {}
for key in pairs(SKILLS) do
    SKILL_NAMES[key] = ns.Locale.skillName(key)
    for _, name in ipairs(ns.Locale.skillNames(key)) do SKILL_KEYS[name] = key end
end
-- An object's requirements: "Requires Mining", "Requires Lockpicking (25)".
local REQUIREMENTS = { LOCKED_WITH_SPELL, LOCKED_WITH_ITEM, ITEM_MIN_SKILL, ITEM_REQ_SKILL }
local function isRequirement(text)
    for _, format in pairs(REQUIREMENTS) do
        if util.unformat(text, format) then return true end
    end
    return false
end

-- A node's English name, as the node data knows it, from the client's:
-- "Kupferader" is "Copper Vein". An ooze covered node yields what the plain
-- one does.
local function nodeKey(name)
    name = ns.nodeNames and ns.nodeNames[name] or name
    return (name:gsub("^Ooze Covered ", ""))
end

-- From Data/NodeSkills.lua, which only Forever loads: retail's nodes need
-- other skill levels.
local function nodeFor(name)
    return ns.nodeSkills and ns.nodeSkills[nodeKey(name)]
end

-- The item an object yields, by its name; for /ptip capture to record.
function ns.objectYield(name)
    local node = nodeFor(name)
    return node and node[1]
end

-- A herb or ore node by name, for the minimap: the skill it needs and at
-- what level.
function ns.gatheringNode(name)
    local node = nodeFor(name)
    if not node then return end
    local key = nodeKey(name)
    local skill = (key:find(" Vein$") or key:find(" Deposit$")) and "Mining" or "Herbalism"
    return { level = node[2], skill = skill }
end

-- The yield's name, icon, and sell price; an unseen item is asked for, for a later hover.
local function itemInfo(itemID, game)
    local info = game.itemInfo(itemID) or {}
    if not info.name then game.loadItem(itemID) end
    return info.name, game.itemIcon(itemID), info.price
end

-- A herb or ore node's contents, from Data/Nodes.lua: the yield's count over
-- all its taps, then each other drop's chance per tap.
local LOOT_ICON = 14
local RARE = 5
local function lootRows(name, game)
    local loot = ns.nodeLoot and ns.nodeLoot[nodeKey(name)]
    if not loot then return end
    local rows = {}
    for _, drop in ipairs(loot) do
        local id, chance, low, high = drop[1], drop[3], drop[4], drop[5]
        local item = game.itemName(id) or drop[2]
        local icon = game.itemIcon(id)
        local right
        if chance >= 100 then
            low, high = low * loot.taps[1], high * loot.taps[2]
            right = low == high and tostring(low) or util.fill(L["%s to %s"], low, high)
        else
            right = chance .. "%"
        end
        rows[#rows + 1] = { left = (icon and ("|T" .. icon .. ":" .. LOOT_ICON .. "|t ") or "") .. item, right = right,
            rare = chance < RARE }
    end
    return rows
end

local function completeModel(model, game)
    local node = nodeFor(model.name)
    model.loot = model.loot or lootRows(model.name, game)
    model.look = model.skill and SKILLS[model.skill] or (#model.quests > 0 and QUEST) or nil
    if model.skill and SKILLS[model.skill] and model.skill ~= "Lockpicking" then
        model.skillRow = {
            name = SKILL_NAMES[model.skill],
            level = node and node[2],
            player = game.skill(model.skill),
        }
    end
    if node then
        local name = itemInfo(node[1], game)
        -- A herb yields itself and a node yields an ore; anything else is a bad
        -- entry. The names to tell by are English, as the node data's.
        local english = not (ns.nodeNames and ns.nodeNames[model.name])
        if english and name and name ~= nodeKey(model.name) and not name:find(" Ore$") then node = nil end
    end
    if node then
        local name, icon, price = itemInfo(node[1], game)
        model.itemName, model.icon = name, icon
        model.prices = {}
        if type(price) == "number" and price > 0 then
            model.prices[#model.prices + 1] = { SELL_PRICE, ui.formatMoney(price) }
        end
        local auction = game.auctionPrice(node[1])
        if auction then model.prices[#model.prices + 1] = { L["Auction"], ui.formatMoney(auction) } end
    end
    model.prices = model.prices or {}
    return model
end

local function objectKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local line = data.lines[1]
    if isSecret(line) or type(line) ~= "table" then return end
    return util.safeText(line.leftText)
end

local function readObject(tooltip, data, game)
    local safeText = util.safeText
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { details = {}, quests = {}, extras = {}, lineIndices = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            local text = trim(left)
            if not model.name then
                model.name = text
            elseif text ~= "" or right ~= "" then
                if isRequirement(text) then
                    tooltipData.add(model.details, left, right)
                    local row = model.details[#model.details]
                    row.requirement, row.met = true, tooltipData.requirementMet(text, line.leftColor, game)
                    for name, key in pairs(SKILL_KEYS) do
                        if not model.skill and text:find(name, 1, true) then
                            model.skill, model.skillMet = key, row.met
                        end
                    end
                elseif SKILL_KEYS[text] then
                    -- Colored by how likely gathering is to raise the skill.
                    model.skill = model.skill or SKILL_KEYS[text]
                    model.skillColor = util.rgb(line.leftColor)
                elseif text == LOCKED then
                    model.skill = model.skill or "Lockpicking"
                    tooltipData.add(model.details, left, right)
                    -- The game colors it by the lockpicking it needs against the player's.
                    model.details[#model.details].color = util.rgb(line.leftColor)
                elseif LINE.QuestTitle and line.type == LINE.QuestTitle then
                    tooltipData.add(model.quests, left, right)
                    model.quests[#model.quests].title = true
                elseif LINE.QuestObjective and line.type == LINE.QuestObjective then
                    tooltipData.add(model.quests, left, right)
                    if not isSecret(line.completed) then
                        model.quests[#model.quests].completed = line.completed == true
                    end
                else
                    tooltipData.add(model.extras, left, right)
                    local row = model.extras[#model.extras]
                    row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
                end
            end
        end
    end
    if not model.name or model.name == "" then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    tooltipData.addExtras(model.extras, appended)
    return completeModel(model, game)
end

local function skillText(skill)
    if skill.level then return util.fill(L["Requires %s %s"], skill.name, skill.level) end
    return util.fill(LOCKED_WITH_SPELL, skill.name)
end

-- What a node holds; rarer finds in the caption color.
local function shownLoot(loot)
    local rows = {}
    for index, row in ipairs(loot) do
        rows[index] = { left = row.left, right = row.right, color = row.rare and colors.caption or nil,
            rightColor = row.rare and colors.caption or nil }
    end
    return rows
end

-- What the panel shows, for Panel/Render.lua to draw.
local function objectView(panel, model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local look = model.look
    local color = look and look.color or colors.neutral
    local sections = {}

    local skill = model.skillRow
    local details = {}
    if skill then
        details[1] = {
            left = skillText(skill),
            right = skill.player and util.fill(L["Your skill %s"], skill.player) or "",
            rightColor = colors.caption,
            color = model.skillMet == false and UNMET_COLOR or model.skillColor or DETAIL_COLOR,
        }
    end
    for _, row in ipairs(model.details) do
        -- The skill row already says what this requirement says.
        if not (skill and row.requirement and row.left:find(skill.name, 1, true)) then
            local rowColor = row.color or DETAIL_COLOR
            if row.requirement then rowColor = row.met and { 1, 1, 1 } or UNMET_COLOR end
            details[#details + 1] = { left = row.left, right = row.right, color = rowColor }
        end
    end
    if #details > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "rows", rows = details,
            style = styles.objectDetails, color = DETAIL_COLOR, gap = 2 }
    end
    if model.loot and ns.showsDetail("gatheringLoot", panel) then
        local rows = shownLoot(model.loot)
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { divider = ui.GOLD_RULE },
            kind = "rows", rows = rows, style = styles.objectLoot, color = DETAIL_COLOR, gap = 2 }
    end
    if #model.quests > 0 then
        local quests = {}
        for index, row in ipairs(model.quests) do
            quests[index] = row.title and { left = row.left, right = row.right, color = QUEST_GOLD }
                or { left = row.left, right = row.right, color = row.completed and colors.done or colors.objective,
                    indent = 8 }
        end
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE },
            kind = "rows", rows = quests, style = styles.objectQuests, gap = 2 }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local prices = {}
    for index, price in ipairs(model.prices) do prices[index] = { left = price[1], right = price[2] } end

    local header = { { text = model.name, style = styles.objectTitle, color = colors.title, gap = 4 } }
    if look then
        header[2] = { text = look.label, style = styles.objectKind,
            color = { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }, gap = 4 }
    end
    local icon = ns.option("iconObjects") and (model.icon or (look and look.icon)) or nil
    return {
        tooltipType = "object",
        color = color,
        tint = look and look.color,
        strength = TINT_STRENGTH,
        icon = icon,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
        footer = { rows = prices, style = styles.objectPrices, color = PRICE_LABEL, gap = 4 },
        -- A plain object, as a mailbox, is only its name.
        minWidth = not (icon or look or #sections > 0 or #prices > 0) and 0 or nil,
    }
end

local function renderObject(panel, tooltip, model)
    ui.renderView(panel, tooltip, objectView(panel, model))
end

ui.objectModel = function(fields)
    for _, list in ipairs({ "details", "quests", "extras" }) do fields[list] = fields[list] or {} end
    return completeModel(fields, ns.Game)
end
local function details(model, context)
    if not (model.loot and ns.showsDetail("gatheringLoot", context)) then return {} end
    local rows = shownLoot(model.loot)
    for _, row in ipairs(rows) do row.color = row.color or DETAIL_COLOR end
    return rows
end

ui.defineTooltipType(OBJECT, {
    read = readObject, render = renderObject, key = objectKey, option = "objectPanels",
    details = details, detailKeys = { "gatheringLoot" },
})
