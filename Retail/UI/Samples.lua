-- Retail's parts in the style editor's samples: the weapon's source, upgrade
-- level, crafted quality, transmogrification, sockets, and secondary stats; a
-- spell with charges; and the player's specialization. UI/Samples.lua adds
-- them to its own (ns.contribute "samples").
local _, ns = ...
local L, fill = ns.L, ns.util.fill
local samples = {}
ns.Retail.Samples = samples

local function find(list, field, value)
    for _, entry in ipairs(list) do
        if entry[field] == value then return entry end
    end
end

-- types: UI/Samples.lua's, in its form; helpers: its statLine, itemName, and spellName.
function samples.extend(types, helpers)
    local statLine, itemName, spellName = helpers.statLine, helpers.itemName, helpers.spellName
    local items, spells, units = find(types, "key", "item"), find(types, "key", "spell"), find(types, "key", "unit")

    local weapon = find(items.samples, "label", "Weapon").fields
    -- Retail's source, upgrade level, and transmogrification.
    weapon.retail = ns.Retail.Item.newFields({
        source = ITEM_HEROIC,
        upgrade = fill(ITEM_UPGRADE_DROPDOWN_LEVEL_FORMAT_STRING, L["Myth"], 2, 6),
        transmog = itemName(7717, "Ravager"),
        craftingQuality = fill(PROFESSIONS_CRAFTING_QUALITY, "|A:Professions-ChatIcon-Quality-Tier5:17:17|a"),
    })
    -- Retail's sockets: a gem, an empty socket, and the bonus once both are filled.
    weapon.sockets = {
        { left = ns.Stats.styleStat(statLine("HASTE", 70), true, false), right = "",
            icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02" },
        { left = EMPTY_SOCKET_PRISMATIC, right = "", color = { .5, .5, .5 },
            icon = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic" },
        { left = fill(ITEM_SOCKET_BONUS, statLine("STAMINA", 8)), right = "", color = { .5, .5, .5 } },
    }
    -- Retail's secondary stats, each in its color.
    weapon.secondary = { statLine("CRITICAL_STRIKE", 48), statLine("HASTE", 31), statLine("MASTERY", 27),
        statLine("VERSATILITY", 19) }

    -- A spell with charges: its most, the time each takes to come back, and
    -- the time left on the next.
    spells.samples[#spells.samples + 1] = {
        label = "Charges",
        fields = {
            name = spellName(108853, "Fire Blast"), icon = { spell = 108853 },
            cost = { "1%", L["Base Mana"] }, power = "Mana", cast = { SPELL_CAST_TIME_INSTANT, L["Cast"] },
            cooldown = { fill(SPELL_DURATION_SEC, 12), L["Recharge"] }, range = { fill(L["%s yd"], 40), L["Range"] },
            charges = ns.util.resolvePlurals(fill(SPELL_MAX_CHARGES, 2)),
            details = { { left = ns.util.resolvePlurals(fill(SPELL_RECHARGE_TIME_SEC, 5)), right = "",
                color = { 1, .60, .25 } } },
            description = { L["Blasts the enemy for 950 Fire damage."] },
        },
    }

    -- Retail names a player's specialization too: Arms, the warrior's first.
    find(units.samples, "label", "Player").fields.spec = (ns.Game.classSpecs(1) or {})[1]
end

ns.contribute("samples", samples.extend)
