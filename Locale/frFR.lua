-- The French client: what the game has no string for, in French, and the
-- client's own names for skills, dispel types, quest kinds, and schools. It
-- loads after Locale\English.lua, so whatever it leaves out stays English.
-- Wordings marked "unconfirmed" are guesses until a French capture shows them.
local _, ns = ...
local locale = ns.Locale

locale.supported = true
locale.features = { coefficients = true }

local formats = locale.formats
formats.weaponSpeed = "Vitesse %s"
-- "Vous apprend à forger", "à concocter", "à fabriquer".
formats.recipeTeaches = "Utiliser : Vous apprend à %s"
-- Unconfirmed.
formats.baseManaCost = "%d%% du mana de base"
-- Unconfirmed: as the map's legend names them.
formats.rare = "Rare"
formats.rareElite = "Élite rare"

-- "Endurance +16 et Armure +100".
locale.listSeparators = { ", et ", " et ", ", " }

-- Descriptions name a school with its article: "dégâts de Feu", "d'Ombre",
-- "du Sacré", "des Arcanes"; "vos sorts de Givre".
locale.descriptions.school = { "dégâts %s", "sorts %s" }
locale.schoolWords = { Arcane = "des Arcanes", Fire = "de Feu", Frost = "de Givre", Holy = "du Sacré",
    Nature = "de Nature", Shadow = "d'Ombre", Holyfire = "de feu-sacré", Frostfire = "de givrefeu" }

-- Amounts and durations from the native Spell table (Forever 1.60.1.70450).
local descriptions = locale.descriptions
descriptions.clause = "^[^%d]-"
descriptions.range = { "%d à %d", "%d - %d", "%d-%d" }
descriptions.over = { "en %d s", "pendant %d s", "sur %d s" }
descriptions.overBefore = false
descriptions.eachSecond = "toutes les secondes pendant %d s"
descriptions.every = { "toutes les %d s", "toutes les %d sec", "toutes les %d secondes" }
descriptions.everyFor = "pendant %d s"
descriptions.lasts = "dure %d s"
descriptions.perSecondAfter = { "toutes les secondes" }
descriptions.units = { "s", "sec", "seconde", "secondes", "min", "minute", "minutes", "heure", "heures", "m", "mètre", "mètres", "cible", "cibles", "fois", "charges", "cumuls" }
descriptions.unitBoundaries = true
descriptions.heals = { "rend", "soigne", "soigner", "soins", "régénère", "absorbe" }

-- Older English equip wordings; the French client prints the game's own.
locale.statWordings = {}

local skills = locale.skills
skills.Alchemy = "Alchimie"
skills.Blacksmithing = "Forge"
skills.Enchanting = "Enchantement"
skills.Engineering = "Ingénierie"
skills.Leatherworking = "Travail du cuir"
skills.Tailoring = "Couture"
skills.Cooking = "Cuisine"
skills["First Aid"] = "Secourisme"
skills.Fishing = "Pêche"
skills.Mining = "Minage"
skills.Herbalism = "Herboristerie"
skills.Skinning = "Dépeçage"
skills.Lockpicking = "Crochetage"

local dispels = locale.dispels
dispels.Magic = "Magie"
dispels.Curse = "Malédiction"
dispels.Disease = "Maladie"
dispels.Poison = "Poison"

locale.questTags = { ["Élite"] = true, Donjon = true, Raid = true, Groupe = true, JcJ = true }

-- The addon's own words: a first draft, for a French speaker to review.
local L = ns.L

-- The panels -------------------------------------------------------------------

-- The spell strip. French spells measure their range in meters.
L["Cast"] = "Incantation"
L["Cooldown"] = "Recharge"
L["Range"] = "Portée"
L["Cost"] = "Coût"
L["Free"] = "Gratuit"
L["None"] = "Aucune"
L["Self"] = "Soi-même"
L["%s yd"] = "%s m"
L["Base Mana"] = "Mana de base"
L["Next Rank"] = "Rang suivant"
L["Rank %s"] = "Rang %s"

-- Items. The requirement follows what is required, as "Niveau 40 requis".
L["%s Slot"] = "%s emplacement"
L["%s Slots"] = "%s emplacements"
L["Requires %s %s"] = "%s %s requis"
L["Recipe"] = "Recette"
L["Made by %s"] = "Fabriqué par %s"
L["Expected value"] = "Valeur estimée"
L["iLvl %s"] = "NI %s"
L["Creates"] = "Crée"
L["Reagents"] = "Composants"
L["Equipped"] = "Équipé"
L["Equipped With"] = "Équipé avec"

