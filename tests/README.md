# PrettyTooltip tests

The tests run the addon outside the game, in Lua 5.1 (the game's) through [lupa](https://pypi.org/project/lupa/), so the code can be changed and refactored with a check that tooltips still read and draw as before.

```
pip install -r tests/requirements.txt
python tests/run.py              # everything
python tests/run.py -k frost     # tests whose name holds "frost" ("samples", "lint", ".blizzard", "retail" work too)
python tests/run.py --update     # accept the current output as the expected
python tests/run.py --notes      # list what each fixture lacked an answer for
python tests/run.py --coverage   # which lines and functions the tests ran
python tests/run.py --profile    # the frame calls each read and render make
python tests/run.py --strict     # require lint and existing outputs; never create baselines
```

## Continuous integration and packages

GitHub Actions runs `.github/workflows/ci.yml` on pull requests and branch pushes.
The release workflow calls the same checks on a `v*` tag and publishes only after
they pass. Checks use Python 3.12, the pinned Lupa dependency, Lua 5.1, and
luacheck 1.2.0. Strict mode fails if lint is unavailable or an expected output is
missing; it cannot be combined with `--update`. New baselines must be generated
and reviewed locally before committing them.

CI also runs BigWigs Packager with `-d` (no publishing), then
`python tests/check_package.py`. The smoke test checks the actual ZIP's integrity,
folder name, TOC metadata and load order, locale conditions, required Lua files
and textures, and exclusion of development files. It compiles the packaged Lua
and starts it through the existing harness in all supported locales, including
both Portuguese locale codes. It reads addon code from the ZIP, not the working
tree. This cannot verify native rendering or Blizzard's taint engine.

`python -m unittest discover -s tests -p test_ci.py` checks that broken packages
and missing baselines are rejected. It runs before the Lua regression suite in CI.

The checked ZIP is available as the `PrettyTooltip-package` workflow artifact for
seven days. To check a downloaded package locally, run
`python tests/check_package.py "path/to/PrettyTooltip.zip"` after installing the
test dependencies. The release job retains its existing publishing process and
rebuilds from the same checked tag; it does not publish the CI artifact directly.

To require CI before merging, select **Tests and package smoke test** in the
branch protection rule or repository ruleset after the first successful run.

`--profile` counts, for one read and one render of each fixture, every method the addon calls on frames, font strings, and textures, and the calls that set what was already set (`SetFont, same font`, `SetText, same text`). It shows how much work a change adds or saves, the same on every run; how long the work takes, and how often the game asks for it, only the game can show, with `/ptip perf`.

## Fixtures and expected outputs

`fixtures/mail.lua` replays the captured multi-attachment summary. `unit/mail.lua`
checks mailbox quantities, asynchronous price fills, other addons' rows, totals,
modifier restoration, presentation settings, owner isolation and restricted data.
New mail captures record the inbox index and attachment API answers for replay.

A fixture is a real tooltip, captured in the game:

1. Hover a tooltip, or click a link in chat, and type `/ptip capture <name>`. Hold Shift first to capture the comparison tooltips too. Values the game hides, as on some player tooltips, are kept marked; the harness gives them back as hidden values that `issecretvalue` knows, so the addon's handling of them is tested too.
2. `/reload` or log out, which is when the game writes the captures to disk.
3. `python tests/import_captures.py "<WoW folder>"` (the folder holding `WTF`, or the `SavedVariables/PrettyTooltip.lua` file itself). It writes `tests/fixtures/<name>.lua`, and `retail-<name>.lua` for a capture retail made; `--only` picks captures and `--rename old=new` renames them. Player and guild names are replaced unless `--keep-names` is given.
4. `python tests/run.py`: a new fixture gets its first expected output in `tests/outputs/<name>.txt`. Read it once; it is what the test holds the code to from then on.

Each fixture is run as the game would: the addon's files load in the order of its game's `.toc` (see *Retail* below), saved settings arrive and the addon's `ADDON_LOADED` event starts it through `PrettyTooltip.lua`, the post-calls select native item wording or the Pretty model path, the tooltip type's reader turns original data into a model when needed, and the renderer draws it. The expected output holds the model and every string and texture drawn, with where it sits. When a change alters them, the run fails with a diff; if the change is meant, `--update` accepts it.

`unit/item_refresh_reuse.lua` repeats the nine native handovers seen in a three-tooltip refresh. It checks that wording preparation is reused while native font bindings stay fresh, that settings and restricted values cannot reuse stale entries, and that native item details read only identity and disenchant metadata. The wording cache holds at most 512 entries, including unchanged lines; live disenchant metadata and prices are not cached.

`unit/native_idle.lua` checks that Lite refreshes create no Pretty panels or panel cleanup timers, and prepare no hidden details. It covers details appearing in the modifier event from the latest data, canceled or restricted handovers, and switching presentations at runtime.

`unit/pretty_noop_hooks.lua` counts native layout queries in Pretty callbacks.
Zero-alpha writes return without a layout probe; external changes, protected
frames, and secret alpha values retain their access checks and cleanup.
Completed refreshes reset the periodic content poll, while quiet tooltips still
detect in-place text changes.

`unit/placement_layout_boundary.lua` checks that Pretty placement never pads
native frames, while Blizzard layout and unstyled types retain their own detail
padding. It covers switching layouts, the original-tooltip modifier, and the
retired placement diagnostic. Legacy fitting tests have been replaced with
checks for stable Pretty constraints across early native Show/refill sequences.

`unit/pixel_rounding.lua` checks native rounding on owned panels, borders, labels,
close buttons and growing text/texture pools, with no setter calls when entries
are reused. The harness records the rounding policy; fractional-scale text and
border rasterization still require an in-game check. Explicit snapping and
one-pixel thickness calculations remain in place during this change.

A capture holds the game's answers to what the readers ask (item, spell, and unit info, the player's level, spell power, and skills), and the client's enums. A call the capture has no answer for returns nothing and is listed with `--notes`; if a reader needs it, add it to `UI/Capture.lua` and capture again.

