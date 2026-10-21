-- The German client: what the game has no string for, in German, and the
-- client's own names for skills, dispel types, quest kinds, and schools. It
-- loads after Locale\English.lua, so whatever it leaves out stays English.
-- Wordings marked "unconfirmed" are guesses until a German capture shows them.
local _, ns = ...
local locale = ns.Locale

locale.supported = true
locale.features = { coefficients = true }

local formats = locale.formats
-- Unconfirmed: the game names a weapon's speed SPEED, "Tempo".
formats.weaponSpeed = "Tempo %s"
-- Recipes teach in two wordings: "Lehrt Euch die Herstellung eines
-- Elixiers ..." and "Lehrt Euch, wie man ein Elixier ... herstellt".
formats.recipeTeaches = { "Benutzen: Lehrt Euch die Herstellung %s", "Benutzen: Lehrt Euch, wie man %s herstellt" }
-- Unconfirmed.
formats.baseManaCost = "%d%% des Grundmanas"
-- Unconfirmed: as the map's legend names them.
formats.rare = "Selten"
formats.rareElite = "Selten - Elite"

-- "Ausdauer +16 und Rüstung +100".
locale.listSeparators = { ", und ", " und ", ", " }

-- Descriptions join the school to its word: "Feuerschaden", "Eure Feuerzauber".
locale.descriptions.school = { "%sschaden", "%szauber" }
locale.schoolWords = { Arcane = "Arkan", Fire = "Feuer", Frost = "Frost", Holy = "Heilig", Nature = "Natur",
    Shadow = "Schatten", Holyfire = "Heiligfeuer", Frostfire = "Frostfeuer" }

-- Amounts and durations from the native Spell table (Forever 1.60.1.70450).
local descriptions = locale.descriptions
descriptions.clause = "^[^%d]-"
descriptions.range = { "%d bis %d", "%d - %d", "%d-%d" }
descriptions.over = false
descriptions.overBefore = { "%d sek. lang", "%d sekunden lang", "über %d sek.", "über %d sekunden", "im verlauf von %d sek." }
descriptions.eachSecond = false
descriptions.every = false
descriptions.everyBefore = { "alle %d sek.", "alle %d sekunden" }
descriptions.everyFor = false
descriptions.lasts = { "hält %d sek.", "hält %d sekunden" }
descriptions.perSecondBefore = { "pro sekunde" }
descriptions.units = { "sek", "sekunde", "sekunden", "min", "minute", "minuten", "stunde", "stunden", "meter", "metern", "m", "mal", "ziele", "zielen", "aufladungen", "stapel" }
descriptions.unitBoundaries = true
descriptions.heals = { "heilt", "heilen", "heilung", "regeneriert", "absorbiert" }

-- Older English equip wordings; the German client prints the game's own.
locale.statWordings = {}

local skills = locale.skills
skills.Alchemy = "Alchimie"
skills.Blacksmithing = "Schmiedekunst"
skills.Enchanting = "Verzauberkunst"
skills.Engineering = "Ingenieurskunst"
skills.Leatherworking = "Lederverarbeitung"
skills.Tailoring = "Schneiderei"
skills.Cooking = "Kochkunst"
skills["First Aid"] = "Erste Hilfe"
skills.Fishing = "Angeln"
skills.Mining = "Bergbau"
skills.Herbalism = "Kräuterkunde"
skills.Skinning = "Kürschnerei"
skills.Lockpicking = "Schlossknacken"

local dispels = locale.dispels
dispels.Magic = "Magie"
dispels.Curse = "Fluch"
dispels.Disease = "Krankheit"
dispels.Poison = "Gift"

locale.questTags = { Elite = true, Dungeon = true, Schlachtzug = true, Gruppe = true, PvP = true }

-- The addon's own words: a first draft, for a German speaker to review.
local L = ns.L

-- The panels -------------------------------------------------------------------

-- The spell strip. German spells measure their range in meters.
L["Cast"] = "Wirken"
L["Cooldown"] = "Abklingzeit"
L["Range"] = "Reichweite"
L["Cost"] = "Kosten"
L["Free"] = "Kostenlos"
L["None"] = "Keine"
L["Self"] = "Selbst"
L["%s yd"] = "%s m"
L["Base Mana"] = "Grundmana"
L["Next Rank"] = "Nächster Rang"
L["Rank %s"] = "Rang %s"

-- Items.
L["%s Slot"] = "%s Platz"
L["%s Slots"] = "%s Plätze"
L["Requires %s %s"] = "Benötigt %s %s"
L["Recipe"] = "Rezept"
L["Made by %s"] = "Hergestellt von %s"
L["Expected value"] = "Erwarteter Wert"
L["iLvl %s"] = "GS %s"
L["Creates"] = "Erzeugt"
L["Reagents"] = "Reagenzien"
L["Equipped"] = "Angelegt"
L["Equipped With"] = "Angelegt mit"

