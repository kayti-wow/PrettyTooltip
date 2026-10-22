-- Retail's own style parts and settings, which Core/Settings.lua adds to
-- ns.ELEMENTS and its defaults (ns.contribute "settings"): each part after the
-- one its after names, so the style editor lists it where it is drawn.
local _, ns = ...
local settings = {}
ns.Retail.Settings = settings

settings.DEFAULTS = {
    -- Retail's "<Shift Right Click to Socket>" under an item's sockets.
    socketHint = true,
}

settings.ELEMENTS = {
    { after = "header", key = "itemSource", label = "Source", size = 12, color = { .12, 1, .12 }, retail = true,
        note = "Where the item comes from, as Heroic or Mythic, under its name. The game's color unless set." },
    { after = "itemSource", key = "itemCosmetic", label = "Cosmetic", size = 12, color = { 1, .50, 1 },
        retail = true, note = "Cosmetic, under the name of an item worn for its look alone. The game's color unless set." },
    { after = "itemCosmetic", key = "itemUpgrade", label = "Upgrade level", size = 12, color = { .90, .80, .55 },
        retail = true, note = "The upgrade track and level, as Myth 2/6." },
    { after = "itemUpgrade", key = "craftingQuality", label = "Crafted quality", size = 12,
        color = { .90, .85, .74 }, retail = true, note = "A crafted item's quality, with the game's quality icon." },
    { after = "craftingQuality", key = "itemTransmog", label = "Transmogrification", size = 12,
        color = { 1, .50, 1 }, retail = true,
        note = "The appearance and weapon illusion the item is transmogrified to." },
    { after = "stats", key = "secondaryStats", label = "Secondary stats", size = 13, color = { .90, .85, .74 },
        retail = true,
        note = "Critical Strike, Haste, Mastery, Versatility, and the stats under them. Colored by stat unless set." },
    { after = "enchants", key = "gems", label = "Gems and sockets", size = 12, color = { .90, .85, .74 },
        retail = true,
        note = "Socketed gems with their icons, empty sockets, and the socket bonus. Gem stats in their stat colors, "
            .. "the socket bonus green once active, unless set." },
    { after = "spellCaptions", key = "spellCharges", label = "Charges", size = 11, color = { .60, .80, 1 },
        tooltipType = "spell", retail = true, note = "Under the strip, on a spell with charges: Max 2 Charges." },
}

ns.contribute("settings", { defaults = settings.DEFAULTS, elements = settings.ELEMENTS })
