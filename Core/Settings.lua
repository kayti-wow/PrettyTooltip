-- Shared settings and styles. Values are read at use time because saved
-- variables arrive after the files run; this file creates no UI or hooks.
local _, ns = ...
local colors = ns.Palette.roles

local DEFAULTS = {
    iconRight = false,
    -- "pretty" draws panels for the types turned on below; "blizzard" keeps
    -- the game's own tooltips everywhere.
    layout = "pretty",
    itemPanels = true,
    -- The game's own item tooltip shortens Equip effects, in its colors but for magic.
    liteWording = true,
    objectPanels = true,
    unitPanels = true,
    auraPanels = true,
    questPanels = true,
    macroPanels = true,
    petPanels = true,
    minimapPanels = true,
    taxiPanels = true,
    iconItems = true,
    iconSpells = true,
    iconObjects = true,
    iconUnits = true,
    iconAuras = true,
    iconQuests = false,
    iconMacros = true,
    cursorObjects = true,
    cursorDisableInCombat = true,
    statColors = true,
    qualityTint = true,
    statMarkers = true,
    -- A weapon's damage on the large line, its DPS and speed under it.
    swapDamage = false,
    itemLevelBadge = true,
    unitLevelBadge = true,
    -- A guild's realm beside its name, when it is another realm's.
    unitRealm = true,
    separators = true,
    spellPanels = true,
    disenchant = true,
    -- What herb and ore nodes and skinnable creatures give, on their panels.
    gatheringLoot = true,
    sellPrice = true,
    spellPower = true,
    -- Damage or healing per second and per mana, under the spell power breakdown.
    spellRates = true,
    -- The game's health bar at the bottom of unit panels.
    unitHealthBar = true,
    -- The item's, spell's, or NPC's ID under the other addons' rows.
    showIDs = true,
    -- "SHIFT" shows disenchant results, the spell power rows, gathering
    -- contents, and IDs only while it is held; "ALWAYS" shows them always.
    detailsKey = "SHIFT",
    -- Only takes effect while DialogueUI is installed.
    dialogueBackdrop = true,
    -- DialogueUI's brown paper for quests and quest items, when installed.
    questParchment = false,
    -- nil chooses: DialogueUI's art when installed, flat with EllesmereUI, else
    -- the game's own tooltip border. "native", "flat", or "dialogue" to pick one.
    backdropStyle = nil,
    -- The editor's frame treatment, independent of the tooltips it previews.
    editorStyle = "native",
    -- "ALT", "CTRL", or "NONE". Shift is the game's comparison key.
    originalKey = "ALT",
    bodyFont = nil,
    titleFont = nil,
    -- "NONE", "OUTLINE", or "THICKOUTLINE", for elements without their own.
    outline = "NONE",
    -- The panels' inner padding, and the width a panel is at least.
    -- Every part's text size is multiplied by this.
    fontScale = 1,
    tooltipScale = 1,
    padding = 19,
    minWidth = 260,
    headerTopAlpha = nil,
    headerBottomAlpha = nil,
}

function ns.option(key)
    local db = PrettyTooltipDB
    if type(db) == "table" and db[key] ~= nil then return db[key] end
    return DEFAULTS[key]
end

function ns.tooltipScale()
    local scale = ns.util.number(ns.option("tooltipScale"))
    if not scale or scale ~= scale then return 1 end
    return math.max(.5, math.min(1.5, scale))
end

-- Whether a type whose panel the setting `option` turns on draws it.
function ns.restyles(option)
    return ns.option("layout") ~= "blizzard" and ns.option(option) and true or false
end

function ns.editorStyle()
    if ns.option("editorStyle") == "flat" then
        return "flat"
    end
    return "native"
end

-- Counts setting changes, so a panel drawn before one is drawn again.
ns.settingsVersion = 0
local function changed() ns.settingsVersion = ns.settingsVersion + 1 end

-- What is saved for a setting: nil while it is at its default.
function ns.savedOption(key)
    local db = PrettyTooltipDB
    return type(db) == "table" and db[key] or nil
end

local function setOption(key, value)
    if type(PrettyTooltipDB) ~= "table" then PrettyTooltipDB = {} end
    PrettyTooltipDB[key] = value
    changed()
end
ns.setOption = setOption

-- 1.3's item lite mode was the game's item tooltip; it is now items not restyled.
function ns.migrateOptions()
    local db = PrettyTooltipDB
    if type(db) ~= "table" or db.itemLite == nil then return end
    if db.itemLite == true then db.itemPanels = false end
    db.itemLite = nil
