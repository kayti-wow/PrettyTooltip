# Localization

PrettyTooltip has to *read* tooltips, not just translate its own labels. A German client prints "Benötigt Stufe 40" where an English one prints "Requires Level 40", and the item reader must recognize both. This page explains how that works and how to add or improve a language.

Supported clients: enUS, deDE, frFR, esES, esMX, ptBR (and ptPT), koKR, zhCN, zhTW, ruRU.

## Reading through the game's own strings

Every client defines the game's strings as globals in its own language: `ITEM_MIN_LEVEL = "Requires Level %d"` in English, `"Benötigt Stufe %d"` in German. Readers match text against these globals rather than English literals:

```lua
local level = util.unformat(text, ITEM_MIN_LEVEL)          -- "40", or nil
local current, maximum = util.unformat(text, DURABILITY_TEMPLATE)
if startsWith(trimmed, ITEM_SPELL_TRIGGER_ONUSE) then ...  -- "Use:"
```

`util.unformat(text, format)` compiles a format string into a Lua pattern (cached) and returns the captured values. It handles `%s` and `%d` (numbers with either decimal separator), positional arguments (`%2$s %1$d`), and the game's grammar markers. Those are plurals (`|4hour:hours;`), Korean particles (`|1으로부터;로부터;`), French elision (`|2 `), and Russian declension (`|3-1(%s)`). Each marker becomes one pattern per choice, because Lua patterns have no "or". It also ignores color codes and treats no-break spaces as spaces. `util.findFormat` finds a format inside longer text, and `util.fill` is the reverse of `unformat`, filling a format with values. A wording can be a list of alternatives, and the first that matches wins.

Stat lines work the same way. `Data/Stats.lua` reads `ITEM_MOD_*` and `TOOLTIP_ITEM_STAT_*` through `_G` to recognize "+12 Stamina" and its equivalents, and prints stats again with the client's own `TOOLTIP_ITEM_STAT_FORMAT` (Korean puts the name first).

Because of this, most of each language works without translation. Every game global the addon reads must be listed in `.luacheckrc` (lint fails otherwise), and `tools/make_strings.py` then writes them, in every language, into `tests/locales/` for the test harness.

## What `Locale/` adds

`Locale/Locale.lua` creates `ns.Locale` with empty tables, and `Locale/English.lua` fills them in English. The client's own language file then overwrites what its language says differently. Each language file has its own load condition in the TOC (`Locale\deDE.lua [AllowLoadTextLocale deDE]`), so a client loads only English and its own file.

| Table | What it holds | Example (deDE) |
|---|---|---|
| `supported` | Whether the addon reads this client's tooltips at all. | `true` |
| `features` | Features that rest on more than the game's strings. Currently only `coefficients` (the spell power rows, which read spell descriptions). | `{ coefficients = true }` |
| `formats` | Wordings the game has no string for: weapon speed, recipe "Teaches you how to…", base mana cost, "Rare", "Rare Elite", talent points, enchant bonus, appearance lines. | `formats.weaponSpeed = "Tempo %s"` |
| `listSeparators` | What joins an enchant's bonuses. A pair gives a separator and text that must follow it. | `{ ", und ", " und ", ", " }` |
| `descriptions` | How spell descriptions word amounts and durations, for the coefficient reader: ranges, "over N sec", "every N sec", "lasts", per-second phrases, units, healing verbs. `…Before` variants put the duration before the amount. | `descriptions.range = { "%d bis %d", "%d - %d" }` |
| `descriptions.school`, `schoolWords`, `schoolBoundaries` | How descriptions name a school ("%s damage"), each school's word, and whether school words must stand alone. Chinese joins them to the surrounding text, so it turns the check off. | `{ "%sschaden", "%szauber" }` |
| `statWordings`, `statWords` | Equip wordings of stats the game's strings don't cover, and the stat each gives. | |
| `skills` | Skill and profession names, keyed by the addon's English key. A list where the client uses two names (the first is printed). | `skills.Mining = "Bergbau"` |
| `dispels` | Dispel types by the aura API's English key. | `dispels.Poison = "Gift"` |
| `questTags` | The kinds of quest a quest tooltip names on its own line. | |