-- Auras, flight paths, macros, and pet abilities.
L["Buff"] = "Stärkung"
L["Debuff"] = "Schwächung"
L["%s stacks"] = "%s Stapel"
L["No time limit"] = "Keine Zeitbegrenzung"
L["by %s"] = "von %s"
L["You are here"] = "Ihr seid hier"
L["Macro"] = "Makro"
L["Macro: %s"] = "Makro: %s"
L["Autocast"] = "Automatisch"
L["Autocast off"] = "Automatisch aus"
L["Active"] = "Aktiv"

-- World objects.
L["Herb"] = "Kraut"
L["Mining node"] = "Erzvorkommen"
L["Fishing pool"] = "Fischschwarm"
L["Quest object"] = "Questobjekt"
L["Auction"] = "Auktion"
L["%s to %s"] = "%s bis %s"
L["Your skill %s"] = "Eure Fertigkeit %s"

-- Quests and units.
L["Legendary"] = "Legendär"
L["Heroic"] = "Heroisch"
L["Group"] = "Gruppe"
L["Scenario"] = "Szenario"
L["World event"] = "Weltereignis"
L["Completed"] = "Abgeschlossen"
L["Ready to turn in"] = "Bereit zur Abgabe"
L["In progress"] = "In Arbeit"
L["AFK"] = "AFK"
L["DND"] = "Beschäftigt"

-- The spell power rows.
L["Healing per Second"] = "Heilung pro Sekunde"
L["Healing per Mana"] = "Heilung pro Mana"
L["Damage per Mana"] = "Schaden pro Mana"
L["Spell Power Coefficient"] = "Zaubermachtkoeffizient"
L["Spell Power Coefficient over time"] = "Zaubermachtkoeffizient über Zeit"
L["Healing Power Coefficient"] = "Heilkraftkoeffizient"
L["Healing Power Coefficient over time"] = "Heilkraftkoeffizient über Zeit"
L["each"] = "je"

-- Stats --------------------------------------------------------------------------

L["All Stats"] = "Alle Werte"
L["Attack Power vs %s"] = "Angriffskraft gegen %s"
L["Hit Chance"] = "Trefferchance"
L["Critical Strike Chance"] = "Kritische Trefferchance"
L["Hit Rating"] = "Trefferwertung"
L["Critical Strike Rating"] = "Kritische Trefferwertung"
L["Haste Rating"] = "Tempowertung"
L["Expertise Rating"] = "Waffenkundewertung"
L["Defense Skill"] = "Verteidigungsfertigkeit"
L["Defense Rating"] = "Verteidigungswertung"
L["Dodge Chance"] = "Ausweichchance"
L["Dodge Rating"] = "Ausweichwertung"
L["Parry Chance"] = "Parierchance"
L["Parry Rating"] = "Parierwertung"
L["Block Chance"] = "Blockchance"
L["Block Rating"] = "Blockwertung"
L["Shield Block Value"] = "Schildblockwert"
L["Resilience Rating"] = "Abhärtungswertung"
L["All Resistances"] = "Alle Widerstände"
L["Spell Damage Power"] = "Zauberschaden"
L["Spell Damage Power vs %s"] = "Zauberschaden gegen %s"
L["Spell Penetration"] = "Zauberdurchschlagskraft"
L["Spell Hit Chance"] = "Zaubertrefferchance"
L["Spell Critical Strike Chance"] = "Kritische Zaubertrefferchance"
L["Spell Hit Rating"] = "Zaubertrefferwertung"
L["Spell Critical Strike Rating"] = "Kritische Zaubertrefferwertung"
L["Spell Haste Rating"] = "Zaubertempowertung"
-- The school's name joins the word: "Feuerzaubermacht".
L["%s Spell Power"] = "%szaubermacht"
L["%s Spell Damage Power"] = "%szauberschaden"
L["Healing Power"] = "Heilkraft"
L["Health per 5 sec"] = "Gesundheit alle 5 Sek."
L["Mana per 5 sec"] = "Mana alle 5 Sek."
L["Beasts"] = "Wildtiere"
L["Demons"] = "Dämonen"
L["Dragonkin"] = "Drachkin"
L["Elementals"] = "Elementare"
L["Giants"] = "Riesen"
L["Humanoids"] = "Humanoide"
L["Mechanical"] = "Mechanische"
L["Undead"] = "Untote"

-- Stat categories, schools, and classes, as the style editor names them.
L["Primary attributes"] = "Primärwerte"
L["Attack"] = "Angriff"
L["Defense"] = "Verteidigung"
L["Magic"] = "Magie"
L["Healing"] = "Heilung"
L["Mana"] = "Mana"
L["Negative values"] = "Negative Werte"
L["Arcane"] = "Arkan"
L["Fire"] = "Feuer"
L["Frost"] = "Frost"
L["Holy"] = "Heilig"
L["Nature"] = "Natur"
L["Shadow"] = "Schatten"
L["Holyfire"] = "Heiligfeuer"
L["Frostfire"] = "Frostfeuer"
L["Warrior"] = "Krieger"
L["Paladin"] = "Paladin"
L["Hunter"] = "Jäger"
L["Rogue"] = "Schurke"
L["Priest"] = "Priester"
L["Shaman"] = "Schamane"
L["Mage"] = "Magier"
L["Warlock"] = "Hexenmeister"
L["Druid"] = "Druide"