-- Auras, flight paths, macros, and pet abilities.
L["Buff"] = "Amélioration"
L["Debuff"] = "Affaiblissement"
L["%s stacks"] = "%s cumuls"
L["No time limit"] = "Sans limite de temps"
L["by %s"] = "par %s"
L["You are here"] = "Vous êtes ici"
L["Macro"] = "Macro"
L["Macro: %s"] = "Macro : %s"
L["Autocast"] = "Auto"
L["Autocast off"] = "Auto désactivé"
L["Active"] = "Actif"

-- World objects.
L["Herb"] = "Herbe"
L["Mining node"] = "Gisement"
L["Fishing pool"] = "Banc de poissons"
L["Quest object"] = "Objet de quête"
L["Auction"] = "Hôtel des ventes"
L["%s to %s"] = "%s à %s"
L["Your skill %s"] = "Votre compétence %s"

-- Quests and units.
L["Legendary"] = "Légendaire"
L["Heroic"] = "Héroïque"
L["Group"] = "Groupe"
L["Scenario"] = "Scénario"
L["World event"] = "Événement mondial"
L["Completed"] = "Terminée"
L["Ready to turn in"] = "À rendre"
L["In progress"] = "En cours"
L["AFK"] = "ABS"
L["DND"] = "NPD"

-- The spell power rows.
L["Healing per Second"] = "Soins par seconde"
L["Healing per Mana"] = "Soins par point de mana"
L["Damage per Mana"] = "Dégâts par point de mana"
L["Spell Power Coefficient"] = "Coefficient de puissance des sorts"
L["Spell Power Coefficient over time"] = "Coefficient de puissance des sorts sur la durée"
L["Healing Power Coefficient"] = "Coefficient de puissance des soins"
L["Healing Power Coefficient over time"] = "Coefficient de puissance des soins sur la durée"
L["each"] = "chacun"

-- Stats --------------------------------------------------------------------------

L["All Stats"] = "Toutes les caractéristiques"
L["Attack Power vs %s"] = "Puissance d'attaque contre les %s"
L["Hit Chance"] = "Chances de toucher"
L["Critical Strike Chance"] = "Chances de coup critique"
L["Hit Rating"] = "Score de toucher"
L["Critical Strike Rating"] = "Score de coup critique"
L["Haste Rating"] = "Score de hâte"
L["Expertise Rating"] = "Score d'expertise"
L["Defense Skill"] = "Compétence en défense"
L["Defense Rating"] = "Score de défense"
L["Dodge Chance"] = "Chances d'esquive"
L["Dodge Rating"] = "Score d'esquive"
L["Parry Chance"] = "Chances de parade"
L["Parry Rating"] = "Score de parade"
L["Block Chance"] = "Chances de blocage"
L["Block Rating"] = "Score de blocage"
L["Shield Block Value"] = "Valeur de blocage du bouclier"
L["Resilience Rating"] = "Score de résilience"
L["All Resistances"] = "Toutes les résistances"
L["Spell Damage Power"] = "Dégâts des sorts"
L["Spell Damage Power vs %s"] = "Dégâts des sorts contre les %s"
L["Spell Penetration"] = "Pénétration des sorts"
L["Spell Hit Chance"] = "Chances de toucher des sorts"
L["Spell Critical Strike Chance"] = "Chances de critique des sorts"
L["Spell Hit Rating"] = "Score de toucher des sorts"
L["Spell Critical Strike Rating"] = "Score de critique des sorts"
L["Spell Haste Rating"] = "Score de hâte des sorts"
-- The school's name follows in brackets: "Puissance des sorts (Feu)".
L["%s Spell Power"] = "Puissance des sorts (%s)"
L["%s Spell Damage Power"] = "Dégâts des sorts (%s)"
L["Healing Power"] = "Puissance des soins"
L["Health per 5 sec"] = "Vie toutes les 5 s"
L["Mana per 5 sec"] = "Mana toutes les 5 s"
L["Beasts"] = "bêtes"
L["Demons"] = "démons"
L["Dragonkin"] = "draconiens"
L["Elementals"] = "élémentaires"
L["Giants"] = "géants"
L["Humanoids"] = "humanoïdes"
L["Mechanical"] = "mécaniques"
L["Undead"] = "morts-vivants"

-- Stat categories, schools, and classes, as the style editor names them.
L["Primary attributes"] = "Caractéristiques principales"
L["Attack"] = "Attaque"
L["Defense"] = "Défense"
L["Magic"] = "Magie"
L["Healing"] = "Soins"
L["Mana"] = "Mana"
L["Negative values"] = "Valeurs négatives"
L["Arcane"] = "Arcanes"
L["Fire"] = "Feu"
L["Frost"] = "Givre"
L["Holy"] = "Sacré"
L["Nature"] = "Nature"
L["Shadow"] = "Ombre"
L["Holyfire"] = "Feu sacré"
L["Frostfire"] = "Givrefeu"
L["Warrior"] = "Guerrier"
L["Paladin"] = "Paladin"
L["Hunter"] = "Chasseur"
L["Rogue"] = "Voleur"
L["Priest"] = "Prêtre"
L["Shaman"] = "Chaman"
L["Mage"] = "Mage"
L["Warlock"] = "Démoniste"
L["Druid"] = "Druide"

