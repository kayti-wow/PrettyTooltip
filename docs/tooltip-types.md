# Tooltip types

Each kind of tooltip the addon restyles lives in one file under `Tooltips/`. Each file reads the game's tooltip into a **model**, turns the model into a **view**, and registers itself with `ui.defineTooltipType`. See [Architecture](ARCHITECTURE.md#3-read--model--view--render) for the contract, and [Rendering](rendering.md) for how views are drawn.

## How readers work

Most readers walk `data.lines`, the line list the game's tooltip processor hands over. Each line has `leftText`, `rightText`, colors, a `lineIndex` (its row on the drawn tooltip), and on newer clients a `type` from `Enum.TooltipDataLineType`. Readers follow these rules:

- **Bail out on anything hidden.** A secret line, field, or color makes the reader return nil (the spell reader is the one exception, see below). The panel code then restores the game's tooltip.
- **Recognize lines by the line type first, then by text.** For example, `isType(lineType, "ItemSpellTriggerOnUse")` is tried before `startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE)`. The type works in every language, and the text is the fallback for clients and lines without one.
- **Match text through the game's own strings.** `util.unformat(text, ITEM_MIN_LEVEL)` reads "Requires Level 40" back into `40` in any language. See [Localization](localization.md).
- **Keep what isn't recognized.** Unknown lines go into `model.extras` with muted colors, and so do rows other addons appended (`TooltipData.appendedRows`). Nothing on the game's tooltip is lost.
- **Ask `ns.Game` for what the lines don't say:** icons, item level, quality, sell price per unit, stack count, whether an item is equipped, aura durations, macro bodies, and so on.
- **Record `lineIndices`** for every line read from the data, so `appendedRows` can tell which drawn lines came from other addons.

Each file also exposes a model builder for the style editor's samples (`ui.itemModel`, `ui.spellModel`, `ui.macroModel`, …), which fills in any lists a sample leaves out.

## Shared helpers (`Game/TooltipData.lua`)

