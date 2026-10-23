-- What the addon asks retail's game alone: a spell's mana cost, the global
-- cooldown after haste, and a class's specializations. Retail/Game/GameExtension.lua,
-- loaded just after Game/Game.lua, puts them in place of Forever's answers.
local _, ns = ...
local util = ns.util
local isSecret, readable, call, number = util.isSecret, util.readable, util.call, util.number
local game = {}
ns.Retail.Game = game

-- The mana a spell costs the player, worked out by the game: retail's
-- tooltips give a share of base mana, which is fixed by level.
function game.spellManaCost(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellPowerCost or GetSpellPowerCost
    if not getter then return end
    local ok, costs = pcall(getter, spellID)
    if not ok or isSecret(costs) or type(costs) ~= "table" then return end
    for _, cost in ipairs(costs) do
        if not isSecret(cost) and type(cost) == "table" and readable(cost.type) == 0 then
            return number(cost.cost)
        end
    end
end

-- Retail's global cooldown shrinks with haste, to 0.75 sec at the least; an
-- energy user's (a rogue, a druid in cat form, a Brewmaster or Windwalker) is
-- 1 sec and does not.
function game.globalCooldown()
    local _, power = call(UnitPowerType, "player")
    if readable(power) == "ENERGY" then return 1 end
    local haste = number((call(UnitSpellHaste, "player"))) or 0
    return math.max(.75, 1.5 / (1 + haste / 100))
end

-- The names of a class's specializations, by class ID; nil where the client has none.
function game.classSpecs(classID)
    if isSecret(classID) or type(classID) ~= "number" or not GetSpecializationInfoForClassID then return end
    local specs = C_SpecializationInfo or {}
    local count = number((call(specs.GetNumSpecializationsForClassID or GetNumSpecializationsForClassID, classID)))
    if not count or count < 1 then return end
    local names = {}
    for index = 1, count do
        local _, name = call(GetSpecializationInfoForClassID, classID, index)
        if not isSecret(name) and type(name) == "string" and name ~= "" then names[#names + 1] = name end
    end
    return #names > 0 and names or nil
end