-- The style editor ---------------------------------------------------------------

L["PrettyTooltip Style Editor"] = "Éditeur de style PrettyTooltip"
L["Click any part of the sample to restyle it. Tooltips use the new look the next time they open."] =
    "Cliquez sur une partie de l'exemple pour changer son style. Les infobulles prennent le nouveau style à leur prochaine ouverture."
L["Click any part of the sample to edit it."] = "Cliquez sur une partie de l'exemple pour la modifier."
L["%s: click to edit"] = "%s : cliquez pour modifier"
L["There is no item with ID %s."] = "Aucun objet n'a l'ID %s."
L["Loading item %s..."] = "Chargement de l'objet %s..."
L["The sample failed to draw: %s"] = "L'exemple n'a pas pu être dessiné : %s"
L["Nothing to show for %s ID %s."] = "Rien à afficher pour l'ID %s %s."
L["%s (not installed)"] = "%s (non installée)"
L["Custom"] = "Personnalisée"
L["Automatic"] = "Automatique"
L["ID, or shift-click a link"] = "ID, ou Maj-clic sur un lien"
L["Clear"] = "Effacer"
L["Reset to default"] = "Rétablir par défaut"
L["Click to choose its color; right-click for the default."] =
    "Cliquez pour choisir sa couleur ; clic droit pour la couleur par défaut."
L["Selected Part"] = "Partie sélectionnée"
L["Font"] = "Police"
L["Name font"] = "Police du nom"
L["Text font"] = "Police du texte"
L["Size"] = "Taille"
L["Color"] = "Couleur"
L["Outline"] = "Contour"
L["Same as global settings"] = "Comme les réglages généraux"
L["Thick outline"] = "Contour épais"
L["All caps"] = "Majuscules"
L["Letters"] = "Lettres"
L["Reset this part"] = "Rétablir cette partie"
L["All Tooltips"] = "Toutes les infobulles"
L["Game default"] = "Par défaut du jeu"
L["Text size"] = "Taille du texte"
L["Panel style"] = "Style du cadre"
L["Blizzard border"] = "Bordure Blizzard"
L["Flat"] = "Plat"
L["Padding"] = "Marge intérieure"
L["Min width"] = "Largeur min."
L["Icon on the right"] = "Icône à droite"
L["Moves the item or spell icon, and the item level badge under it, to the right of the name."] =
    "Place l'icône de l'objet ou du sort, et le niveau d'objet en dessous, à droite du nom."
L["Tint the panel"] = "Teinter le cadre"
L["Washes the panel in the item's quality color, or the spell's school or resource. Off, every panel is neutral; the name keeps its quality color."] =
    "Teinte le cadre de la couleur de qualité de l'objet, ou de l'école ou de la ressource du sort. Désactivé : chaque cadre est neutre, le nom garde sa couleur de qualité."
L["Separators"] = "Séparateurs"
L["The gold dividers between sections and the thin rules above other addons' rows. Off, they are hidden along with the space around them."] =
    "Les séparateurs dorés entre les sections et les fines lignes au-dessus des lignes des autres addons. Désactivé : ils sont masqués avec l'espace qui les entoure."
L["School colors"] = "Couleurs des écoles"
L["%s Panel"] = "Cadre : %s"
L["Show icon"] = "Afficher l'icône"
L["The icon or portrait in the header, for the kind of tooltip shown."] =
    "L'icône ou le portrait dans l'en-tête, pour le type d'infobulle affiché."
L["Band top"] = "Bande du haut"
L["Band bottom"] = "Bande du bas"
L["Backdrop"] = "Fond"
L["Glow"] = "Halo"
L["Footer"] = "Pied"
L["Item Details"] = "Détails des objets"
L["Spell Details"] = "Détails des sorts"
L["Unit Details"] = "Détails des unités"
L["Object Details"] = "Détails des objets du monde"
L["Quest Details"] = "Détails des quêtes"
L["Quest parchment"] = "Parchemin de quête"
L["DialogueUI's brown parchment for quest tooltips, Quest Items, and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed."] =
    "Le parchemin brun de DialogueUI pour les infobulles de quête, les objets de quête et les objets qui commencent une quête, avec une encre plus sombre pour la lisibilité. Nécessite DialogueUI."
L["Level badge"] = "Plaque de niveau"
L["The item level on a plate under the icon, for equipment."] =
    "Le niveau d'objet sur une plaque sous l'icône, pour l'équipement."
L["The level on a plate under the portrait. Off, the level stays in the info line."] =
    "Le niveau sur une plaque sous le portrait. Désactivé : le niveau reste dans la ligne d'information."