-- The style editor ---------------------------------------------------------------

L["PrettyTooltip Style Editor"] = "PrettyTooltip-Stileditor"
L["Click any part of the sample to restyle it. Tooltips use the new look the next time they open."] =
    "Klickt auf einen Teil des Beispiels, um seinen Stil zu ändern. Tooltips zeigen den neuen Stil, sobald sie das nächste Mal geöffnet werden."
L["Click any part of the sample to edit it."] = "Klickt auf einen Teil des Beispiels, um ihn zu bearbeiten."
L["%s: click to edit"] = "%s: Zum Bearbeiten klicken"
L["There is no item with ID %s."] = "Es gibt keinen Gegenstand mit der ID %s."
L["Loading item %s..."] = "Gegenstand %s wird geladen ..."
L["The sample failed to draw: %s"] = "Das Beispiel konnte nicht gezeichnet werden: %s"
L["Nothing to show for %s ID %s."] = "Nichts anzuzeigen für %s-ID %s."
L["%s (not installed)"] = "%s (nicht installiert)"
L["Custom"] = "Angepasst"
L["Automatic"] = "Automatisch"
L["ID, or shift-click a link"] = "ID, oder Umschalt-Klick auf einen Link"
L["Clear"] = "Leeren"
L["Reset to default"] = "Auf Standard zurücksetzen"
L["Click to choose its color; right-click for the default."] =
    "Klicken, um die Farbe zu wählen; Rechtsklick für den Standard."
L["Selected Part"] = "Gewählter Teil"
L["Font"] = "Schriftart"
L["Name font"] = "Namensschrift"
L["Text font"] = "Textschrift"
L["Size"] = "Größe"
L["Color"] = "Farbe"
L["Outline"] = "Kontur"
L["Same as global settings"] = "Wie die allgemeinen Einstellungen"
L["Thick outline"] = "Dicke Kontur"
L["All caps"] = "Großbuchstaben"
L["Letters"] = "Buchstaben"
L["Reset this part"] = "Diesen Teil zurücksetzen"
L["All Tooltips"] = "Alle Tooltips"
L["Game default"] = "Spielstandard"
L["Text size"] = "Textgröße"
L["Panel style"] = "Rahmenstil"
L["Blizzard border"] = "Blizzard-Rahmen"
L["Flat"] = "Flach"
L["Padding"] = "Innenabstand"
L["Min width"] = "Mindestbreite"
L["Icon on the right"] = "Symbol rechts"
L["Moves the item or spell icon, and the item level badge under it, to the right of the name."] =
    "Setzt das Gegenstands- oder Zaubersymbol und die Gegenstandsstufe darunter rechts neben den Namen."
L["Tint the panel"] = "Rahmen einfärben"
L["Washes the panel in the item's quality color, or the spell's school or resource. Off, every panel is neutral; the name keeps its quality color."] =
    "Färbt den Rahmen in der Qualitätsfarbe des Gegenstands oder in der Schule oder Ressource des Zaubers. Aus: Jeder Rahmen ist neutral, der Name behält seine Qualitätsfarbe."
L["Separators"] = "Trennlinien"
L["The gold dividers between sections and the thin rules above other addons' rows. Off, they are hidden along with the space around them."] =
    "Die goldenen Trenner zwischen den Abschnitten und die feinen Linien über den Zeilen anderer Addons. Aus: Sie werden mitsamt ihrem Abstand ausgeblendet."
L["School colors"] = "Schulfarben"
L["%s Panel"] = "Rahmen: %s"
L["Show icon"] = "Symbol zeigen"
L["The icon or portrait in the header, for the kind of tooltip shown."] =
    "Das Symbol oder Porträt in der Kopfzeile, für die gezeigte Art von Tooltip."
L["Band top"] = "Band oben"
L["Band bottom"] = "Band unten"
L["Backdrop"] = "Hintergrund"
L["Glow"] = "Schimmer"
L["Footer"] = "Fußzeile"
L["Item Details"] = "Gegenstandsdetails"
L["Spell Details"] = "Zauberdetails"
L["Unit Details"] = "Einheitendetails"
L["Object Details"] = "Objektdetails"
L["Quest Details"] = "Questdetails"
L["Quest parchment"] = "Questpergament"
L["DialogueUI's brown parchment for quest tooltips, Quest Items, and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed."] =
    "Das braune Pergament von DialogueUI für Quest-Tooltips, Questgegenstände und Gegenstände, die eine Quest beginnen, mit dunklerer Tinte zur besseren Lesbarkeit. Benötigt DialogueUI."
L["Level badge"] = "Stufenschild"
L["The item level on a plate under the icon, for equipment."] =
    "Die Gegenstandsstufe auf einem Schild unter dem Symbol, für Ausrüstung."
L["The level on a plate under the portrait. Off, the level stays in the info line."] =
    "Die Stufe auf einem Schild unter dem Porträt. Aus: Die Stufe bleibt in der Infozeile."
L["Stat markers"] = "Wertemarker"
L["The small diamond before each stat; enchants use a green one."] =
    "Die kleine Raute vor jedem Wert; Verzauberungen haben eine grüne."
