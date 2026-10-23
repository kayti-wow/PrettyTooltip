-- Cloth, leather, mail, and plate lead the subtitle in their colors while the
-- setting is on. A type the game shows red, as one the player cannot wear,
-- stays red, and a cloak's cloth is not colored.
return function(test)
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" }
    local WHITE, RED = { r = 1, g = 1, b = 1 }, { r = 1, g = .13, b = .13 }

    -- answer is GetItemInfoInstant's: class name, subclass name, slot, class, subclass.
    local function item(slot, kind, answer, color)
        local capture = {
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, EquipSlot = 2 } },
            calls = { ["C_Item.GetItemInfoInstant"] = { ["2000"] = { n = 7, 2000, answer[1], answer[2], answer[3], 0,
                answer[4], answer[5] } } },
            data = { type = 0, id = 2000, quality = 2, lines = {
                { type = 1, lineIndex = 1, leftText = "Test Piece" },
                { type = 2, lineIndex = 2, leftText = slot, rightText = kind, rightColor = color or WHITE },
            } },
            lines = { { left = { text = "Test Piece" } }, { left = { text = slot }, right = { text = kind } } },
        }
        local ns, world = test.load(FILES, capture)
        return ns.TooltipTypes[0].read(world.main, capture.data, ns.Game), ns
    end
    -- The drawn line holding the word.
    local function drawn(ns, model, word)
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, 0)
        for _, font in ipairs(panel.pool) do
            local text = font:IsShown() and font:GetText() or ""
            if ns.util.uncolored(text):find(word, 1, true) then return text end
        end
    end

    local plate, ns = item("Chest", "Plate", { "Armor", "Plate", "INVTYPE_CHEST", 4, 4 })
    test.check("plate is read from its subclass", plate.armorClass, "Plate")
    test.check("off by default, the subtitle keeps the quality color", drawn(ns, plate, "Chest"),
        "Plate \194\183 Chest")
    ns.setOption("armorColors", true)
    test.check("on, the type takes its color", drawn(ns, plate, "Chest"), "|cffADBACCPlate|r \194\183 Chest")
    ns.setOption("armorColorPlate", { 1, 0, 0 })
    test.check("the editor's color replaces the default", drawn(ns, plate, "Chest"),
        "|cffFF0000Plate|r \194\183 Chest")
    ns.setOption("armorColorPlate", { 1, "invalid", 0 })
    test.check("a malformed color falls back to the default", drawn(ns, plate, "Chest"),
        "|cffADBACCPlate|r \194\183 Chest")
    ns.resetStyles()
    test.check("reset fonts and colors clears armor colors", ns.savedOption("armorColorPlate"), nil)
    test.check("and keeps the setting", ns.option("armorColors"), true)
    -- A recipe's crafted item shows its type in its own subtitle.
    local recipe = ns.ui.itemModel({ name = "Plans: Test Gloves", quality = 2, slot = "Plans \194\183 Blacksmithing",
        created = ns.ui.itemModel({ name = "Test Gloves", quality = 2, slot = "Mail \194\183 Hands",
            armorClass = "Mail" }) })
    test.check("a crafted item's type takes its color", drawn(ns, recipe, "Hands"), "|cff5EBFADMail|r \194\183 Hands")
    recipe.created.levelRequirement = { text = "Requires Level 15", met = false }
    test.check("a level the player lacks keeps the crafted item's whole line red", drawn(ns, recipe, "Hands"),
        "Mail \194\183 Hands \194\183 Requires Level 15")

    local unwearable, redNs = item("Chest", "Plate", { "Armor", "Plate", "INVTYPE_CHEST", 4, 4 }, RED)
    redNs.setOption("armorColors", true)
    test.check("a type shown red has no armor color", unwearable.armorClass, nil)
    test.check("and is drawn red", drawn(redNs, unwearable, "Chest"), "|cffFF5747Plate|r \194\183 Chest")

    test.check("a cloak's cloth is not colored",
        (item("Back", "Cloth", { "Armor", "Cloth", "INVTYPE_CLOAK", 4, 1 })).armorClass, nil)
    test.check("nor a shield",
        (item("Off Hand", "Shield", { "Armor", "Shields", "INVTYPE_SHIELD", 4, 6 })).armorClass, nil)
    test.check("nor a weapon",
        (item("Two-Hand", "Mace", { "Weapon", "Two-Handed Maces", "INVTYPE_2HWEAPON", 2, 5 })).armorClass, nil)
    test.check("leather is read from its subclass",
        (item("Feet", "Leather", { "Armor", "Leather", "INVTYPE_FEET", 4, 2 })).armorClass, "Leather")
end