L["Stat markers"] = "Marqueurs de caractéristiques"
L["The small diamond before each stat; enchants use a green one."] =
    "Le petit losange devant chaque caractéristique ; les enchantements en ont un vert."
L["Stat colors"] = "Couleurs des caractéristiques"
L["Each kind of stat in its color below, and the school colors. Off, every stat is parchment."] =
    "Chaque type de caractéristique dans sa couleur ci-dessous, et les couleurs des écoles. Désactivé : toutes les caractéristiques sont couleur parchemin."
L["Abbreviated Equip Effects"] = "Effets Équipé abrégés"
L["Where the game's own item tooltip shows, in the Blizzard layout or with items not restyled, its Equip effects are shortened, as +1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit effects in their stat colors. Hold the default tooltip modifier for the full wording."] =
    "Là où l'infobulle d'objet du jeu s'affiche, dans la mise en page Blizzard ou pour les objets non restylés, ses effets Équipé sont raccourcis, comme +1% Chances de coup critique, et les couleurs du jeu gardées, sauf la puissance des sorts et les effets Chances quand vous touchez, dans leurs couleurs de caractéristique. Maintenez la touche pour l'infobulle du jeu pour le libellé complet."
L["Disenchant"] = "Désenchanter"
L["Green, blue, and purple armor and weapons list what they disenchant into, with each result's chance and the Enchanting it needs; with Auctionator, the expected value."] =
    "Les armures et armes vertes, bleues et violettes indiquent ce qu'elles donnent une fois désenchantées, avec la chance de chaque résultat et l'Enchantement requis ; avec Auctionator, la valeur estimée."
L["Sell price"] = "Prix de vente"
L["The vendor price in the footer; for a stack, the price of one and of the whole stack."] =
    "Le prix chez le marchand dans le pied ; pour une pile, le prix d'un objet et de la pile entière."
L["Swap Damage Stats"] = "Inverser les dégâts"
L["A weapon's damage on the large line, with its speed and damage per second on the small one under it."] =
    "Les dégâts d'une arme sur la grande ligne, sa vitesse et ses dégâts par seconde sur la petite ligne en dessous."
L["Spell power"] = "Puissance des sorts"
L["Under the description, each amount's spell power coefficient and its split into base and spell power. No game API has coefficients: they come from Forever's client data, and ones marked ~ are estimates."] =
    "Sous la description, le coefficient de puissance des sorts de chaque montant et sa répartition entre valeur de base et puissance des sorts. Aucune API du jeu ne donne les coefficients : ils viennent des données du client Forever, ceux marqués ~ sont des estimations."
L["Rates"] = "Débits"
L["Under the spell power breakdown, the average a cast deals or heals per second and per mana. Per second, what lands at once counts over the cast time (instants as the 1.5 sec global cooldown) and what comes over time over its duration. Crits and talents do not count."] =
    "Sous la répartition de puissance des sorts, la moyenne de dégâts ou de soins d'un sort par seconde et par point de mana. Par seconde, ce qui arrive d'un coup compte sur le temps d'incantation (les sorts instantanés comme le temps de recharge global de 1,5 s) et ce qui arrive sur la durée compte sur cette durée. Les critiques et les talents ne comptent pas."
L["Health bar"] = "Barre de vie"
L["The game's own health bar at the bottom of player and NPC panels. The game fills it, so it stays live without the addon reading health, which WoW Forever keeps from addons."] =
    "La barre de vie du jeu en bas des cadres des joueurs et des PNJ. Le jeu la remplit, elle reste donc à jour sans que l'addon lise la vie, que WoW Forever cache aux addons."
L["Gathering"] = "Récolte"
L["What a herb or ore node holds: its yield over all the times it can be gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. From Classic's loot tables."] =
    "Ce que contient une herbe ou un gisement : son rendement sur toutes les récoltes possibles, puis les pierres, gemmes et autres herbes qu'il peut donner, avec la chance à chaque fois. Sur une créature morte qui peut être dépecée, le Dépeçage requis et le cuir, les peaux et les écailles qu'elle peut donner. D'après les tables de butin de Classic."
L["Class colors"] = "Couleurs des classes"
L["Reset all fonts and colors"] = "Rétablir toutes les polices et couleurs"
L["More options"] = "Plus d'options"
L["IDs"] = "ID"
L["The item's, spell's, or NPC's ID at the bottom of its panel, under other addons' rows."] =
    "L'ID de l'objet, du sort ou du PNJ en bas de son cadre, sous les lignes des autres addons."
L["Item ID: %s"] = "ID d'objet : %s"
L["NPC ID: %s"] = "ID de PNJ : %s"

