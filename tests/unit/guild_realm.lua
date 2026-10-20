-- A guild from another realm reads "Guild-Realm"; the realm is a part of its
-- own beside the guild, styled apart and turned off on its own.
return function(test)
    local ns = test.load(test.tocs.retail,
        { enums = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { None = 0 } } })

    local function player(fields)
        local model = { name = "Zul'jin", isPlayer = true, level = 80, race = "Troll", className = "Shaman",
            classFile = "SHAMAN", classID = 7, guild = "Dawnbreakers", extras = {} }
        for key, value in pairs(fields) do model[key] = value end
        return ns.ui.unitModel(model)
    end
    local function lefts(model)
        local list = {}
        for _, row in ipairs(model.extras) do list[#list + 1] = row.left end
        return list
    end
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function shown(model)
        local list = {}
        for _, font in ipairs(ns.ui.renderPreview(anchor, model, 2).pool) do
            if font._shown and font._text then list[#list + 1] = ns.util.plainText(font._text) end
        end
        return list
    end
    local function has(list, text)
        for _, value in ipairs(list) do if value == text then return true end end
        return false
    end

    local model = player({ extras = { { left = "Dawnbreakers-Argent Dawn", right = "" },
        { left = "Item Level 650", right = "" } } })
    test.check("the realm is read from the guild line", model.guildRealm, "Argent Dawn")
    test.check("and the line goes", lefts(model), { "Item Level 650" })
    local texts = shown(model)
    test.check("the guild shows on its own", has(texts, "<Dawnbreakers>"), true)
    test.check("the realm shows as its own part", has(texts, "Argent Dawn"), true)

    test.check("a bracketed guild line", player({ tag = "<Dawnbreakers-Argent Dawn>" }).guildRealm, "Argent Dawn")
    test.check("a realm after the brackets",
        player({ extras = { { left = "<Dawnbreakers>-Azjol-Nerub", right = "" } } }).guildRealm, "Azjol-Nerub")
    test.check("a colored guild line",
        player({ extras = { { left = "|cff40ff40Dawnbreakers-Argent Dawn|r", right = "" } } }).guildRealm,
        "Argent Dawn")

    model = player({ extras = { { left = "Dawnbreakers", right = "" } } })
    test.check("a guild of the same realm has none", model.guildRealm, nil)
    test.check("its line still goes", #model.extras, 0)

    model = player({ guild = "Other", extras = { { left = "Dawnbreakers-Argent Dawn", right = "" } } })
    test.check("another guild's line is left alone", lefts(model), { "Dawnbreakers-Argent Dawn" })

    ns.setOption("unitRealm", false)
    model = player({ extras = { { left = "Dawnbreakers-Argent Dawn", right = "" } } })
    texts = shown(model)
    test.check("turned off, the line still goes", #model.extras, 0)
    test.check("and the realm is not shown", has(texts, "Argent Dawn"), false)
    test.check("but the guild is", has(texts, "<Dawnbreakers>"), true)
    ns.setOption("unitRealm", nil)

    test.check("the realm has its own style", ns.ui.styleOf("unitRealm").size, 11)
end
