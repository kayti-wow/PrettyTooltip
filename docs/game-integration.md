# Game integration

Everything that touches the game's own tooltips lives in `Integration/`, plus a few hooks specific to one tooltip type (quest links in `Tooltips/Quest.lua`, the flight map in `Tooltips/FlightPath.lua`). This page explains each part in the order it runs. The reasons behind the restrictions are in [tests/taint-safety.md](../tests/taint-safety.md), and the summary is in [Architecture](ARCHITECTURE.md#taint-and-hidden-values).

## Startup

`PrettyTooltip.lua` waits for its own `ADDON_LOADED`, when saved settings have arrived, then calls `ns.start()` once:

1. `ns.migrateOptions()`: converts old settings (1.3's `itemLite` became `itemPanels = false`).
2. `ns.ItemLite.register()`: the item wording stage.
3. `ns.Hooks.install()`: the panel stage, for every registered tooltip type.
4. `ns.Details.register()`: detail rows on the game's tooltip.
5. `ns.Cursor.register()`: follow cursor.
6. `ns.Options.register()`: the settings page.
7. `ns.Commands.register()`: `/ptip` and `/prettytooltip`.

Each `register` guards against running twice and returns early when the client lacks what it needs (`TooltipDataProcessor`, `Enum.TooltipDataType`, or a supported language). `tests/unit/startup.lua` checks this order.

## The processor (`ns.Processor`, in `Game/Game.lua`)

| Function | Purpose |
|---|---|
| `processor.onData(stage, dataType, handler)` | Adds `handler(tooltip, data)` for a data type. The first call for a type registers one `TooltipDataProcessor.AddTooltipPostCall`, and every later stage for that type joins the same list. |
| `processor.onKey(stage, handler)` | Adds `handler(key)` to one shared `MODIFIER_STATE_CHANGED` watcher. |
| `processor.stages(dataType)` | Lists a type's stages in order (used by tests). |
| `processor.available()` | Whether the client has the tooltip processor at all. |

Stages are sorted by a fixed rank (`wording`, `panel`, `details`, `cursor`) whatever order they were added in, and each one runs in its own `pcall`. A failure goes to the game's error handler and the remaining stages still run. The addon registers **no pre-calls**, and its post-calls never write into `data`.

## When panels draw (`Integration/Hooks.lua`)

### The handover

`onTooltipData(dataType, tooltip, data)` runs once the game has filled a tooltip:

1. Rejects frames the addon may not touch (`util.canModify`) and unreadable data. Skips the style editor's own scanner tooltip.
2. `native.unpark(tooltip)`, in case the tooltip was parked while fading.
3. Computes the type's `key`. An invalid key restores the native tooltip.
4. Saves `dataType`, `data`, and a new `refreshToken` on the panel.
5. On first sight of this tooltip, installs its hooks (below).
6. If the panel shouldn't show (type not restyled, Blizzard layout, or the original-tooltip key held), restores the native tooltip.
7. **New content** (panel hidden, different data type, or different key): calls `update` at once.
8. **Same content**: hides the native tooltip again, refits it, and keeps the old panel.
9. In both cases, on the next frame (`C_Timer.After(0)`), if the token still matches and the tooltip still shows this type, it redraws, unless the fingerprint matches what the panel already shows ("render skipped").

`update(tooltip, data)` does the actual work: `read`, remember the native alpha, `render`, `refitNative`, store the key, line count, and fingerprint, then `SetAlpha(0)` on the game's tooltip. Any failure along the way calls `restoreNative`.

### The fingerprint

`fingerprint(tooltip, data)` joins into one string:

- the settings version
- whether the tooltip is a comparison
- whether the details key is down
- every shown font string's text and color
- each data line's sell price

A redraw is skipped when it matches. It returns nil when anything is hidden, which forces a redraw. Units opt out with `alwaysRedraw`.

### Hooks on each tooltip

Installed once per tooltip, the first time it gets a panel:

| Hook | Why |
|---|---|
| `OnHide`, `OnTooltipCleared` → `scheduleRestore` | Restores on the next frame, unless new data arrived meanwhile. Some owners clear and refill the same item, and tearing down at once would flicker. |
| `Show`, `SetShown`, `OnShow` → `onNativeShown` | Every refresh shows the game's tooltip at full size and opacity. Refit it, realign the panel, re-anchor comparisons, and set alpha back to 0. The comparison manager uses `SetShown`, which never goes through `Show`. |
| `SetPoint` | The comparison code anchors a comparison one point at a time after showing it. Move it next to the panels instead (`anchorToPanels`). |
| `SetAlpha` | Keeps the game's tooltip at 0 and remembers the alpha the game wanted. A secret alpha restores the native tooltip. |
| `FadeOut` → `native.fadeOut` | See [Fading](#fading-world-unit-tooltips). Hooked after follow cursor's, which stops following first. |
| `SetOwner`, `OnHide` → `native.unpark` | Puts a parked tooltip back. |
| Panel `OnUpdate` | Keeps the game's tooltip at alpha 0 every frame. Every 0.25 s, checks whether lines were added or rewritten in place (the talent window does this) and redraws on the next frame if so. |

### The modifier keys

`processor.onKey("panel", …)` reacts to the original-tooltip key (ALT by default) and the details key (Shift by default). For every shown tooltip with a panel, it either restores the native tooltip (original key down) or redraws from the saved `panel.data` (details key changed).

### Tooltips filled with lines only

Some tooltips have no data type: the flight map, Questie's quest links, and the world map's quest log buttons. `ns.Hooks.renderLines(tooltip, dataType, id)` sends them through the same `onTooltipData` path with `{ lines = {}, fromLines = true }`. Their readers then read the drawn font strings. `showsDataType` treats such a panel as current until the tooltip is cleared.

## The hidden tooltip underneath (`Integration/Native.lua`)

### Fitting

`refitNative(tooltip, panel)` makes the hidden tooltip at least as large as the panel by adding right and bottom padding:

1. Remembers the tooltip's own padding the first time (`panel.nativeSize`).
2. Works in the tooltip's units: the panel's size times `panelScale / nativeScale`.
3. Skips the fit if neither the tooltip's nor the panel's size changed by more than half a unit.
4. **Fast path.** `GetPadding` reports the padding applied now, so the natural size is `size - (padding - base)`. The new padding is `base + max(0, panel - natural)`. It doesn't read the size back, which would cost a second layout. A wrong guess fails the next check and refits.
5. **Shrink guard.** Right after `Show` the game can report a size from before layout finished. A size below the largest seen for this item waits for a recheck on the next frame (`recheckNextFrame`).
6. **Fallback** (no `GetPadding`): reset the padding, `Show`, measure, set the padding, `Show` again. `Show` is only called on a tooltip that's already shown.
7. Realigns the panel, because a tooltip anchored by its bottom edge moves its top as it grows.

`refitUnlessPartial` skips the fit while the tooltip has fewer lines than the most it has shown for this item. Each refresh re-sets the item's lines and then adds the comparison lines, and fitting the shorter step would set the padding twice.

### Comparisons

Blizzard anchors `ShoppingTooltip1` and `ShoppingTooltip2` to the hidden tooltip's edges, which can lie past a narrower panel. `anchorToPanels` re-points each of their anchor points from a hidden tooltip to its shown panel. `native.anchoring` stops the `SetPoint` hook from re-entering. `restoreNative` points them back. Comparison panels are tagged "Equipped" by the item view.

### Restoring

`restoreNative(tooltip)`:

1. Puts the base padding back (only if the tooltip still shows this content, because the game resets size on hide and a new owner may have set its own padding).
2. Hides the panel.
3. Restores the saved alpha.
4. Re-points any comparisons at the game's tooltip.

It's safe to call at any time, and it's the fallback for every failure.

### Fading world-unit tooltips

When the mouse leaves a unit in the world, the game fades `GameTooltip` by setting its alpha from C every frame, bypassing the `SetAlpha` hook. The hidden tooltip would show through. `fadeOut`:

1. Hides the panel at once.
2. **Parks** the tooltip: saves its anchors and clamping, unclamps it, and anchors it 10000 units off the bottom-left of the screen.

The game hides the tooltip itself when the fade ends. `unpark` runs on `SetOwner`, `OnHide`, or new data. It removes the parked anchor (recognized by being far off screen, because `GetPoint` may not return exactly what was set), restores the saved anchors if no others remain, restores clamping, and realigns the panel. A shown tooltip keeps its points through `SetOwner`, so the game's new anchor can land beside the parked one. Removing only the parked point avoids stretching the tooltip to zero height.

Parking replaced calling `Hide()`, which ran `GameTooltip_OnHide` under the addon's taint. `tests/unit/fade_in_combat.lua` and `tests/unit/cursor_combat.lua` check that the addon never hides the game's tooltip.

## Details on the game's tooltip (`Integration/Details.lua`)

Where the game's tooltip shows instead of a panel (the Blizzard layout, or a type that isn't restyled), the addon still adds its **details**: disenchant results, the spell power breakdown and rates, gathering and skinning loot, and IDs. Each tooltip type's `details(model, context)` returns those rows, and `detailKeys` names the settings that turn them on.

The rows aren't added as tooltip lines. They're the addon's own font strings on a frame parented to the tooltip, in room taken at its bottom:

- **Bottom padding** for their height, the way the game makes room for an embedded item.
- **A minimum width** for their widest row. A wider minimum the game set is kept.

`SetPadding` resizes the tooltip immediately, so no `Show()` is needed. The game's `OnShow` clears the padding (`GameTooltip_CalculatePadding`), so the stage hooks `Show` and `SetShown` to take its room again afterwards. The details key shows and hides the rows instantly, even in combat, without the game refilling the tooltip. The original-tooltip key leaves the game's tooltip untouched. Room is given back on hide and on refill.

## Item wording on the game's tooltip (`Integration/ItemLite.lua`)

Even where items have no panel, item stat lines can be shortened on the game's own tooltip ("Abbreviated Equip Effects", the `liteWording` setting). The stage runs first, so the panel reader sees the same lines.

- For each item line with a shorter wording (`TooltipData.itemWording`), it remembers the font string and three versions: `original`, `display` (the panel's colors and markers), and `lite` (the game's colors except for magic stats).
- It applies one version with `SetText`, and `SetWordWrap(true)` for combined bonuses that became several lines. Which one depends on the state: the original while the original-tooltip key is held, `display` under a panel, otherwise `lite` or the original.
- When the original-tooltip key changes, it switches every shown item tooltip and calls `Show()` on the already shown tooltip to lay out the changed lines.
- Remembered rows are kept in a weak table and forgotten on hide and clear.

The tooltip data itself is never changed. Before 1.3 this was a pre-call that replaced the data's line tables, which tainted the rest of the game's fill.

## Follow cursor (`Integration/Cursor.lua`)

Each tooltip category in `ns.TOOLTIP_TYPES` has a `cursor*` setting. When it's on, `GameTooltip` follows the mouse. This only applies to tooltips the game placed with `GameTooltip_SetDefaultAnchor`, because owners that place their own tooltips (bags, many addons) re-anchor them on every refresh.

- A 1×1 **tracker** frame moves to the cursor in its `OnUpdate`, snapped to whole pixels, and only when the cursor has moved.
- `GameTooltip` is anchored to the tracker by its bottom-left, the panel's height above the cursor. It's re-anchored only when that height changes, so refreshes that briefly resize the hidden tooltip don't make the panel jump. It's never reparented.
- While following, `GameTooltip` is unclamped, and the panel keeps itself on screen. Otherwise every resize of the larger hidden tooltip near a screen edge would shift the panel.
- **Stopping.** `SetOwner`, `OnTooltipCleared`, and `OnHide` stop following and restore the tooltip's original anchors without `SetOwner`, which could clear its content. On `FadeOut` it restores the real anchor before `Native` saves it for parking. A panel whose tooltip is hiding is pinned where it stands.
- **Combat.** With `cursorDisableInCombat` (on by default), following pauses when combat starts and resumes after.

## Other addons

| Addon | Where | What |
|---|---|---|
| DialogueUI | `Panel/Layout.lua` | Backdrop texture and quest parchment, used from its folder. |
| EllesmereUI | `Panel/Layout.lua`, `Tooltips/Unit.lua` | Flat backdrop and Expressway title font by default. When its tooltip health strip hides the game's health bar, the panel shows no bar. |
| Questie | `Tooltips/Quest.lua` | Reads its quest tooltips in its own language. Hooks chat frames whether Questie loads before or after this addon. |
| Auctionator | `Game/Game.lua` | `game.auctionPrice` via `Auctionator.API.v1`. |
| LibSharedMedia-3.0 | `Core/Settings.lua` | Font choices. |
| Class-color addons | `Game/Game.lua`, `Core/Palette.lua` | `CUSTOM_CLASS_COLORS`, ahead of the editor's class colors. |

All but the class-color addons are listed in `## OptionalDeps` in the TOC, so they load first where possible. All of them are detected at runtime with `C_AddOns.GetAddOnInfo` or by checking their globals, and called through `pcall`.
