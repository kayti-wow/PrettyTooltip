# PrettyTooltip developer docs

These pages explain how the addon works, for anyone changing its code. What the addon does for players is in the [main README](../README.md).

Start with the architecture overview, then read the topic guide for the area you're working on.

| Page | What it covers |
|---|---|
| [Architecture](ARCHITECTURE.md) | The big picture: panels drawn over the game's tooltips, the code layout and load order, the life of a tooltip, and the key design decisions. |
| [Tooltip types](tooltip-types.md) | Each kind of tooltip (items, spells, units, auras, quests, objects, macros, pet actions, minimap, flight paths): what its reader looks for and what its panel shows. |
| [Rendering](rendering.md) | How a panel is drawn: views, sections, measuring and fitting, fonts and styles, backdrops, pixel snapping, and the pools of font strings and textures. |
| [Game integration](game-integration.md) | How the addon hooks the game's tooltips: the processor stages, when panels redraw, the hidden tooltip underneath, comparisons, fading, detail rows on the game's tooltip, item wording, and follow cursor. |
| [Localization](localization.md) | How tooltips are read in every client language, what the `Locale/` files hold, and how to add or improve a language. |
| [Settings and the style editor](settings-and-editor.md) | Saved settings, per-part styles, the options page, the style editor, and its samples. |
| [Static data](data.md) | The tables in `Data/`, where each one comes from, and how to regenerate them. |
| [Debugging](debugging.md) | The `/ptip` diagnostic commands, the report window, and capturing a tooltip as a test fixture. |

Related pages elsewhere in the repo:

- [tests/README.md](../tests/README.md): running the tests, fixtures, expected outputs, CI, and packaging.
- [tests/taint-safety.md](../tests/taint-safety.md): the taint and hidden-value audit, with every Blizzard API the addon calls.
- [art/README.md](../art/README.md): each texture and the script that makes it.
- [CHANGELOG.md](../CHANGELOG.md): release notes.