L["Stat colors"] = "Wertefarben"
L["Each kind of stat in its color below, and the school colors. Off, every stat is parchment."] =
    "Jede Art von Wert in ihrer Farbe unten, und die Schulfarben. Aus: Jeder Wert ist pergamentfarben."
L["Abbreviated Equip Effects"] = "Gekürzte Anlegen-Effekte"
L["Where the game's own item tooltip shows, in the Blizzard layout or with items not restyled, its Equip effects are shortened, as +1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit effects in their stat colors. Hold the default tooltip modifier for the full wording."] =
    "Wo der Gegenstands-Tooltip des Spiels erscheint, im Blizzard-Layout oder bei nicht neu gestalteten Gegenständen, werden seine Anlegen-Effekte gekürzt, etwa zu +1% Kritische Trefferchance, und die Farben des Spiels bleiben, außer bei Zaubermacht und Trefferchance-Effekten in ihren Wertefarben. Haltet die Zusatztaste für den Standard-Tooltip für den vollen Wortlaut."
L["Disenchant"] = "Entzaubern"
L["Green, blue, and purple armor and weapons list what they disenchant into, with each result's chance and the Enchanting it needs; with Auctionator, the expected value."] =
    "Grüne, blaue und violette Rüstungen und Waffen zeigen, was sie beim Entzaubern ergeben, mit der Chance jedes Ergebnisses und der nötigen Verzauberkunst; mit Auctionator auch den erwarteten Wert."
L["Sell price"] = "Verkaufspreis"
L["The vendor price in the footer; for a stack, the price of one and of the whole stack."] =
    "Der Händlerpreis in der Fußzeile; bei einem Stapel der Preis für einen und für den ganzen Stapel."
L["Swap Damage Stats"] = "Schadenswerte tauschen"
L["A weapon's damage on the large line, with its speed and damage per second on the small one under it."] =
    "Der Schaden einer Waffe in der großen Zeile, ihr Tempo und Schaden pro Sekunde in der kleinen darunter."
L["Spell power"] = "Zaubermacht"
L["Under the description, each amount's spell power coefficient and its split into base and spell power. No game API has coefficients: they come from Forever's client data, and ones marked ~ are estimates."] =
    "Unter der Beschreibung der Zaubermachtkoeffizient jedes Betrags und seine Aufteilung in Grundwert und Zaubermacht. Keine Spiel-API liefert Koeffizienten: Sie stammen aus den Clientdaten von Forever, mit ~ markierte sind Schätzungen."
L["Rates"] = "Raten"
L["Under the spell power breakdown, the average a cast deals or heals per second and per mana. Per second, what lands at once counts over the cast time (instants as the 1.5 sec global cooldown) and what comes over time over its duration. Crits and talents do not count."] =
    "Unter der Zaubermacht-Aufteilung der durchschnittliche Schaden oder die Heilung eines Zaubers pro Sekunde und pro Mana. Pro Sekunde zählt, was sofort wirkt, über die Zauberzeit (Spontanzauber als globale Abklingzeit von 1,5 Sek.) und was über Zeit wirkt, über seine Dauer. Kritische Treffer und Talente zählen nicht."
L["Health bar"] = "Gesundheitsleiste"
L["The game's own health bar at the bottom of player and NPC panels. The game fills it, so it stays live without the addon reading health, which WoW Forever keeps from addons."] =
    "Die Gesundheitsleiste des Spiels am unteren Rand von Spieler- und NSC-Rahmen. Das Spiel füllt sie, sodass sie aktuell bleibt, ohne dass das Addon die Gesundheit liest, die WoW Forever Addons vorenthält."
L["Gathering"] = "Sammeln"
L["What a herb or ore node holds: its yield over all the times it can be gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. From Classic's loot tables."] =
    "Was ein Kräuter- oder Erzvorkommen enthält: seinen Ertrag über alle Male, die es gesammelt werden kann, dann Steine, Edelsteine und weitere Kräuter, die es geben kann, mit der Chance pro Mal. Bei einer toten, häutbaren Kreatur die nötige Kürschnerei und das Leder, die Bälge und Schuppen, die sie geben kann. Aus den Beutetabellen von Classic."
L["Class colors"] = "Klassenfarben"
L["Reset all fonts and colors"] = "Alle Schriften und Farben zurücksetzen"
L["More options"] = "Weitere Optionen"
L["IDs"] = "IDs"
L["The item's, spell's, or NPC's ID at the bottom of its panel, under other addons' rows."] =
    "Die ID des Gegenstands, Zaubers oder NPCs unten im Rahmen, unter den Zeilen anderer Addons."
L["Item ID: %s"] = "Gegenstands-ID: %s"
L["NPC ID: %s"] = "NPC-ID: %s"

