# Rendering

How a model becomes pixels. Shared drawing code is in `Panel/Layout.lua` (frames, text, textures, chrome, alignment, exported as `ns.ui`) and `Panel/Render.lua` (`ui.renderView`). Anything only one tooltip type draws stays in that type's file as a custom section.

## The panel frame

`ui.getPanel(tooltip)` returns the panel for a game tooltip, creating it on first use. Panels are kept in a weak table keyed by the tooltip (`ui.panels`), so each game tooltip has exactly one. A panel is a plain `Frame` parented to `UIParent` in the `TOOLTIP` strata, clamped to the screen, and set to ignore its parent's alpha. `createPanel` builds its permanent regions once:

| Region | Purpose |
|---|---|
| `halo` | An additive glow behind the panel (`art/glow.tga`, nine-sliced), tinted by quality or school. |
| `background`, `glow` | The backdrop. The glow is an additive copy used with the DialogueUI texture. |
| `shades`, `edges` | Inner shading gradients and 1 px edges, used only by the flat backdrop. |
| `header` | The tinted band behind the header. |
| `icon`, `iconBorder` | The icon and its frame. |
| `badge`, `badgeFill`, `badgeText` | The level plate under the icon. |
| `measure` | An invisible font string used to measure text. |

Everything else (each text row, rule, divider, bar, and marker) comes from pools, described below.

The style editor's preview uses `ui.renderPreview`, which creates a separate panel inside the editor window with `isPreview = true`. Previews show every detail that's turned on, regardless of the details key, and record a "hit" for each styled part so the editor knows which part is under the cursor.

## Views

A tooltip type's `render` usually builds a **view** and calls `ui.renderView(panel, tooltip, view)`. The full shape is documented at the top of `Panel/Render.lua`. In short:

```lua
{
    tooltipType = "item",            -- backdrop and header settings by type
    color = accent, tint = accent,   -- border/halo color, header tint
    strength = .7,                   -- how strongly the header is tinted
    gradient = { left, right },      -- a dual school, drawn across
    icon = texture, iconSize = 43,
    portrait = "mouseover",          -- a unit portrait fills the icon
    badge = "iLvl 63",               -- the plate under the icon
    tag = "EQUIPPED",                -- the label above a comparison
    header = {                       -- beside the icon, in order
        { text = name, style = styles.title, color = quality, gap = 4 },
        { badges = { { "Buff", BLUE } }, style = ..., before = 1, gap = 4 },
        { rows = { { left = .., right = .. } }, style = ..., color = .., gap = 3 },
    },
    sections = {                     -- below the header, in order
        { separator = { divider = GOLD }, kind = "prose", sentences = { .. }, style, color, numbers = "FFF6E4", gap = 5 },
        { separator = { rule = GREY },    kind = "rows", rows = { .. }, style, color, gap = 2, wrap = true },
        { separator = { caption = "Reagents", style = .. }, kind = "custom",
          measure = function(panel) return width end, draw = function(panel, y) return y end },
    },
    footer = { rows = { .. }, style, color, gap = 4 }   -- or { measure, draw }
}
```

- **Separators** go above a section: a gold `divider`, a thin `rule`, a small-caps `caption`, or plain `space`. A divider or rule after rows is spaced so it sits as far below the last row's letters as above the next section. `panel.rowTail` records how much space the last row left below its text, and `before` overrides it.
- **`prose`** sections draw each sentence as a wrapped row, optionally with numbers highlighted (`util.colorNumbers`).
- **`rows`** sections draw left/right pairs. With `wrap`, a row with nothing on the right wraps at prose width.
- **`custom`** sections draw themselves. Their optional `measure` reports the width they need. Item stats, spell bodies, sets, created items, quest objectives, and the aura time bar are custom sections.

### Measure, then draw

`renderView` works in this order:

1. Return anything a tooltip type lent the panel (`panel.release`, used for the unit health bar), and apply the global tooltip scale.
2. Clear the pools and any live update.
3. **Fit the width.** `fitWidth` measures every header line, badge line, row, sentence, custom section, and footer. It returns the widest plus padding, between `minWidth` (a setting, 260 by default) and `MAX_WIDTH` (408). Prose is capped at `PROSE_WIDTH` (270), so long sentences wrap rather than widen the panel. The width is snapped to whole pixels.
4. **Draw the chrome** (`ui.drawChrome`): backdrop, halo, header band and tint, icon and border, badge, and comparison tag. On a chat-link tooltip (`ItemRefTooltip`) it also draws a close button of its own, which clicks the game's, because the game's button is a child of the hidden tooltip. It returns the minimum header height, which the icon sets.
5. Draw the header lines beside the icon, then each section with its separator, then the footer.
6. **Finish** (`ui.finishPanel`): set the height (snapped), align the panel to its tooltip, and show it.

Because the width is measured from the same view that's then drawn, the two can't disagree. Each row's height comes from its font string after layout (`GetStringHeight`), so wrapped text pushes the next row down.

## Text

All text goes through a few helpers:

| Helper | Purpose |
|---|---|
| `ui.styledAt(panel, text, x, y, width, style, color, align)` | Draws text in a style (font, size, outline, capitals, custom color). Returns its height. |
| `ui.textAt(...)` | The lower-level version, given a size and font. Takes the next font string from the panel's pool. |
| `ui.drawRow(panel, row, y, style, color, indent, gap, rightIndent)` | A left/right row. The right side is right-aligned and takes at most half the width when the left needs room. The left wraps in the space left over. |
| `ui.measureStyled(panel, text, style)` / `ui.rowWidth` | Unwrapped widths, from the panel's `measure` font string. |
| `ui.hiddenTextAt(...)` | Draws a secret value without reading it. See below. |