-- The kinds of tooltip, their samples' tabs, and the lookup by ID.
L["Items"] = "Objets"
L["Spells"] = "Sorts"
L["Objects"] = "Objets du monde"
L["Units"] = "Unités"
L["Buffs"] = "Auras"
L["Quests"] = "Quêtes"
L["Macros"] = "Macros"
L["Item ID"] = "ID d'objet"
L["Spell ID"] = "ID de sort"
L["Object ID"] = "ID d'objet du monde"
L["Unit ID"] = "ID d'unité"
L["Buff ID"] = "ID d'aura"
L["Quest ID"] = "ID de quête"
L["Macro ID"] = "ID de macro"
L["Weapon"] = "Arme"
L["Set piece"] = "Pièce d'ensemble"
L["Potion"] = "Potion"
L["Quest item"] = "Objet de quête"
L["Fireball"] = "Boule de feu"
L["Ability"] = "Technique"
L["Heal"] = "Soins"
L["Ore"] = "Minerai"
L["Chest"] = "Coffre"
L["Quest"] = "Quête"
L["Player"] = "Joueur"
L["Enemy"] = "Ennemi"
L["Vendor"] = "Marchand"
L["Rare"] = "Rare"
L["Rare elite"] = "Élite rare"
L["Boss"] = "Boss"
L["Curse"] = "Malédiction"
L["Poison"] = "Poison"
L["Ready"] = "Prête"
L["New"] = "Nouvelle"
L["Targeting"] = "Ciblage"

-- The style parts, and what each says about its color.
L["Item name"] = "Nom de l'objet"
L["Quality color unless set."] = "Couleur de qualité, sauf réglage."
L["Type and slot"] = "Type et emplacement"
L["Half the quality color, red for a type you cannot use."] =
    "Demi-teinte de la couleur de qualité, rouge pour un type que vous ne pouvez pas utiliser."
L["Binding and level"] = "Lien et niveau"
L["The required level is red while you are below it."] = "Le niveau requis est rouge tant que vous ne l'avez pas."
L["Damage per second"] = "Dégâts par seconde"
L["Damage and speed"] = "Dégâts et vitesse"
L["Armor"] = "Armure"
L["Stats"] = "Caractéristiques"
L["Colored by category unless set."] = "Colorées par catégorie, sauf réglage."
L["Equip effects"] = "Effets Équipé"
L["On-hit numbers use the spell tooltip's school colors unless set."] =
    "Les chiffres des effets en touchant prennent les couleurs d'école de l'infobulle de sort, sauf réglage."
L["Enchants"] = "Enchantements"
L["Use and other effects"] = "Utiliser et autres effets"
L["Flavor text"] = "Texte d'ambiance"
L["Set name and count"] = "Nom et compte de l'ensemble"
L["Set pieces"] = "Pièces d'ensemble"
L["Owned pieces bright, missing ones grey, unless set."] = "Pièces possédées claires, manquantes grises, sauf réglage."
L["Set bonuses"] = "Bonus d'ensemble"
L["Active bonuses green, inactive ones grey, unless set."] = "Bonus actifs verts, inactifs gris, sauf réglage."
L["Other addons' rows"] = "Lignes des autres addons"
L["Durability, crafter, requirements, and sell price."] = "Durabilité, artisan, conditions et prix de vente."
L["Item level badge"] = "Plaque de niveau d'objet"
L["Crafted item's name"] = "Nom de l'objet fabriqué"
L["On recipes; quality color unless set."] = "Sur les recettes ; couleur de qualité, sauf réglage."
L["On recipes; the count you carry red while short, unless set."] =
    "Sur les recettes ; le nombre que vous portez en rouge s'il manque, sauf réglage."
L["Section captions"] = "Titres de section"
L["Creates and Reagents on recipes."] = "Crée et Composants sur les recettes."
L["Disenchant results"] = "Résultats de désenchantement"
L["The Enchanting needed red while yours is too low, grey without Enchanting, unless set."] =
    "L'Enchantement requis en rouge tant que le vôtre est trop bas, gris sans Enchantement, sauf réglage."
L["Spell name"] = "Nom du sort"
L["School and rank badges"] = "Plaques d'école et de rang"
L["Colored by school unless set."] = "Colorées par école, sauf réglage."
L["Cost, cast, cooldown, range"] = "Coût, incantation, recharge, portée"
L["The cost takes its resource color unless set."] = "Le coût prend la couleur de sa ressource, sauf réglage."
L["Strip captions"] = "Légendes du bandeau"
L["Requirements and details"] = "Conditions et détails"
L["Unmet requirements red, time remaining orange, unless set."] =
    "Conditions non remplies en rouge, temps restant en orange, sauf réglage."