-- The kinds of tooltip, their samples' tabs, and the lookup by ID.
L["Items"] = "Gegenstände"
L["Spells"] = "Zauber"
L["Objects"] = "Objekte"
L["Units"] = "Einheiten"
L["Buffs"] = "Auren"
L["Quests"] = "Quests"
L["Macros"] = "Makros"
L["Item ID"] = "Gegenstands-ID"
L["Spell ID"] = "Zauber-ID"
L["Object ID"] = "Objekt-ID"
L["Unit ID"] = "Einheiten-ID"
L["Buff ID"] = "Auren-ID"
L["Quest ID"] = "Quest-ID"
L["Macro ID"] = "Makro-ID"
L["Weapon"] = "Waffe"
L["Set piece"] = "Setteil"
L["Potion"] = "Trank"
L["Quest item"] = "Questgegenstand"
L["Fireball"] = "Feuerball"
L["Ability"] = "Fähigkeit"
L["Heal"] = "Heilung"
L["Ore"] = "Erz"
L["Chest"] = "Truhe"
L["Quest"] = "Quest"
L["Player"] = "Spieler"
L["Enemy"] = "Feind"
L["Vendor"] = "Händler"
L["Rare"] = "Selten"
L["Rare elite"] = "Selten, Elite"
L["Boss"] = "Boss"
L["Curse"] = "Fluch"
L["Poison"] = "Gift"
L["Ready"] = "Bereit"
L["New"] = "Neu"
L["Targeting"] = "Zielen"

-- The style parts, and what each says about its color.
L["Item name"] = "Gegenstandsname"
L["Quality color unless set."] = "Qualitätsfarbe, wenn nicht gesetzt."
L["Type and slot"] = "Art und Platz"
L["Half the quality color, red for a type you cannot use."] =
    "Halbe Qualitätsfarbe, rot für eine Art, die Ihr nicht benutzen könnt."
L["Binding and level"] = "Bindung und Stufe"
L["The required level is red while you are below it."] = "Die benötigte Stufe ist rot, solange Ihr darunter seid."
L["Damage per second"] = "Schaden pro Sekunde"
L["Damage and speed"] = "Schaden und Tempo"
L["Armor"] = "Rüstung"
L["Stats"] = "Werte"
L["Colored by category unless set."] = "Nach Kategorie gefärbt, wenn nicht gesetzt."
L["Equip effects"] = "Anlegen-Effekte"
L["On-hit numbers use the spell tooltip's school colors unless set."] =
    "Zahlen bei Treffer nutzen die Schulfarben des Zauber-Tooltips, wenn nicht gesetzt."
L["Enchants"] = "Verzauberungen"
L["Use and other effects"] = "Benutzen und andere Effekte"
L["Flavor text"] = "Beschreibungstext"
L["Set name and count"] = "Setname und Anzahl"
L["Set pieces"] = "Setteile"
L["Owned pieces bright, missing ones grey, unless set."] = "Vorhandene Teile hell, fehlende grau, wenn nicht gesetzt."
L["Set bonuses"] = "Setboni"
L["Active bonuses green, inactive ones grey, unless set."] = "Aktive Boni grün, inaktive grau, wenn nicht gesetzt."
L["Other addons' rows"] = "Zeilen anderer Addons"
L["Durability, crafter, requirements, and sell price."] = "Haltbarkeit, Hersteller, Anforderungen und Verkaufspreis."
L["Item level badge"] = "Gegenstandsstufen-Schild"
L["Crafted item's name"] = "Name des hergestellten Gegenstands"
L["On recipes; quality color unless set."] = "Bei Rezepten; Qualitätsfarbe, wenn nicht gesetzt."
L["On recipes; the count you carry red while short, unless set."] =
    "Bei Rezepten; die mitgeführte Anzahl rot, solange sie fehlt, wenn nicht gesetzt."
L["Section captions"] = "Abschnittsüberschriften"
L["Creates and Reagents on recipes."] = "Erzeugt und Reagenzien bei Rezepten."
L["Disenchant results"] = "Entzauberungsergebnisse"
L["The Enchanting needed red while yours is too low, grey without Enchanting, unless set."] =
    "Die nötige Verzauberkunst rot, solange Eure zu niedrig ist, grau ohne Verzauberkunst, wenn nicht gesetzt."
L["Spell name"] = "Zaubername"
L["School and rank badges"] = "Schul- und Rangschilder"
L["Colored by school unless set."] = "Nach Schule gefärbt, wenn nicht gesetzt."
L["Cost, cast, cooldown, range"] = "Kosten, Wirken, Abklingzeit, Reichweite"
L["The cost takes its resource color unless set."] = "Die Kosten haben ihre Ressourcenfarbe, wenn nicht gesetzt."
L["Strip captions"] = "Leistenbeschriftungen"
L["Requirements and details"] = "Anforderungen und Details"
L["Unmet requirements red, time remaining orange, unless set."] =
    "Unerfüllte Anforderungen rot, verbleibende Zeit orange, wenn nicht gesetzt."
L["Description"] = "Beschreibung"
L["Numbers in the school color unless set."] = "Zahlen in der Schulfarbe, wenn nicht gesetzt."
L["Object name"] = "Objektname"
L["Kind of object"] = "Art des Objekts"
L["Tinted by the skill it needs, unless set."] = "Nach der nötigen Fertigkeit gefärbt, wenn nicht gesetzt."
L["Skill and requirements"] = "Fertigkeit und Anforderungen"
L["The skill in its skill-up color, unmet requirements red, unless set."] =
    "Die Fertigkeit in ihrer Steigerungsfarbe, unerfüllte Anforderungen rot, wenn nicht gesetzt."
