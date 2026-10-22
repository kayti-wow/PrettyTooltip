# PrettyTooltip 1.3.6

## Tooltips

- Added **Mail** attachment summaries with item icons, quality-colored names, quantities, and a total item count. Auctionator's price rows appear beneath each attachment, with its total value in the footer. Mail has its own Restyle switch and style-editor preview; individual attachments keep their normal item tooltips.
- Added **Weapon imbues**: hovering a temporary weapon enchant shows the spell that applied it, its weapon slot, charges, and time remaining. Supported imbues include shaman weapon enchants, poisons, oils, and sharpening stones.
- Reworked comparison placement around the Pretty panels' own dimensions with a new, custom anchoring logic.
- Improved pixel alignment of tooltip text, borders, and other panel elements at different UI scales.

## Performance

- Reduced repeated item reads, rendering, and anchor changes during auction-house and comparison refreshes. Pretty placement no longer inflates hidden native tooltips to match the panels' dimensions.

## Bug reports

- Tooltip traces now include equipped comparison panels. Performance reports include placement and dragging measurements, and `/ptip perf <seconds>` accepts a capture duration.

# PrettyTooltip 1.3.5

## Performance

- ItemLite and Pretty item panels now use separate processing paths, avoiding duplicate work on the same tooltip.
- Added several skips and caching steps to minimize stutter on tooltip refresh, particularly in comparison mode.
- *Note: Please report any issues with the new item processing paths.*

## Tooltips

- Improved comparison panel sizing and anchoring while the game refreshes equipped items.
- Fixed flickering during tooltip anchoring and layout issues when reopening the same item.

## Style editor

- Fixed Lua errors in buff and macro previews, and improved sample styling.

# PrettyTooltip 1.3.4

## Options

- Fixed the **Global scale** slider's layout on the main options page: the percentage stays inside the settings window, and the slider uses the game's artwork without overlapping custom graphics.

# PrettyTooltip 1.3.3

## Tooltips

- Improved anchor restoration when the game rounds tooltip positions or adds a new anchor while the tooltip is temporarily off-screen.
- Class colors from other addons now take priority over the style editor's choices and update when those addons change their colors. The editor's class color swatches explain when another addon controls them.

# PrettyTooltip 1.3.2

## Options

- Added **Global scale** to resize all PrettyTooltip panels together, including text, icons, spacing, and bars, from 50% to 150%. Available on the main options page and under **All Tooltips** in the style editor. Individual text settings are preserved.
- Added **Swap Damage Stats** under **Item Details** in the style editor: weapon damage takes the large line, with DPS and speed beneath it. Off by default.

## Tooltips

- Improved anchor restoration between hovers, including when following the cursor, so tooltips do not retain their temporary off-screen position.
- Player and NPC tooltip panels now disappear immediately when the mouse leaves, without the lingering fade.
- Shield block value now appears alongside armor.
- Base weapon damage, DPS, armor, and block use steel-gray colors, with brighter numbers and dimmer labels.
- Scaled editor previews keep their clickable parts aligned and can scroll horizontally when enlarged.

# PrettyTooltip 1.3.1

## Layouts

- Added **Layout Style** to the options page: **PrettyTooltip** draws the panels as before, **Blizzard** keeps the game's own tooltips everywhere. In the Blizzard layout, or for a kind whose **Restyle** box is off, the game's tooltip shows the panel's details while the **Tooltip Details Modifier** is held: disenchant results, the spell power breakdown and rates, gathering contents, and IDs.
- **Lite tooltips** is now **Abbreviated Equip Effects**: item Equip effects are shortened wherever the game's item tooltip shows. If you had Lite tooltips on, items are no longer restyled, which gives the same tooltip.

## Tooltips

- Fixed the game's original tooltip showing under the panel as a world unit's tooltip fades, most noticeably in combat, and popping back up after combat when follow cursor is on.
- Fixed the panel briefly appearing at the tooltip's default anchor when moving between action buttons.
- NPC panels show the NPC's title next to its type ("Humanoid · Herbalism Supplier") and its faction above the PvP badge.
- Trainer recipes show the item they create, and their reagents in a list of their own, missing ones in red.
- "Locked" on chests keeps the game's color for how hard the lock is to pick, instead of always showing gray.
- Recipes no longer list their required skill as a reagent ("Cooking 0 / 80"), and show reagents listed without a count. Reagents no longer show icons, since the game only knows icons of items it has already loaded.

## Reliability

- The addon no longer changes the game's tooltip data or hides the game's tooltip, which reduces taint in combat.

## Bug reports

- Added `/ptip trace`: for a few seconds it records how the game's tooltips and their panels show, fade, and move, to copy into a bug report.

# PrettyTooltip 1.3.0

## Languages

- PrettyTooltip now works on German, French, Spanish (Spain and Mexico), Portuguese, Russian, Korean, and Simplified and Traditional Chinese clients, in addition to English. It relies heavily on built-in localization where possible. For custom addon text, we built separate per-language string tables and parsing logic. The translations are a first draft: please report anything that feels wrong.

## Tooltips

- Added the **Tooltip Details Modifier** option: disenchant results, the spell power breakdown and rates, gathering contents, and IDs show only while **Shift** is held, or always with **Always Show**. Shift is the default, which means the details stay hidden by default.
- Item, spell, and NPC panels can show the item, spell, or NPC ID at the bottom. You can turn it off with **IDs** under each panel's details in the style editor.
- Improved in-combat behavior of spell, item and unit tooltips.
- Fixed a few parsing bugs related to combo point finishers spells such as Rip.
- Improved tooltip cursor anchoring logic.
- Cursor anchoring now pauses in combat by default; change it with **Disable in combat** under **Follow cursor** in the options.
- Removed the darker band behind the footer and its opacity setting. I believe this option wasn't adding much value.

