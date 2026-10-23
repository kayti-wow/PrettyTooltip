# Retail

Retail World of Warcraft loads `PrettyTooltip_Mainline.toc`, WoW Forever loads `PrettyTooltip_Camelot.toc`, and one download carries both. Retail's own code lives in this folder, which only retail's `.toc` loads. The shared code never asks which game it runs on: retail adds to it and changes it in the three ways below, and nothing else. A maintainer can read a shared file without knowing retail exists, apart from the extension points it lists at its top.

## Where a file goes

Each file here is named for the shared file it serves, and that name says when it loads and what it may do:

| File | Loads | Does |
| --- | --- | --- |
| `Retail/<path>.lua` | just before `<path>.lua` | adds data to that file's lists (`ns.contribute`) |
| `Retail/<path>.lua`, where retail's `.toc` leaves `<path>.lua` out | in its place | stands in for it: `Retail/Data/Schools.lua`, `Retail/Data/Imbues.lua` |
| `Retail/<path>Extension.lua` | just after `<path>.lua` | changes what that file does (`descriptor.extension`, `ns.replace`) |
| `Retail/Retail.lua` | first | starts `ns.Retail`, where retail's files share their parts |

Retail's `.toc` is Forever's with these placed, and without the files only Forever loads. `tests/unit/retail.lua` checks that it follows this rule, that every file here is named for a shared one, and that every Forever-only file says so in its header. In unit tests, `test.retail(files)` turns a list of shared files into retail's by the same rule.

## The three ways in

### 1. Data: `ns.contribute`

A file loaded before a shared one registers data, and the shared file reads it when it loads (`ns.contributions(target)`), in the order it came.

| Target | Read by | Retail's | Holds |
| --- | --- | --- | --- |
| `classes` | `Core/Palette.lua` | `Core/Palette.lua` | classes, each `{ after, key, label }`, placed after the class `after` names |
| `settings` | `Core/Settings.lua` | `Core/Settings.lua` | `{ defaults, elements }`: settings, and style parts placed after the part `after` names |
| `stats` | `Data/Stats.lua` | `Data/Stats.lua` | `{ label, categories, stats }`: stat colors, offered in the editor under `label`, and the stats |
| `itemKinds` | `Tooltips/Item.lua` | `Tooltips/Item.lua` | kinds of item the game names on a line of their own: "Finishing Crafting Reagent" |
| `spellPowers` | `Tooltips/Spell.lua` | `Tooltips/Spell.lua` | resources a spell can cost, as `Tooltips/Spell.lua`'s `POWERS` |
| `spellTimes` | `Tooltips/Spell.lua` | `Tooltips/Spell.lua` | strip times, as its `TIMES`: a charge's recharge |
| `samples` | `UI/Samples.lua` | `UI/Samples.lua` | `function(types, helpers)`, which adds to the style editor's samples |

A placement naming a key that does not exist stops the load (`util.insertAfter`), rather than leaving a part out until its tooltip is drawn.

### 2. Behavior: `descriptor.extension` and `ns.replace`

A file loaded after a tooltip type's file sets that type's `descriptor.extension` (`ns.TooltipTypes[type].extension`) to a table of callbacks. Each type's file lists the callbacks it calls at its top:

- **Items** (`Tooltips/Item.lua`; retail's `Tooltips/ItemExtension.lua`): `initModel`, `readText`, `findKind`, `isProfession`, `isSetBonus`, `isSetPiece`, `readLine`, `afterReadLine`, `afterRead`, and `extendView`. Retail's fields go in `model.retail`; the shared code adds none of its own there.
- **Spells** (`Tooltips/Spell.lua`; retail's `Tooltips/SpellExtension.lua`): `readStat`, `isCooldown`, `leadRows`, and `isDetail`.
- **Units** (`Tooltips/Unit.lua`; retail's `Tooltips/UnitExtension.lua`): `afterRead`.
- **Any type**: `install()`, which `Integration/Hooks.lua` calls once with its own hooks, for a client that must hook the game itself. Retail's flight map pins do (`Tooltips/FlightPathExtension.lua`).

The item reader's callbacks get a context. For the whole read it has `nativeTooltip`, `data`, `game`, `rootModel`, and `state`, a table the client keeps its notes in. Each line gets a fresh one that also has that line's `lineNumber`, `lineModel`, `originalText`, `leftText`, `text`, `rightText`, and, for `afterReadLine`, `added`, the rows the shared reader added for it. `afterRead` gets the read's context with `itemType` and `recipe`, and none of a line's fields. `newRead` in `Tooltips/Item.lua` documents each field.

A helper module that answers questions about the game takes a client's answers in place of its own through `ns.replace(module, name, answers)`, which stops the load if the module lacks a function it replaces. Retail replaces `ns.Game`'s `spellManaCost`, `globalCooldown`, and `classSpecs` (`Game/GameExtension.lua`), and `ns.TooltipData.inactiveColor` (`Game/TooltipDataExtension.lua`). The shared versions say in their comments that a client may replace them.

Callbacks run inside the reader's and renderer's protected calls: an error falls back to the game's own tooltip. Treat the game's data as read-only, check every value for `util.isSecret` before using it, and do not keep a context after the call.

### 3. Data only Forever loads: `ns.hasData`

Classic's tables do not hold for retail, so retail's `.toc` leaves out `Data/Disenchant.lua`, `Data/Coefficients.lua` with `Data/SpellRanks.lua`, `Data/Nodes.lua`, `Data/NodeNames.lua`, `Data/NodeSkills.lua`, and `Data/Skinning.lua`. Each such file says `-- Forever only:` in its header and calls `ns.provideData(name)`; code that draws from one asks `ns.hasData(name)` first. The names are listed in `Core/Util.lua`, and an unknown one stops the load. A style part drawn from one names it in `needs` (`Core/Settings.lua`), and the editor offers it only where it is loaded.

## Adding to retail

1. Data for a shared list: contribute it from `Retail/<path>.lua`. A list the shared file does not read contributions for yet gets a loop like `Data/Stats.lua`'s, and a line in the table above.
2. Behavior: use the type's callbacks from `Retail/<path>Extension.lua`. When none fits, add a call site to the shared file, list it at the file's top and here, and cover it in `tests/unit` (as `item_extensions.lua` covers the item callbacks).
3. A game string the code reads goes in `.luacheckrc`; then run `python tools/make_strings.py` and `python tools/make_strings.py --retail` so the tests have it in both games' wording.
4. Capture the tooltip on retail with `/ptip capture <name>` and import it (`tests/README.md`): the import names it `retail-<name>`, and the tests replay it with retail's files and game strings.

## Testing retail

`python tests/run.py -k retail` runs what concerns retail:

- Retail's captures, `tests/fixtures/retail-*.lua`, with retail's `.toc` and retail's game strings (`tests/locales/retail`), against their expected outputs. A capture's name must start with `retail-` exactly when retail made it; the run fails otherwise.
- Every Forever capture with retail's `.toc` too, as `retail/<name>`, which must not fail; they have no expected output there.
- The style editor's samples, drawn with retail's files, against `tests/outputs/samples/retail/`.
- The unit checks for retail, which load files through `test.retail(files)`, and with them retail's game strings.
