-- Lite shortens selected lines and keeps native colors and other rows; with
-- stat colors on, magical stats and chance on hit effects keep theirs.
return function(test)
    local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua", "Locale/English.lua", "Data/Stats.lua", "Integration/ItemLite.lua" }
    local combined = "Equip: Increases healing done by up to 20 and damage done by up to 10 for all magical spells and effects."
    local original = { "Test Item", "+6 Intellect", combined,
        "Equip: Improves your chance to get a critical strike by 1%.", "Requires Level 60",
        "Chance on hit: Deals |cff33aaee40|r Fire damage.", "|cff33aaeeAddon information|r",
        "Equip: Increases your speed in a specific zone." }
    local shortened = { original[1], original[2], "+20 Healing Power|n+10 Spell Damage Power",
        "+1% Critical Strike Chance", original[5], original[6], original[7], original[8] }
    local colors = { { .6, .3, .9 }, { 1, 1, 1 }, { 0, 1, 0 }, { .5, .5, .5 },
        { 1, 0, 0 }, { 0, 1, 0 }, { .2, .4, .8 }, { 0, 1, 0 } }
    for _, enabled in ipairs({ true, false }) do
        local capture = { enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0 } },
            data = { type = 0, lines = {} }, lines = {} }
        for index, text in ipairs(original) do
            local color = colors[index]
            capture.data.lines[index] = { type = 0, lineIndex = index, leftText = text,
                leftColor = { r = color[1], g = color[2], b = color[3] } }
            capture.lines[index] = { left = { text = text, color = color } }
        end
        capture.data.lines[7].rightText = "Other detail"
        capture.data.lines[7].rightColor = { r = .8, g = .6, b = .2 }
        capture.lines[7].right = { text = "Other detail", color = { .8, .6, .2 } }
        local ns, world = test.load(files, capture)
        -- Magic is colored, base stats and crit are not.
        local expected = { unpack(shortened) }
        if enabled then
            local function colored(text) return select(2, ns.Stats.styleStat(text, true, false)) end
            expected[3] = colored("+20 Healing Power") .. "|n" .. colored("+10 Spell Damage Power")
            expected[6] = ns.Stats.styleEffect(original[6], true)
        end
        ns.setOption("itemLite", true)
        ns.setOption("statColors", enabled)
        ns.setOption("statMarkers", enabled)
        ns.ItemLite.register()
        local data = capture.data
        world.postCalls[0][1](world.main, data)
        for index, text in ipairs(expected) do
            test.check("lite wording " .. index .. " with colors " .. tostring(enabled), world.main:GetLeftLine(index):GetText(), text)
            test.check("native line color " .. index, { world.main:GetLeftLine(index):GetTextColor() },
                { colors[index][1], colors[index][2], colors[index][3], 1 })
            test.check("native data color " .. index, data.lines[index].leftColor,
                { r = colors[index][1], g = colors[index][2], b = colors[index][3] })
        end
        -- The game's data is left alone, so its tooltip code is not tainted.
        test.check("game data keeps its wording", data.lines[3].leftText, combined)
        test.check("game data gains no fields", data.lines[3].wrapText, nil)
        test.check("native row count", #data.lines, #original)
        test.check("right-hand text", world.main:GetRightLine(7):GetText(), "Other detail")
        test.check("right-hand color", { world.main:GetRightLine(7):GetTextColor() }, { .8, .6, .2, 1 })

        IsAltKeyDown = function() return true end
        world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
        test.check("ALT restores combined wording", world.main:GetLeftLine(3):GetText(), combined)
        IsAltKeyDown = function() return false end
        world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
        test.check("ALT release restores shortened wording", world.main:GetLeftLine(3):GetText(), expected[3])
        test.check("native color after modifier changes", { world.main:GetLeftLine(3):GetTextColor() }, { 0, 1, 0, 1 })
        ns.setOption("itemPanels", false)
        world.postCalls[0][1](world.main, data)
        test.check("disabled item restyling restores original", world.main:GetLeftLine(3):GetText(), combined)
    end
end
