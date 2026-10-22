-- Weapon imbues as a panel. The buff bar's button for a temporary weapon
-- enchant (a shaman's Windfury Weapon, a poison, an oil, a stone) shows the
-- weapon's own tooltip; the panel shows the imbue instead, as the spell that
-- applied it (Data/Imbues.lua), with the weapon slot, its charges, and the time
-- it has left. An imbue the data does not know shows by the name the weapon's
-- tooltip gives it. Off, the weapon's tooltip shows, as the game draws it or
-- as an item panel.
local _, ns = ...
local ui = ns.ui
local TYPES = Enum and Enum.TooltipDataType
local ITEM, SPELL = TYPES and TYPES.Item, TYPES and TYPES.Spell
if not (ui and ITEM and SPELL and ui.spellView and ui.timeSections and ui.spellModel) then
    return
end

local util = ns.util
local isSecret, readable, trim = util.isSecret, util.readable, util.trim
local MUTED = ns.Palette.roles.caption
local IMBUE = "imbue"
-- The weapon slots an imbue can be on, by the game's name for each.
local SLOT_NAMES = { [16] = "INVTYPE_WEAPONMAINHAND", [17] = "INVTYPE_WEAPONOFFHAND", [18] = "INVTYPE_RANGED" }
-- The line the weapon's tooltip names its imbue on: "Windfury (59 min)".
local NAME_LINES = { "ITEM_ENCHANT_TIME_LEFT_DAYS", "ITEM_ENCHANT_TIME_LEFT_HOURS", "ITEM_ENCHANT_TIME_LEFT_MIN",
    "ITEM_ENCHANT_TIME_LEFT_SEC" }
-- The time left, as an aura's tooltip words it, from the largest unit down.
local REMAINING = { { 86400, "SPELL_TIME_REMAINING_DAYS" }, { 3600, "SPELL_TIME_REMAINING_HOURS" },
    { 60, "SPELL_TIME_REMAINING_MIN" }, { 1, "SPELL_TIME_REMAINING_SEC" } }

-- The weapon slot of the imbue button the tooltip shows for, which the game's
-- buff bar marks as a temporary enchant's, and the button.
local function slotOf(tooltip)
    local owner = util.call(tooltip.GetOwner, tooltip)
    if type(owner) ~= "table" or readable(owner.auraType) ~= "TempEnchant" then return end
    local slot = util.number((util.call(owner.GetID, owner)))
    if slot and SLOT_NAMES[slot] then return slot, owner end
end

-- Which of a weapon's enchants the button shows, when it has more than one (on
-- Forever, a poison and a class imbue): both buttons give the same slot, so
-- go by when the button's ends and its charges.
local function shownBy(owner, imbues)
    if #imbues < 2 then return imbues[1] end
    local info = readable(owner.buttonInfo)
    local expires = type(info) == "table" and util.number(info.expirationTime)
    if not expires then return end
    local count = util.number(info.count)
    local now, best, bestGap = GetTime(), nil, nil
    for _, imbue in ipairs(imbues) do
        local gap = math.abs(now + (imbue.remaining or 0) - expires)
        if count ~= imbue.charges then gap = gap + 1e6 end
        if not bestGap or gap < bestGap then best, bestGap = imbue, gap end
    end
    return best
end

local function remainingText(seconds)
    for _, unit in ipairs(REMAINING) do
        local format = _G[unit[2]]
        if seconds >= unit[1] and type(format) == "string" then
            -- Whole units, the seconds rounded up so the last one shows as 1.
            local count = unit[1] == 1 and math.ceil(seconds) or math.floor(seconds / unit[1])
            return util.fill(format, tostring(count))
        end
    end
end

-- The imbue's name from the weapon's tooltip, for one the data does not know.
local function nameOf(data)
    for _, line in ipairs(data.lines) do
        local text = not isSecret(line) and type(line) == "table" and util.safeText(line.leftText)
        if text then
            for _, key in ipairs(NAME_LINES) do
                local format = _G[key]
                local name = type(format) == "string" and util.unformat(text, format)
                if type(name) == "string" and trim(name) ~= "" then return trim(name) end
            end
        end
    end
end

-- The imbue's spell as the spell panel reads it, from the spell's own tooltip.
local function spellOf(spellID, game)
    local scanner, data = game.spellTooltip(spellID)
    if not scanner then return end
    local ok, model = pcall(ns.TooltipTypes[SPELL].read, scanner, data, game)
    if ok then return model end
end

local function imbueOf(tooltip, game)
    local slot, owner = slotOf(tooltip)
    local imbue = slot and shownBy(owner, game.weaponImbues(slot))
    if imbue then return slot, imbue end
end

local function claimImbue(tooltip)
    return imbueOf(tooltip, ns.Game) ~= nil
end

local function imbueKey(tooltip)
    local slot, imbue = imbueOf(tooltip, ns.Game)
    if not slot then return end
    return table.concat({ slot, imbue.enchantID, imbue.remaining and remainingText(imbue.remaining) or "",
        imbue.charges or "" }, ":")
end

local function readImbue(tooltip, data, game)
    if not util.canModify(tooltip) then return end
    local slot, imbue = imbueOf(tooltip, game)
    if not slot then return end
    local known = ns.imbues and ns.imbues[imbue.enchantID]
    local spell = known and spellOf(known[1], game)
    if not spell then
        local name = nameOf(data)
        if not name then return end
        spell = ui.spellModel({ name = name, icon = game.slotIcon(slot) })
    end
    local model = { spell = spell, slot = slot, charges = imbue.charges }
    local left = imbue.remaining
    if left and left > 0 then
        model.remaining = remainingText(left)
        model.expires = GetTime() + left
        -- One applied for longer than the data says keeps a full bar.
        model.duration = known and math.max(known[2], left) or nil
    end
    return model
end

local function badgesOf(model)
    local list = {}
    local slotName = _G[SLOT_NAMES[model.slot]]
    if type(slotName) == "string" then list[#list + 1] = { slotName, MUTED } end
    if model.charges and model.charges > 0 and type(ITEM_SPELL_CHARGES) == "string" then
        list[#list + 1] = { util.fill(ITEM_SPELL_CHARGES, tostring(model.charges)), MUTED }
    end
    return list
end

local function imbueView(panel, model)
    local view = ui.spellView(panel, model.spell, function(sections, color)
        ui.timeSections(sections, model, color)
    end)
    local badges = view.header[2] and view.header[2].badges
    if badges then
        for _, badge in ipairs(badgesOf(model)) do badges[#badges + 1] = badge end
    end
    return view
end

local function renderImbue(panel, tooltip, model)
    ui.renderView(panel, tooltip, imbueView(panel, model))
end

ui.imbueModel = function(fields)
    fields.spell = ui.spellModel(fields.spell or {})
    return fields
end
-- No game data type of its own: the weapon's tooltip, claimed from the item
-- type when an imbue's button shows it.
ui.defineTooltipType(IMBUE, { read = readImbue, render = renderImbue, key = imbueKey, option = "imbuePanels",
    linesOnly = true, claims = ITEM, claim = claimImbue })