| Helper | Purpose |
|---|---|
| `add(list, left, right)` | Appends a `{ left, right }` row. |
| `colorOf(color)` / `quietColor(r, g, b)` | A line's color, dimmed to 85%. Unreadable or near-white colors become the muted "extras" grey. |
| `isRed(color)` | Whether the game colored a line red (the character can't use it). Nil when unreadable. |
| `requirementMet(text, color, game)` | For a "Requires Level N" line, compares N with the player's level. Otherwise it goes by the line's red color. |
| `appendedRows(tooltip, lineIndices)` | Rows on the drawn tooltip that aren't in the data, which other addons added. Nil if any is unreadable. |
| `nested(data)` | The spell or item a tooltip nests in full (a `#showtooltip` macro, a pet ability, a trainer recipe), as data for that type's reader. |
| `itemWording(line)` | The shortened wording of an item line, from `Data/Stats.lua`. |

## Items (`Tooltips/Item.lua`)

The biggest reader. Its model has separate lists for each part of the panel: `header` (binding rows), `armor`, `primary` and `secondary` stats, `equipEffects`, `enchants`, `effects` (use effects and `<Right Click to Open>`-style lines), `flavor`, `setItems`, `setBonuses`, `extras`, `footerLeft` (durability, class and race limits, crafter), `footerRight` (requirements and sell price), and `kinds` (item kinds such as "Crafting Reagent").

How it reads the lines:

- **The name, item level, and equip slot** come from typed lines (`ItemName`, `ItemLevel`, `EquipSlot`). The slot and type form the subtitle, `Mail · Head`. Words the character can't use are colored red.
- **Stats** are read through `ns.TooltipData.itemWording`, which rewords each line with `Data/Stats.lua`. "Equip: Increases healing done by up to 20…" becomes "+20 Healing Power". A combined line becomes one row per stat. Primary attributes (Strength, Agility, Stamina, Intellect, Spirit, All Stats) go into `primary` and the rest into `secondary`.
- **Weapons.** Damage and speed (`DAMAGE_TEMPLATE`, `formats.weaponSpeed`), DPS (`DPS_TEMPLATE`), and bonus school damage (`PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL`) are read into their own fields. With **Swap Damage Stats** on, damage takes the large line and DPS the small one.
- **Armor and block.** A shield's block value joins its armor line ("547 Armor · 11 Block").
- **Effects.** A chance on hit (line type `ItemSpellTriggerOnProc`) becomes an equip effect marked `onHit`, drawn with a sword marker. Other equip effects drop their `Equip:` label and join the stats. Use effects drop `Use:` and get a gear marker. Enchants (`ItemEnchantmentPermanent`) are split into one row per bonus by `ui.enchantRows`, using `ns.Locale.listSeparators`.
- **Item sets.** `ITEM_SET_NAME` starts the set section. Piece names and bonuses follow, each greyed out when the game greys it (`isActive`).
- **Recipes.** A recipe's lines contain the crafted item's whole tooltip. A second `ItemName` line starts `model.created`, a nested item model, and the lines after it go there. The recipe's profession requirement, its "Teaches you how to…" line, and its reagent list are recognized by text. `finishRecipe` then looks up the crafted item, counts the reagents you carry, and names the recipe's kind in the subtitle.
- **Sell price.** The game draws the price with a money frame, so it isn't text. The reader takes it from the data line's `price`, works out the stack count (from the bag slot, or from the total price divided by the unit price), and shows `2g (20 × 10s)` for a stack.
- **Other details.** The item's class from `GetItemInfoInstant` adds "Consumable · Potion" to the subtitle. Quest items, and items that begin a quest, tint the panel quest gold. `ns.disenchantFor` adds disenchant results. On comparison tooltips the panel is tagged "Equipped" or "Equipped With".

The view puts the header beside the icon (with the item level badge), then sections in this order: the quest it starts, stats (one custom section drawn by `drawStats`), set, created item, reagents, disenchant results, other addons' rows plus the ID row, and a footer with durability on the left and requirements and price on the right.

`ui.createdItem` reads and draws an item nested in another tooltip. The spell reader uses it for the item a trainer's recipe spell creates.

## Spells (`Tooltips/Spell.lua`)

The model has `name`, `rank`, the strip cells (`cost`, `cast`, `cooldown`, `range`), `passive`, `requirements`, `details`, `description` (sentences), `reagents`, `extras`, and optionally `nested` (another spell inside this one, such as another form's version) or `created` (a crafted item).

- **The strip.** `readStat` recognizes each cell from the game's strings: costs in each power (`MANA_COST`, energy, rage, …), a share of base mana, cast times (`SPELL_CAST_TIME_SEC`, instant, channeled, next swing), cooldowns, and range (`SPELL_RANGE`, `MELEE_RANGE`). The strip always shows four cells in a fixed order. A missing one shows what its absence means, dimmed. A spell with none, such as a passive, has no strip.
- **A two-resource cost** ("30 Energy" over "1 to 5 Combo Points") is one line with a break. The first part is the cost and the rest become details.
- **Descriptions** are split into one sentence per line by `util.splitSentences`, which knows decimal points, Chinese full stops, and Russian abbreviations. Numbers are highlighted in the school's lighter tint.
- **The school** comes from `ns.Palette.detectSchool`. It looks up the spell's ID or name in `Data/Schools.lua` first, then searches the description for a school phrase ("Fire damage"). The school sets the accent and badge, and a blend such as Holyfire sets a gradient. Without a school the accent follows the power type, or neutral.
- **Talents.** The talent window writes the rank, the next rank, and the points still needed onto the tooltip after the game fills it, so those lines come through `appendedRows`. `readTalent` sorts them into `model.talent` and leaves the rest as other addons' rows.
- **The game's right-side text.** Sometimes only the drawn tooltip has a line's right side (a cooldown beside the cast time). `nativeRight` reads it from the font string.
- **The spell power breakdown.** `ns.spellPowerRows` in `Data/Coefficients.lua` splits damage or healing into base and spell power, and adds per-second and per-mana rates. These rows show only when the language has `features.coefficients` and the details key allows it.
- **Combat.** In combat the game hides some lines, such as the cooldown remaining, and every drawn font string. This reader alone keeps its panel in combat. A hidden line's text is kept as an opaque value in `model.hidden` and drawn by `ui.hiddenTextAt` without being read. Only a hidden spell name makes it give up.

Pet actions (below) and `#showtooltip` macros reuse this reader for the spell they nest.

## Players and NPCs (`Tooltips/Unit.lua`)

- **The unit.** The data's GUID identifies the unit, because the `mouseover` token can still point at the previous one. `unitFor` finds a token for it with `UnitTokenFromGUID`.
- **The model** takes name, level, class, race, faction, reaction, classification, guild, and PvP/AFK/DND/dead state from the game's unit functions. The tooltip's lines add an NPC's title ("Herbalism Supplier"), its faction ("Ironforge"), and the level line's rank. "Level ?? (Boss)" outranks `UnitClassification`, which calls some bosses "elite".
- **The header.** A portrait fills the icon, with a level plate beneath it like the target frame's. The name is in its class or reaction color. A class-color addon's `CUSTOM_CLASS_COLORS` comes first, then the editor's colors, then the game's. Badges show PvP, dead, AFK, and similar states.
- **Watermarks.** Players get a faction crest. Elites, rares, and bosses get the target frame's dragon, drawn from the client's own atlases.
- **The health bar.** The game's `GameTooltipStatusBar` is lent to the panel and placed in room left at its bottom. It's returned exactly as it was when the panel hides or draws something else. Its value is never read.
- **Skinning.** A dead creature gets the Skinning skill it needs and its possible drops, from `Data/Skinning.lua` and the creature ID in its GUID.

Units set `alwaysRedraw`, so the panel is redrawn on every refresh even when its lines read the same.

## Buffs and debuffs (`Tooltips/Aura.lua`)

The tooltip's lines have the aura's name, description, and time remaining, but not its stacks or exact expiration. `auraOf` looks the aura up with `C_UnitAuras` while the game is filling the tooltip, and caches it in a weak table for later redraws, because the lookup only works during the fill. The panel shows a dispel-type badge in the game's dispel colors (with dispel names in the client's language from `ns.Locale.dispels`), the description, and a draining time bar. The bar is a **live part**: `ui.setLive` updates it ten times a second while the panel shows.

## Quests (`Tooltips/Quest.lua`)

The panel shows the title with its level and kind (such as "Dungeon", by the names in `ns.Locale.questTags`), the description as the quest giver's words, and the objectives with checkboxes. A quest that's been turned in counts every objective as done.

Quest tooltips come from several places:

- **The game's quest data.** A normal data-type reader.
- **The world map's quest log buttons.** They fill the tooltip with lines only, so `questLogButton` finds the quest from the button.
- **Chat links and Questie.** Questie fills tooltips with its own lines for its links and the game's. The file hooks the chat frames' hyperlink scripts and `SetItemRef`, and draws those tooltips with `ns.Hooks.renderLines`. Questie's labels, separators, and color codes are read in the language Questie is set to.

With DialogueUI installed and **quest parchment** on, quest panels use DialogueUI's brown paper, and text colors are converted to ink (see [Rendering](rendering.md#backdrops)).

## World objects (`Tooltips/Object.lua`)

Covers herbs, ore, chests, and quest objects. The reader picks out the name, requirement lines ("Requires Mining", "Requires Lockpicking (25)"), and quest rows. A gathering node shows the skill it needs, colored by how likely gathering is to raise your skill (`Palette.skillUpColor`). Herb and ore nodes also list their contents from `Data/Nodes.lua`: the yield's count over all its taps, then each other drop's chance. Names are matched through `Data/NodeNames.lua`, so "Kupferader" on German clients finds "Copper Vein". Item IDs in the data are checked against the item's name, so a wrong entry is skipped rather than shown. A plain object, such as a mailbox, is just its name.

## Macros (`Tooltips/Macro.lua`)

A macro's tooltip only has its name. The reader asks `game.macro(name)` for its icon and body and shows the body's lines with commands in gold and `#directives` and `[conditions]` muted. The accent comes from the school of the spell the first `/cast` or `/use` names.

A macro with `#showtooltip` gets a tooltip that nests the spell or item it shows. The reader then hands that nested data to the spell or item reader, adding "Macro: Name" to its subtitle or tags.

## Pet actions (`Tooltips/PetAction.lua`)

A pet ability nests its spell, which is read with the spell reader. A command or stance (Attack, Follow, Defensive) is just its name and description. The pet bar adds badges for autocast and the active command. The key ignores autocast and stance, so toggling them doesn't count as new content.

## Minimap (`Tooltips/Minimap.lua`)

The minimap tooltip lists the blips under the cursor, sometimes several on one line. The panel shows one row per name: herb and ore nodes with their required skill in its skill-up color, players in their class color, and the game's up/down arrow for blips above or below you. It has no header, only a list sized to its longest row.

## Flight paths (`Tooltips/FlightPath.lua`)

The flight map fills `GameTooltip` with lines only and has no tooltip data type, so this type is `linesOnly`. `hookTaxi` hooks `TaxiNodeOnButtonEnter` and calls `ns.Hooks.renderLines`. The reader takes the node's name and zone, and reads the cost from the coin text or textures. Because the flight map can load as its own addon, the hook waits for it if needed.
