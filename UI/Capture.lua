-- /ptip capture <name>: saves the shown tooltip's data, the lines it shows,
-- and the game's answers its reader asks for, as a test fixture. Captures land
-- in the PrettyTooltipCaptures saved variable, which the game writes on
-- /reload or logout; tests/import_captures.py copies them into tests/fixtures.
-- No game function is replaced to record calls: that would taint it, so the
-- answers are asked for here, and the test runner names any it lacks.
local _, ns = ...

local isSecret, pack = ns.util.isSecret, ns.util.pack
local util = ns.util
local TYPES = Enum and Enum.TooltipDataType or {}
-- Addons the readers check for.
local ADDONS = { "DialogueUI", "EllesmereUI", "Questie", "Auctionator" }

-- Values the game hides in some situations are kept as this mark, which the
-- tests play back as hidden; hidden counts them for the capture's message.
local SECRET_MARK = { __secret = true }
local hidden = 0

-- A plain copy that a saved variable can hold: colors become { r, g, b, a },
-- hidden values a mark, and frames, functions, and userdata are left out.
local function plain(value, depth, seen)
    if isSecret(value) then
        hidden = hidden + 1
        return { __secret = SECRET_MARK.__secret }
    end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return value end
    if kind ~= "table" or depth > 8 or seen[value] then return nil end
    if value.GetObjectType then return nil end
    if value.GetRGBA then
        local r, g, b, a = value:GetRGBA()
        return { r = plain(r, depth + 1, seen), g = plain(g, depth + 1, seen),
            b = plain(b, depth + 1, seen), a = plain(a, depth + 1, seen), color = true }
    end
    seen[value] = true
    local copy = {}
    for key, item in pairs(value) do
        local keyKind = isSecret(key) and "hidden" or type(key)
        if keyKind == "hidden" then hidden = hidden + 1 end
        if keyKind == "string" or keyKind == "number" then copy[key] = plain(item, depth + 1, seen) end
    end
    seen[value] = nil
    return copy
end

local function copyOf(value) return plain(value, 0, {}) end

-- The answers fixtures replay, keyed by function name, then by its arguments
-- joined by commas; a table argument, as the tooltip a method is called on,
-- is "self".
local function recorder()
    local calls = {}
    local function record(name, fn, ...)
        if type(fn) ~= "function" then return end
        for index = 1, select("#", ...) do if isSecret(select(index, ...)) then return end end
        local ok, results = pcall(function(...) return pack(fn(...)) end, ...)
        if not ok then return end
        local args = pack(...)
        local keys = {}
        for index = 1, args.n do
            keys[index] = isSecret(args[index]) and "<restricted>"
                or (type(args[index]) == "table" and "self" or tostring(args[index]))
        end
        calls[name] = calls[name] or {}
        calls[name][table.concat(keys, ",")] = copyOf(results)
        return unpack(results, 1, results.n)
    end
    return calls, record
end

local function fontState(font)
    if not font then return nil end
    local r, g, b = font:GetTextColor()
    return { text = copyOf(font:GetText()), color = copyOf({ r, g, b }), shown = copyOf(font:IsShown()) }
end

local function visibleLines(tooltip)
    local lines = {}
    local name = tooltip:GetName()
    for index = 1, tooltip:NumLines() do
        local left = tooltip:GetLeftLine(index)
        local right = tooltip.GetRightLine and tooltip:GetRightLine(index)
            or (name and _G[name .. "TextRight" .. index])
        lines[index] = { left = fontState(left), right = fontState(right) }
    end
    return lines
end