L["Quest lines"] = "Questzeilen"
L["Quest names gold, finished objectives green, unless set."] =
    "Questnamen golden, erfüllte Ziele grün, wenn nicht gesetzt."
L["Contents"] = "Inhalt"
L["A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. Turned off by Gathering contents in the options."] =
    "Der Ertrag eines Kräuter- oder Erzvorkommens über alle Male, dann was es sonst enthalten kann, mit der Chance pro Mal. Wird mit Sammeln in den Optionen abgeschaltet."
L["Prices"] = "Preise"
L["The yielded item's sell price, and its auction price with Auctionator."] =
    "Der Verkaufspreis des Ertrags und mit Auctionator sein Auktionspreis."
L["Name"] = "Name"
L["Class color for players, reaction color for NPCs, unless set."] =
    "Klassenfarbe für Spieler, Reaktionsfarbe für NSCs, wenn nicht gesetzt."
L["Guild or role"] = "Gilde oder Rolle"
L["Level, race, and class"] = "Stufe, Volk und Klasse"
L["The level in its difficulty color, unless set."] = "Die Stufe in ihrer Schwierigkeitsfarbe, wenn nicht gesetzt."
L["Badges"] = "Schilder"
L["Elite, rare, faction, PvP, AFK, and dead."] = "Elite, selten, Fraktion, PvP, AFK und tot."
L["Skinning"] = "Kürschnerei"
L["On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what it may give. Turned off by Gathering contents in the options."] =
    "Bei einer toten, häutbaren Kreatur: die nötige Kürschnerei in ihrer Steigerungsfarbe und was sie geben kann. Wird mit Sammeln in den Optionen abgeschaltet."
L["Target and owner"] = "Ziel und Besitzer"
L["Buff or debuff, dispel type in the game's colors, and stacks."] =
    "Stärkung oder Schwächung, Bannart in den Farben des Spiels und Stapel."
L["Numbers in the aura's color unless set."] = "Zahlen in der Farbe der Aura, wenn nicht gesetzt."
L["Time and caster"] = "Zeit und Zaubernder"
L["Quest name"] = "Questname"
L["Dungeon"] = "Dungeon"
L["The level in its difficulty color, tags, and where the quest stands."] =
    "Die Stufe in ihrer Schwierigkeitsfarbe, Kennzeichen und der Stand der Quest."
L["Section caption"] = "Abschnittsüberschrift"
L["Objectives"] = "Questziele"
L["Finished objectives green unless set."] = "Erfüllte Ziele grün, wenn nicht gesetzt."
L["Macro lines"] = "Makrozeilen"
L["Commands gold, conditions grey, unless set."] = "Befehle golden, Bedingungen grau, wenn nicht gesetzt."

-- The options page ---------------------------------------------------------------

L["A full reskin of tooltips. Changes apply the next time a tooltip opens."] =
    "Eine vollständige Neugestaltung der Tooltips. Änderungen gelten ab dem nächsten Öffnen eines Tooltips."
L["Open the style editor"] = "Stileditor öffnen"
L["Style editor"] = "Stileditor"
L["The look of every kind of tooltip, with a live sample: fonts, sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, as disenchant results, the spell power breakdown, and the health bar. Also /ptip."] =
    "Das Aussehen jeder Art von Tooltip, mit einem Beispiel: Schriften, Größen und Farben für jeden Teil, Textgröße, Tönungen und Deckkraft sowie die Details jeder Art, etwa Entzauberungsergebnisse, die Zaubermacht-Aufteilung und die Gesundheitsleiste. Auch mit /ptip."
L["Restyled Tooltips"] = "Neu gestaltete Tooltips"
L["Restyle"] = "Neu gestalten"
L["Follow cursor"] = "Mauszeiger folgen"
L["Disable in combat"] = "Im Kampf deaktivieren"
L["Use the default tooltip position during combat, then resume following the cursor afterward."] =
    "Im Kampf die Standardposition des Tooltips verwenden und danach wieder dem Mauszeiger folgen."
L["Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip, with the details modifier's rows added to it."] =
    "Zeichnet den PrettyTooltip-Rahmen. Aus: Diese Art behält den Tooltip des Spiels, ergänzt um die Zeilen der Zusatztaste für Details."
L["Not restyled yet; this kind keeps the game's own tooltip."] =
    "Noch nicht neu gestaltet; diese Art behält den Tooltip des Spiels."
L["Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags and other panels keep theirs. Off, its position is left to the game and other addons."] =
    "Zeigt den Tooltip dieser Art am Mauszeiger, wenn das Spiel ihn in seine Standardecke setzen würde; Taschen und andere Fenster behalten ihre Position. Aus: Die Position bleibt dem Spiel und anderen Addons überlassen."