### Settings variants

`tests/variants.lua` lists, by type of tooltip, other settings each fixture of that type also runs with: items, spells, objects, and units in the Blizzard layout, and items and spells with their optional parts turned off. A variant's expected output is `tests/outputs/<fixture>.<variant>.txt`. The Blizzard layout leaves the game's tooltip showing, so its output is the game's tooltip, line by line, after every post-call, then the details below its lines (the harness holds Shift).

### The style editor's samples

Every sample the style editor shows (a weapon, a herb, a hostile elite, a quest in progress, and the rest) is drawn and compared against `tests/outputs/samples/<kind>-<sample>.txt`, so every kind of panel is tested without a capture. The samples have no recorded game answers, so what needs one, as an icon or an item's price, is left out of them.

### The game's strings, by language

Every client defines the game's strings (`ITEM_MIN_LEVEL`, `DURABILITY_TEMPLATE`, …) as globals in its own language, and the addon reads tooltips through them. `tests/locales/<locale>.lua` holds them for enUS, deDE, frFR, esES, esMX, ptBR, koKR, zhCN, zhTW, and ruRU, and each world defines the ones of its fixture's language (`client.locale`, enUS when a fixture has none). `python tools/make_strings.py` writes them from Forever's own string table on wago.tools: the globals `.luacheckrc` lists, the families a quoted name ending in `_` stands for (`"TOOLTIP_ITEM_STAT_"`), and the names the unit checks use. Run it again after adding a game string to the addon.

Retail words many of the same strings its own way ("Binds to Warband", where Forever says "Binds to Account"; Russian "Дальность действия: %s м" for "Радиус действия: %s м."), and lacks Forever's Classic stats. `python tools/make_strings.py --retail` writes retail's into `tests/locales/retail/<locale>.lua`, and a world that loads retail's files (`Retail/Retail.lua`) defines those instead. Run both after adding a game string.

## Retail

Retail loads `PrettyTooltip_Mainline.toc`, Forever `PrettyTooltip_Camelot.toc`; `Retail/README.md` describes how retail's files plug into the shared ones. The run covers both games:

- **Retail's captures** are named `retail-<name>` and run with retail's `.toc` and game strings, against `outputs/retail-<name>.txt` and their variants. The name decides: a capture records whether it came from retail's `.toc` (`client.retail`; for an older capture, a client version of 2 or later), and the run fails one whose name says otherwise.
- **Forever's captures** run once more with retail's `.toc`, as `retail/<name>`. They have no expected output there; they must only not fail.
- **The samples** are drawn with each game's files: `outputs/samples/` for Forever, `outputs/samples/retail/` for retail.
- **Unit checks** load retail's files with `test.retail(files)`: it adds, around each shared file, the retail files named for it, and puts a retail stand-in in place of a Forever-only file (`Retail/README.md` has the rule; `unit/retail.lua` checks retail's `.toc` follows it). `test.tocs.forever` and `test.tocs.retail` are each `.toc`'s files in load order; `test.sources` holds every file a test may load.

`python tests/run.py -k retail` runs all of it. `tools/toc.py` reads the `.toc` files for the runner, the package check, `deploy.py`, and the tools alike.

## Lint