end

function ns.resetOptions()
    PrettyTooltipDB = {}
    changed()
end

-- tooltipType: "item" (default), "spell", "object", "unit", "aura", "quest", "macro", or "shared" by all. color is where the picker starts
-- while the color is automatic. classic: drawn from Classic-only data, so not offered on retail. Retail's own
-- parts, marked retail, are in Retail/Core/Settings.lua.
ns.ELEMENTS = {
    { key = "title", label = "Item name", size = 19, title = true, color = { 1, 1, 1 },
        note = "Quality color unless set." },
    { key = "subtitle", label = "Type and slot", size = 13, color = { .9, .9, .9 },
        note = "Half the quality color, red for a type you cannot use." },
    { key = "header", label = "Binding and level", size = 12, color = { .78, .72, .63 },
        note = "The required level is red while you are below it." },
    { key = "dps", label = "Damage per second", size = 18, color = { .90, .93, .95 } },
    { key = "damage", label = "Damage and speed", size = 12, color = { .62, .65, .70 } },
    { key = "armor", label = "Armor", size = 16, color = { .90, .93, .95 } },
    { key = "stats", label = "Stats", size = 13, color = { .90, .85, .74 },
        note = "Colored by category unless set." },
    { key = "equipEffects", label = "Equip effects", size = 13, color = { .48, .88, .48 },
        note = "On-hit numbers use the spell tooltip's school colors unless set." },
    { key = "enchants", label = "Enchants", size = 13, color = { .30, .90, .30 } },
    { key = "effects", label = "Use and other effects", size = 13, color = { .48, .88, .48 } },
    { key = "flavor", label = "Flavor text", size = 12, color = colors.flavor },
    { key = "setName", label = "Set name and count", size = 15, title = true,
        color = { 1, .76, .18 } },
    { key = "setItems", label = "Set pieces", size = 12, color = { .94, .89, .77 },
        note = "Owned pieces bright, missing ones grey, unless set." },
    { key = "setBonuses", label = "Set bonuses", size = 12, color = { .48, .88, .48 },
        note = "Active bonuses green, inactive ones grey, unless set." },
    { key = "extras", label = "Other addons' rows", size = 11, color = colors.extras,
        tooltipType = "shared" },
    { key = "footer", label = "Footer", size = 11, color = colors.detail,
        note = "Durability, crafter, requirements, and sell price." },
    { key = "badge", label = "Item level badge", size = 10, color = { .9, .9, .9 } },
    { key = "createdName", label = "Crafted item's name", size = 14, title = true, color = { 1, 1, 1 },
        note = "On recipes; quality color unless set." },
    { key = "reagents", label = "Reagents", size = 12, color = { .90, .85, .74 },
        note = "On recipes; the count you carry red while short, unless set." },
    { key = "caption", label = "Section captions", size = 9, color = colors.caption, caps = true,
        note = "Creates and Reagents on recipes." },
    { key = "disenchant", label = "Disenchant results", size = 11, color = colors.detail, classic = true,
        note = "The Enchanting needed red while yours is too low, grey without Enchanting, unless set." },
    { key = "spellTitle", label = "Spell name", size = 17, title = true,
        color = colors.title, tooltipType = "spell" },
    { key = "spellBadges", label = "School and rank badges", size = 12, color = { .9, .9, .9 },
        tooltipType = "spell", note = "Colored by school unless set." },
    { key = "spellValues", label = "Cost, cast, cooldown, range", size = 13,
        color = { .96, .92, .84 }, tooltipType = "spell",
        note = "The cost takes its resource color unless set." },
    { key = "spellCaptions", label = "Strip captions", size = 9, color = colors.caption,
        tooltipType = "spell" },
    { key = "spellDetails", label = "Requirements and details", size = 11,
        color = colors.detail, tooltipType = "spell",
        note = "Unmet requirements red, time remaining orange, unless set." },
    { key = "spellText", label = "Description", size = 12, color = colors.description,
        tooltipType = "spell", note = "Numbers in the school color unless set." },
    { key = "objectTitle", label = "Object name", size = 17, title = true,
        color = colors.title, tooltipType = "object" },
    { key = "objectKind", label = "Kind of object", size = 12, color = { .9, .9, .9 },
        tooltipType = "object", note = "Tinted by the skill it needs, unless set." },
    { key = "objectDetails", label = "Skill and requirements", size = 12,
        color = colors.detail, tooltipType = "object",
        note = "The skill in its skill-up color, unmet requirements red, unless set." },
    { key = "objectQuests", label = "Quest lines", size = 12, color = colors.objective,
        tooltipType = "object", note = "Quest names gold, finished objectives green, unless set." },
    { key = "objectLoot", label = "Contents", size = 11, color = colors.detail, tooltipType = "object", classic = true,
        note = "A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. "
            .. "Turned off by Gathering contents in the options." },
    { key = "objectPrices", label = "Prices", size = 11, color = { .88, .78, .60 },
        tooltipType = "object", note = "The yielded item's sell price, and its auction price with Auctionator." },
    { key = "unitName", label = "Name", size = 17, title = true, color = { 1, 1, 1 },
        tooltipType = "unit", note = "Class color for players, reaction color for NPCs, unless set." },
    { key = "unitGuild", label = "Guild or role", size = 12, color = { .9, .9, .9 }, tooltipType = "unit" },
    { key = "unitRealm", label = "Guild realm", size = 11, color = colors.detail, tooltipType = "unit",
        note = "Beside the guild, for a guild from another realm. Turned off by Guild realm in the options." },
    { key = "unitInfo", label = "Level, race, and class", size = 12, color = colors.detail,
        tooltipType = "unit", note = "The level in its difficulty color, unless set." },
    { key = "unitBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "unit",
        note = "Elite, rare, faction, PvP, AFK, and dead." },
    { key = "unitSkinning", label = "Skinning", size = 11, color = colors.detail, tooltipType = "unit", classic = true,
        note = "On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what "
            .. "it may give. Turned off by Gathering contents in the options." },
    { key = "unitDetails", label = "Target and owner", size = 11, color = colors.detail,
        tooltipType = "unit" },
    { key = "unitQuests", label = "Quest lines", size = 12, color = colors.objective,
        tooltipType = "unit", note = "Quest names gold, finished objectives green, unless set." },
    { key = "auraName", label = "Name", size = 15, title = true, color = colors.title,
        tooltipType = "aura" },
    { key = "auraBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "aura",
        note = "Buff or debuff, dispel type in the game's colors, and stacks." },
    { key = "auraText", label = "Description", size = 12, color = colors.description,
        tooltipType = "aura", note = "Numbers in the aura's color unless set." },
    { key = "auraTime", label = "Time and caster", size = 11, color = { .88, .78, .60 },
        tooltipType = "aura" },
    { key = "questTitle", label = "Quest name", size = 16, title = true, color = colors.title,
        tooltipType = "quest" },
    { key = "questInfo", label = "Dungeon", size = 12, color = colors.detail, tooltipType = "quest" },
    { key = "questBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "quest",
        note = "The level in its difficulty color, tags, and where the quest stands." },
    { key = "questText", label = "Description", size = 12, color = colors.flavor, tooltipType = "quest" },
    { key = "questCaption", label = "Section caption", size = 9, color = colors.caption,
        tooltipType = "quest", caps = true },
    { key = "questObjectives", label = "Objectives", size = 12, color = colors.objective,
        tooltipType = "quest", note = "Finished objectives green unless set." },
    { key = "macroName", label = "Name", size = 15, title = true, color = colors.title,
        tooltipType = "macro" },
    { key = "macroBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "macro" },
    { key = "macroText", label = "Macro lines", size = 12, color = colors.detail, tooltipType = "macro",
        note = "Commands gold, conditions grey, unless set." },
}
-- types are Enum.TooltipDataType names; ones missing on this client are skipped.
ns.TOOLTIP_TYPES = {
    { label = "Items", restyle = "itemPanels", cursor = "cursorItems", types = { "Item" } },
    { label = "Spells", restyle = "spellPanels", cursor = "cursorSpells", types = { "Spell" } },
    { label = "Players and NPCs", restyle = "unitPanels", cursor = "cursorUnits",
        types = { "Unit", "Corpse" } },
    { label = "Buffs and debuffs", restyle = "auraPanels", cursor = "cursorAuras",
        types = { "UnitAura" } },
    { label = "Herbs, ore, chests, and other objects", restyle = "objectPanels",
        cursor = "cursorObjects", types = { "Object" } },
    { label = "Flight paths", restyle = "taxiPanels", types = {} },
    { label = "Quests", restyle = "questPanels", cursor = "cursorQuests", types = { "Quest", "QuestPartyProgress" } },
    { label = "Macros", restyle = "macroPanels", cursor = "cursorMacros", types = { "Macro" } },
    { label = "Currencies", cursor = "cursorCurrencies", types = { "Currency" } },
    { label = "Dungeon and raid lockouts", cursor = "cursorLockouts", types = { "InstanceLock" } },
    { label = "Pet abilities", restyle = "petPanels", cursor = "cursorPetActions", types = { "PetAction" } },
    { label = "Minimap", restyle = "minimapPanels", cursor = "cursorMinimap", types = { "MinimapMouseover" } },
    { label = "Mounts, toys, and pets", cursor = "cursorCollections",
        types = { "Mount", "Toy", "CompanionPet", "BattlePet" } },
    { label = "Achievements", cursor = "cursorAchievements", types = { "Achievement" } },
    { label = "Totems", cursor = "cursorTotems", types = { "Totem" } },
    { label = "Flyout buttons", cursor = "cursorFlyouts", types = { "Flyout" } },
}

-- Retail's own parts and defaults (Retail/Core/Settings.lua), each part after the one it names.
if ns.IsRetail() then
    for key, value in pairs(ns.Retail.Settings.DEFAULTS) do DEFAULTS[key] = value end
    for _, element in ipairs(ns.Retail.Settings.ELEMENTS) do
        for index, other in ipairs(ns.ELEMENTS) do
            if other.key == element.after then
                table.insert(ns.ELEMENTS, index + 1, element)
                break
            end
        end
    end
end

local ELEMENT_BY_KEY = {}
for _, element in ipairs(ns.ELEMENTS) do ELEMENT_BY_KEY[element.key] = element end
ns.ELEMENT_BY_KEY = ELEMENT_BY_KEY

-- Saved by name; LibSharedMedia lists the game's faces too, under its own names.
local GAME_FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
}
-- Use the client's Cyrillic and CJK faces where the Latin files lack glyphs.
-- LibSharedMedia filters its fonts by language; these are the choices without it.
if GetLocale() == "ruRU" then
    GAME_FONTS = {
        { "Friz Quadrata", "Fonts\\FRIZQT___CYR.TTF" },
        { "Arial Narrow", "Fonts\\ARIALN.TTF" },
        { "Morpheus", "Fonts\\MORPHEUS_CYR.TTF" },
        { "Skurri", "Fonts\\SKURRI_CYR.TTF" },
    }