## Options

- The default tooltip modifier choices read **Ctrl** and **Alt**.
- `/ptip options` and the editor's **More options** now indicate when the game's settings window cannot open in combat.

## Reliability

- Hardened tooltip handling against values the game hides in combat and against restricted frames: a tooltip that cannot be read falls back to the game's own instead of raising an error, and the addon no longer hides the game's tooltip itself in combat.
- Fixed the "Error loading Locale/enUS.lua" Lua error at login on English clients.

# PrettyTooltip 1.2.1

## Tooltips

- Fixed comparison tooltips sliding under the hovered item's tooltip when they open to its left, as when comparing items from bags or action bars.

## Bug reports

- `/ptip anchors`, `/ptip perf`, `/ptip pixel`, and `/ptip dump` now open a window with their results already selected: press Ctrl+C to copy them into a bug report. The first line names the addon version, game client, and language.

# PrettyTooltip 1.2.0

## Tooltips

- Added an experimental **Quest parchment** option under **Quest Details** and **Item Details** in the style editor. With DialogueUI installed, quest tooltips, Quest Items, and items that begin a quest can use its brown parchment with dark ink. Off by default.
- Updated spell power coefficients from WoW Forever's client data, covering every rank of caster damage, healing, and absorb spells.
- Spell power breakdowns now distinguish **Spell Power Coefficient** from **Healing Power Coefficient**, with the percentage beside the base amount and spell power bonus.
- Updated spell schools from the latest client data, including correcting Turn Undead to Holy.
- Improved spacing around section dividers and separators across tooltip types.
- Fixed quest objectives for quests not in the log and quests already completed, and removed the duplicate Requirements heading.

## Editor

- Reorganized the settings column into **Selected Part**, **All Tooltips**, and the selected type's **Panel** and **Details** sections. The column scrolls within a fixed-height window; clicking a part returns to its controls. Per-type settings now live in the editor.
- The editor now uses Blizzard's settings frame artwork, controls, scrollbars, and tooltip type tabs by default. Choose **Blizzard** or **Flat** in the main addon options.
- Added eight school color swatches under **All Tooltips**, including Holyfire and Frostfire. Choices apply to spell panels, item stats and effects, and macros, and update without a reload.
- Added nine class color swatches under **Unit Details** for player names, panel accents, guild shades, player targets, and minimap players. Unset colors follow the game's class colors, including changes from other addons.
- **Reset all fonts and colors** now also restores stat-category, school, and class colors.
- Added a **Quest item** sample to the Items tab.

# PrettyTooltip 1.1.3

## Tooltips

- Elites, rares, rare elites, and world bosses now show the dragon from the game's target frame behind their tooltip's header.
- Unit tooltips show a health bar again, at the bottom of the panel: the game's own bar, which the game fills, so it works without the addon reading unit health. It can be turned off under **Unit Details** in the options.
- Bosses that WoW Forever reports as elites, such as faction leaders, are now shown as bosses, as the game's own tooltip names them.
- Quests hovered in the world map's quest log are now restyled, with the quest's level and status from your quest log. Lines other addons add, such as a guide's note, are kept below.
- Removed the progress bar under quest objectives; each objective still shows its count.
- Fixed divider lines that vanished, or were drawn twice as thick, depending on where the tooltip sat on screen.
- Fixed an error when a tooltip refreshed before it had any lines.

## Editor

- Added Rare elite and Boss samples to the Units tab.
- Unit samples show the health bar, each filled to its own health.

# PrettyTooltip 1.1.2

## Tooltips

- Added optional damage and healing per second and per mana under a spell's spell power breakdown.
- Unit tooltips now fade out smoothly, without the game's tooltip showing through behind them. ([#2](https://github.com/FallenShard/PrettyTooltip/issues/2))
- Removed the unit health bar, since WoW Forever does not let addons read unit health. ([#3](https://github.com/FallenShard/PrettyTooltip/issues/3))

# PrettyTooltip 1.1.1

## Tooltips

- Added optional drop tables for herb nodes, ore nodes and skinnable mobs.
- Added a new table for spell power coefficients. This is still WIP until we confirm scaling formulas for all spells in WoW Forever.
- Added clearer descriptions for quest-starting items.
- Revamped the color palette to be a little brighter and removed default colorization of primary stats.
- Toned down colorization for lite mode.
- Borders, dividers, and separators stay one pixel sharp at any UI scale.

## Editor

- Each stat category's color can be chosen in the style editor.
- Added global text size for accessibility.

# PrettyTooltip 1.1.0

## Tooltips

- Added styled macro tooltips, including spell and item previews selected through #showtooltip.
- Added pet ability, command, and stance tooltips, with autocast and active-state indicators.
- Added styled minimap tooltips.
- Added flight path tooltips showing the destination, zone, travel cost, and current location.
- Improved spell school detection with a dedicated database covering WoW Forever spells and Frostfire Bolt.
- Expanded spell damage and healing breakdowns and fixed talent tooltip layouts.
- Added markers for use effects, chance-on-hit effects, and enchants, plus number highlighting for use and proc effects.
- Improved bag tooltip handling and parsing of bonuses against specific creature types.
- Added font string caching for faster drawing, and addon memory reporting in /ptip perf.

## Editor

- Expanded style controls with padding, minimum width, Blizzard borders, and individual reset buttons; refined badges and item level icons.
