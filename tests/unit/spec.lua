-- Retail's player tooltips name the specialization with the class, as
-- "Restoration Shaman"; the panel's info line takes it: "Level 80 Troll
-- Restoration Shaman", and a line saying nothing more goes.
return function(test)
    local ns = test.load(test.tocs.retail,
        { enums = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { None = 0 } } })
    local SPECS = { [3] = { "Beast Mastery", "Marksmanship", "Survival" }, [7] = { "Elemental", "Enhancement", "Restoration" } }
    C_SpecializationInfo = { GetNumSpecializationsForClassID = function(classID) return #(SPECS[classID] or {}) end }
    GetSpecializationInfoForClassID = function(classID, index)
        local name = SPECS[classID] and SPECS[classID][index]
        if name then return classID * 100 + index, name end
    end

    local function shaman(fields)
        local model = { name = "Zul'jin", isPlayer = true, level = 80, race = "Troll", className = "Shaman",
            classFile = "SHAMAN", classID = 7, extras = {} }
        for key, value in pairs(fields) do model[key] = value end
        return ns.ui.unitModel(model)
    end
    local function lefts(model)
        local list = {}
        for _, row in ipairs(model.extras) do list[#list + 1] = row.left end
        return list
    end
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function infoLine(model)
        ns.setOption("unitLevelBadge", false)
        for _, font in ipairs(ns.ui.renderPreview(anchor, model, 2).pool) do
            local text = font._shown and font._text and ns.util.plainText(font._text)
            if text and text:find("^Level ") then return text end
        end
    end

    local model = shaman({ extras = { { left = "Restoration Shaman", right = "" }, { left = "Item Level 650", right = "" } } })
    test.check("the spec line names the spec", model.spec, "Restoration")
    test.check("and goes, as the info line shows it", lefts(model), { "Item Level 650" })
    test.check("the info line names the spec", infoLine(model), "Level 80 Troll Restoration Shaman")

    model = shaman({ levelLine = "Level 80 Troll Restoration Shaman (Player)" })
    test.check("a spec with the level and race", model.spec, "Restoration")

    model = shaman({ extras = { { left = "|cffffffffRestoration Shaman|r", right = "" } } })
    test.check("a colored spec line", model.spec, "Restoration")

    model = shaman({ extras = { { left = "Restoration Shaman Trainer", right = "" } } })
    test.check("a line saying more stays", lefts(model), { "Restoration Shaman Trainer" })

    model = shaman({ className = "Hunter", classFile = "HUNTER", classID = 3,
        extras = { { left = "Beast Mastery Hunter", right = "" } } })
    test.check("a spec of two words", model.spec, "Beast Mastery")

    model = shaman({ extras = { { left = "Shaman", right = "" } } })
    test.check("no spec line, no spec", model.spec, nil)
    test.check("the class line still goes", #model.extras, 0)
    test.check("and the info line is race and class", infoLine(model), "Level 80 Troll Shaman")

    -- Other languages can put the class first, and write in other scripts.
    SPECS[7] = { "Restauration" }
    model = shaman({ className = "Chaman", extras = { { left = "Chaman Restauration", right = "" } } })
    test.check("a spec after the class", { model.spec, #model.extras }, { "Restauration", 0 })
    test.check("keeps the client's order", infoLine(model), "Level 80 Troll Chaman Restauration")
    SPECS[7] = { "\208\152\209\129\209\134\208\181\208\187\208\181\208\189\208\184\208\181" }
    model = shaman({ className = "\208\168\208\176\208\188\208\176\208\189",
        extras = { { left = "\208\152\209\129\209\134\208\181\208\187\208\181\208\189\208\184\208\181 "
            .. "\208\168\208\176\208\188\208\176\208\189", right = "" } } })
    test.check("a spec in Cyrillic", #model.extras, 0)

    GetSpecializationInfoForClassID = nil
    model = shaman({ extras = { { left = "Restoration Shaman", right = "" } } })
    test.check("a client without specs leaves the line", model.spec, nil)
end