L["Description"] = "Description"
L["Numbers in the school color unless set."] = "Chiffres dans la couleur de l'école, sauf réglage."
L["Object name"] = "Nom de l'objet du monde"
L["Kind of object"] = "Type d'objet du monde"
L["Tinted by the skill it needs, unless set."] = "Teinté selon la compétence requise, sauf réglage."
L["Skill and requirements"] = "Compétence et conditions"
L["The skill in its skill-up color, unmet requirements red, unless set."] =
    "La compétence dans sa couleur de progression, conditions non remplies en rouge, sauf réglage."
L["Quest lines"] = "Lignes de quête"
L["Quest names gold, finished objectives green, unless set."] =
    "Noms de quête dorés, objectifs remplis en vert, sauf réglage."
L["Contents"] = "Contenu"
L["A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. Turned off by Gathering contents in the options."] =
    "Le rendement d'une herbe ou d'un gisement sur toutes ses récoltes, puis ce qu'il peut contenir d'autre, avec la chance à chaque récolte. Désactivé par Récolte dans les options."
L["Prices"] = "Prix"
L["The yielded item's sell price, and its auction price with Auctionator."] =
    "Le prix de vente de l'objet récolté, et son prix aux enchères avec Auctionator."
L["Name"] = "Nom"
L["Class color for players, reaction color for NPCs, unless set."] =
    "Couleur de classe pour les joueurs, couleur de réaction pour les PNJ, sauf réglage."
L["Guild or role"] = "Guilde ou fonction"
L["Level, race, and class"] = "Niveau, race et classe"
L["The level in its difficulty color, unless set."] = "Le niveau dans sa couleur de difficulté, sauf réglage."
L["Badges"] = "Plaques"
L["Elite, rare, faction, PvP, AFK, and dead."] = "Élite, rare, faction, JcJ, ABS et mort."
L["Skinning"] = "Dépeçage"
L["On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what it may give. Turned off by Gathering contents in the options."] =
    "Sur une créature morte qui peut être dépecée : le Dépeçage requis, dans sa couleur de progression, et ce qu'elle peut donner. Désactivé par Récolte dans les options."
L["Target and owner"] = "Cible et propriétaire"
L["Buff or debuff, dispel type in the game's colors, and stacks."] =
    "Amélioration ou affaiblissement, type de dissipation dans les couleurs du jeu, et cumuls."
L["Numbers in the aura's color unless set."] = "Chiffres dans la couleur de l'aura, sauf réglage."
L["Time and caster"] = "Durée et lanceur"
L["Quest name"] = "Nom de la quête"
L["Dungeon"] = "Donjon"
L["The level in its difficulty color, tags, and where the quest stands."] =
    "Le niveau dans sa couleur de difficulté, les mentions et l'avancement de la quête."
L["Section caption"] = "Titre de section"
L["Objectives"] = "Objectifs"
L["Finished objectives green unless set."] = "Objectifs remplis en vert, sauf réglage."
L["Macro lines"] = "Lignes de macro"
L["Commands gold, conditions grey, unless set."] = "Commandes dorées, conditions grises, sauf réglage."

-- The options page ---------------------------------------------------------------

L["A full reskin of tooltips. Changes apply the next time a tooltip opens."] =
    "Une refonte complète des infobulles. Les changements s'appliquent à la prochaine ouverture d'une infobulle."
L["Open the style editor"] = "Ouvrir l'éditeur de style"
L["Style editor"] = "Éditeur de style"
L["The look of every kind of tooltip, with a live sample: fonts, sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, as disenchant results, the spell power breakdown, and the health bar. Also /ptip."] =
    "L'apparence de chaque type d'infobulle, avec un exemple : polices, tailles et couleurs de chaque partie, taille du texte, teintes et opacités, et les détails propres à chaque type, comme les résultats de désenchantement, la répartition de puissance des sorts et la barre de vie. Aussi avec /ptip."
L["Restyled Tooltips"] = "Infobulles restylées"
L["Restyle"] = "Restyler"
L["Follow cursor"] = "Suivre le curseur"
L["Disable in combat"] = "Désactiver en combat"
L["Use the default tooltip position during combat, then resume following the cursor afterward."] =
    "Utiliser la position par défaut de l’infobulle en combat, puis suivre à nouveau le curseur après le combat."
L["Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip, with the details modifier's rows added to it."] =
    "Dessine le cadre PrettyTooltip. Désactivé : ce type garde l'infobulle du jeu, complétée des lignes de la touche des détails."
L["Not restyled yet; this kind keeps the game's own tooltip."] =
    "Pas encore restylé ; ce type garde l'infobulle du jeu."
L["Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags and other panels keep theirs. Off, its position is left to the game and other addons."] =
    "Affiche l'infobulle de ce type au curseur quand le jeu la mettrait dans son coin par défaut ; les sacs et les autres fenêtres gardent la leur. Désactivé : sa position est laissée au jeu et aux autres addons."
