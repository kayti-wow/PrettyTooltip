-- luacheck settings: `luacheck .` from here, or `python tests/run.py --lint`.
-- It reports names used but never defined, which a rename or a move leaves
-- behind, whether or not a test runs that code.
std = "lua51"
-- The harness defines the game's globals rather than using them.
exclude_files = { "tests/**", ".release/**", "art_unused/**" }

-- Style, not correctness: long data lines, as the cast time table, are fine.
max_line_length = false
ignore = {
    "542", -- An empty if branch, with a comment saying where the case is handled.
}

-- What the addon sets: its saved variables, its slash command, and the fields
-- the style editor gives the color picker.
globals = {
    "PrettyTooltipDB",
    "PrettyTooltipCaptures",
    "SLASH_PRETTYTOOLTIP1",
    "SLASH_PRETTYTOOLTIP2",
    SlashCmdList = { other_fields = true },
    ColorPickerFrame = { other_fields = true },
}

-- The game's functions, objects, and constants the addon reads.
read_globals = {
    -- Lua the game adds
    "date", "tinsert", "issecretvalue", "canaccesstable", "debugprofilestop", "hooksecurefunc", "geterrorhandler", "debugstack",
    -- Frames and UI
    "CreateFrame", "CreateColor", "UIParent", "GameTooltip", "GameTooltipStatusBar", "ItemRefTooltip", "GameTooltipText",
    "GameTooltipHeaderText", "QuestScrollFrame", "GameFontHighlightSmall", "UISpecialFrames", "ShowUIPanel", "HideUIPanel",
    "SetPortraitTexture", "ChatEdit_InsertLink", "GetCursorPosition", "NUM_CHAT_WINDOWS",
    "Settings", "SettingsPanel", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
    "STANDARD_TEXT_FONT", "RAID_CLASS_COLORS", "CUSTOM_CLASS_COLORS", "LOCALIZED_CLASS_NAMES_MALE", "NineSliceUtil",
    -- The game's strings, in the client's language; tools/make_strings.py gives
    -- the tests each one listed here.
    "ITEM_DELTA_DESCRIPTION", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONPROC",
    "ITEM_CREATED_BY", "ENCHANTED_TOOLTIP_LINE", "ITEM_MIN_LEVEL", "ITEM_MIN_SKILL", "ITEM_REQ_SKILL",
    "ITEM_STARTS_QUEST", "ITEM_BIND_QUEST", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_USE",
    "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP", "ITEM_SOULBOUND",
    "ITEM_UNIQUE", "ITEM_UNIQUE_EQUIPPABLE", "ITEM_UNIQUE_MULTIPLE", "ITEM_LIMIT_CATEGORY", "ITEM_LIMIT_CATEGORY_MULTIPLE",
    "CONTAINER_SLOTS", "ITEM_SET_NAME", "ITEM_SET_BONUS_GRAY", "DURABILITY_TEMPLATE", "ITEM_CLASSES_ALLOWED",
    "ITEM_RACES_ALLOWED", "TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN", "TRANSMOGRIFY_STYLE_UNCOLLECTED",
    "DAMAGE_TEMPLATE", "DAMAGE_TEMPLATE_WITH_SCHOOL", "PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL", "DPS_TEMPLATE",
    "ARMOR_TEMPLATE", "SELL_PRICE", "PROFESSIONS_USED_IN_COOKING", "LARGE_NUMBER_SEPERATOR", "DECIMAL_SEPERATOR",
    "SHIELD_BLOCK_TEMPLATE",
    "MANA", "RAGE", "ENERGY", "FOCUS", "RUNIC_POWER", "MANA_COST", "MANA_COST_LARGE", "RAGE_COST", "ENERGY_COST",
    "FOCUS_COST", "RUNIC_POWER_COST", "SPELL_CAST_TIME_SEC", "SPELL_CAST_TIME_MIN", "SPELL_CAST_TIME_INSTANT",
    "SPELL_CAST_TIME_INSTANT_NO_MANA", "SPELL_CAST_CHANNELED", "SPELL_ON_NEXT_SWING", "SPELL_RECAST_TIME_SEC",
    "SPELL_RECAST_TIME_MIN", "SPELL_RECAST_TIME_HOURS", "SPELL_RECAST_TIME_DAYS", "SPELL_DURATION_SEC",
    "SPELL_DURATION_MIN", "SPELL_DURATION_HOURS", "SPELL_DURATION_DAYS", "SPELL_RANGE", "MELEE_RANGE", "SPELL_PASSIVE",
    "SPELL_REAGENTS", "SPELL_TOTEMS", "ITEM_COOLDOWN_TIME", "SPELL_EQUIPPED_ITEM", "SPELL_REQUIRED_FORM",
    "TOOLTIP_TALENT_RANK", "TOOLTIP_TALENT_NEXT_RANK", "NEXT_RANK_COLON", "TOOLTIP_TALENT_PREREQ",
    "TOOLTIP_TALENT_TIER_POINTS", "TOOLTIP_UNIT_LEVEL", "TOOLTIP_UNIT_LEVEL_TYPE", "TOOLTIP_UNIT_LEVEL_RACE",
    "TOOLTIP_UNIT_LEVEL_RACE_TYPE", "PLAYER", "BOSS", "ELITE", "FACTION_ALLIANCE", "FACTION_HORDE", "PVP_ENABLED",
    "DEAD", "CORPSE", "UNIT_SKINNABLE_LEATHER", "QUEST_TOOLTIP_ACTIVE", "OBJECTIVES_LABEL", "QUEST_TOOLTIP_REQUIREMENTS",
    "UNIT_LEVEL_TEMPLATE", "LOCKED", "LOCKED_WITH_SPELL", "LOCKED_WITH_ITEM", "SPELL_TIME_REMAINING_SEC",
    "SPELL_TIME_REMAINING_MIN", "SPELL_TIME_REMAINING_HOURS", "SPELL_TIME_REMAINING_DAYS", "SLASH_CAST1", "SLASH_CAST2",
    "SLASH_CAST3", "SLASH_CAST4", "SLASH_USE1", "SLASH_USE2", "TOOLTIP_ITEM_STAT_FORMAT", "ITEM_RESIST_ALL",
    "ITEM_RESIST_SINGLE", "DAMAGE_SCHOOL2", "DAMAGE_SCHOOL3", "DAMAGE_SCHOOL4", "DAMAGE_SCHOOL5", "DAMAGE_SCHOOL6",
    "DAMAGE_SCHOOL7", "RESISTANCE0_NAME", "RESISTANCE1_NAME", "RESISTANCE2_NAME", "RESISTANCE3_NAME",
    "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME",
    "MELEE", "ROLL_DISENCHANT", "DAMAGE_PER_SECOND", "ARMOR", "RAID", "LFG_TYPE_DUNGEON", "FAILED",
    "QUEST_CLASSIFICATION_RECURRING", "TARGET", "YOU", "CLOSE",
    "INVTYPE_2HWEAPON", "INVTYPE_CHEST", "INVTYPE_HAND", "ITEM_REQ_REPUTATION", "FACTION_STANDING_LABEL7",
    "ITEM_COOLDOWN_TOTAL_MIN", "ITEM_COOLDOWN_TIME_SEC", "ITEM_LEVEL",
    -- Tooltip data
    "TooltipDataProcessor", "TooltipComparisonManager", "Enum",
    -- Game state
    "C_Item", "C_Spell", "C_Texture", "C_AddOns", "C_QuestLog", "C_UnitAuras", "C_Timer", "C_CurrencyInfo",
    "GetLocale", "GetBuildInfo", "GetAddOnMetadata", "GetTime", "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown", "InCombatLockdown",
    "GetSpellInfo", "GetSpellTexture", "GetSpellBonusDamage", "GetSpellBonusHealing", "GetMacroInfo", "GetMacroIndexByName",
    "GetNumMacros", "GetMacroSpell", "GetMacroItem", "MAX_ACCOUNT_MACROS", "GetPetActionInfo",
    "NumTaxiNodes", "TaxiNodeName", "TaxiNodeCost", "TaxiNodeGetType", "TaxiNodeOnButtonEnter",
    "TAXINODEYOUAREHERE", "UpdateAddOnMemoryUsage", "GetAddOnMemoryUsage", "GetPhysicalScreenSize", "PixelUtil",
    "NUM_PET_ACTION_SLOTS",
    "GetSkillLineInfo", "GetNumSkillLines", "GetProfessions", "GetProfessionInfo",
    "GetQuestDifficultyColor", "GetGuildInfo", "GetCoinTextureString", "BreakUpLargeNumbers",
    "UnitName", "UnitExists", "UnitGUID", "UnitTokenFromGUID", "UnitLevel", "UnitEffectiveLevel",
    "UnitClass", "UnitRace", "UnitFactionGroup", "UnitReaction", "UnitIsUnit", "UnitIsPlayer",
    "UnitHealth", "UnitHealthMax", "UnitIsTapDenied", "UnitIsPVP", "UnitIsDeadOrGhost", "UnitIsDND",
    "UnitIsAFK", "UnitCreatureType", "UnitClassification",
    -- Other addons, used when installed
    "LibStub", "Auctionator", "QuestieLoader",
}
