-- Registration waits for the addon's own event and uses saved settings.
return function(test)
    local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Integration/ItemLite.lua", "UI/Options.lua", "UI/Commands.lua", "PrettyTooltip.lua" }
    local fixture = { enums = { TooltipDataType = { Item = 0 } } }
    local ns, world = test.load(files, fixture)
    local before = #world.objects
    test.check("slash command waits for startup", SlashCmdList.PRETTYTOOLTIP, nil)
    test.check("slash aliases wait for startup", SLASH_PRETTYTOOLTIP1, nil)
    test.check("settings are available before startup", ns.option("itemPanels"), true)
    test.check("wording post-call waits for startup", world.postCalls[0], nil)

    local page, registered, opened
    local registrations = 0
    local category = { GetID = function() return 42 end }
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
            page = canvas
            test.check("category name", name, "PrettyTooltip")
            registrations = registrations + 1
            return category
        end,
        RegisterAddOnCategory = function(value) registered = value end,
        OpenToCategory = function(id) opened = id end,
    }
    world.fireEvent("ADDON_LOADED", "AnotherAddon")
    test.check("another addon's event does not register settings", registrations, 0)
    test.check("another addon's event does not create UI", #world.objects, before)
    test.check("another addon's event does not register commands", SlashCmdList.PRETTYTOOLTIP, nil)

    PrettyTooltipDB = { itemPanels = false, originalKey = "CTRL" }
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    test.check("startup installs no pre-call", world.preCalls[0], nil)
    test.check("startup installs wording post-call", #world.postCalls[0], 1)
    test.check("settings category registered", registered == category, true)
    test.check("settings page starts hidden", page:IsShown(), false)
    -- The first checkbox controls item panels; it must use the saved false.
    local firstCheckbox
    for _, child in ipairs(page._children) do
        if child._kind == "CheckButton" then firstCheckbox = child break end
    end
    test.check("controls use settings saved after file loading", firstCheckbox:GetChecked(), false)
    test.check("saved settings are retained", PrettyTooltipDB.originalKey, "CTRL")
    test.check("long slash alias", SLASH_PRETTYTOOLTIP1, "/prettytooltip")
    test.check("short slash alias", SLASH_PRETTYTOOLTIP2, "/ptip")

    local editorOpened = 0
    ns.openEditor = function() editorOpened = editorOpened + 1 end
    SlashCmdList.PRETTYTOOLTIP("")
    test.check("default command opens editor", editorOpened, 1)
    SlashCmdList.PRETTYTOOLTIP(" OPTIONS ")
    test.check("options command opens registered settings", opened, 42)
    local version = ns.settingsVersion
    page.OnDefault()
    test.check("settings page defaults refresh controls", firstCheckbox:GetChecked(), true)
    test.check("settings page defaults invalidate panels", ns.settingsVersion, version + 1)

    local after = #world.objects
    local handler = SlashCmdList.PRETTYTOOLTIP
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    ns.start()
    ns.Options.register()
    ns.Commands.register()
    ns.ItemLite.register()
    test.check("repeated startup does not recreate UI", #world.objects, after)
    test.check("repeated startup does not register another category", registrations, 1)
    test.check("repeated startup preserves command handler", SlashCmdList.PRETTYTOOLTIP == handler, true)
    test.check("repeated startup preserves wording post-call count", #world.postCalls[0], 1)
    local listeners = 0
    for _, object in ipairs(world.objects) do
        if object:IsEventRegistered("ADDON_LOADED") then listeners = listeners + 1 end
    end
    test.check("startup listener removed", listeners, 0)

    Settings = nil
    local legacyPage, legacyOpened
    InterfaceOptions_AddCategory = function(canvas) legacyPage = canvas end
    InterfaceOptionsFrame_OpenToCategory = function(canvas) legacyOpened = canvas end
    ns, world = test.load(files, fixture)
    test.check("legacy category also waits for startup", legacyPage, nil)
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    ns.openSettings()
    test.check("legacy settings opens registered page", legacyOpened == legacyPage and legacyPage ~= nil, true)
    InterfaceOptions_AddCategory, InterfaceOptionsFrame_OpenToCategory = nil, nil

    ns, world = test.load({ "Core/Util.lua", "UI/Options.lua" })
    listeners = 0
    for _, object in ipairs(world.objects) do
        if object:IsEventRegistered("ADDON_LOADED") then listeners = listeners + 1 end
    end
    test.check("options module alone installs no startup listener", listeners, 0)
    test.check("options module alone installs no command", SlashCmdList.PRETTYTOOLTIP, nil)

    ns, world = test.load({ "UI/Commands.lua" })
    test.check("commands alone create no settings page", ns.Options, nil)
    local dispatched = 0
    ns.openEditor = function() dispatched = dispatched + 1 end
    ns.Commands.register()
    SlashCmdList.PRETTYTOOLTIP("")
    test.check("commands dispatch without settings-page implementation", dispatched, 1)

    -- Pretty reads original data and does not run native item wording.
    local item = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 22 } },
        data = { type = 0, lines = {
            { type = 22, lineIndex = 1, leftText = "Test Item" },
            { type = 0, lineIndex = 2, leftText = "+6 Intellect" },
        } },
        lines = { { left = { text = "Test Item" } }, { left = { text = "+6 Intellect" } } },
    }
    local integrated = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Tooltips/Item.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua",
        "Integration/Details.lua", "Integration/ItemLite.lua", "Integration/Cursor.lua", "UI/Options.lua",
        "UI/Commands.lua", "PrettyTooltip.lua" }
    ns, world = test.load(integrated, item)
    test.check("item integration post-calls wait for startup", world.postCalls[0], nil)
    PrettyTooltipDB = {}
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    test.check("startup installs one post-call for items", #world.postCalls[0], 1)
    test.check("which runs wording, panel, details, and cursor in order", ns.Processor.stages(0),
        { "wording", "panel", "details", "cursor" })
    test.check("and no pre-call that would change the game's data", world.preCalls[0], nil)
    local observed
    local read = ns.TooltipTypes[0].read
    ns.TooltipTypes[0].read = function(tooltip, data, game)
        observed = tooltip:GetLeftLine(2):GetText()
        return read(tooltip, data, game)
    end
    local cursorSeesPanel
    local shownPanel = ns.ui.shownPanel
    ns.ui.shownPanel = function(tooltip)
        local panel = shownPanel(tooltip)
        if cursorSeesPanel == nil then cursorSeesPanel = panel ~= nil end
        return panel
    end
    ns.setOption("cursorItems", true)
    GameTooltip_SetDefaultAnchor(world.main, UIParent)
    world.main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    for _, callback in ipairs(world.postCalls[0]) do callback(world.main, item.data) end
    test.check("panel sees the original native text", observed, "+6 Intellect")
    test.check("the game's data keeps its wording", item.data.lines[2].leftText, "+6 Intellect")
    test.check("cursor sees the fitted panel", cursorSeesPanel, true)
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("modifier restores original wording", world.main:GetLeftLine(2):GetText(), "+6 Intellect")
    test.check("modifier hides the custom panel", shownPanel(world.main), nil)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("modifier release keeps native wording original", world.main:GetLeftLine(2):GetText(), "+6 Intellect")
    test.check("modifier release restores custom panel", shownPanel(world.main) ~= nil, true)
    local count = #world.objects
    ns.start()
    ns.ItemLite.register()
    ns.Hooks.install()
    ns.Cursor.register()
    test.check("repeated installation creates no frames", #world.objects, count)
    test.check("repeated installation creates no post-calls", #world.postCalls[0], 1)
    test.check("or stages", #ns.Processor.stages(0), 4)

    local rewriteFiles = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Game/Game.lua", "Integration/ItemLite.lua" }
    ns, world = test.load(rewriteFiles, { client = { locale = "ruRU" }, enums = fixture.enums })
    ns.ItemLite.register()
    test.check("unsupported locale installs no wording", next(world.postCalls), nil)
    ns, world = test.load(rewriteFiles, fixture)
    TooltipDataProcessor.AddTooltipPostCall = nil
    ns.ItemLite.register()
    test.check("missing API installs no partial wording", next(world.postCalls), nil)
end