L["Restyle items"] = "Restyler les objets"
L["Restyle spells"] = "Restyler les sorts"
L["Restyle players and npcs"] = "Restyler les joueurs et les PNJ"
L["Restyle buffs and debuffs"] = "Restyler les améliorations et affaiblissements"
L["Restyle herbs, ore, chests, and other objects"] = "Restyler les herbes, minerais, coffres et autres objets"
L["Restyle flight paths"] = "Restyler les trajets aériens"
L["Restyle quests"] = "Restyler les quêtes"
L["Restyle macros"] = "Restyler les macros"
L["Restyle currencies"] = "Restyler les monnaies"
L["Restyle dungeon and raid lockouts"] = "Restyler les verrous de donjon et de raid"
L["Restyle pet abilities"] = "Restyler les techniques de familier"
L["Restyle minimap"] = "Restyler la minicarte"
L["Restyle mounts, toys, and pets"] = "Restyler les montures, jouets et mascottes"
L["Restyle achievements"] = "Restyler les hauts faits"
L["Restyle totems"] = "Restyler les totems"
L["Restyle flyout buttons"] = "Restyler les boutons déroulants"
L["Players and NPCs"] = "Joueurs et PNJ"
L["Buffs and debuffs"] = "Améliorations et affaiblissements"
L["Herbs, ore, chests, and other objects"] = "Herbes, minerais, coffres et autres objets"
L["Flight paths"] = "Trajets aériens"
L["Currencies"] = "Monnaies"
L["Dungeon and raid lockouts"] = "Verrous de donjon et de raid"
L["Pet abilities"] = "Techniques de familier"
L["Minimap"] = "Minicarte"
L["Mounts, toys, and pets"] = "Montures, jouets et mascottes"
L["Achievements"] = "Hauts faits"
L["Totems"] = "Totems"
L["Flyout buttons"] = "Boutons déroulants"
L["Layout Style"] = "Style de mise en page"
L["PrettyTooltip"] = "PrettyTooltip"
L["Draw the PrettyTooltip panel for each kind turned on under Restyled Tooltips."] =
    "Dessine le cadre PrettyTooltip pour chaque type activé sous Infobulles restylées."
L["Keep the game's own tooltips. Item Equip effects are shortened, and the details modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs."] =
    "Garde les infobulles du jeu. Les effets Équipé des objets sont raccourcis, et la touche des détails ajoute les résultats de désenchantement, la répartition de puissance des sorts et les débits, le contenu des récoltes et les ID."
L["Default Tooltip Modifier"] = "Touche pour l'infobulle du jeu"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Never"] = "Jamais"
L["Hold Ctrl to see the game's own tooltip instead of the panel."] =
    "Maintenez Ctrl pour voir l'infobulle du jeu au lieu du cadre."
L["Hold Alt to see the game's own tooltip instead of the panel."] =
    "Maintenez Alt pour voir l'infobulle du jeu au lieu du cadre."
L["Never show the game's own tooltip in place of the panel."] = "Ne jamais afficher l'infobulle du jeu à la place du cadre."
L["Tooltip Details Modifier"] = "Touche des détails d'infobulle"
L["Shift"] = "Maj"
L["Always Show"] = "Toujours afficher"
L["Hold Shift to see disenchant results, the spell power breakdown and rates, gathering contents, and IDs. Each can still be turned off in the style editor."] =
    "Maintenez Maj pour voir les résultats de désenchantement, la répartition de puissance des sorts et les débits, le contenu des récoltes et les ID. Chacun peut toujours être désactivé dans l'éditeur de style."
L["Always show disenchant results, the spell power breakdown and rates, gathering contents, and IDs, as each one's setting in the style editor allows."] =
    "Affiche toujours les résultats de désenchantement, la répartition de puissance des sorts et les débits, le contenu des récoltes et les ID, selon le réglage de chacun dans l'éditeur de style."
L["Style Editor Appearance"] = "Apparence de l'éditeur de style"
L["Blizzard"] = "Blizzard"
L["Use the game's settings frame borders and controls."] = "Utiliser les bordures et contrôles des options du jeu."
L["Use the flat editor appearance."] = "Utiliser l'apparence plate de l'éditeur."

-- Commands and the report window.
L["PrettyTooltip: hover something first; there is no tooltip to dump."] =
    "PrettyTooltip : survolez d'abord quelque chose ; il n'y a pas d'infobulle à afficher."
L["PrettyTooltip: this tooltip cannot be read right now (%s)."] =
    "PrettyTooltip : cette infobulle ne peut pas être lue pour l'instant (%s)."
L["PrettyTooltip: the options cannot open during combat. Try again once it ends."] =
    "PrettyTooltip : les options ne peuvent pas s'ouvrir en combat. Réessayez une fois le combat terminé."
L["Press Ctrl+C to copy the selected text, and paste it into your bug report."] =
    "Appuyez sur Ctrl+C pour copier le texte sélectionné, et collez-le dans votre rapport de bug."