L["Restyle items"] = "Gegenstände neu gestalten"
L["Restyle spells"] = "Zauber neu gestalten"
L["Restyle players and npcs"] = "Spieler und NSCs neu gestalten"
L["Restyle buffs and debuffs"] = "Stärkungen und Schwächungen neu gestalten"
L["Restyle herbs, ore, chests, and other objects"] = "Kräuter, Erz, Truhen und andere Objekte neu gestalten"
L["Restyle flight paths"] = "Flugrouten neu gestalten"
L["Restyle quests"] = "Quests neu gestalten"
L["Restyle macros"] = "Makros neu gestalten"
L["Restyle currencies"] = "Währungen neu gestalten"
L["Restyle dungeon and raid lockouts"] = "Dungeon- und Schlachtzugssperren neu gestalten"
L["Restyle pet abilities"] = "Begleiterfähigkeiten neu gestalten"
L["Restyle minimap"] = "Minikarte neu gestalten"
L["Restyle mounts, toys, and pets"] = "Reittiere, Spielzeuge und Haustiere neu gestalten"
L["Restyle achievements"] = "Erfolge neu gestalten"
L["Restyle totems"] = "Totems neu gestalten"
L["Restyle flyout buttons"] = "Ausklappleisten neu gestalten"
L["Players and NPCs"] = "Spieler und NSCs"
L["Buffs and debuffs"] = "Stärkungen und Schwächungen"
L["Herbs, ore, chests, and other objects"] = "Kräuter, Erz, Truhen und andere Objekte"
L["Flight paths"] = "Flugrouten"
L["Currencies"] = "Währungen"
L["Dungeon and raid lockouts"] = "Dungeon- und Schlachtzugssperren"
L["Pet abilities"] = "Begleiterfähigkeiten"
L["Minimap"] = "Minikarte"
L["Mounts, toys, and pets"] = "Reittiere, Spielzeuge und Haustiere"
L["Achievements"] = "Erfolge"
L["Totems"] = "Totems"
L["Flyout buttons"] = "Ausklappleisten"
L["Layout Style"] = "Layout-Stil"
L["PrettyTooltip"] = "PrettyTooltip"
L["Draw the PrettyTooltip panel for each kind turned on under Restyled Tooltips."] =
    "Zeichnet den PrettyTooltip-Rahmen für jede Art, die unter „Neu gestaltete Tooltips“ eingeschaltet ist."
L["Keep the game's own tooltips. Item Equip effects are shortened, and the details modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs."] =
    "Behält die Tooltips des Spiels. Anlegen-Effekte von Gegenständen werden gekürzt, und die Zusatztaste für Details fügt Entzauberungsergebnisse, die Aufschlüsselung der Zaubermacht und Raten, Sammelinhalte und IDs hinzu."
L["Default Tooltip Modifier"] = "Zusatztaste für den Standard-Tooltip"
L["Ctrl"] = "Strg"
L["Alt"] = "Alt"
L["Never"] = "Nie"
L["Hold Ctrl to see the game's own tooltip instead of the panel."] =
    "Haltet Strg, um statt des Rahmens den Tooltip des Spiels zu sehen."
L["Hold Alt to see the game's own tooltip instead of the panel."] =
    "Haltet Alt, um statt des Rahmens den Tooltip des Spiels zu sehen."
L["Never show the game's own tooltip in place of the panel."] = "Nie den Tooltip des Spiels statt des Rahmens zeigen."
L["Tooltip Details Modifier"] = "Zusatztaste für Tooltip-Details"
L["Shift"] = "Umschalt"
L["Always Show"] = "Immer zeigen"
L["Hold Shift to see disenchant results, the spell power breakdown and rates, gathering contents, and IDs. Each can still be turned off in the style editor."] =
    "Haltet Umschalt, um Entzauberungsergebnisse, die Aufschlüsselung der Zaubermacht und Raten, Sammelinhalte und IDs zu sehen. Jedes lässt sich im Stileditor weiterhin ausschalten."
L["Always show disenchant results, the spell power breakdown and rates, gathering contents, and IDs, as each one's setting in the style editor allows."] =
    "Zeigt Entzauberungsergebnisse, die Aufschlüsselung der Zaubermacht und Raten, Sammelinhalte und IDs immer, soweit ihre Einstellung im Stileditor es erlaubt."
L["Style Editor Appearance"] = "Aussehen des Stileditors"
L["Blizzard"] = "Blizzard"
L["Use the game's settings frame borders and controls."] = "Die Rahmen und Steuerelemente der Spieleinstellungen nutzen."
L["Use the flat editor appearance."] = "Das flache Aussehen des Editors nutzen."

-- Commands and the report window.
L["PrettyTooltip: hover something first; there is no tooltip to dump."] =
    "PrettyTooltip: Zeigt zuerst auf etwas; es gibt keinen Tooltip zum Ausgeben."
L["PrettyTooltip: this tooltip cannot be read right now (%s)."] =
    "PrettyTooltip: Dieser Tooltip kann gerade nicht gelesen werden (%s)."
L["PrettyTooltip: the options cannot open during combat. Try again once it ends."] =
    "PrettyTooltip: Die Optionen lassen sich im Kampf nicht öffnen. Versucht es nach dem Kampf erneut."
