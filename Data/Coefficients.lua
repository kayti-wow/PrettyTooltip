-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. Each class spell rank's
-- comes from Data/SpellRanks.lua, the Forever client's data; any other spell's
-- is estimated from Classic's rules (cast time / 3.5, duration / 15), which
-- Forever follows without Classic's cap on spells over time or its penalty
-- for spells learned before level 20. Forever's tooltips already count spell
-- power in, so the base is what is left without it.
-- Forever only: retail's .toc leaves this file out.
local _, ns = ...
ns.provideData("coefficients")

local util = ns.util
local L = ns.L

-- Between a row's coefficient and its split, dim, as between badges.
local SEPARATOR = " |cff" .. util.hex(ns.Palette.roles.caption) .. "\194\183|r "

-- As GetSpellBonusDamage numbers the schools.
local SCHOOLS = { Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }

local amounts = ns.SpellAmounts
local words = ns.Locale.descriptions
local readAmounts, isInstant, isChanneled, castTime = amounts.readAmounts, amounts.isInstant, amounts.isChanneled,
    amounts.castTime
local decimal, heals, rateRows = amounts.decimal, amounts.heals, amounts.rateRows

-- For the rules: instant casts count as 1.5 sec; casts beyond 3.5 sec gain no
-- more. The tooltip shows the cast after talents and haste, so a spell the
-- rules estimate can be off by those.
local function castSeconds(cast)
    if isInstant(cast) then return 1.5 end
    local seconds = castTime(cast)
    return seconds and math.min(3.5, math.max(1.5, seconds))
end

local function playerPower(game, school, healing)
    if healing then return game.spellHealing() end
    return game.spellDamage(SCHOOLS[school])
end

local function range(low, high)
    if low == high then return tostring(low) end
    return util.fill(L["%s to %s"], low, high)
end

-- Each rank's spell ID in rank order, by the spell's name on this client;
-- the names are asked for at the first use.
local byName
local function ranksNamed(name)
    if not byName then
        byName = {}
        for english, ranks in pairs(ns.spellRankByName or {}) do
            byName[ns.Game.localSpellName(ranks[1], english)] = ranks
        end
    end
    return name and byName[name]
end

-- Rows splitting a spell's amounts into base and spell power, or nil; and
-- the rows of its rates, or nil. part has the panel's name, cost,
-- cast, description, and spellID; part.spellPower, when set, stands in for
-- the player's, as on the editor's samples; else game answers it.
function ns.spellPowerRows(part, bonusCode, game)
    local text = util.uncolored(table.concat(part.description, " ")):gsub("\194\160", " "):gsub("\226\128\175", " ")
    local rank = ns.spellRanks and ns.spellRanks[part.spellID]
    local named = not rank and ranksNamed(part.name)
    if named then
        -- A spell named without an ID it has: the rank it names, else its top rank.
        local number = tonumber((part.rank or ""):match("(%d+)"))
        rank = ns.spellRanks[named[number] or named[#named]]
    end
    local school = ns.Palette.schoolIn(text, words.damageSchool or { words.school[1] }, SCHOOLS)
    -- Some translations name the school only in the spell's name (Chinese
    -- Arcane Missiles). A known scaling rank also has a school in our data.
    if rank and not rank.heals and not school then
        local known = ns.Palette.detectSchool(part.description, part.name, part.spellID)
        if SCHOOLS[known] then school = known end
    end
    -- The table holds every class spell that scales; another class spell, as
    -- Dampen Magic, gains nothing, however its text reads.
    if not rank and ns.spellSchool and ns.spellSchool(part.name, part.spellID) then return end
    -- Heals, healing, or healed; not health, as a totem's.
    local healing = (rank and rank.heals) or (not school and heals(text))
    if not (school or healing) then return end
    local direct, periodic = readAmounts(util.lower(text), rank)
    if not (direct or periodic) then return end

    local directShare, periodicShare
    if rank then
        directShare, periodicShare = rank[2], rank[3]
    else
        -- Channeled spells have no rule.
        if isChanneled(part.cast) then return end
        local cast = castSeconds(part.cast)
        if direct and periodic then
            -- Classic's split between what lands at once and over time.
            if cast then
                local castPart, timePart = cast / 3.5, periodic.duration / 15
                directShare = castPart * castPart / (castPart + timePart)
                periodicShare = timePart * timePart / (castPart + timePart)
            end
        else
            directShare = direct and cast and cast / 3.5
            periodicShare = periodic and periodic.duration / 15
        end
    end
    local estimate = not rank or rank.estimate

    local power = part.spellPower or playerPower(game, school, healing) or 0
    local rows = {}
    local function addRow(amount, share, label)
        if not (amount and share) then return end
        -- An amount per tick gains its share of the whole duration's bonus.
        local bonus = math.floor(power * share / (amount.ticks or 1) + 1e-6)
        -- The share in the school's color, as the bonus it brings, then the split.
        rows[#rows + 1] = {
            left = label,
            right = "|cff" .. bonusCode .. (estimate and "~" or "") .. decimal(share * 100, 1) .. "%" .. "|r"
                .. SEPARATOR .. range(math.max(0, amount.low - bonus), math.max(0, amount.high - bonus))
                .. " + |cff" .. bonusCode .. bonus .. "|r" .. (amount.ticks and " " .. L["each"] or ""),
        }
    end
    addRow(direct, directShare, healing and L["Healing Power Coefficient"] or L["Spell Power Coefficient"])
    addRow(periodic, periodicShare,
        healing and L["Healing Power Coefficient over time"] or L["Spell Power Coefficient over time"])
    if #rows > 0 then return rows, rateRows(part, direct, periodic, healing, game) end
end
