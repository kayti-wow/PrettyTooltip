# PrettyTooltip

A full reskin of tooltips for WoW Forever and retail World of Warcraft. PrettyTooltip replaces the game's tooltip with a compact, ornamented panel: the icon and name up front, the details in short colored rows grouped by kind, and the fine print gathered in a footer. Hold **ALT** (or the key you choose) at any time to see the game's own tooltip.

## Forever and retail

One download serves both games: Forever loads `PrettyTooltip_Camelot.toc`, retail `PrettyTooltip_Mainline.toc`. Forever's file needs its own suffix: Forever counts as a Mainline game too, and would load retail's file over a plain `PrettyTooltip.toc`. Retail leaves out what comes from Classic's data, as no retail source exists for it: disenchant results, spell power coefficients, and herb, ore, and skinning loot. Their settings are hidden there. Spell schools come from retail's own spell tables, and damage and healing rates from the description alone, with the global cooldown after haste.

## Item tooltips

Top to bottom, an item panel shows:

- **Header.** The icon with an item level badge, the name in its quality color, and a subtitle with the item's type and slot, such as `Mail · Head` or `Staff · Two-Hand`. The subtitle also names what the game leaves unsaid: `Consumable · Potion`, `Crafting Reagent`, `Scarce`. The binding sits below it, with the required level at the right, red while you are below it. The whole panel is tinted by quality; quest items, and items that begin a quest, are tinted quest gold.
- **Retail's source, upgrade, and transmogrification.** On retail, where the item comes from (`Heroic`, `Mythic`) sits under its name, its upgrade level (`Myth 2/6`) under the subtitle, and what it is transmogrified to, with any weapon illusion, after the binding. A crafted item's quality, with the game's quality icon, follows the upgrade level. Each is its own part in the style editor: **Source**, **Upgrade level**, **Crafted quality**, and **Transmogrification**.
- **Gems and sockets.** On retail, after the enchants: each socketed gem with its icon and its stat in that stat's color, its enchantment indented under it, empty sockets with the game's socket icon, and the socket bonus, green once active. The style editor's **Gems and sockets** part sets their look, and its **Socket hint** switch hides the game's `<Shift Right Click to Socket>` line.
- **Weapon damage.** DPS as the prominent row, with damage and speed beneath it.
- **Armor and stats.** Armor (and a shield's block under it), then the stats in two blocks: the primary attributes, and everything else under a divider. Long stat wording is shortened (see below), and each stat is colored by kind. On retail, the primary stats your specialization does not use stay grey, as the game shows them. Retail's Critical Strike, Haste, Mastery, and Versatility each have a color of their own, and Leech, Avoidance, and Speed share one; set them under **Secondary stat colors** in the style editor, and their font under its **Secondary stats** part.
- **Equip effects and enchants.** Equip effects that are not a plain stat, such as a zone-limited speed bonus, join the stat list in green without the `Equip:` prefix. A chance on hit joins them too, marked with a small sword instead of its `Chance on hit:` prefix. Its numbers follow the spell tooltip's highlighting: a lighter school color when the description names that school's damage, or a neutral highlight otherwise. Holyfire blends Holy and Fire. These highlights follow **Stat colors** and a custom **Equip effects** color in the panel. Enchants follow as green rows marked with a sparkle, one per bonus: `Enchanted: Stamina +1 and Armor +8` becomes `+1 Stamina` and `+8 Armor`.
- **Use effects and flavor text,** as the game words them, each use effect marked with a small gear instead of its `Use:` prefix.
- **Item set.** The set name and how many pieces you own, the pieces you own highlighted, and the set bonuses, with active ones highlighted.
- **Disenchant.** For green, blue, and purple armor and weapons: what the item disenchants into, each result with its icon, count, and chance, and the Enchanting it needs, red while your skill is too low and grey if you have no Enchanting. The chances are Classic's published tables (Warcraft Wiki's *Disenchanting tables*); the game has no way to ask. Turned off under **Item Details** in the style editor.
- **Footer.** Durability as a small bar, the crafter's name for crafted items, other requirements such as skills or classes, and the sell price as coins alone; a stack shows its total first, then the count and one item's price, dimmed (`2g  (20 × 10s)`), which can be turned off under **Item Details** in the style editor.

