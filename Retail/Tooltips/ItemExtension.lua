-- Retail's part in reading and drawing items, through the callbacks
-- Tooltips/Item.lua offers a client (descriptor.extension). It loads just
-- after that file; Retail/Tooltips/Item.lua, before it, holds what these use.
local _, ns = ...
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
local descriptor = ns.TooltipTypes and ns.TooltipTypes[ITEM]
if not descriptor then return end
local item = ns.Retail.Item

-- What one read keeps between lines, in its context: the item the last line
-- went to, its effect counts then, and its notes on effects (the list the last
-- effect went into, and a note waiting for the effect it comes before).
local function stateOf(context)
    local state = context.retail
    if not state then
        -- Every item starts with no effects or header rows.
        state = { model = context.rootModel, effectCount = 0, equipCount = 0, headerCount = 0 }
        context.retail = state
    end
    return state
end

-- Where the counts are taken, after each line, for the item lines now go to.
local function remember(state, m)
    if state.model ~= m then state.model, state.last = m, nil end
    state.effectCount, state.equipCount, state.headerCount = #m.effects, #m.equipEffects, #m.header
end

-- The header entry with this id, by its place.
local function headerAt(view, id)
    for index, entry in ipairs(view.header) do
        if entry.id == id then return index end
    end
end

descriptor.extension = {
    readLine = function(m, line, context)
        local state = stateOf(context)
        local lineNumber, data = context.lineNumber, context.data
        local left, right, trimmed = context.leftText, context.rightText, context.text
        -- A Mythic keystone's name, levels, modifiers, and duration.
        return item.readKeystone(m, line, lineNumber, left, right, trimmed)
            -- "Legacy Item: Effects are inactive", "You are in the wrong zone.":
            -- beside the effects they speak of.
            or item.readEffectNote(state, line, right, trimmed)
            -- Upgrade level, sockets, crafted quality, and transmogrification.
            or item.readLine(m, line, data, lineNumber, left, right, trimmed, context.originalText)
            -- Where it comes from, between the name and level: Heroic, Mythic.
            or item.readSource(m, line, data, lineNumber, right, trimmed)
    end,

    afterReadLine = function(m, line, context)
        local state = stateOf(context)
        local LINE = Enum.TooltipDataLineType or {}
        local model = context.rootModel
        if state.model == m then
            -- A Warband binding in its own blue, once the reader has added the row.
            if #m.header > state.headerCount then item.colorBinding(m.header[#m.header], line, context.text) end
            -- A waiting note goes before the effect it speaks of.
            local effects, equips = m.effects, m.equipEffects
            local grown = (#effects > state.effectCount and effects) or (#equips > state.equipCount and equips) or nil
            local grownAt = grown == effects and state.effectCount or state.equipCount
            if state.pending and grown then
                table.insert(grown, grownAt + 1, state.pending)
                state.pending = nil
            end
            -- A note after an effect follows it, past blank lines only.
            local blank = context.text == "" and context.rightText == ""
            if grown then state.last = grown elseif not blank then state.last = nil end
        end
        -- Decor names its placement cost beside its name.
        if LINE.ItemName and line.type == LINE.ItemName and not state.named then
            state.named = true
            if model.name then item.readNameRight(model, context.rightText) end
        end
        remember(state, m)
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