elseif GetLocale() == "koKR" then
    GAME_FONTS = {
        { "기본 글꼴", "Fonts\\2002.TTF" },
        { "굵은 글꼴", "Fonts\\2002B.TTF" },
        { "퀘스트 글꼴", "Fonts\\K_Pagetext.TTF" },
    }
elseif GetLocale() == "zhCN" then
    GAME_FONTS = {
        { "默认", "Fonts\\ARKai_T.ttf" },
        { "聊天", "Fonts\\ARHei.ttf" },
        { "伤害数字", "Fonts\\ARKai_C.ttf" },
    }
elseif GetLocale() == "zhTW" then
    GAME_FONTS = {
        { "預設", "Fonts\\bLEI00D.ttf" },
        { "提示訊息", "Fonts\\bHEI00M.ttf" },
        { "聊天", "Fonts\\bHEI01B.ttf" },
        { "傷害數字", "Fonts\\bKAI00M.ttf" },
    }
end

local function sharedMedia()
    return LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

function ns.fontNames()
    local names = {}
    local media = sharedMedia()
    if media then
        for _, name in ipairs(media:List("font")) do names[#names + 1] = name end
    else
        for _, font in ipairs(GAME_FONTS) do names[#names + 1] = font[1] end
    end
    return names
end

function ns.fontPath(name)
    if type(name) ~= "string" then return end
    local media = sharedMedia()
    if media and media:IsValid("font", name) then return media:Fetch("font", name, true) end
    for _, font in ipairs(GAME_FONTS) do
        if font[1] == name then return font[2] end
    end
end

local function savedStyles(create)
    if type(PrettyTooltipDB) ~= "table" then
        if not create then return end
        PrettyTooltipDB = {}
    end
    if type(PrettyTooltipDB.styles) ~= "table" then
        if not create then return end
        PrettyTooltipDB.styles = {}
    end
    return PrettyTooltipDB.styles
end

function ns.elementSetting(key, field)
    local styles = savedStyles(false)
    local saved = styles and styles[key]
    -- An explicit nil: callers pass the result straight to tonumber.
    if type(saved) ~= "table" then return nil end
    return saved[field]
end

function ns.setElementSetting(key, field, value)
    local styles = savedStyles(true)
    local saved = type(styles[key]) == "table" and styles[key] or {}
    saved[field] = value
    styles[key] = next(saved) and saved or nil
    changed()
end

function ns.resetElement(key)
    local styles = savedStyles(false)
    if styles then styles[key] = nil end
    changed()
end

-- Settings kept per type of tooltip are named with these, as iconItems.
-- The backdrop's opacity with none set, for every type and style.
ns.BACKDROP_ALPHA = .9
ns.TYPE_SUFFIX = { item = "Items", spell = "Spells", object = "Objects", unit = "Units", aura = "Auras", quest = "Quests",
    macro = "Macros" }

-- The header band's opacity at an edge ("Top" or "Bottom") for a tooltip type; one
-- without its own follows the setting shared by all, and nil means the default.
function ns.headerAlpha(tooltipType, edge)
    local suffix = ns.TYPE_SUFFIX[tooltipType]
    local own = suffix and ns.option("header" .. edge .. "Alpha" .. suffix)
    if own ~= nil then return own end
    return ns.option("header" .. edge .. "Alpha")
end

function ns.resetStyles()
    if type(PrettyTooltipDB) ~= "table" then return end
    PrettyTooltipDB.styles = nil
    PrettyTooltipDB.bodyFont, PrettyTooltipDB.titleFont, PrettyTooltipDB.outline = nil, nil, nil
    PrettyTooltipDB.headerTopAlpha, PrettyTooltipDB.headerBottomAlpha = nil, nil
    for key in pairs(PrettyTooltipDB) do
        if type(key) == "string" and (key:match("^statColor%u") or key:match("^schoolColor%u")
            or key:match("^classColor%u")) then
            PrettyTooltipDB[key] = nil
        end
    end
    for _, suffix in pairs(ns.TYPE_SUFFIX) do
        PrettyTooltipDB["headerTopAlpha" .. suffix] = nil
        PrettyTooltipDB["headerBottomAlpha" .. suffix] = nil
        PrettyTooltipDB["backdropAlpha" .. suffix] = nil
        PrettyTooltipDB["glowAlpha" .. suffix] = nil
    end
    changed()
end

function ns.style(key)
    local element = ELEMENT_BY_KEY[key]
    local outline = ns.elementSetting(key, "outline") or ns.option("outline")
    local color = ns.elementSetting(key, "color")
    if type(color) ~= "table" then color = nil end
    -- Names are in capitals unless turned off; other parts only when turned on.
    local caps = ns.elementSetting(key, "caps")
    if caps == nil then caps = element.caps or element.title == true end
    return {
        key = key,
        title = element.title,
        size = (tonumber(ns.elementSetting(key, "size")) or element.size) * ns.option("fontScale"),
        font = ns.fontPath(ns.elementSetting(key, "font")),
        flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or "",
        color = color and { color[1], color[2], color[3] },
        caps = caps,
    }
end

-- The keys a modifier setting can name: how to tell one is held, and the keys
-- MODIFIER_STATE_CHANGED reports for it. A value not here, as "NONE" or
-- "ALWAYS", names no key.
local MODIFIERS = {
    SHIFT = { down = function() return IsShiftKeyDown() end, keys = { LSHIFT = true, RSHIFT = true } },
    CTRL = { down = function() return IsControlKeyDown() end, keys = { LCTRL = true, RCTRL = true } },
    ALT = { down = function() return IsAltKeyDown() end, keys = { LALT = true, RALT = true } },
}

local function keyDown(name)
    local modifier = MODIFIERS[name]
    return modifier ~= nil and modifier.down() and true or false
end

local function isKey(name, key)
    local modifier = MODIFIERS[name]
    return modifier ~= nil and modifier.keys[key] == true
end

function ns.originalKeyDown() return keyDown(ns.option("originalKey")) end
function ns.isOriginalKey(key) return isKey(ns.option("originalKey"), key) end

-- Whether the details show now: their key is held, or they always show.
function ns.detailsKeyDown()
    local name = ns.option("detailsKey")
    return not MODIFIERS[name] or keyDown(name)
end
function ns.isDetailsKey(key) return isKey(ns.option("detailsKey"), key) end

-- Whether a panel shows a detail its option turns on. The editor's previews,
-- and the details on the game's own tooltip, which follow the key themselves,
-- have every detail that is on.
function ns.showsDetail(key, panel)
    if not ns.option(key) then return false end
    if panel and (panel.isPreview or panel.allDetails) then return true end
    return ns.detailsKeyDown()
end