While the game shows a comparison, the comparison panels are tagged **Equipped**, and the game's own "If you replace this item" stat changes appear among the rows at the bottom, in their usual green and red.

Recipes are the recipe first: their own icon and name, `Plans · Blacksmithing` beneath, and the skill they need beside the binding, red while yours is too low. The item they craft follows under **Creates** as a smaller card with its icon, name, slot, required level, and its own armor, stats, and effects, then the **Reagents** with their icons and how many you carry (`4 / 10`, red while short).

### Shorter stats

Common Equip wordings become short stat rows:

| The game says | PrettyTooltip shows |
| --- | --- |
| Equip: Increases healing done by up to 48 and damage done by up to 16 for all magical spells and effects. | +48 Healing Power<br>+16 Spell Damage Power |
| Equip: Increases damage and healing done by magical spells and effects by up to 12. | +12 Spell Power |
| Equip: Increases damage done by Fire spells and effects by up to 20. | +20 Fire Spell Damage Power |
| Equip: Improves your chance to get a critical strike by 1%. | +1% Critical Strike Chance |
| Equip: Increased Defense +2. | +2 Defense Skill |
| Equip: Restores 3 mana per 5 sec. | +3 Mana per 5 sec |

**Spell Power** is a bonus to both damage and healing; **Spell Damage Power** is damage only. Hit, crit, dodge, parry, block, ratings, attack power, health regeneration, and spell penetration are shortened the same way. Wording PrettyTooltip does not recognize is shown as the game writes it.

### The Blizzard layout

With **Layout Style** set to **Blizzard** on the options page, every tooltip keeps the game's own look, and so does each kind whose **Restyle** box is off. Items keep the game's tooltip with selected Equip effects shortened as in the table above and the game's line colors kept, except for magic: spell power, spell hit and crit, penetration, and healing power in their stat colors, and the damage of chance on hit effects in its school's color, while **Stat colors** is on. Combined bonuses split into separate lines. **Abbreviated Equip Effects** under **Item Details** in the style editor turns this off.

While the **Tooltip Details Modifier** is held (Shift by default), the details a panel would show appear at the bottom of the game's tooltip, below every other addon's rows: disenchant results, the spell power breakdown and rates, gathering contents, and IDs, each as its switch in the style editor allows. They show and hide as the key is pressed and released, in combat too. Holding the **Default Tooltip Modifier** shows the game's tooltip as it is, with neither.

### Colors

Each stat value takes a color and its name a lighter shade of the same hue. The category colors are soft and evenly light, so every kind of stat reads alike on the dark panel, and the vivid spell school colors stand apart from them:

| Category | Color |
| --- | --- |
| Primary attributes | Ivory |
| Attack: attack power, hit, crit, haste | Amber |
| Defense: defense, dodge, parry, block | Steel blue |
| Magic: spell power, spell hit and crit, penetration | Lavender |
| Healing | Mint |
| Mana regeneration | Periwinkle |
| Spell schools and resistances | Arcane, Fire, Frost, Holy, Nature, and Shadow each in their own color |

Set **School colors** under **All Tooltips** in the style editor. The same choices color spell panels, school badges, highlighted numbers, item spell-power and resistance stats, school weapon damage, and macro accents. Holyfire and Frostfire have their own swatches; their panel gradients follow their two component schools. Click a swatch to choose its color, right-click it for the default, or use the row's reset to restore every school. With no overrides, the original colors are kept.

## Spell tooltips

Spells use the same panel: the icon and name, small badges for the spell's school, its rank, and **Passive** for passive spells and talents, and a strip with cost, cast time, cooldown, and range. On retail, a spell with charges shows its recharge in the cooldown cell, its most charges under the strip (**Charges** in the style editor), and the time left on the next charge in orange. The description follows one sentence per line, with its numbers highlighted.

The panel is tinted by the spell's school: a class spell's comes from WoW Forever's client spell data, which the addon carries, and any other spell's is read from the damage its description names (`Fire damage`) or a school that starts its name (`Holy Light`). Spells with neither are tinted by the resource they cost: blue for mana, red for rage, yellow for energy.

A spell that carries another spell inside its tooltip, such as Feral Charge with its Cat Form version, shows the inner spell as a second section with its own name, strip, requirements, and description. Talents get the spell panel too.