The addon's **own words** (labels such as "Sell Price", "Creates", "Item ID: %s") go through `ns.L`. It's a table whose missing entries return their key, so `L["Sell Price"]` is English unless the language file sets it. Words with values in them are formats, filled by `util.fill(L["Your skill %s"], 150)`.

Many names come from the client at runtime instead of from translation tables: spell names via `game.localSpellName`, item names via `C_Item.GetItemNameByID`, quest titles via `C_QuestLog`, class names, and school names (`DAMAGE_SCHOOL*`). The static data in `Data/` is keyed by ID for this reason (see [Static data](data.md)). Herb and ore node names are the exception: `Data/NodeNames.lua` keeps each node's name in the client's language, because no API gives them.

## Gating

Many files return early when `ns.Locale.supported` is false. On a client whose language hasn't been checked against real tooltips, the addon installs nothing and the game's tooltips are left alone. That's better than misreading them. Similarly, `features.coefficients` hides the spell power rows (and their editor controls) until descriptions in that language have been checked (`tests/unit/localized_coefficients.lua`).

## Text helpers that know other scripts

| Helper | What it handles |
|---|---|
| `util.splitSentences` | Ends sentences at `. ! ?` followed by a space and a capital, so decimals and Russian abbreviations followed by a lowercase word stay whole. Also ends them at Chinese and Japanese full-width stops. |
| `util.upper` / `util.lower` | Accented Latin and Cyrillic letters, which `string.upper` ignores. |
| `util.width` | How long a line reads, in characters. A Chinese, Japanese, or Korean character counts as two Latin letters. |
| `palette.schoolIn` | Finds a school phrase as whole words, unless the language opts out of word boundaries. Where two phrases start at the same place, the longer one wins, because it names a blend (Holyfire's French name begins with Fire's). |
| `Data/Stats.lua` | Reads amounts with the client's group separator ("1,000" or "1.000") and prints them without it. |

## Fonts

The default title font, EllesmereUI's Expressway, has no Hangul or Chinese glyphs, so koKR, zhCN, and zhTW use the client's own header font. Without LibSharedMedia, the font menu lists the client's own faces for Russian, Korean, and Chinese.

## Adding or improving a language

1. **Capture real tooltips** on that client with `/ptip capture <name>` (see [Debugging](debugging.md)). Include items with stats and effects, recipes, spells of several schools, talents, units, quests, and gathering nodes. Import them with `python tests/import_captures.py`.
2. **Create or edit `Locale/<locale>.lua`.** Copy the structure of an existing language: set `locale.supported = true`, and fill `formats`, `listSeparators`, `descriptions`, `schoolWords`, `skills`, `dispels`, `questTags`, and `ns.L` entries. Mark guesses with an "Unconfirmed" comment until a capture confirms them.
3. **Add it to the TOC** with its `[AllowLoadTextLocale <locale>]` condition, after `Locale\English.lua`.
4. **Generate test strings.** If `tests/locales/<locale>.lua` doesn't exist yet, add the locale to `tools/make_strings.py` and run it.
5. **Node names.** Add the language's herb and ore node names to `Data/NodeNames.lua`.
6. **Run the tests.** `python tests/run.py`. Review each new expected output in `tests/outputs/`. The localized unit tests (`tests/unit/german.lua`, `french.lua`, …) are good models for language-specific checks.
7. **Turn on coefficients** (`features.coefficients = true`) only once `tests/unit/localized_coefficients.lua` passes for the language's spell descriptions.
8. **Check the package.** `tests/check_package.py` starts the packaged addon in every locale in its `LOCALES` list, so add the new one there too.
