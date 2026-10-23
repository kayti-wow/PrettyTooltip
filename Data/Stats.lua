-- Item wording and formatting rules. Settings are explicit arguments, but for
-- the category and school colors the style editor may replace; no game hooks.
-- A stat is read from the game's own wording, in the client's language, into
-- its key and amount, and printed again from them as the game prints a stat.
local _, ns = ...
local util = ns.util
local unformat, fill = util.unformat, util.fill
local L = ns.L
local stats = {}
ns.Stats = stats

-- Category colors are soft and evenly light, so every kind of stat reads
-- alike on the dark panel; the vivid school colors stay apart from them.
-- Each has a lighter, less saturated shade for the stat's name. The style
-- editor can replace a category's color (setting statColor plus its name),
-- and the shade then follows from it.
local CATEGORIES = {
    { key = "Primary", label = L["Primary attributes"], value = "E9DDC4", name = "EEE7DA" },
    { key = "Attack", label = L["Attack"], value = "FAA365", name = "F7C5A5" },
    { key = "Defense", label = L["Defense"], value = "A6C1DD", name = "C7D6E6" },
    { key = "Magic", label = L["Magic"], value = "C6A9FC", name = "D7C8F7" },
    { key = "Healing", label = L["Healing"], value = "89DA9B", name = "BDE8C4" },
    { key = "Mana", label = L["Mana"], value = "9EB8FE", name = "C0D0FA" },
    { key = "Negative", label = L["Negative values"], value = "F66D67" },
}
local CATEGORY = {}
for _, category in ipairs(CATEGORIES) do CATEGORY[category.key] = category end
-- A client's own stats and colors (retail's Retail/Data/Stats.lua): its
-- categories, which the editor lists apart under the label given, and stats.
local contributions = ns.contributions("stats")
local CATEGORY_GROUPS = {}
for _, extra in ipairs(contributions) do
    for _, category in ipairs(extra.categories or {}) do CATEGORY[category.key] = category end
    if extra.categories then CATEGORY_GROUPS[#CATEGORY_GROUPS + 1] = { label = extra.label, categories = extra.categories } end
end
stats.CATEGORIES = CATEGORIES
stats.CATEGORY_GROUPS = CATEGORY_GROUPS
local STAT_MARKER = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2|t  "

local function mod(name) return _G["ITEM_MOD_" .. name] end
local function itemStat(name) return _G["TOOLTIP_ITEM_STAT_" .. name] end

-- The schools, by the client's names for them.
local SCHOOL_NAMES = { Holy = DAMAGE_SCHOOL2, Fire = DAMAGE_SCHOOL3, Nature = DAMAGE_SCHOOL4,
    Frost = DAMAGE_SCHOOL5, Shadow = DAMAGE_SCHOOL6, Arcane = DAMAGE_SCHOOL7 }
local RESISTANCE_NAMES = { Holy = RESISTANCE1_NAME, Fire = RESISTANCE2_NAME, Nature = RESISTANCE3_NAME,
    Frost = RESISTANCE4_NAME, Shadow = RESISTANCE5_NAME, Arcane = RESISTANCE6_NAME }
local SCHOOLS = { "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
local SCHOOL_KEYS = {}
for school, name in pairs(SCHOOL_NAMES) do SCHOOL_KEYS[name] = school end

-- Creature types, by the game's key for them, and the panel's name for each.
local CREATURES = { BEAST = L["Beasts"], DEMON = L["Demons"], DRAGONKIN = L["Dragonkin"], ELEMENTAL = L["Elementals"],
    GIANT = L["Giants"], HUMANOID = L["Humanoids"], MECHANICAL = L["Mechanical"], UNDEAD = L["Undead"] }
local CREATURE_KEYS = { "BEAST", "DEMON", "DRAGONKIN", "ELEMENTAL", "GIANT", "HUMANOID", "MECHANICAL", "UNDEAD" }

-- Every stat the panel shows, by key: its category, which colors it, else
-- its school's colors; whether lite mode colors it (magic); whether its value
-- is a percent; and its name, the game's or the addon's own. A stat of each
-- school or creature type fills its name's %s with it.
local STATS = {
    STRENGTH = { category = "Primary", name = mod("STRENGTH_SHORT"), line = mod("STRENGTH") },
    AGILITY = { category = "Primary", name = mod("AGILITY_SHORT"), line = mod("AGILITY") },
    STAMINA = { category = "Primary", name = mod("STAMINA_SHORT"), line = mod("STAMINA") },
    INTELLECT = { category = "Primary", name = mod("INTELLECT_SHORT"), line = mod("INTELLECT") },
    SPIRIT = { category = "Primary", name = mod("SPIRIT_SHORT"), line = mod("SPIRIT") },
    ALL_STATS = { category = "Primary", name = L["All Stats"] },

    ATTACK_POWER = { category = "Attack", name = mod("ATTACK_POWER_SHORT") },
    RANGED_ATTACK_POWER = { category = "Attack", name = mod("RANGED_ATTACK_POWER_SHORT") },
    ATTACK_POWER_VS = { category = "Attack", name = L["Attack Power vs %s"], each = "creature" },
    HIT_CHANCE = { category = "Attack", name = L["Hit Chance"], percent = true },
    CRIT_CHANCE = { category = "Attack", name = L["Critical Strike Chance"], percent = true },
    HIT_RATING = { category = "Attack", name = L["Hit Rating"] },
    CRIT_RATING = { category = "Attack", name = L["Critical Strike Rating"] },
    HASTE_RATING = { category = "Attack", name = L["Haste Rating"] },
    EXPERTISE_RATING = { category = "Attack", name = L["Expertise Rating"] },

    ARMOR = { category = "Defense", name = RESISTANCE0_NAME },
    DEFENSE_SKILL = { category = "Defense", name = L["Defense Skill"] },
    DEFENSE_RATING = { category = "Defense", name = L["Defense Rating"] },
    DODGE_CHANCE = { category = "Defense", name = L["Dodge Chance"], percent = true },
    DODGE_RATING = { category = "Defense", name = L["Dodge Rating"] },
    PARRY_CHANCE = { category = "Defense", name = L["Parry Chance"], percent = true },
    PARRY_RATING = { category = "Defense", name = L["Parry Rating"] },
    BLOCK_CHANCE = { category = "Defense", name = L["Block Chance"], percent = true },
    BLOCK_RATING = { category = "Defense", name = L["Block Rating"] },
    BLOCK_VALUE = { category = "Defense", name = L["Shield Block Value"] },
    RESILIENCE_RATING = { category = "Defense", name = L["Resilience Rating"] },
    ALL_RESISTANCES = { category = "Defense", name = L["All Resistances"] },
    RESISTANCE = { each = "school" },

    SPELL_POWER = { category = "Magic", magic = true, name = mod("SPELL_POWER_SHORT") },
    SPELL_DAMAGE = { category = "Magic", magic = true, name = L["Spell Damage Power"] },
    SPELL_DAMAGE_VS = { category = "Magic", name = L["Spell Damage Power vs %s"], each = "creature" },
    SPELL_PENETRATION = { category = "Magic", magic = true, name = L["Spell Penetration"] },
    SPELL_HIT_CHANCE = { category = "Magic", magic = true, name = L["Spell Hit Chance"], percent = true },
    SPELL_CRIT_CHANCE = { category = "Magic", magic = true, name = L["Spell Critical Strike Chance"], percent = true },
    SPELL_HIT_RATING = { category = "Magic", magic = true, name = L["Spell Hit Rating"] },
    SPELL_CRIT_RATING = { category = "Magic", magic = true, name = L["Spell Critical Strike Rating"] },
    SPELL_HASTE_RATING = { category = "Magic", magic = true, name = L["Spell Haste Rating"] },
    SCHOOL_SPELL_POWER = { magic = true, name = L["%s Spell Power"], each = "school" },
    SCHOOL_SPELL_DAMAGE = { magic = true, name = L["%s Spell Damage Power"], each = "school" },

    HEALING_POWER = { category = "Healing", magic = true, name = L["Healing Power"] },
    HEALTH_REGEN = { category = "Healing", name = L["Health per 5 sec"] },
    MANA_REGEN = { category = "Mana", name = L["Mana per 5 sec"] },
    MANA = { category = "Mana", name = mod("MANA_SHORT"), line = mod("MANA") },
}

-- A client's own stats, as retail's ratings: "+120 Haste".
for _, extra in ipairs(contributions) do
    for key, def in pairs(extra.stats or {}) do STATS[key] = def end
end

-- A stat's name, as the panel shows it: "Fire Resistance", "Attack Power vs Undead".
local function nameOf(stat)
    if stat.key == "RESISTANCE" then return RESISTANCE_NAMES[stat.school] end
    local name = STATS[stat.key].name
    local filler = stat.school and SCHOOL_NAMES[stat.school] or stat.creature and CREATURES[stat.creature]
    return name and filler and fill(name, filler) or name
end

-- Its value as printed: "+12", "+1%".
local function valueOf(stat)
    return stat.sign .. stat.amount .. (stat.percent and "%" or "")
end

-- A stat as the game prints one: "+12 Spell Power", or in Korean the name first.
function stats.text(stat)
    return fill(TOOLTIP_ITEM_STAT_FORMAT, stat.sign, stat.amount .. (stat.percent and "%" or ""), nameOf(stat))
end

-- Every stat the panel knows, by its name.
local NAMED = {}
local function known(stat)
    local text = nameOf(stat)
    if text then NAMED[text] = stat end
end
for key, def in pairs(STATS) do
    if def.each == "school" then
        for _, school in ipairs(SCHOOLS) do known({ key = key, school = school }) end
    elseif def.each == "creature" then
        for _, creature in ipairs(CREATURE_KEYS) do known({ key = key, creature = creature }) end
    else
        known({ key = key })
    end
end

-- Lines the game prints its own way, besides as a stat's name after its value.
local LINES = { { ITEM_RESIST_ALL, "ALL_RESISTANCES" }, { ITEM_RESIST_SINGLE, "RESISTANCE", school = true } }
for key, def in pairs(STATS) do
    if def.line then LINES[#LINES + 1] = { def.line, key } end
end

local function isNumber(text)
    return type(text) == "string" and text:match("^%d[%d%.,]*$") ~= nil
end

-- The second argument is numeric. Reading it as the game's %s would match
-- an empty amount when the next %s (the label) touches it, as on zhTW.
local function statAmountFormat(suffix)
    local format, count = TOOLTIP_ITEM_STAT_FORMAT:gsub("%%2%$s", function() return "%2$d" .. suffix end)
    if count == 0 then
        format = TOOLTIP_ITEM_STAT_FORMAT:gsub("%%s", function() return "%d" .. suffix end, 1)
    end
    return format
end
local STAT_AMOUNT_FORMAT, STAT_PERCENT_FORMAT = statAmountFormat(""), statAmountFormat("%%")

-- A value's sign, amount, and the rest when the text is printed as a stat
-- line, whatever the stat: "+6", "Intellect" from "+6 Intellect".
function stats.lineParts(text)
    local sign, amount, rest = unformat(text, STAT_PERCENT_FORMAT)
    if sign then
        amount = amount .. "%"
    else
        sign, amount, rest = unformat(text, STAT_AMOUNT_FORMAT)
    end
    if sign and isNumber((amount or ""):gsub("%%$", "")) and rest ~= "" then return sign, amount, rest end
end

local function withValue(found, sign, amount)
    local stat = { key = found.key, school = found.school, creature = found.creature, sign = sign }
    stat.percent = amount:sub(-1) == "%"
    if stat.percent then amount = amount:sub(1, -2) end
    -- Shown without the client's group separator: "1,000" as "1000".
    local group = LARGE_NUMBER_SEPERATOR
    if group == "," or group == "." then amount = amount:gsub("%" .. group .. "(%d%d%d)", "%1") end
    stat.amount = amount
    return stat
end

-- The stat a line names, as the game or stats.text prints it: "+6 Intellect",
-- "+5 Fire Resistance". nil for other text and stats the panel does not know.
function stats.read(text)
    if type(text) ~= "string" then return end
    local sign, amount, rest = stats.lineParts(text)
    if sign and NAMED[rest] then return withValue(NAMED[rest], sign, amount) end
    for _, line in ipairs(LINES) do
        local lineSign, lineAmount, word = unformat(text, line[1])
        local school = line.school and SCHOOL_KEYS[word]
        if lineSign and isNumber(lineAmount) and (school or not line.school) then
            return withValue({ key = line[2], school = school }, lineSign, lineAmount)
        end
    end
end

-- A category's color and its name's shade, as "RRGGBB": the style editor's,
-- if set, with a shade lifted toward white, else the defaults.
local function categoryColors(key)
    local category = CATEGORY[key]
    local custom = ns.option and ns.option("statColor" .. key)
    if type(custom) == "table" and type(custom[1]) == "number" then
        local shade = {}
        for index = 1, 3 do shade[index] = custom[index] + (1 - custom[index]) * .45 end
        return util.hex(custom), util.hex(shade)
    end
    return category.value, category.name or category.value
end
stats.categoryColors = categoryColors

-- Text in a color, the space around it left outside the color.
local function tinted(text, color)
    local before, core, after = text:match("^(%s*)(.-)(%s*)$")
    if core == "" then return text end
    return before .. "|cff" .. color .. core .. "|r" .. after
end

-- The text with its value, from first to last, in one color, and the rest,
-- before it or after it, in another.
local function colorValue(text, first, last, value, rest)
    return tinted(text:sub(1, first - 1), rest) .. "|cff" .. value .. text:sub(first, last) .. "|r"
        .. tinted(text:sub(last + 1), rest)
end

local function colorizeStat(text, colors)
    local stat = stats.read(text)
    if not stat then return end
    local value, name
    if STATS[stat.key].category then
        value, name = categoryColors(STATS[stat.key].category)
    else
        value, name = ns.Palette.schoolStatColors(stat.school)
    end
    if not value then return end

    if not colors then value, name = "F2E8D5", "A89F8E" end
    if stat.sign == "-" then value = categoryColors("Negative") end
    local printed = stats.text(stat)
    local first, last = printed:find(valueOf(stat), 1, true)
    return colorValue(printed, first, last, value, name)
end

-- Whether a stat row is a spell's: spell power and its schools, spell hit,
-- crit, and penetration, and healing power. Lite mode colors only these.
function stats.isMagical(text)
    local stat = stats.read(text)
    return stat ~= nil and STATS[stat.key].magic == true
end

function stats.styleStat(text, colors, markers)
    local colored = colorizeStat(text, colors)
    if not colored then return text end
    -- The second result supplies the colored wording without a marker.
    return (markers and STAT_MARKER or "") .. colored, colored
end

-- Weapon damage of a school in that school's stat colors: a wand's
-- "64 - 120 Shadow Damage", or a bonus "+5 - 7 Fire Damage".
function stats.styleDamage(text, colors)
    local trimmed = util.trim(text)
    local low, high, word = unformat(trimmed, DAMAGE_TEMPLATE_WITH_SCHOOL)
    if not low then low, high, word = unformat(trimmed, PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL) end
    local color, label = ns.Palette.schoolStatColors(SCHOOL_KEYS[word])
    if not color or not colors or not isNumber(low) or not isNumber(high) then return text end
    local first = trimmed:find(low, 1, true)
    local _, last = trimmed:find(high, first + #low, true)
    if trimmed:sub(first - 1, first - 1) == "+" then first = first - 1 end
    return colorValue(trimmed, first, last, color, label)
end

-- Item effects (procs, Use, and Equip) use the same school detection and
-- lighter number colors as spell descriptions, with the same neutral fallback.
function stats.styleEffect(text, colors)
    if not colors then return text end
    text = ns.util.uncolored(text)
    local school = ns.Palette.detectSchool({ text })
    return ns.util.colorNumbers(text, ns.Palette.numberCode(ns.Palette.school(school)))
end

-- Equip wordings, read without case or a final period, and the stats each
-- gives: keys in the order of their amounts; a school or creature type; or,
-- for words, the table that names the stat (no key) or creature type in them.
local RULES = {}

-- No-break spaces, as French puts before a colon, read as spaces.
local function normalized(text)
    text = util.uncolored(text):gsub("\194\160", " "):gsub("\226\128\175", " ")
    return (util.trim(text):lower():gsub("%.$", ""))
end

local function rule(format, keys, fields)
    if type(format) ~= "string" then return end
    local entry = { format = normalized(format), keys = type(keys) == "table" and keys or { keys } }
    -- Its words before anything it fills in, which a line must open with.
    entry.opening = entry.format:match("^[^%%|]*")
    for field, value in pairs(fields or {}) do entry[field] = value end
    RULES[#RULES + 1] = entry
end

-- The game's own sentences.
for _, entry in ipairs({
    { "SPELL_POWER_INCREASE", "SPELL_POWER" },
    { "SPELL_DAMAGE_INCREASE", "SPELL_DAMAGE" },
    { "SPELL_HEALING_INCREASE", "HEALING_POWER" },
    { "SPELL_HEALING_INCREASE_DAMAGE_INCREASE", { "HEALING_POWER", "SPELL_DAMAGE" } },
    { "ATTACK_POWER_INCREASE", "ATTACK_POWER" },
    { "RANGED_ATTACK_POWER_INCREASE", "RANGED_ATTACK_POWER" },
    { "HIT_PERCENT_INCREASE", "HIT_CHANCE" },
    { "CRIT_PERCENT_INCREASE", "CRIT_CHANCE" },
    { "DODGE_PCT_INCREASE", "DODGE_CHANCE" },
    { "PARRY_PCT_INCREASE", "PARRY_CHANCE" },
    { "BLOCK_CHANCE_INCREASE", "BLOCK_CHANCE" },
    { "DEFENSE_INCREASE", "DEFENSE_SKILL" },
    { "BLOCK_VALUE_INCREASE", "BLOCK_VALUE" },
    { "MANA_REGEN_INCREASE", "MANA_REGEN" },
    { "HEALTH_REGEN_INCREASE", "HEALTH_REGEN" },
    { "SPELL_PENETRATION_INCREASE", "SPELL_PENETRATION" },
}) do
    rule(itemStat(entry[1]), entry[2])
end
for _, school in ipairs(SCHOOLS) do
    rule(itemStat(school:upper() .. "_DAMAGE_INCREASE"), "SCHOOL_SPELL_DAMAGE", { school = school })
end
for _, creature in ipairs(CREATURE_KEYS) do
    rule(itemStat("SD_VS_" .. creature .. "_INCREASE"), "SPELL_DAMAGE_VS", { creature = creature })
    rule(itemStat("AP_VS_" .. creature .. "_INCREASE"), "ATTACK_POWER_VS", { creature = creature })
end

-- The game's descriptions of item stats, after the label it puts first.
local function equipMod(name, key, fields)
    local sentence = mod(name)
    if sentence and ITEM_SPELL_TRIGGER_ONEQUIP then rule(ITEM_SPELL_TRIGGER_ONEQUIP .. " " .. sentence, key, fields) end
end
for _, entry in ipairs({
    { "ATTACK_POWER", "ATTACK_POWER" }, { "RANGED_ATTACK_POWER", "RANGED_ATTACK_POWER" },
    { "SPELL_POWER", "SPELL_POWER" }, { "SPELL_DAMAGE_DONE", "SPELL_DAMAGE" }, { "SPELL_HEALING_DONE", "HEALING_POWER" },
    { "HIT_RATING", "HIT_RATING" }, { "CRIT_RATING", "CRIT_RATING" }, { "HASTE_RATING", "HASTE_RATING" },
    { "EXPERTISE_RATING", "EXPERTISE_RATING" }, { "HIT_SPELL_RATING", "SPELL_HIT_RATING" },
    { "CRIT_SPELL_RATING", "SPELL_CRIT_RATING" }, { "DEFENSE_SKILL_RATING", "DEFENSE_SKILL" },
    { "DODGE_RATING", "DODGE_RATING" }, { "PARRY_RATING", "PARRY_RATING" }, { "BLOCK_RATING", "BLOCK_RATING" },
    { "RESILIENCE_RATING", "RESILIENCE_RATING" }, { "BLOCK_VALUE", "BLOCK_VALUE" },
    { "MANA_REGENERATION", "MANA_REGEN" }, { "HEALTH_REGEN", "HEALTH_REGEN" }, { "EXTRA_ARMOR", "ARMOR" },
}) do
    equipMod(entry[1], entry[2])
end
for _, school in ipairs(SCHOOLS) do
    equipMod(school:upper() .. "_DAMAGE_DONE", "SCHOOL_SPELL_DAMAGE", { school = school })
end

-- Wordings the game's strings do not cover, from the client's language file.
for _, wording in ipairs(ns.Locale.statWordings) do
    rule(wording[1], wording[2], { words = wording[3] and ns.Locale.statWords[wording[3]] })
end

-- The stats one rule reads from what it found; nil when they are not stats.
local function apply(entry, found)
    local amounts, word = {}, nil
    for index = 1, found.n do
        local value = found[index]
        if isNumber(value) then amounts[#amounts + 1] = value elseif type(value) == "string" then word = value end
    end
    local named = entry.words and entry.words[word or ""]
    if entry.words and not named then return end
    local list = {}
    for index, key in ipairs(entry.keys) do
        if not amounts[index] then return end
        local stat = { key = key, sign = "+", amount = amounts[index], school = entry.school,
            creature = entry.creature }
        -- A word names the stat itself, or the creature type of a stat that has one.
        if named then
            if STATS[key].each == "creature" then stat.creature = named else stat.key = named end
        end
        stat.percent = STATS[stat.key].percent
        list[index] = stats.text(stat)
    end
    if #entry.keys == 0 and named then
        if not amounts[1] then return end
        local stat = { key = named, sign = "+", amount = amounts[1], percent = STATS[named].percent }
        list[1] = stats.text(stat)
    end
    return list
end

-- An equip line's stats, each printed as the game prints a stat: "Equip:
-- Increases healing done by up to 20 and damage done by up to 10 for all
-- magical spells and effects." gives "+20 Healing Power", "+10 Spell Damage
-- Power". nil for any other line.
function stats.rewrite(text)
    if type(text) ~= "string" then return end
    local line = normalized(text)
    for _, entry in ipairs(RULES) do
        if line:sub(1, #entry.opening) == entry.opening then
            local found = util.pack(unformat(line, entry.format))
            if found[1] ~= nil then
                local list = apply(entry, found)
                if list and #list > 0 then return list end
            end
        end
    end
end

-- An item line's two wordings, each stat on its own line: display for the
-- panel, styled by colors and markers; lite for the game's own tooltip, in its
-- colors but for magic, spell power and what a proc deals. proc marks a
-- chance on hit line. nil when the line reads the same either way.
function stats.itemWording(text, proc, colors, markers)
    local replacements = stats.rewrite(text)
    local display = replacements or { text }
    local lite = {}
    local styled = false
    for index, piece in ipairs(display) do
        local shown, colored = stats.styleStat(piece, colors, markers)
        local onHit = proc or util.startsWith(piece, ITEM_SPELL_TRIGGER_ONPROC)
        if onHit then
            local effect = stats.styleEffect(piece, colors)
            if effect ~= piece then shown, colored = effect, effect end
        end
        local magical = onHit or stats.isMagical(piece)
        lite[index] = colored and magical and colors and colored or piece
        if colored then
            display[index] = shown
            styled = true
        end
    end
    if not (replacements or styled) then return end
    return { display = table.concat(display, "|n"), lite = table.concat(lite, "|n"), lines = #display }
end
