-- These preview titles must stay localized even with an empty client cache.
-- Localized gathering titles must still resolve to the same node data.
return function(test)
    local locales = {
        { "enUS" }, { "deDE", "deDE" }, { "esES", "esES" }, { "esMX", "esMX" },
        { "frFR", "frFR" }, { "koKR", "koKR" }, { "ptBR", "Portuguese" },
        { "ptPT", "Portuguese" }, { "ruRU", "ruRU" }, { "zhCN", "zhCN" }, { "zhTW", "zhTW" },
    }
    for _, client in ipairs(locales) do
        local locale, language = client[1], client[2]
        local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua" }
        if language then files[#files + 1] = "Locale/" .. language .. ".lua" end
        for _, file in ipairs({ "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Data/Nodes.lua",
            "Data/NodeNames.lua", "Data/NodeSkills.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua",
            "Tooltips/Quest.lua", "UI/Samples.lua" }) do files[#files + 1] = file end
        local ns = test.load(files, { client = { locale = locale },
            enums = { TooltipDataType = { Object = 33, Quest = 23 } } })
        local types = {}
        for _, sampleType in ipairs(ns.editorSampleTypes()) do types[sampleType.key] = sampleType.samples end
        for index, key in ipairs({ "Bruiseweed", "Mithril Deposit" }) do
            local model = types.object[index].build()
            if language then
                test.check(locale .. ": explicit translation for " .. key,
                    type(rawget(ns.L, key)) == "string" and rawget(ns.L, key) ~= key, true)
            end
            test.check(locale .. ": localized gathering title " .. key, model.name, ns.L[key])
            test.check(locale .. ": localized title retains node lookup " .. key,
                ns.objectYield(model.name), index == 1 and 2453 or 3858)
        end
        local keys = { "The Fury Runs Deep", "Wolves Across the Border", "Arugal Must Die" }
        local ids = { 378, 33, 1014 }
        C_QuestLog = nil
        for index, key in ipairs(keys) do
            if language then
                test.check(locale .. ": explicit translation for " .. key,
                    type(rawget(ns.L, key)) == "string" and rawget(ns.L, key) ~= key, true)
            end
            test.check(locale .. ": no-API quest title " .. key, types.quest[index].build().name, ns.L[key])
        end
        local requests, titles = {}, {}
        C_QuestLog = {
            GetTitleForQuestID = function(id) return titles[id] end,
            RequestLoadQuestByID = function(id) requests[#requests + 1] = id end,
        }
        for index, key in ipairs(keys) do
            test.check(locale .. ": uncached quest title " .. key, types.quest[index].build().name, ns.L[key])
        end
        test.check(locale .. ": requests all three quest titles by ID", requests, ids)
        for index, key in ipairs(keys) do
            titles[ids[index]] = locale .. " client: " .. ns.L[key]
            test.check(locale .. ": native title overrides fallback " .. key,
                types.quest[index].build().name, titles[ids[index]])
        end
    end
end