L["Select all"] = "Tout sélectionner"

-- The samples ---------------------------------------------------------------------
-- The names of quests, people, and places are the French client's where known;
-- a reviewer should check them against the client.

L["Axe"] = "Hache"
L["Plate"] = "Plaques"
L["Polearm"] = "Arme d'hast"
L["Mail"] = "Mailles"
L["Consumable"] = "Consommable"
L["Plans"] = "Plans"
L["Shields"] = "Boucliers"
L["Human"] = "Humain"
L["Humanoid"] = "Humanoïde"
L["Beast"] = "Bête"
L["Innkeeper"] = "Aubergiste"
L["Your attacks have a chance to cleave a nearby enemy."] =
    "Vos attaques ont une chance de frapper aussi un ennemi proche."
L["Wounds the target for 40 to 60 damage."] = "Blesse la cible et lui inflige 40 à 60 points de dégâts."
L["Sample flavor text sits here, in gold."] = "Un exemple de texte d'ambiance, en or."
L["Redemption Armor"] = "Armure de Rédemption"
L["Increases the amount healed by your Judgement of Light by 20."] =
    "Augmente de 20 les soins prodigués par votre Jugement de lumière."
L["Reduces cooldown on your Lay on Hands by 12 min."] = "Réduit de 12 min le temps de recharge de votre Imposition des mains."
L["Dropped by: %s"] = "Butin de : %s"
L["Argent Dawn"] = "Aube d'argent"
L["Restores 1050 to 1750 health."] = "Rend 1050 à 1750 points de vie."
L["A schedule of gold pickups."] = "Un calendrier des collectes d'or."
L["Hurls a fiery ball that causes 16 to 25 Fire damage and an additional 2 Fire damage over 4 sec."] =
    "Projette une boule enflammée qui inflige 16 à 25 points de dégâts de Feu et 2 points de dégâts de Feu supplémentaires en 4 s."
L["Bashes the target with your shield for 8 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 6 sec."] =
    "Frappe la cible avec votre bouclier et lui inflige 8 points de dégâts. Interrompt aussi l'incantation et empêche tout sort de cette école pendant 6 s."
L["Heals a friendly target for 42 to 51."] = "Rend 42 à 51 points de vie à une cible alliée."
L["Spell ID: %s"] = "ID de sort : %s"
L["Gathered here %s times"] = "Récolté ici %s fois"
L["Bruiseweed"] = "Doulourante"
L["Mithril Deposit"] = "Gisement de mithril"
L["Battered Chest"] = "Coffre cabossé"
L["Sealed Supply Crate"] = "Caisse de ravitaillement scellée"
L["Heavy Supplies"] = "Ravitaillement lourd"
L["Supply Crate: 2/5"] = "Caisse de ravitaillement : 2/5"
L["Report to the quartermaster"] = "Faire votre rapport à l'intendant"
L["Defias Pillager"] = "Pillard défias"
L["The Defias Brotherhood"] = "La Confrérie défias"
L["Defias Pillager slain: 4/10"] = "Pillard défias tué : 4/10"
L["Innkeeper Farley"] = "Aubergiste Farley"
L["Mother Fang"] = "Mère Croc"
L["Foe Reaper 4000"] = "Faucheur d'ennemis 4000"
L["Increases Stamina by 26."] = "Augmente l'Endurance de 26."
L["Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, and builds up as the Curse reaches its full duration."] =
    "Inflige 84 points de dégâts d'Ombre en 24 s. Ces dégâts sont faibles au début et augmentent à mesure que la Malédiction approche de sa durée totale."
L["Inflicts 9 Nature damage every 3 sec."] = "Inflige 9 points de dégâts de Nature toutes les 3 s."
L["The Fury Runs Deep"] = "Fureur dans les Profondeurs"
L["Arugal Must Die"] = "Arugal doit mourir"
L["The Stockade"] = "La Prison"
L["Shadowfang Keep"] = "Donjon d'Ombrecroc"
L["Silverpine Forest"] = "Forêt des Pins-Argentés"
L["Wolves Across the Border"] = "Les loups derrière la frontière"
L["Dalar Dawnweaver"] = "Dalar Tisseaube"
L["Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr."] =
    "Motley Garmason veut que vous lui rapportiez la tête de Kam Furie-du-fond à Dun Modr."
L["Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner."] =
    "Éliminez les loups à l'est de Comté-du-Nord et rapportez leurs pattes à Eagan Peltskinner."
L["Dalar Dawnweaver wants Arugal dead and his head brought to him."] =
    "Dalar Tisseaube veut la mort d'Arugal et qu'on lui rapporte sa tête."
L["Ended by"] = "Terminée auprès de"
L["Started by"] = "Commencée auprès de"
L["Found in"] = "Se trouve à"
L["Rares"] = "Rares"
