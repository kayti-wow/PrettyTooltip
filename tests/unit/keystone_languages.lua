-- A Mythic keystone sends no name line; its first line, "Keystone: %s", names
-- the dungeon. In each client language the panel reads the dungeon as the
-- name, "Keystone" as its kind, its levels under the name, its modifiers
-- under their heading, and its duration with the plural worded. Forever has
-- no keystones and reads none.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 22 }
    local LANGUAGE_FILES = { enUS = false, deDE = "deDE", frFR = "frFR", esES = "esES", esMX = "esMX",
        ptBR = "Portuguese", ruRU = "ruRU", koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW" }
    local locales = {}
    for locale in pairs(LANGUAGE_FILES) do locales[#locales + 1] = locale end
    table.sort(locales)
    local PURPLE, GOLD, WHITE, GREEN = { r = .64, g = .21, b = .93 }, { r = 1, g = .82, b = 0 },
        { r = 1, g = 1, b = 1 }, { r = 0, g = 1, b = 0 }

    local function read(locale, retail)
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = ITEM }, TooltipDataLineType = LINE },
            data = { type = ITEM, id = 180653, lines = {} }, lines = {} }
        local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
            "Panel/Render.lua", "Tooltips/Item.lua" }
        if retail then files = test.retail(files) end
        if LANGUAGE_FILES[locale] then
            local at
            for index, file in ipairs(files) do if file == "Locale/English.lua" then at = index end end
            table.insert(files, at + 1, "Locale/" .. LANGUAGE_FILES[locale] .. ".lua")
        end
        local ns, world = test.load(files, capture)
        -- The game's own wording in this language, read once it is loaded.
        local name = CHALLENGE_MODE_KEYSTONE_NAME:gsub("%%s", "Ruby Life Pools")
        local mythic = CHALLENGE_MODE_ITEM_POWER_LEVEL:gsub("%%d", "15")
        local resilient = RESILIENT_KEY_LEVEL:gsub("%%d", "14")
        local duration = ITEM_DURATION_DAYS:gsub("%%d", "7")
        local lines = { { name, PURPLE, 4 }, { mythic, GOLD }, { resilient, GOLD },
            { CHALLENGE_MODE_DUNGEON_MODIFIERS, WHITE }, { "  Tyrannical", GREEN }, { "  Fortified", GREEN },
            { duration, WHITE } }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = LINE.None, lineIndex = index, leftText = line[1],
                leftColor = line[2], quality = line[3] }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local model = ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game)
        return model, duration
    end

    for _, locale in ipairs(locales) do
        local model, duration = read(locale, true)
        local effects = {}
        for _, row in ipairs(model.effects) do effects[#effects + 1] = { row.left, row.indent or 0 } end
        test.check(locale .. ": the keystone read", {
            name = model.name, quality = model.quality, kind = model.slot ~= nil and model.slot ~= "",
            header = #model.header, effects = effects, extras = #model.extras,
            duration = model.footerLeft[1] and model.footerLeft[1].left,
        }, {
            name = "Ruby Life Pools", quality = 4, kind = true, header = 2,
            effects = { { CHALLENGE_MODE_DUNGEON_MODIFIERS, 0 },
                { "Tyrannical", 12 }, { "Fortified", 12 } },
            extras = 0, duration = duration:gsub("(%d+)(%s*)|4([^:;]*):([^;]*);", function(n, space, one, rest)
                local many = rest:match("([^:]*)$")
                return n .. space .. (n == "1" and one or many)
            end),
        })
    end

    local model = read("enUS", false)
    test.check("Forever reads no keystone", model == nil or model.name ~= "Ruby Life Pools", true)
end