A style comes from `ui.styleOf(key)`. It resolves the part's saved size, font, outline, color, and capitals (see [Settings](settings-and-editor.md#styles)), then fills in the title or body font. The title font is EllesmereUI's Expressway when that addon is installed, except on Korean and Chinese clients, which lack those glyphs. Otherwise both fonts come from the game's tooltip font objects, so a UI addon that replaces those fonts is followed. A chosen LibSharedMedia font takes priority over both.

A **custom color** on a part replaces every color in the text, inline color codes included. **Capitals** (`style.caps`) uppercase only the text between escape codes, because codes such as `|r`, `|T…|t`, and hyperlinks are case-sensitive. `util.upper` also handles accented Latin and Cyrillic letters.

### Pools and change checks

Each panel keeps a pool of font strings (`panel.pool`) and one of textures (`panel.texturePool`). `ui.clearPool` hides all of them at the start of a render, and each draw takes the next one. Nothing is created after the pool has grown to the largest panel drawn. Font strings remember their font, size, flags, alignment, and color (`prettyTooltipFont`, …) and skip calls that would set the same value. `/ptip perf` and the test runner's `--profile` count these calls.

### Hidden text

`ui.hiddenTextAt` draws a secret value (a combat-hidden spell line). It uses a separate pool, `panel.hiddenPool`, because a font string that has held a secret can keep reporting its size as hidden. The text is never measured: the line is single, unwrapped, at the width given, and its height is taken from the style's size. If `SetText` fails, the line is skipped.

## Pixel snapping

A 1-unit line covers exactly one screen pixel only at some UI scales. At others its edges round apart, and identical lines come out one or two pixels thick. So the panel places sizes and positions on whole pixels:

- `ui.pixel(region)`: one screen pixel in the region's units, from `PixelUtil.GetPixelToUIUnitFactor` or `768 / screen height`.
- `ui.snap(region, value)`: a value rounded to whole pixels (`PixelUtil.GetNearestPixelSize` where available).

The panel's width, height, rules, dividers, and borders are snapped. Alignment (`gridOffset` in `alignPanel`) also nudges the panel so its anchored corner lands on a pixel; otherwise a corner half a pixel off makes every 1 px line round to zero or two. Follow cursor snaps its tracker frame the same way. `/ptip pixel` reports which method is in use and the current pixel size.

## Backdrops

`applyBackdrop` picks one of four looks, and only rebuilds when the look changes (`panel.backdropMode`):

| Mode | When | Look |
|---|---|---|
| `native` | Default without DialogueUI or EllesmereUI | The game's own tooltip border (`NineSliceUtil` with GameTooltip's layout) on a child frame, with the panel's background inside it. |
| `flat` | Default beside EllesmereUI, or chosen | A plain dark fill with soft inner shades and 1 px edges. |
| `dialogue` | DialogueUI installed and wanted | DialogueUI's tooltip texture, nine-sliced, with an additive glow and feathered header band (`art/band.tga`). |
| `parchment` | Quests, with **quest parchment** on and DialogueUI installed | DialogueUI's brown paper. No halo or band, and text colors become ink. |

DialogueUI's and EllesmereUI's art and fonts are used from those addons' folders and never copied into this one.

**Ink on parchment.** `inkColor` turns neutral tooltip colors into dark brown ink, and keeps colored text's hue in a darker shade. `inkText` applies the same change to inline `|c` codes.

The header band's opacity at its top and bottom edges can be set per tooltip type, or shared by all (`ns.headerAlpha`). The backdrop and glow opacity can also be set per type.

## Markers and textures

Item rows can start with small textures instead of words: a diamond for stats (`stat-marker.tga`), a sword for a chance on hit, a sparkle for an enchant, and a gear for a use effect. They're drawn separately from the text and centered where the diamond sits, so every row's text starts at the same indent. With markers off, the game's words (`Equip:`, `Use:`, …) come back. Textures are described in [art/README.md](../art/README.md), and their generators are `art/make_*.py`.

## Alignment

The hidden game tooltip is often wider than its panel (as wide as its longest unwrapped line), and it's narrower until it's been fitted. `ui.alignPanel` anchors the panel's top-left or top-right corner to the same corner of the tooltip, choosing the side the tooltip is anchored by (`anchoredSide`). Any difference in width then faces away from the frame the tooltip hangs from. It skips the `SetPoint` when nothing changed. `ui.pinPanel` holds a panel where it is on screen while its tooltip moves, for fading and follow-cursor hand-offs. Panels whose tooltip is parked off screen are left where they are.

## Live parts

`ui.setLive(panel, update)` registers one update function per panel. A shared ticker frame calls each one every 0.1 s while its panel is shown. A redraw clears it. The aura time bar uses this. `ui.drawTrack` draws a bar's dark track and returns its fill texture for the caller to size.

## Profiling hooks

`ui.probe(name, fn)` wraps a function so that, while `/ptip perf` is running, its calls and time are counted. Otherwise it costs one check. `ui.tally(name)` counts events such as "render skipped" or "refit fast", and `ui.timed(name, start)` adds time to a named part. Every tooltip type's `read` and `render` are probed automatically by `defineTooltipType`.