Spells that deal magic damage or heal show their spell power under the description: each amount's coefficient, one row for what lands at once and one for what comes over time, and the amount split into its base and what your spell power adds, as `Healing Power Coefficient` and `85.7% · 441 to 595 + 120`, the coefficient in the spell school's color. WoW Forever's tooltips already count your spell power in, so the base is the shown amount less spell power times the coefficient. No game API has coefficients, so the addon carries them: every rank of the caster classes' damage, healing, and absorb spells takes its own from Forever's client spell data, with the corrections in Blizzard's development notes, including what it hands to the spells it triggers, as a missile, an area's ticks, or a seal's strike. Other spells follow Classic's rules (cast time / 3.5, duration / 15), which Forever keeps without Classic's cap on spells over time or its penalty for spells learned before level 20; a coefficient marked `~` is the rules' estimate, and a channeled spell the addon has no data for shows none. Turned off under **Spell Details** in the style editor.

## Players and NPCs

Units under the cursor get a panel with their portrait, the name in class color (players) or reaction color (NPCs: red hostile, yellow neutral, green friendly, grey when tapped by someone else), the guild or an NPC's role, and the level, race, and class or creature type, the level in its difficulty color. Badges mark elites, rares, bosses, a player's faction, PvP, AFK, DND, and the dead. Below sit what the unit is targeting (in red when it is you), and the unit's quest lines. Rows other addons add are kept below, and the game's own health bar closes the panel; the game fills it, as WoW Forever keeps unit health from addons. Elites, rares, rare elites, and bosses show the dragon from the game's target frame behind the header, and players their faction's crest.

**Class colors** under **Unit Details** in the style editor has a swatch for each of the nine classes. Overrides apply to player names, panel tints and glows, the guild's lighter shade, player targets, and players on the minimap. Click to choose a color, right-click for the default, or reset the row to clear all class overrides. With no override, the game's current class color is used, including changes made by other addons.

## Buffs and debuffs

Auras show their icon and name, badges for buff or debuff, the dispel type in the game's colors (Magic, Curse, Disease, Poison), and stacks, then the description one sentence per line, the time left with who cast it, and a bar that drains as the aura runs out.

## Quests

With **DialogueUI** installed, enable **Quest parchment** under **Quest Details** or **Item Details** in the style editor for its brown parchment and darker ink. The shared toggle applies to quest tooltips, items marked **Quest Item**, and items that begin a quest; the **Quest item** sample on the Items tab previews it. It is off by default. Per-part custom text colors still take precedence, and the artwork is read from DialogueUI's folder.

Quest links read like a page of the quest log: the quest's name and the dungeon it is in, then badges for its level in the game's difficulty color, tags such as Elite or Dungeon, and where it stands (in progress, ready to turn in, completed, failed, repeatable). Below sit the quest giver's words in quotes and the objectives as a checklist with their progress, ticked and green once finished. The header has no icon unless **Show icon** is turned on in the style editor. With **Questie** installed, which draws quest links itself, the panel is built from Questie's tooltip, both for a clicked link and for one hovered in chat; who starts or ends the quest and where follow as label and value rows. Quests hovered in the world map's quest log get the same panel, with the level from your quest log; rows other addons add, such as a guide's note, are kept below.

## World objects

Herbs, ore, chests, and quest objects get a panel too. A herb or ore node shows the herb or ore it yields, with its icon; the skill it needs and the level, in the game's skill-up color (red while your skill is too low), beside your own skill; and in the footer the yield's sell price and, with **Auctionator** installed, its auction price. Locked chests show the lock and the Lockpicking they need, and quest objects show their quests and objectives. Rows other addons add, such as Questie's, are kept below.

## Working with other addons

- Rows other addons add to a tooltip are kept, below a thin rule in smaller, muted text, in their original order and colors.
- Comparison tooltips, screen-edge clamping, and anything anchored to the tooltip follow the panel's real size.
- With **DialogueUI** installed, the panel uses its dark tooltip backdrop, unless another **Panel style** is picked in the style editor. Text uses the game's own tooltip fonts, so a UI addon that changes the default font is followed; with **EllesmereUI** installed, names use its Expressway font. Both are used from those addons' own folders; nothing of theirs is bundled.
- Whenever a tooltip cannot be read safely, such as spell details restricted during combat, the game's own tooltip is shown instead.