-- Item names a recipe's lines mention: "Requires Bronze Bar (10), ..." and the
-- crafted item's name, so their info and counts are on hand.
local function mentionedItems(data)
    local names = {}
    for _, line in ipairs(data.lines or {}) do
        local text = not isSecret(line.leftText) and type(line.leftText) == "string" and line.leftText or ""
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if text:find("%(%d+%)") then
            for piece in (text:gsub("^%s*Requires%s+", "") .. ", "):gmatch("(.-), ") do
                local itemName = piece:match("^%s*(.-)%s*%(%d+%)$")
                if itemName then names[#names + 1] = itemName end
            end
        end
        if TYPES and Enum.TooltipDataLineType and line.type == Enum.TooltipDataLineType.ItemName then
            names[#names + 1] = (text:match("^%s*(.-)%s*$"))
        end
    end
    return names
end

local function recordItem(record, tooltip, data)
    local _, link = record("tooltip:GetItem", tooltip.GetItem, tooltip)
    -- A macro's tooltip names no item link; its item is known by ID alone.
    for _, item in pairs({ link or false, data.id or false }) do
        if item then
            record("C_Item.GetItemInfo", C_Item.GetItemInfo, item)
            record("C_Item.GetItemInfoInstant", C_Item.GetItemInfoInstant, item)
            record("C_Item.GetDetailedItemLevelInfo", C_Item.GetDetailedItemLevelInfo, item)
            record("C_Item.IsEquippedItem", C_Item.IsEquippedItem, item)
            record("C_Item.GetItemCount", C_Item.GetItemCount, item)
            record("C_Item.GetItemIconByID", C_Item.GetItemIconByID, item)
        end
    end
    -- The bag slot's stack: an item location cannot be saved, only its count.
    if type(data.guid) == "string" and C_Item.GetItemLocation and C_Item.GetStackCount then
        record("stackCount", function(guid)
            return C_Item.GetStackCount(C_Item.GetItemLocation(guid))
        end, data.guid)
    end
    -- What it may disenchant into, which the panel names and shows.
    for materialID in pairs(ns.disenchantMaterials or {}) do
        record("C_Item.GetItemNameByID", C_Item.GetItemNameByID, materialID)
        record("C_Item.GetItemIconByID", C_Item.GetItemIconByID, materialID)
    end
    for _, name in ipairs(mentionedItems(data)) do
        record("C_Item.GetItemInfo", C_Item.GetItemInfo, name)
        record("C_Item.GetItemCount", C_Item.GetItemCount, name)
    end
end

local function recordSpell(record, tooltip, data)
    record("tooltip:GetSpell", tooltip.GetSpell, tooltip)
    if type(data.id) ~= "number" then return end
    record("C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, data.id)
    record("C_Spell.GetSpellName", C_Spell and C_Spell.GetSpellName, data.id)
    for _, line in ipairs(data.lines or {}) do
        if type(line.tooltipID) == "number" then
            record("C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, line.tooltipID)
        end
    end
end

local UNIT_FUNCTIONS = {
    "UnitExists", "UnitGUID", "UnitName", "UnitIsPlayer", "UnitLevel", "UnitEffectiveLevel", "UnitClass",
    "UnitRace", "UnitFactionGroup", "UnitIsAFK", "UnitIsDND", "UnitCreatureType", "UnitClassification",
    "UnitIsPVP", "UnitIsDeadOrGhost", "UnitIsTapDenied", "UnitHealth", "UnitHealthMax", "GetGuildInfo",
}

local function recordUnit(record, tooltip, data)
    local _, token = record("tooltip:GetUnit", tooltip.GetUnit, tooltip)
    if type(data.guid) == "string" then record("UnitTokenFromGUID", UnitTokenFromGUID, data.guid) end
    local units = { "mouseover", "mouseovertarget" }
    if type(token) == "string" then
        units[#units + 1] = token
        units[#units + 1] = token .. "target"
    end
    for _, unit in ipairs(units) do
        for _, name in ipairs(UNIT_FUNCTIONS) do record(name, _G[name], unit) end
        record("UnitReaction", UnitReaction, unit, "player")
        record("UnitIsUnit", UnitIsUnit, unit, "player")
    end
end

local function recordAura(record, tooltip, data)
    -- The aura's own data, kept by the reader while the game filled the tooltip.
    local kept = ns.keptAuras and ns.keptAuras[tooltip]
    if kept and kept.aura and type(kept.aura.sourceUnit) == "string" then
        record("UnitName", UnitName, kept.aura.sourceUnit)
    end
    if type(data.id) == "number" then
        record("C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, data.id)
    end
    return kept and copyOf(kept)
end

local function recordQuest(record, data)
    if type(data.id) ~= "number" or not C_QuestLog then return end
    record("C_QuestLog.IsOnQuest", C_QuestLog.IsOnQuest, data.id)
    record("C_QuestLog.IsQuestFlaggedCompleted", C_QuestLog.IsQuestFlaggedCompleted, data.id)
end

-- The item a herb or ore node yields, which the panel names and prices.
local function recordObject(record, data)
    local first = data.lines and data.lines[1]
    local name = first and not isSecret(first.leftText) and first.leftText
    local itemID = type(name) == "string" and ns.objectYield and ns.objectYield(name)
    if itemID then
        record("C_Item.GetItemInfo", C_Item.GetItemInfo, itemID)
        record("C_Item.GetItemIconByID", C_Item.GetItemIconByID, itemID)
    end
end

-- A macro's name, icon, and body, by its index and its name; the spell or item
-- #showtooltip puts in its tooltip; and every macro's spell and item, to find
-- the one showing it.
local function recordMacro(record, tooltip, data)
    if not GetMacroInfo then return end
    if type(data.id) == "number" then record("GetMacroInfo", GetMacroInfo, data.id) end
    local first = data.lines and data.lines[1]
    local name = first and not isSecret(first.leftText) and first.leftText
    if type(name) == "string" and name ~= "" then
        record("GetMacroInfo", GetMacroInfo, name)
        if GetMacroIndexByName then record("GetMacroIndexByName", GetMacroIndexByName, name) end
    end
    for _, line in ipairs(data.lines or {}) do
        if type(line.tooltipID) == "number" and line.tooltipType == TYPES.Item then
            recordItem(record, tooltip, { id = line.tooltipID, lines = data.lines, guid = data.guid })
        elseif type(line.tooltipID) == "number" then
            record("C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, line.tooltipID)
        end
    end
    if not (GetNumMacros and GetMacroSpell) then return end
    local account, character = record("GetNumMacros", GetNumMacros)
    local offset = MAX_ACCOUNT_MACROS or 120
    for index = 1, offset + (character or 0) do
        if index <= (account or 0) or index > offset then
            record("GetMacroSpell", GetMacroSpell, index)
            if GetMacroItem then record("GetMacroItem", GetMacroItem, index) end
            record("GetMacroInfo", GetMacroInfo, index)
        end
    end
end

-- The pet bar: each slot's name, icon, and autocast state, and the icon of
-- the spell an ability's tooltip nests.
local function recordPetAction(record, data)
    for _, line in ipairs(data.lines or {}) do
        if type(line.tooltipID) == "number" then
            record("C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, line.tooltipID)
        end
    end
    for slot = 1, NUM_PET_ACTION_SLOTS or 10 do record("GetPetActionInfo", GetPetActionInfo, slot) end
end

-- The minimap's blips: the units a player in the list may be, for their class.
local function recordMinimap(record)
    for _, unit in ipairs(ns.Game.NEARBY_UNITS) do
        if record("UnitName", UnitName, unit) then
            record("UnitIsPlayer", UnitIsPlayer, unit)
            record("UnitClass", UnitClass, unit)
        end
    end
end

-- The frame a tooltip is for: its name and ID, and a flight map pin's node.
local function ownerOf(tooltip)
    local owner = tooltip:GetOwner()
    if not util.canModify(owner) then return end
    return {
        name = owner.GetName and copyOf(owner:GetName()),
        id = owner.GetID and copyOf(owner:GetID()),
        kind = owner.GetObjectType and owner:GetObjectType(),
        parent = owner.GetParent and owner:GetParent() and owner:GetParent().GetName and copyOf(owner:GetParent():GetName()),
        taxiNode = owner.taxiNodeData and copyOf(owner.taxiNodeData),
    }
end

-- The flight map while it is open: each node's name, cost, and type.
local function recordTaxi(record)
    if not NumTaxiNodes then return end
    local count = record("NumTaxiNodes", NumTaxiNodes)
    for index = 1, type(count) == "number" and count or 0 do
        record("TaxiNodeName", TaxiNodeName, index)
        record("TaxiNodeCost", TaxiNodeCost, index)
        record("TaxiNodeGetType", TaxiNodeGetType, index)
    end
end

-- The player, the same for every tooltip type: level, spell power, and skills.
local function recordPlayer(record)
    for _, name in ipairs({ "UnitLevel", "UnitClass", "UnitRace", "UnitFactionGroup", "UnitName" }) do
        record(name, _G[name], "player")
    end
    for school = 1, 7 do record("GetSpellBonusDamage", GetSpellBonusDamage, school) end
    record("GetSpellBonusHealing", GetSpellBonusHealing)
    local count = record("GetNumSkillLines", GetNumSkillLines)
    for index = 1, type(count) == "number" and count or 0 do
        record("GetSkillLineInfo", GetSkillLineInfo, index)
    end
    -- Clients without the skill list name professions by these instead.
    local professions = pack(record("GetProfessions", GetProfessions))
    for index = 1, professions.n do
        if type(professions[index]) == "number" then
            record("GetProfessionInfo", GetProfessionInfo, professions[index])
        end
    end
    for level = 1, 63 do record("GetQuestDifficultyColor", GetQuestDifficultyColor, level) end
    for _, addon in ipairs(ADDONS) do record("C_AddOns.GetAddOnInfo", C_AddOns and C_AddOns.GetAddOnInfo, addon) end
end

local function typeName(dataType)
    for name, value in pairs(TYPES) do
        if value == dataType then return name end
    end
end

local function captureTooltip(tooltip)
    local data = util.call(tooltip.GetTooltipData, tooltip)
    local calls, record = recorder()
    local entry = { tooltip = tooltip:GetName(), calls = calls }
    -- A part that trips on a hidden value is noted and the rest still kept.
    local function attempt(part, ...)
        local ok, problem = pcall(...)
        if not ok then
            entry.problems = entry.problems or {}
            entry.problems[#entry.problems + 1] = part .. ": " .. (util.safeText(problem) or "<restricted>")
        end
        return ok and problem or nil
    end
    entry.lines = attempt("lines", visibleLines, tooltip) or {}
    entry.owner = attempt("owner", ownerOf, tooltip)
    attempt("taxi", recordTaxi, record)
    if isSecret(data) or type(data) ~= "table" then
        -- Filled by an addon with lines alone, as Questie's quest links.
        entry.fromLines = true
    else
        entry.data = copyOf(data)
        local dataType = not isSecret(data.type) and data.type or nil
        entry.tooltipType = typeName(dataType)
        if dataType == TYPES.Item then
            attempt("item", recordItem, record, tooltip, data)
        elseif dataType == TYPES.Spell then
            attempt("spell", recordSpell, record, tooltip, data)
        elseif dataType == TYPES.Unit or dataType == TYPES.Corpse then
            attempt("unit", recordUnit, record, tooltip, data)
        elseif dataType == TYPES.UnitAura then
            entry.aura = attempt("aura", recordAura, record, tooltip, data)
        elseif dataType == TYPES.Quest then
            attempt("quest", recordQuest, record, data)
        elseif dataType == TYPES.Object then
            attempt("object", recordObject, record, data)
        elseif dataType == TYPES.Macro then
            attempt("macro", recordMacro, record, tooltip, data)
        elseif dataType == TYPES.MinimapMouseover then
            attempt("minimap", recordMinimap, record)
        elseif dataType == TYPES.PetAction then
            attempt("pet action", recordPetAction, record, data)
        end
    end
    attempt("player", recordPlayer, record)
    return entry
end

local COMPARISONS = { "ShoppingTooltip1", "ShoppingTooltip2" }

-- Functions the addon checks for before calling; the tests give a fixture
-- only those its client had.
local OPTIONAL = {
    "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo", "UnitTokenFromGUID",
    "UnitEffectiveLevel", "UnitAura", "GetSpellInfo", "GetSpellTexture", "GetCoinTextureString",
    "BreakUpLargeNumbers", "issecretvalue", "SetPortraitTexture", "C_Item.GetItemLocation",
    "C_Item.GetStackCount", "C_Item.GetItemInfoInstant", "C_Item.GetDetailedItemLevelInfo",
    "C_Item.GetItemNameByID", "C_Item.RequestLoadItemDataByID", "C_Spell.GetSpellTexture",
    "C_Spell.GetSpellName", "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetAuraDataByAuraInstanceID",
    "C_QuestLog.IsOnQuest", "C_QuestLog.IsQuestFlaggedCompleted", "C_CurrencyInfo.GetCoinTextureString",
    "GetMacroInfo", "GetMacroIndexByName", "GetNumMacros", "GetMacroSpell", "GetMacroItem", "GetPetActionInfo",
}

local function present()
    local found = {}
    for _, path in ipairs(OPTIONAL) do
        local value = _G
        for part in path:gmatch("[^.]+") do value = type(value) == "table" and value[part] or nil end
        found[path] = type(value) == "function"
    end
    return found
end

function ns.capture(name)
    name = name and name:match("^%s*(.-)%s*$") or ""
    if name == "" or not name:match("^[%w%-_]+$") then
        print("PrettyTooltip: name the capture with letters, digits, - or _, as /ptip capture frostbolt-r3.")
        return
    end
    local tooltip = util.canModify(GameTooltip) and GameTooltip:IsShown() and GameTooltip or ItemRefTooltip
    if not (util.canModify(tooltip) and tooltip:IsShown()) then
        print("PrettyTooltip: hover something first; there is no tooltip to capture.")
        return
    end
    hidden = 0
    local ok, entry = pcall(captureTooltip, tooltip)
    if not ok then
        print("PrettyTooltip: the capture failed (" .. (util.safeText(entry) or "<restricted>") .. ").")
        return
    end
    entry.comparisons = {}
    for _, comparisonName in ipairs(COMPARISONS) do
        local comparison = _G[comparisonName]
        if util.canModify(comparison) and comparison:IsShown() then
            local captured, result = pcall(captureTooltip, comparison)
            if captured then entry.comparisons[#entry.comparisons + 1] = result end
        end
    end
    local version, build = GetBuildInfo()
    entry.client = { version = version, build = build, locale = GetLocale() }
    -- The client's numbers for the types of tooltip and line the readers compare against.
    entry.enums = copyOf({ TooltipDataType = Enum.TooltipDataType, TooltipDataLineType = Enum.TooltipDataLineType,
        ItemClass = Enum.ItemClass, TooltipDataItemBinding = Enum.TooltipDataItemBinding })
    entry.present = present()
    entry.settings = copyOf(PrettyTooltipDB)
    entry.captured = date("%Y-%m-%d %H:%M")
    if type(PrettyTooltipCaptures) ~= "table" then PrettyTooltipCaptures = {} end
    local replaced = PrettyTooltipCaptures[name] ~= nil
    PrettyTooltipCaptures[name] = entry
    entry.hidden = hidden
    print(("PrettyTooltip: captured %s as %q%s%s%s; /reload to save it."):format(entry.tooltipType or "a tooltip", name,
        #entry.comparisons > 0 and (" with " .. #entry.comparisons .. " comparison") or "",
        hidden > 0 and (", " .. hidden .. " values hidden by the game") or "",
        replaced and ", replacing the last one" or ""))
end

function ns.listCaptures()
    local names = {}
    for name in pairs(type(PrettyTooltipCaptures) == "table" and PrettyTooltipCaptures or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    print(#names == 0 and "PrettyTooltip: no captures yet."
        or ("PrettyTooltip: " .. #names .. " captures: " .. table.concat(names, ", ")))
end

function ns.clearCaptures()
    PrettyTooltipCaptures = {}
    print("PrettyTooltip: captures cleared; /reload to save that.")
end