L["Press Ctrl+C to copy the selected text, and paste it into your bug report."] =
    "Drückt STRG+C, um den markierten Text zu kopieren, und fügt ihn in Euren Fehlerbericht ein."
L["Select all"] = "Alles markieren"

-- The samples ---------------------------------------------------------------------
-- The names of quests, people, and places are the German client's where known;
-- a reviewer should check them against the client.

L["Axe"] = "Axt"
L["Plate"] = "Platte"
L["Polearm"] = "Stangenwaffe"
L["Mail"] = "Kette"
L["Consumable"] = "Verbrauchbar"
L["Plans"] = "Pläne"
L["Shields"] = "Schilde"
L["Human"] = "Mensch"
L["Humanoid"] = "Humanoid"
L["Beast"] = "Wildtier"
L["Innkeeper"] = "Gastwirt"
L["Your attacks have a chance to cleave a nearby enemy."] =
    "Eure Angriffe haben eine Chance, einen nahen Gegner mitzutreffen."
L["Wounds the target for 40 to 60 damage."] = "Verwundet das Ziel und verursacht 40 bis 60 Schaden."
L["Sample flavor text sits here, in gold."] = "Hier steht ein Beispiel für Beschreibungstext, in Gold."
L["Redemption Armor"] = "Rüstung der Erlösung"
L["Increases the amount healed by your Judgement of Light by 20."] =
    "Erhöht die durch Euer Richturteil des Lichts gewirkte Heilung um 20."
L["Reduces cooldown on your Lay on Hands by 12 min."] = "Verringert die Abklingzeit Eurer Handauflegung um 12 Min."
L["Dropped by: %s"] = "Beute von: %s"
L["Argent Dawn"] = "Argentumdämmerung"
L["Restores 1050 to 1750 health."] = "Stellt 1050 bis 1750 Gesundheit wieder her."
L["A schedule of gold pickups."] = "Ein Plan der Goldabholungen."
L["Hurls a fiery ball that causes 16 to 25 Fire damage and an additional 2 Fire damage over 4 sec."] =
    "Schleudert eine glühende Kugel, die 16 bis 25 Feuerschaden und im Verlauf von 4 Sek. zusätzlich 2 Feuerschaden verursacht."
L["Bashes the target with your shield for 8 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 6 sec."] =
    "Schlägt das Ziel mit Eurem Schild und verursacht 8 Schaden. Unterbricht außerdem das Zauberwirken und verhindert 6 Sek. lang jeden Zauber dieser Schule."
L["Heals a friendly target for 42 to 51."] = "Heilt ein befreundetes Ziel um 42 bis 51 Punkte."
L["Spell ID: %s"] = "Zauber-ID: %s"
L["Gathered here %s times"] = "Hier %s Mal gesammelt"
L["Bruiseweed"] = "Beulengras"
L["Mithril Deposit"] = "Mithrilvorkommen"
L["Battered Chest"] = "Ramponierte Truhe"
L["Sealed Supply Crate"] = "Versiegelte Vorratskiste"
L["Heavy Supplies"] = "Schwere Vorräte"
L["Supply Crate: 2/5"] = "Vorratskiste: 2/5"
L["Report to the quartermaster"] = "Meldet Euch beim Rüstmeister"
L["Defias Pillager"] = "Plünderer der Defias"
L["The Defias Brotherhood"] = "Die Bruderschaft der Defias"
L["Defias Pillager slain: 4/10"] = "Plünderer der Defias getötet: 4/10"
L["Innkeeper Farley"] = "Gastwirt Farley"
L["Mother Fang"] = "Mutter Fang"
L["Foe Reaper 4000"] = "Feindschnitter 4000"
L["Increases Stamina by 26."] = "Erhöht die Ausdauer um 26."
L["Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, and builds up as the Curse reaches its full duration."] =
    "Verursacht im Verlauf von 24 Sek. 84 Schattenschaden. Der Schaden ist anfangs gering und steigt, je näher der Fluch seiner vollen Dauer kommt."
L["Inflicts 9 Nature damage every 3 sec."] = "Fügt alle 3 Sek. 9 Naturschaden zu."
L["The Fury Runs Deep"] = "Tief empfundener Zorn"
L["Arugal Must Die"] = "Arugal muss sterben"
L["The Stockade"] = "Das Verlies"
L["Shadowfang Keep"] = "Burg Schattenfang"
L["Silverpine Forest"] = "Silberwald"
L["Wolves Across the Border"] = "Wölfe an der Grenze"
L["Dalar Dawnweaver"] = "Dalar Dämmerweber"
L["Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr."] =
    "Motley Garmason will, dass Ihr ihm Kam Tiefenzorns Kopf nach Dun Modr bringt."
L["Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner."] =
    "Erlegt die Wölfe östlich von Nordhain und bringt ihre Pfoten zu Eagan Peltskinner."
L["Dalar Dawnweaver wants Arugal dead and his head brought to him."] =
    "Dalar Dämmerweber will Arugal tot sehen und seinen Kopf haben."
L["Ended by"] = "Abgeschlossen bei"
L["Started by"] = "Begonnen bei"
L["Found in"] = "Zu finden in"
L["Rares"] = "Seltene"
