-- Retail has four classes Forever lacks. The style editor offers a color for
-- each, in the game's order, over two lines of swatches where one is too
-- narrow for thirteen; Forever keeps its nine on one line.
return function(test)
    local function files(retail)
        local list = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
            "Panel/Render.lua", "Tooltips/Item.lua", "Tooltips/Unit.lua", "UI/Samples.lua", "UI/EditorSkin.lua",
            "UI/Editor.lua" }
        if retail then list = test.retail(list) end
        return list
    end
    local capture = { enums = { TooltipDataType = { Item = 0, Unit = 2 } } }

    local function classSwatches(world, ns)
        for _, object in ipairs(world.objects) do
            local children = object.GetChildren and { object:GetChildren() } or {}
            if #children == #ns.Palette.CLASSES and object.extraHeight ~= nil then
                local lines = {}
                for _, child in ipairs(children) do
                    local _, _, _, _, y = child:GetPoint(1)
                    lines[y] = true
                end
                local count = 0
                for _ in pairs(lines) do count = count + 1 end
                return { lines = count, extraHeight = object.extraHeight }
            end
        end
    end

    local ns, world = test.load(files(true), capture)
    local keys = {}
    for _, class in ipairs(ns.Palette.CLASSES) do keys[#keys + 1] = class.key end
    test.check("retail's classes in the game's order", keys, { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
        "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" })
    ns.setOption("classColorEVOKER", { 0, 1, 0 })
    test.check("a retail class takes the color the editor sets", ns.Palette.classColor("EVOKER"), { 0, 1, 0 })
    test.check("the editor's class swatches, over two lines", classSwatches(world, ns), { lines = 2, extraHeight = 28 })

    ns, world = test.load(files(false), capture)
    test.check("Forever keeps its nine", #ns.Palette.CLASSES, 9)
    test.check("on one line", classSwatches(world, ns), { lines = 1, extraHeight = 0 })
end
