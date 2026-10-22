-- Retail's part in reading and drawing items, through the callbacks
-- Tooltips/Item.lua offers a client (descriptor.extension). It loads just
-- after that file; Retail/Tooltips/Item.lua, before it, holds what these use.
local _, ns = ...
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
local descriptor = ns.TooltipTypes and ns.TooltipTypes[ITEM]
if not descriptor then return end
local item = ns.Retail.Item

local util = ns.util
local unformat = util.unformat
local isSecret = util.isSecret

-- Retail's reagent kinds: "Finishing Crafting Reagent", "Optional Crafting Reagent".
for _, kind in ipairs(item.kinds()) do descriptor.kinds[#descriptor.kinds + 1] = kind end

-- What one read keeps between lines, in its context: the item lines went to,
-- whether retail took the line, and its notes on effects (the list the last
-- effect went into, and a note waiting for the effect it comes before).
local function stateOf(context)
    local state = context.retail
    if not state then
        state = { model = context.rootModel }
        context.retail = state
    end
    return state
end

-- Whether the game greys a line, as it does a primary stat another
-- specialization uses.
local function isGrey(color)
    if isSecret(color) or type(color) ~= "table" then return false end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return false
    end
    return r < .7 and math.abs(r - g) < .06 and math.abs(g - b) < .06
end

-- The header entry with this id, by its place.
local function headerAt(view, id)
    for index, entry in ipairs(view.header) do
        if entry.id == id then return index end
    end
end

descriptor.extension = {
    -- Retail's own fields on every item, its embedded one, and the editor's
    -- samples (Retail/Tooltips/Item.lua's item.newFields).
    initModel = function(model)
        model.retail = item.newFields()
    end,

    -- Retail writes some colors with spaces for zeros: read as the color meant.
    readText = function(left, right)
        return item.repairedColors(left), item.repairedColors(right)
    end,

    -- An expansion's reagents, "Zandalari Crafting Reagent".
    findKind = item.kindWithin,

    -- One expansion's part of a profession, "Midnight Blacksmithing", on a line
    -- the game marks as a requirement; a reagent's name can hold one too
    -- ("Elixir of Mining"), so other lines need the name exactly.
    isProfession = function(name, professions, marked)
        return marked and item.isExpansionProfession(name, professions)
    end,

    -- Retail keeps an active bonus in the set, worded "Set: ...".
    isSetBonus = function(text)
        return unformat(text, ITEM_SET_BONUS) ~= nil
    end,

    -- Retail's appearance sets can list more pieces than they count ("(0/3)"
    -- over five), each indented.
    isSetPiece = function(left)
        return left:match("^%s%s%S") ~= nil
    end,

    readLine = function(m, line, context)
        local state = stateOf(context)
        local lineNumber, data = context.lineNumber, context.data
        local left, right, trimmed = context.leftText, context.rightText, context.text
        -- A Mythic keystone's name, levels, modifiers, and duration.
        state.claimed = item.readKeystone(m, line, lineNumber, left, right, trimmed)
            -- "Legacy Item: Effects are inactive", "You are in the wrong zone.":
            -- beside the effects they speak of.
            or item.readEffectNote(state, line, right, trimmed)
            -- Upgrade level, sockets, crafted quality, and transmogrification.
            or item.readLine(m, line, data, lineNumber, left, right, trimmed, context.originalText)
            -- Where it comes from, between the name and level: Heroic, Mythic.
            or item.readSource(m, line, data, lineNumber, right, trimmed)
        return state.claimed
    end,

    afterReadLine = function(m, line, context)
        local state = stateOf(context)
        local LINE = Enum.TooltipDataLineType or {}
        local model = context.rootModel
        local read = not state.claimed
        state.claimed = nil
        -- What the reader made of a line retail did not take: an effect the
        -- character will not get, greyed or reddened, keeps that color; so does
        -- a primary stat another specialization uses, grey.
        local inactive = read and not context.text:match("^<.+>$") and ns.TooltipData.inactiveColor(line.leftColor)
        local grey = read and isGrey(line.leftColor)
        local effectsAt, equipsAt
        for _, entry in ipairs(context.added) do
            local list, row = entry.list, entry.row
            if list == "header" and read then
                -- A Warband binding in its own blue.
                item.colorBinding(row, line, context.text)
            elseif list == "effects" or list == "equipEffects" then
                if inactive then row.color, row.inactive = inactive, true end
                if list == "effects" then effectsAt = math.min(effectsAt or entry.at, entry.at)
                else equipsAt = math.min(equipsAt or entry.at, entry.at) end
            elseif list == "primary" and grey then
                item.markInactiveStat(row)
            end
        end
        -- A waiting note goes before the effect it speaks of.
        local lineModel = context.lineModel
        local grown = (effectsAt and lineModel.effects) or (equipsAt and lineModel.equipEffects) or nil
        if state.pending and grown then
            table.insert(grown, (effectsAt or equipsAt), state.pending)
            state.pending = nil
        end
        -- A note after an effect follows it, past blank lines only.
        local blank = context.text == "" and context.rightText == ""
        if grown then state.last = grown elseif not blank then state.last = nil end
        -- Decor names its placement cost beside its name.
        if LINE.ItemName and line.type == LINE.ItemName and not state.named then
            state.named = true
            if model.name then item.readNameRight(model, context.rightText) end
        end
        -- Notes stay with the item they were read for.
        if state.model ~= m then state.model, state.last = m, nil end
    end,

    afterRead = function(model, context)
        if model ~= context.rootModel then return end
        -- A note with no effect after it stays with the effects.
        local state = stateOf(context)
        if state.pending then table.insert((state.model or model).effects, state.pending) end
        state.pending = nil
        -- Decor names its class, "Housing Decor", on a line of its own; with its
        -- placement cost, it joins the kinds under its name.
        if context.itemType and not context.recipe then item.readClassLine(model, context.itemType) end
        local shown = {}
        item.addKinds(shown, model)
        if #shown > 0 then
            local kinds = table.concat(shown, " \194\183 ")
            model.slot = model.slot and model.slot ~= "" and (model.slot .. " \194\183 " .. kinds) or kinds
        end
    end,

    extendView = function(view, model, context)
        local styles = context.styles
        -- Where it comes from and whether it is cosmetic, under its name.
        local source = {}
        item.addSource(source, model, styles)
        for index, entry in ipairs(source) do table.insert(view.header, 1 + index, entry) end
        -- Its upgrade level and crafted quality, under its slot.
        local upgrade = {}
        item.addUpgrade(upgrade, model, styles)
        local binding = headerAt(view, "binding")
        for index, entry in ipairs(upgrade) do table.insert(view.header, binding + index - 1, entry) end
        -- What it is transmogrified to, under its binding and level.
        item.addLooks(view.header, model, styles)
    end,
}