## Style editor

The editor uses Blizzard's settings frame borders and native controls by default. Choose **Blizzard** or **Flat** under **AddOns > PrettyTooltip > Style Editor Appearance** in the game's settings. This choice affects the editor window; **Panel style** inside the editor controls the tooltips themselves.

Type `/ptip` (or `/prettytooltip`) to open the style editor, where everything about the tooltip's look is set. **Items**, **Spells**, **Objects**, **Units**, **Buffs**, and **Quests** switch between the kinds of panel. The editor shows a sample tooltip; click any part of it, such as the name, the stats, or a spell's description, to change that part's font, size, color, and outline. The samples (for items a weapon, the equipped item it is compared with, a set piece, and a potion; for spells a damage spell, an ability with a cooldown and an unmet requirement, and a heal, and on retail a spell with charges; for objects a herb, an ore node you cannot mine yet, a locked chest, and a quest object; for units a player, a hostile elite with a quest, a friendly innkeeper, a rare, a rare elite, and a boss; for buffs a buff, a curse, and a stacked poison; for quests one in progress, one ready to turn in, and one not taken) cover every part, and the editor switches to one that has the part you pick from its list.

To preview a real item or spell instead (objects, units, auras, and quests have no ID), type its ID in the box at the top right and press Enter, or click the box and shift-click the item or spell, as you would to link it in chat. **Clear**, or a sample tab, goes back to the samples.

The controls on the right follow the kind of panel shown, top to bottom (hover a setting for its description):

- **Selected Part**: the part you clicked, or picked from the list. **Font** offers every font registered with LibSharedMedia, which includes EllesmereUI's fonts when it is installed, plus the game's own; a part's own font overrides the ones below. A custom **Color** replaces every color the part would have had, including quality, category, and red or grey states; **Automatic** goes back to the normal colors. **All caps** is on by default for item, spell, and set names (off, they keep the game's capitalization) and off for every other part. **Reset this part** puts it back.
- **All Tooltips**: **Global scale** resizes every PrettyTooltip panel together, including text, icons, spacing, and bars, from 50% to 150% (100% by default). It is also on the main options page and preserves individual text settings. The text and name fonts, outline, **Text size** multiplier, **Panel style** (the game's tooltip border, flat, or DialogueUI's art), padding, and minimum width follow; **Icon on the right** moves the icon and its item level badge to the right of the name, **Tint the panel** off leaves every panel neutral (names keep their quality color), and **Separators** off hides the gold dividers and thin rules with the space around them.
- **School colors**, below the shared switches: a swatch for each of the six spell schools, followed by Holyfire and Frostfire. These colors apply across tooltip types, including item stats.
- **Items Panel**, **Spells Panel**, and so on, for the kind shown: **Show icon**, and the opacity of the header band at its top and bottom edges, of the panel's body (**Backdrop**), and of the soft rarity **Glow** around it.
- The kind's own details:
  - **Item Details**: the item level badge, the stat markers, **Stat colors** (off, every stat is parchment) with each stat category's color below, a swatch each (click to choose, right-click for the default; the stat's name takes a lighter shade), **Abbreviated Equip Effects** (see *The Blizzard layout* above), the disenchant section, and the sell price.
  - **Spell Details**: the spell power breakdown and the damage and healing rates under it; on retail, the rates alone.
  - **Unit Details**: the level badge (off, the level stays in the info line), the health bar, what a skinnable creature gives, and the nine **Class colors** swatches. Hover a swatch for its class name.
  - **Object Details**: what herbs and ore give: a node's yield over all its taps and the stone, gems, or other herbs it may give, with the chance each tap.

**Reset all fonts and colors** puts every part back and clears custom stat-category, school, and class colors. The restyle and detail switches keep their settings. Tooltips use the new look the next time they open.

## Options

Open the game's options, then **AddOns > PrettyTooltip**, or type `/ptip options`. The page opens the style editor, which has every setting about the look and each kind's details, and holds the rest; hover a setting for what it does.

