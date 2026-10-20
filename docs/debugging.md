# Debugging

## Slash commands

`/ptip` and `/prettytooltip` share one handler in `UI/Commands.lua`.

| Command | What it does |
|---|---|
| `/ptip` | Opens the style editor. |
| `/ptip options` | Opens the addon's page in the game's settings window (not in combat). |
| `/ptip dump` | Shows the raw data of the tooltip under the mouse, or of a chat link's tooltip when nothing is hovered: owner, data type, top-level fields, and every line with its type and fields. For a tooltip filled with lines only, it lists the drawn lines. Hidden values print as `<restricted>`. |
| `/ptip perf` | For five seconds, counts how often each probed function and event runs and how long it takes, plus the addon's memory. Use it to see the cost of a change in the real game. |
| `/ptip trace [seconds]` | For 1–10 seconds (default 4), logs every change in each game tooltip's and panel's visibility, opacity, size, and anchors. It also logs each call that moves, shows, hides, or fades a game tooltip, with the first stack line outside the game's code and this file. It flags two faults: the game's tooltip showing under a shown panel, and a panel shown while its tooltip is hidden. |
| `/ptip anchors` | For each shown panel, left to right: where it sits, the gaps between panels, and how its hidden tooltip is anchored. Useful for comparison layout bugs. |
| `/ptip pixel` | Whether pixel snapping uses the game's `PixelUtil` or the addon's own math, and the size of one screen pixel at the current UI scale. |
| `/ptip capture <name>` | Saves the hovered tooltip as a test fixture (debug builds only, see below). |
| `/ptip capture list` / `clear` | Lists or removes saved captures. |

The diagnostic commands open the **report window** (`UI/Report.lua`). Its text is already selected, under a line naming the addon's version, the client build, and the locale. Ctrl+C copies it for a bug report, and Escape closes it. Escape codes are shown as typed, not drawn. Where the window can't be made, the report goes to chat.

The probes `/ptip perf` reads are the `ui.probe` / `ui.tally` / `ui.timed` calls described in [Rendering](rendering.md#profiling-hooks). Common tallies include "render skipped", "refit fast", "refit skipped (partial)", "show hook (comparison)", and "re-anchor after SetPoint". For the same count without the game, run `python tests/run.py --profile`.

## Capturing a tooltip as a test fixture

`UI/Capture.lua` is only in debug builds. It sits between `#@debug@` and `#@end-debug@` in the TOC, so the packager leaves it out of releases. To use it, run the addon from the repository (`python deploy.py`) rather than a release zip.

1. Hover the tooltip, or click a link in chat. Hold Shift first to include comparison tooltips.
2. `/ptip capture <name>`.
3. `/reload` or log out. The game writes saved variables then.
4. `python tests/import_captures.py "<WoW folder>"` writes `tests/fixtures/<name>.lua`. `--only` picks captures and `--rename old=new` renames them. Player and guild names are replaced unless you pass `--keep-names`.
5. `python tests/run.py` creates the fixture's first expected output in `tests/outputs/<name>.txt`. Read it carefully: from then on the tests hold the code to it.

A capture holds:

- the tooltip data, with colors as `{ r, g, b, a }`, hidden values as a marker, and frames and functions left out;
- the lines as drawn (text, color, visibility);
- comparison tooltips, if shown;
- **the game's answers to every question the reader asks** for that type. For example: item info, icons, levels, counts, and stack size for items (including materials a recipe or disenchant mentions); spell info and spell power for spells; unit functions for units; the aura's own data; quest info; macro bodies and every macro's spell and item; the pet bar; the client's enums; the player's level, skills, and installed addons the readers check for.

Capturing doesn't replace any game function to record calls, because that would taint it. The answers are asked for in `UI/Capture.lua` directly. If a reader starts asking something new, `python tests/run.py --notes` lists the calls a fixture had no answer for. Add them to the capture code and capture again.

The full testing workflow, including settings variants, editor samples, unit checks, and CI, is in [tests/README.md](../tests/README.md).

## Running the addon from the repository

`python deploy.py` copies the game files into a WoW AddOns folder. Pass `--addons-dir "<path to Interface\AddOns>"` for a different installation than the default. `/reload` picks up Lua changes. Changes to the `.toc` need a game restart.

## Checking for taint in the client

The offline tests can't run Blizzard's secure execution engine. To check taint in the game:

1. `/console scriptErrors 1` and `/console taintLog 2`, then `/reload`.
2. Use unit and aura tooltips, action buttons, bags and comparisons, quest links, and follow cursor, both in and out of combat, with the original-tooltip key, details key, and health bar option.
3. Repeat with your usual addons, especially other tooltip, unit frame, and UI skin addons.
4. Log out, then read `Logs/taint.log`.
5. `/console taintLog 0` when done.

[tests/taint-safety.md](../tests/taint-safety.md) records the last results and the known harmless entries.

## Common symptoms

| Symptom | Where to look |
|---|---|
| The game's tooltip flashes through a panel | `SetAlpha` and show hooks in `Integration/Hooks.lua`, and fading in `Integration/Native.lua`. `/ptip trace` flags it. |
| Comparisons overlap the panel or sit too far away | `refitNative` and `anchorToPanels` in `Integration/Native.lua`, and `alignPanel` in `Panel/Layout.lua`. `/ptip anchors`. |
| A panel is missing and the game's tooltip shows instead | A reader returned nil or something failed, so `restoreNative` ran. `/ptip dump` the tooltip, then capture it and run the reader in the tests. |
| A line is in "other addons' rows" when it should be parsed | The reader's line matching. Check the line type in `/ptip dump`, and whether the language's `Locale/` file covers its wording. |
| Lines are blurry or 1 px lines vary in thickness | Pixel snapping. `/ptip pixel`. |
| A panel jumps while following the cursor | `place()` in `Integration/Cursor.lua` re-anchors only when the panel's height changes. |
| An error appears only in combat | Hidden values. Check that every game value goes through `util.isSecret`, `util.call`, `util.number`, or `util.safeText` before use. |
