-- Each herb and ore node's yield and the skill level it needs, as
-- { item ID, level }, by its English name. No API links a node to what it
-- yields or the skill it needs. Item IDs are checked against the item's name,
-- so a wrong entry is skipped, not shown. Classic's levels.
-- Forever only: retail's .toc leaves this file out.
local _, ns = ...
ns.provideData("nodeSkills")

ns.nodeSkills = {
    ["Peacebloom"] = { 2447, 1 }, ["Silverleaf"] = { 765, 1 }, ["Earthroot"] = { 2449, 15 },
    ["Mageroyal"] = { 785, 50 }, ["Briarthorn"] = { 2450, 70 }, ["Stranglekelp"] = { 3820, 85 },
    ["Bruiseweed"] = { 2453, 100 }, ["Wild Steelbloom"] = { 3355, 115 },
    ["Grave Moss"] = { 3369, 120 }, ["Kingsblood"] = { 3356, 125 }, ["Liferoot"] = { 3357, 150 },
    ["Fadeleaf"] = { 3818, 160 }, ["Goldthorn"] = { 3821, 170 },
    ["Khadgar's Whisker"] = { 3358, 185 }, ["Wintersbite"] = { 3819, 195 },
    ["Firebloom"] = { 4625, 205 }, ["Purple Lotus"] = { 8831, 210 },
    ["Arthas' Tears"] = { 8836, 220 }, ["Sungrass"] = { 8838, 230 }, ["Blindweed"] = { 8839, 235 },
    ["Ghost Mushroom"] = { 8845, 245 }, ["Gromsblood"] = { 8846, 250 },
    ["Golden Sansam"] = { 13464, 260 }, ["Dreamfoil"] = { 13463, 270 },
    ["Mountain Silversage"] = { 13465, 280 }, ["Plaguebloom"] = { 13466, 285 },
    ["Icecap"] = { 13467, 290 }, ["Black Lotus"] = { 13468, 300 },
    ["Copper Vein"] = { 2770, 1 }, ["Tin Vein"] = { 2771, 65 },
    ["Incendicite Mineral Vein"] = { 3340, 65 }, ["Silver Vein"] = { 2775, 75 },
    ["Lesser Bloodstone Deposit"] = { 4278, 75 }, ["Iron Deposit"] = { 2772, 125 },
    ["Indurium Mineral Vein"] = { 5833, 150 }, ["Gold Vein"] = { 2776, 155 },
    ["Mithril Deposit"] = { 3858, 175 }, ["Truesilver Deposit"] = { 7911, 230 },
    ["Dark Iron Deposit"] = { 11370, 230 }, ["Small Thorium Vein"] = { 10620, 245 },
    ["Rich Thorium Vein"] = { 10620, 275 },
}