- **Layout Style**: **PrettyTooltip** (the default) draws the panel for each kind turned on under **Restyled Tooltips**; **Blizzard** keeps the game's own tooltips everywhere, as described in *The Blizzard layout* above, and greys out the **Restyle** column.
- **Restyled Tooltips** is a table with a row for every kind of tooltip the game has: items, spells, players and NPCs, buffs and debuffs, herbs, ore, chests and other objects, quests, currencies, lockouts, pet abilities, the minimap, mounts, toys and pets, achievements, totems, and flyout buttons.
  - **Restyle**: **Items**, **Spells**, **Players and NPCs**, **Buffs and debuffs**, **Herbs, ore, chests, and other objects**, and **Quests** can each be turned off, and that kind then keeps the game's own tooltip, with the details added while their modifier is held. The other kinds are greyed out until PrettyTooltip restyles them.
  - **Follow cursor** (on by default for herbs, ore, chests, and other objects; off for the rest): the kind's tooltip appears at the cursor and follows it whenever the game would show it in its default corner, as for units, world objects, and action buttons. Tooltips that bags, the character pane, and other panels place beside themselves stay there. While it is off, PrettyTooltip leaves the tooltip's position to the game and to any other addon that places tooltips.
  - **Disable in combat**, under **Follow cursor** (on by default): use the default tooltip position during combat, then resume following the cursor afterward. Each kind's Follow cursor preference is kept.
- **Default Tooltip Modifier** picks the key you hold to see the game's own tooltip: CTRL, ALT (the default), or **Never**.

## Install

1. Download the release and extract the `PrettyTooltip` folder into your WoW Forever installation's `Interface\AddOns` folder.
2. Restart the game if it was running, and enable **PrettyTooltip** on the character select AddOns screen.

## Compatibility

- WoW Forever 1.60.1 (`## Interface: 16001`). Other clients may word their tooltips differently.
- English, German, French, Spanish (Spain and Latin America), Portuguese, Korean, Simplified Chinese, Traditional Chinese, and Russian clients, including localized spell power coefficients and rate rows. Translations outside English are drafts. Spell descriptions are read with each language's amount, duration, and tick wording; unrecognized descriptions can omit the extra rows. On unsupported languages the panel and stat rewriting stay off, though the options page still appears.

## Known limitations

- No game API names a spell's school. Class spells take theirs from the client data the addon carries; any other spell's is read from its text, so one that never names its damage type may get no school, or the wrong one if its name starts with one.
- Spell power coefficients are not read from the game. Those marked `~` are estimates, and a talent or effect that changes a spell's damage or healing makes its base off by that much.
- Profession recipe spells do not show the crafted item as an item panel.
- Herb and ore nodes show their yield, skill level, and prices only for the classic herbs and ores; other nodes show their skill alone. Chest and quest object tooltips are less tested.
- Stat wordings not in the table above are shown unchanged.

## Development

`python deploy.py` copies the game files into `D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns\PrettyTooltip`; pass `--addons-dir "<path to Interface\AddOns>"` for another installation. After a deploy, `/reload` picks up Lua changes; changes to the `.toc` need a game restart.

`/ptip dump` shows the raw data of the tooltip you are hovering, to see what a kind of tooltip carries, or the lines shown when an addon filled it without data. A link clicked in chat is dumped when nothing is hovered. `/ptip perf` measures for five seconds how often the panel's work runs and how long it takes. `/ptip anchors` shows where each shown panel sits, the gaps between them, and how the game's tooltips under them are anchored. `/ptip pixel` shows how lines are snapped to screen pixels at the current UI scale.

Each opens a window with its findings already selected, under a line naming the addon's version, the client build, and the locale: Ctrl+C copies them for a bug report, and Escape closes the window.

`/ptip capture <name>` saves the tooltip you are hovering, or a link clicked in chat, as a test fixture: its data, the lines it shows, any comparison tooltips beside it, and the game's answers its reader asks for (item, spell, and unit info, your level, spell power, and skills). Values the game hides, as on some player tooltips, are kept marked as hidden, and the tests play them back that way. Captures are kept in the `PrettyTooltipCaptures` saved variable, which the game writes on `/reload` or logout; `/ptip capture list` names them and `/ptip capture clear` removes them.

`tests/` runs the addon outside the game against captured tooltips and checks: `pip install -r tests/requirements.txt`, then `python tests/run.py`. `tests/README.md` describes capturing, importing, and the expected outputs.

`art/README.md` describes each texture and how it is made.
