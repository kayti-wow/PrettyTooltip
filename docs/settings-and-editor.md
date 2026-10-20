# Settings and the style editor

## Saved variables

| Variable | Contents |
|---|---|
| `PrettyTooltipDB` | The player's settings. Only values that differ from the defaults are stored (a key at its default is nil). Per-part styles are under `PrettyTooltipDB.styles[key]`. |
| `PrettyTooltipCaptures` | Tooltips saved by `/ptip capture` in debug builds, for the tests (see [Debugging](debugging.md)). |

## Reading and writing settings (`Core/Settings.lua`)

| Function | Purpose |
|---|---|
| `ns.option(key)` | The saved value, else `DEFAULTS[key]`. Always called at the moment of use: saved variables arrive after the files run, and changes should apply right away. |
| `ns.setOption(key, value)` | Saves a value (nil returns it to the default) and bumps `ns.settingsVersion`. |
| `ns.savedOption(key)` | The stored value only (nil at the default), for reset buttons. |
| `ns.restyles(option)` | Whether a type whose panel `option` turns on draws one: the option is on and the layout isn't `"blizzard"`. |
| `ns.showsDetail(key, panel)` | Whether a detail row shows now: its option is on, and either the details key is down, the key setting is `"ALWAYS"`, or the panel is a preview or the game's own tooltip. |
| `ns.originalKeyDown()`, `ns.isOriginalKey(key)` | The original-tooltip key (`"ALT"`, `"CTRL"`, or `"NONE"`). |
| `ns.detailsKeyDown()`, `ns.isDetailsKey(key)` | The details key (`"SHIFT"` or `"ALWAYS"`). |
| `ns.tooltipScale()` | The global panel scale, clamped to 0.5–1.5. |
| `ns.migrateOptions()`, `ns.resetOptions()`, `ns.resetStyles()` | Upgrade old settings, and reset everything or only the styles. |

`ns.settingsVersion` is part of every panel's fingerprint, so any change redraws the panels that are showing.

### The defaults

`DEFAULTS` groups into these kinds of setting:

- **Layout:** `layout` (`"pretty"` or `"blizzard"`), and one `…Panels` switch per type (`itemPanels`, `spellPanels`, `unitPanels`, `auraPanels`, `questPanels`, `objectPanels`, `macroPanels`, `petPanels`, `minimapPanels`, `taxiPanels`).
- **Icons:** `icon…` per type, and `iconRight` to put the icon on the right.
- **Items:** `liteWording`, `statColors`, `statMarkers`, `qualityTint`, `swapDamage`, `itemLevelBadge`, `separators`, `sellPrice`, `disenchant`.
- **Spells:** `spellPower` and `spellRates`.
- **Units:** `unitLevelBadge` and `unitHealthBar`.
- **Details:** `gatheringLoot`, `showIDs`, and the `detailsKey` that shows them.
- **Keys:** `originalKey` and `detailsKey`.
- **Follow cursor:** one `cursor…` per category in `ns.TOOLTIP_TYPES`, and `cursorDisableInCombat`.
- **Look:** `backdropStyle` (nil means automatic), `dialogueBackdrop`, `questParchment`, `editorStyle`, `bodyFont`, `titleFont`, `outline`, `fontScale`, `tooltipScale`, `padding`, `minWidth`, `headerTopAlpha`, `headerBottomAlpha`.

Some settings are kept per tooltip type with a suffix from `ns.TYPE_SUFFIX` (`Items`, `Spells`, …): `headerTopAlphaSpells`, `backdropAlphaUnits`, `glowAlphaItems`. A type without its own value follows the shared one. Color overrides are stored as flat keys: `statColor<Category>`, `schoolColor<School>`, `classColor<Class>`.

### Tooltip categories

`ns.TOOLTIP_TYPES` lists the categories the options page and follow cursor know, each with its `restyle` setting, its `cursor` setting, and the game data types it covers. Some categories have only a cursor setting (currencies, lockouts, mounts and toys, achievements, totems, flyouts). The addon doesn't restyle those, but they can still follow the cursor.

## Styles

`ns.ELEMENTS` lists every part of a panel that can be styled. Each element has:

- `key`: used in views and `ui.styleOf(key)`.
- `label`: the name shown in the editor.
- `size`: the default font size.
- `color`: the color the picker starts from.
- `title`: true for parts in the title font. These are also in capitals by default.
- `caps`: capitals by default.
- `tooltipType`: `"spell"`, `"unit"`, `"shared"`, and so on. Omitted means items.
- `note`: explains when a part's color is automatic.

Item parts include `title`, `subtitle`, `header`, `dps`, `damage`, `armor`, `stats`, `equipEffects`, `enchants`, `effects`, `flavor`, the set parts, `footer`, `badge`, `createdName`, `reagents`, `caption`, and `disenchant`. Each other type has its own (`spellTitle`, `spellBadges`, `spellValues`, …). `extras`, the other addons' rows, is shared by every type.