The run starts with [luacheck](https://github.com/lunarmodules/luacheck), by `.luacheckrc`, which reports names used but never defined: a rename or a move that leaves one behind fails it, whether or not a test runs that code. It runs when `luacheck` is on the PATH, or where the `LUACHECK` environment variable points (as at the `luacheck.exe` from its [releases](https://github.com/lunarmodules/luacheck/releases)); without it the run says lint was skipped. The game's globals the addon reads are listed in `.luacheckrc`; a new one goes there.

## What the tests cover

`python tests/run.py --coverage` reports, for each file either `.toc` loads, retail's included, the share of its code lines the tests ran, and the top-level functions none entered. The share is counted from the text, so it is close, not exact, and it includes what runs while a file loads.

The code falls into these kinds, by how far the tests can check it (counts from October 2026, of about 5,400 code lines):

| Kind | Share | Where | Checked how | Reach |
|---|---|---|---|---|
| Parsing: game data into a model | 18% | each tooltip type's reader, the item wording | fixture outputs: the model, field by field | all of it, given a fixture for each case |
| Conversion and formatting | 9% | stat wording and colors, money, coefficients, disenchant tables, settings and styles | unit checks and fixture outputs | all of it |
| Rendering our panels | 25% | `fitWidth`, `render*`, `draw*`, the chrome | fixture outputs: every string and texture, with place, size, and color | all of it runs; the layout is checked under fixed text metrics, not as the game draws fonts |
| Load-time code | 12% | data tables, frames made at file level | every test loads every file | all of it: a load error fails every test |
| Game integration | 10% | hiding and refitting the game's tooltip, hooks, timers, the modifier key, follow cursor, comparison anchoring | not yet; scenario tests could drive the hooks and timers, but how the game lays out and times its tooltips cannot be reproduced | part; the rest needs the game |
| UI and tools | 25% | the style editor, the options page, `/ptip capture` | loaded by every test; the editor's samples can be rendered as expected outputs | the drawing; clicks and menus only with simulated input, which is little use |

Assets are apart from these: the `art/make_*.py` generators are deterministic, so a check can regenerate them and compare against the committed textures.

### Renaming and moving code

A rename or a move breaks a test when the code it touches runs in one: every test loads every file, so a name left behind at file level fails all of them, and one inside a function fails the tests that run it. A model field renamed on purpose shows as an output diff to accept with `--update`. A name left behind on a path no test runs goes unnoticed, which `--coverage` shows; a static checker such as [luacheck](https://github.com/lunarmodules/luacheck), which reports names used but never defined, catches those regardless of coverage.

## Unit checks

`unit/safe_values.lua`, `unit/safe_integration.lua`, and `unit/safe_health_bar.lua` exercise restricted API results and arguments, inaccessible tables, malformed tooltip callbacks, forbidden/protected frames, native bar restoration, and diagnostic redaction. These are simulated checks, not a replacement for the client's taint engine; see [the audit and client checks](taint-safety.md).

Each file in `tests/unit` returns a function given `test`, with `test.load(files, fixture)`, which loads the named addon files with a world answering from `fixture.calls`, and `test.check(name, got, expected)`. `test.load` returns the namespace and the world without starting the addon, using `fixture.enums` when supplied; `world.fireEvent(event, ...)` drives its registered listeners. `unit/coefficient.lua` is an example, giving the spell power split a table that stands in for the game; `unit/game.lua` checks that hidden answers come back as nil and runs disenchant results against a stand-in game; `unit/on_hit.lua` checks weapon proc colors against spell rendering, settings, and native tooltip restoration. `unit/settings.lua` checks the shared settings API without loading UI; `unit/stats.lua` checks formatting without saved settings or game APIs. `unit/startup.lua` checks deferred registration, rewrite/panel/cursor order, modifier restoration, and repeated installation.

`unit/localized_coefficients.lua` checks nine native spell descriptions in each translated locale against fixed spell power and known results: direct damage, direct healing, mixed effects, periodic totals, per-tick channels, and absorbs. The wording comes from Forever's Spell table, with fixed values substituted for its client tokens. Existing localized spell captures check that the translated coefficient and efficiency rows render correctly, and that the plain variant hides them.

## How it fits together

- `harness/wow.lua` stands in for the game: frames, font strings, and textures that keep what is set on them, game functions that answer from the fixture, and fixed text metrics (half the font size per character), so layouts come out the same every run.
- `harness/main.lua` loads the addon and runs a fixture or a unit file, with retail's game strings when the files are retail's.
- `harness/serialize.lua` writes fixtures (Lua that reads back exactly) and expected outputs (sorted, readable text).
- `harness/enums.lua`, when present, holds the client's enums from the newest capture, for fixtures captured before captures carried them.

`tests/` is not packaged with the addon (see `.pkgmeta`).
