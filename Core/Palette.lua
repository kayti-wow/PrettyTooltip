-- Shared colors by role and the rules for highlighting descriptions.
local _, ns = ...
local util = ns.util
local palette = {}
ns.Palette = palette

-- Shared tables are read-only; per-tooltip tints are built separately.
palette.roles = {
    title = { .96, .92, .84 },
    detail = { .82, .78, .71 },
    description = { .92, .87, .76 },
    caption = { .60, .57, .52 },
    neutral = { .62, .66, .74 },
    unmet = { 1, .34, .28 },
    quest = { 1, .82, 0 },
    objective = { .90, .85, .74 },
    done = { .45, .80, .40 },
    flavor = { .86, .74, .45 },
    extras = { .60, .60, .63 },
}

-- The original item tones have slightly different rounding and hand-picked
-- label shades. Keep them alongside the panel colors so defaults stay exact.
palette.SCHOOLS = {
    { key = "Arcane", label = "Arcane", color = { .92, .38, .84 }, statValue = "EB60D6", statName = "F0ADE6" },
    { key = "Fire", label = "Fire", color = { 1, .43, .11 }, statValue = "FF6D1B", statName = "EE9F72" },
    { key = "Frost", label = "Frost", color = { .30, .78, .97 }, statValue = "4CC6F7", statName = "9EDCF5" },
    { key = "Holy", label = "Holy", color = { .98, .73, .22 }, statValue = "FBBA38", statName = "F6D28A" },
    { key = "Nature", label = "Nature", color = { .50, .80, .28 }, statValue = "7FCD48", statName = "A6D783" },
    -- Lifted from a darker violet that read poorly on the panel.
    { key = "Shadow", label = "Shadow", color = { .76, .45, 1 }, statValue = "C174FF", statName = "C9A2EE" },
    { key = "Holyfire", label = "Holyfire", color = { .99, .58, .165 } },
    -- Frostfire is picked by hand: blending frost and fire gives grey.
    { key = "Frostfire", label = "Frostfire", color = { .18, .78, .72 } },
}
palette.schools = {}
local SCHOOL = {}
for _, school in ipairs(palette.SCHOOLS) do
    palette.schools[school.key] = school.color
    SCHOOL[school.key] = school
end

palette.CLASSES = {
    { key = "WARRIOR", label = "Warrior" }, { key = "PALADIN", label = "Paladin" },
    { key = "HUNTER", label = "Hunter" }, { key = "ROGUE", label = "Rogue" },
    { key = "PRIEST", label = "Priest" }, { key = "SHAMAN", label = "Shaman" },
    { key = "MAGE", label = "Mage" }, { key = "WARLOCK", label = "Warlock" },
    { key = "DRUID", label = "Druid" },
}
-- A client's own classes (retail's Retail/Core/Palette.lua), each after the
-- one it names, so the style editor lists them in the game's order.
for _, extra in ipairs(ns.contributions("classes")) do
    for _, class in ipairs(extra) do
        util.insertAfter(palette.CLASSES, class.after, { key = class.key, label = class.label }, "class")
    end
end

-- subClass is the game's Enum.ItemArmorSubclass, the same in every language.
palette.ARMOR = {
    { key = "Cloth", label = "Cloth", subClass = 1, color = { .90, .70, .78 } },
    { key = "Leather", label = "Leather", subClass = 2, color = { .78, .58, .35 } },
    { key = "Mail", label = "Mail", subClass = 3, color = { .37, .75, .68 } },
    { key = "Plate", label = "Plate", subClass = 4, color = { .68, .73, .80 } },
}
local ARMOR = {}
for _, armor in ipairs(palette.ARMOR) do ARMOR[armor.key] = armor end

local function customColor(key)
    local color = ns.option and ns.option(key)
    if type(color) ~= "table" then return end
    for index = 1, 3 do
        if type(color[index]) ~= "number" or not (color[index] >= 0 and color[index] <= 1) then return end
    end
    return color
end

-- Read settings when drawing; saved variables and picker changes arrive
-- after these files load. Shared defaults are never changed by a picker.
function palette.school(name)
    local default = name and palette.schools[name]
    if default then return customColor("schoolColor" .. name) or default end
end

function palette.armorColor(key)
    local armor = key and ARMOR[key]
    if armor then return customColor("armorColor" .. key) or armor.color end
end

-- A school's name on this client, as a badge shows it: the game's for each of
-- the six, the addon's own for a blend of two.
function palette.schoolName(school)
    local names = { Holy = DAMAGE_SCHOOL2, Fire = DAMAGE_SCHOOL3, Nature = DAMAGE_SCHOOL4, Frost = DAMAGE_SCHOOL5,
        Shadow = DAMAGE_SCHOOL6, Arcane = DAMAGE_SCHOOL7 }
    return names[school] or ns.L[school]
end