`ns.style(key)` combines the element's defaults with its saved overrides (`size`, `font`, `outline`, `color`, `caps`) and multiplies the size by the global `fontScale`. `ui.styleOf(key)` then fills in the title or body font (see [Rendering](rendering.md#text)). A saved `color` replaces the part's automatic colors, inline codes included. With no color saved, the part keeps its automatic coloring (quality, school, stat category, red for unmet requirements).

**Fonts.** `ns.fontNames()` lists LibSharedMedia's fonts when it's installed, otherwise the client's own faces (with Cyrillic and CJK variants on those clients). Fonts are saved by name and resolved by `ns.fontPath(name)`.

**Colors.** `Core/Palette.lua` holds the shared role colors (`title`, `detail`, `caption`, `unmet`, `quest`, …) and the school colors, and builds tints. Its shared tables are never changed. Picker overrides are read at draw time (`palette.school`, `palette.classColor`, `Stats.categoryColors`). Each stat category's lighter name shade is derived from its value color.

## The options page (`UI/Options.lua`)

The options page is registered in the game's settings window as a canvas page (`Settings.RegisterCanvasLayoutCategory`), falling back to `InterfaceOptions_AddCategory` on older clients. It has two columns:

- **Left, "Restyled Tooltips":** for each tooltip category, a "Restyle" checkbox (disabled while the Blizzard layout is on, because then nothing is restyled) and a "Follow cursor" checkbox.
- **Right:** layout style, the default-tooltip modifier, the details modifier, follow cursor in combat, the style editor's appearance, and the global scale.

Each control's explanation shows as a hover tooltip. A button opens the style editor over the settings window. It doesn't close the settings window, because `HideUIPanel` on it would run Blizzard code under the addon's taint.

`/ptip options` opens this page through `ns.openSettings`, which refuses in combat. The settings window doesn't open in combat, and opening it from addon code taints it.

## The style editor (`UI/Editor.lua`)

`/ptip` opens the editor. It's a window of the addon's own (`PrettyTooltipEditor`, closed by Escape through `UISpecialFrames`), with a live sample panel on the left and a scrolling column of controls on the right.

- **Tabs** switch between tooltip types (Items, Spells, Objects, Units, Buffs, Quests, Macros) and between each type's samples. For example, items have Weapon, Set piece, Equipped, Potion, Recipe, and Quest item, and units have Player, Enemy, Vendor, Rare, Rare elite, and Boss.
- **Picking a part.** Hovering the sample highlights the part under the cursor, using the hit regions `ui.renderPreview` records. Clicking selects that part, and its size, font, outline, capitals, and color controls head the column.
- **The column lists**, in order: the selected part; settings every type shares (fonts, outline, scale, padding, width, backdrop style); settings this type keeps for itself (header band and backdrop opacity, icon); and options only this type has (stat colors and markers for items, school colors for spells, class colors for units, coefficients where the language supports them). Every changed setting shows its label in gold with a reset button.
- **Looking up by ID.** The lookup box above the column takes an ID, or a link shift-clicked into it (the editor hooks `ChatEdit_InsertLink` while the box has focus). It fills a hidden scanner tooltip (`PrettyTooltipScanner`, which `Hooks.lua` skips) and draws that tooltip's real panel as the sample. Uncached items are requested, and `GET_ITEM_INFO_RECEIVED` redraws them. Clear returns to the samples.
- **Its own skin.** `UI/EditorSkin.lua` gives the editor either the game's frame art (`native`) or a flat look (`editorStyle`), independent of the tooltips' backdrop. Switching keeps the same controls, selection, and scroll position.

### Samples (`UI/Samples.lua`)

Samples are **models written as data**, which each type's model builder (`ui.itemModel`, `ui.spellModel`, …) completes and the type's normal `render` draws. Anything that must come from the game or the settings is written as a marker and filled in on each draw:

| Marker | Filled with |
|---|---|
| `{ item = ID }`, `{ spell = ID }` | The icon. |
| `{ itemName = ID, "English" }`, `{ spellName = … }`, `{ questName = … }` | The client's name for it, falling back to the English while it loads. |
| `{ money = copper }` | Coin text, optionally a stack. |
| A stat list's strings | Stat rows styled by the current settings. |
| `enchant` | An "Enchanted:" line split into rows. |
| `disenchant = { quality, class, level, slot }` | The disenchant results. |
| `expiresIn` | An aura's end time, so the time bar runs. |

Sample text uses the game's strings (`ITEM_BIND_ON_EQUIP`, `fill(DAMAGE_TEMPLATE, 153, 256)`) and `ns.L`, so samples appear in the client's language. They're also part of the test suite: every sample is drawn and compared against `tests/outputs/samples/<type>-<sample>.txt`.