function palette.schoolStatColors(name)
    local color = palette.school(name)
    if not color then return end
    local school = SCHOOL[name]
    if color == school.color and school.statValue then return school.statValue, school.statName end
    local shade = {}
    for index = 1, 3 do shade[index] = color[index] + (1 - color[index]) * .45 end
    return util.hex(color), util.hex(shade)
end

-- A class-color addon's colors come first, then the editor's, then the game's.
function palette.classColor(classFile, game)
    if type(classFile) ~= "string" then return end
    game = game or ns.Game
    local color = game and game.customClassColor and game.customClassColor(classFile)
    if color then return color end
    color = customColor("classColor" .. classFile)
    if color then return color end
    if game and game.classColor then return game.classColor(classFile) end
end

-- Whether a class-color addon sets the class colors, over the editor's.
function palette.addonClassColors(game)
    game = game or ns.Game
    return game and game.customClassColor and game.customClassColor("WARRIOR") ~= nil or false
end

-- Left to right.
local DUAL_SCHOOLS = { Frostfire = { "Frost", "Fire" }, Holyfire = { "Holy", "Fire" } }

function palette.gradient(school)
    local parts = school and DUAL_SCHOOLS[school]
    if parts then return { palette.school(parts[1]), palette.school(parts[2]) } end
end

-- Gathering's skill-up colors, by how far the player's skill is past what a
-- node or corpse needs: red below it, then orange, yellow, green, and grey.
local SKILL_UP = { { 25, { 1, .50, .25 } }, { 50, { 1, 1, 0 } }, { 100, { .25, .75, .25 } } }
local TRIVIAL = { .50, .50, .50 }

function palette.skillUpColor(level, player)
    if type(level) ~= "number" or type(player) ~= "number" then return end
    if player < level then return palette.roles.unmet end
    for _, step in ipairs(SKILL_UP) do
        if player < level + step[1] then return step[2] end
    end
    return TRIVIAL
end

-- A letter, as Lua's %a knows only ASCII ones: any byte of a UTF-8 character
-- counts.
local function isLetter(char)
    return char ~= "" and char:match("[%a\128-\255]") ~= nil
end

-- Where a phrase first stands in the text as words of their own: "fire
-- damage" in "40 fire damage", not in "wildfire damage". A language without
-- spaces between words opts out of the boundary check.
local function wordsAt(text, phrase)
    local position = 1
    while true do
        local start, stop = text:find(phrase, position, true)
        if not start then return end
        if ns.Locale.schoolBoundaries == false
            or (not isLetter(text:sub(start - 1, start - 1)) and not isLetter(text:sub(stop + 1, stop + 1))) then
            return start
        end
        position = start + 1
    end
end

-- The school a text names first in one of the phrases, filled with the
-- language's word for each school (ns.Locale.schoolWords): "%s damage" finds
-- Fire in "40 Fire damage". Only those in only count, when given.
-- French descriptions write "d’ombre" about as often as "d'ombre".
local function straightQuotes(text)
    return (util.lower(text):gsub("\226\128\153", "'"))
end

function palette.schoolIn(text, phrases, only)
    local plain = straightQuotes(util.plainText(text))
    local found, at, length
    for school, words in pairs(ns.Locale.schoolWords) do
        if not only or only[school] then
            for _, word in ipairs(type(words) == "table" and words or { words }) do
                for _, phrase in ipairs(phrases) do
                    phrase = straightQuotes(util.fill(phrase, word))
                    local start = wordsAt(plain, phrase)
                    -- Where two start together, the longer names a blend: Holyfire's
                    -- French name begins with Fire's.
                    if start and (not at or start < at or (start == at and #phrase > length)) then
                        found, at, length = school, start, #phrase
                    end
                end
            end
        end
    end
    return found
end

-- A class spell's school comes from Data/Schools.lua, by its ID or name. Otherwise
-- the text must name damage or spells, as "40 Fire damage" or "your Fire
-- spells", so "Fire Elementals" and "Rapid Fire" cannot change the color.
-- Spell names may supply a leading school instead.
function palette.detectSchool(description, name, spellID)
    local known = ns.spellSchool and ns.spellSchool(name, spellID)
    if known then return known end
    for _, text in ipairs(description) do
        local found = palette.schoolIn(text, ns.Locale.descriptions.school)
        if found then return found end
    end
    local lower = name and util.lower(name) or ""
    local leading, length
    for school, words in pairs(ns.Locale.schoolWords) do
        for _, word in ipairs(type(words) == "table" and words or { words }) do
            word = util.lower(word)
            if lower:sub(1, #word) == word
                and (ns.Locale.schoolBoundaries == false or not isLetter(lower:sub(#word + 1, #word + 1)))
                and (not length or #word > length) then
                leading, length = school, #word
            end
        end
    end
    return leading
end

-- The lighter description tint shared by spells, auras, and weapon procs.
function palette.numberCode(color)
    return color and util.hex({ color[1] * .7 + .3, color[2] * .7 + .3, color[3] * .7 + .3 }) or "FFF6E4"
end
