# Taint and restricted-data audit

Reviewed on 2026-10-19 for WoW Forever (interface 16001), against the addon's code and Blizzard's `classic_beta` UI source.

The addon contains guards and regression checks for the cases below. This is not a certification that no combination of client state, Blizzard changes, or other addons can cause taint. The offline Lua harness does not implement Blizzard's secure execution engine, protected-frame ancestry, or every behavior of secret primitives. No path is known to taint Blizzard code; the ones found are listed under [Resolved](#resolved).

## What taint means here

Code an addon runs is insecure, and every value it writes carries that taint. Blizzard code that reads a tainted value runs tainted from then on. The addon calls no protected functions and tooltips are not protected frames, so the classic symptom, "Interface action failed because of an AddOn", is unlikely. The risk in Forever is secret values: Blizzard code running tainted loses the right to operate on them, so in combat, where unit, aura, and cooldown data are hidden, it can raise Lua errors in Blizzard files that the client attributes to the addon, and tainted fields stay tainted until Blizzard rewrites them securely.

`pcall` only contains Lua and API errors. It does not remove taint, grant access to secret values, or authorize a protected operation; permission and data checks must happen before the operation.

## Guards in place

| Area | Handling |
| --- | --- |
| Game functions | Integrations use `hooksecurefunc`, `HookScript`, and the tooltip processor callback API. They do not replace Blizzard functions or use secure-call wrappers to attempt protected actions. |
| Callback isolation | The processor runs callbacks an addon registers through `securecallfunction` after `forceinsecure()`, so a callback's own execution does not taint the processor. Values a callback writes into the tooltip data are not isolated, so the addon writes none: item wording goes onto the native font strings in a post-call (see [Resolved](#resolved)). |
| Restricted data | `util.isSecret` checks secret values and, when available, inaccessible tables through `canaccesstable`. `util.call` rejects restricted arguments and results; individual consumers also validate nested fields. |
| Tooltip callbacks | Restricted callback data and failed key, read, or render operations leave or restore the native tooltip. Secret alpha and visibility arguments are not compared or formatted. |
| Combat | In combat the client hides a spell's "Cooldown remaining" line (text and color) and every font string of the game's tooltip, the spell's name included. The spell reader keeps its panel: a hidden line is kept as an opaque value and drawn by `ui.hiddenTextAt`, which passes it to a font string of its own without reading, measuring, or comparing it; rows other addons append are left out while unreadable. Font strings that showed a secret are never reused for readable text, and the panel's size comes from the addon's own numbers, so its geometry stays readable. The item, aura, and unit readers still restore the native tooltip when a line is hidden. |
| Native frames | Cosmetic integrations reject forbidden and protected native frames, including outside combat. A frame whose width cannot be read is rejected too: it can inherit a forbidden layout from the frame it is anchored to without `IsForbidden` reporting it. A width that is only hidden is not a restriction, as combat hides a tooltip's size with its text. Permission-check errors or unknown permission results fail closed. |
| Layout | Cursor follow anchors GameTooltip once to a 1x1 tracker frame of the addon's that moves with the cursor, and again only when the panel's height changes; the tooltip is never reparented, and moving the mouse touches only the tracker. Cursor placement and saved anchor replay require readable coordinates. Native refitting checks dimensions and padding before arithmetic. Placement flags are reset after guarded operations fail. |
| Health bar | The renderer borrows the native bar without calling `UnitHealth`, `UnitHealthMax`, or reading the bar's value. Restricted bars are not adopted. If a borrowed bar becomes restricted, its return is deferred and retried after combat when accessible. Another addon can keep the native bar hidden (EllesmereUI's tooltip health strip setting); the panel then shows none. |
| Addon bookkeeping | Aura caching and native health-bar hook registration use addon-owned weak tables rather than adding bookkeeping fields to Blizzard objects. The editor's scanner metadata is on an addon-created frame. |
| Diagnostics | Dump output marks restricted fields rather than stringifying secrets. Anchor output omits unreadable geometry. Captures retain restricted-value markers and skip forbidden/protected frames. |

## Known taint paths

None known. The two paths found by this audit are fixed; see [Resolved](#resolved).

### Resolved

#### Item wording rewrote Blizzard's tooltip data

`Integration/ItemLite.lua` used to register an item pre-call that replaced stat lines in the tooltip data with tables it built (`lines[index] = copy`). The processor's `ProcessLines` read those lines afterwards, so the rest of that processing ran tainted, and other addons' callbacks saw the rewritten lines instead of the game's. The pre-call is gone: the item post-call puts the wording onto the native font strings with `SetText`, as the modifier-key switch does, and the item reader asks `ns.ItemLite.wording(line)` for it instead of reading fields from the data (`unit/item_lite.lua`, `unit/startup.lua`).

#### `Hide()` on GameTooltip ran its OnHide under taint

`Integration/Native.lua` (`fadeOut`) and the cursor-follow fade hook in `Integration/Cursor.lua` used to call `Hide()` on GameTooltip when a world unit's tooltip started fading, so the native tooltip did not show through the panel's fade. GameTooltip's OnHide (`GameTooltip_OnHide`) then ran tainted and wrote `needsReset`, `default`, `overrideComparisonAnchorFrame`, `overrideComparisonAnchorSide`, and `comparing`, and hid `ShoppingTooltip1` and `ShoppingTooltip2`. Neither hook hides the tooltip now, in combat or out of it. `fadeOut` sets the tooltip's alpha to zero and fades the panel; a faded panel stays shown at zero alpha, its OnUpdate holding the tooltip hidden, until the game hides its tooltip, which takes the panel with it. The cursor-follow fade hook is gone: a fading tooltip keeps following until the game hides it (`unit/fade.lua`, `unit/fade_in_combat.lua`, `unit/cursor_combat.lua`).

### Not a concern

- `Show()` on GameTooltip runs no Blizzard Lua: in `classic_beta` GameTooltip has no OnShow script. `EmbeddedItemTooltip`'s OnShow sets `recalculatePadding`, should a panel ever draw on it.
- The editor's and options page's `GameTooltip:Hide()` on mouse-leave runs the same OnHide, as in most addons, outside the tooltips hovered in play.

### Settings window in combat

The game's settings window does not open in combat (checked on the client). `ns.openSettings` checks `InCombatLockdown()` first and tells the player instead, so `/ptip options` and the style editor's More options button do nothing to Blizzard's window then; the editor stays open (`unit/options_combat.lua`). The style editor is the addon's own frame and opens in combat.

## Blizzard APIs the addon uses

The second column says what can go wrong: **Secret** marks a value the client can hide (how the addon guards it is in the comment), **Taint** marks a call that runs Blizzard Lua or changes Blizzard data under the addon's taint, and **Low** marks static data with no known restriction. The `.luacheckrc` lists every game global the addon reads.

### Hooks and callbacks

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `hooksecurefunc` | None: the hook runs after the original, and its taint stays in the hook | Post-hooks on the game's tooltips' `Show`, `SetShown`, `SetPoint`, `SetAlpha`, `SetOwner`, `FadeOut` (Hooks, Native, Cursor, Quest; `FadeOut` by Native alone); `GameTooltipStatusBar:SetPoint` (Unit); the globals `GameTooltip_SetDefaultAnchor` (Cursor), `SetItemRef` (Quest), `TaxiNodeOnButtonEnter` (FlightPath), `ChatEdit_InsertLink` (Editor). |
| `Frame:HookScript` | None, as above | `OnHide`, `OnTooltipCleared`, `OnShow` on the game's tooltips (Hooks, ItemLite, Aura, Cursor); `OnHyperlinkEnter` and `OnHyperlinkLeave` on the chat frames (Quest). |
| `TooltipDataProcessor.AddTooltipPostCall` | None for the callback, which the processor runs through `securecallfunction`; its `tooltipData` can hold secrets | Hooks draws a panel per data type, Cursor follows the cursor, ItemLite switches item wording. Receives `(tooltip, tooltipData)`. |
| `issecretvalue`, `canaccesstable` | None: the permitted checks | `util.isSecret`, which every read of game data goes through. |

### The game's tooltips (GameTooltip, ItemRefTooltip, ShoppingTooltip1 and 2)

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `GetTooltipData`, `GetProcessingTooltipInfo` | **Secret**: in combat, line text and color and fields such as `hasDynamicData` | The item, spell, aura, and quest readers; `/ptip dump` and captures. Called through `util.call`; every field is checked with `isSecret` before use. |
| `IsTooltipType`, `GetItem`, `GetUnit` | **Secret** (results) | Which type a tooltip shows, and the item link and unit token for the readers. Through `util.call` or `pcall`. |
| `NumLines`, `GetLeftLine`, `GetRightLine` | None; the font strings they return can hold secrets | Change detection, other addons' rows, a spell line's drawn right side, and the rows ItemLite rewords. |
| FontString `GetText`, `GetTextColor` (the game's lines) | **Secret**: every drawn line in combat, the name included | Read through `safeText` and `isSecret`. A secret leaves the row out, or keeps it as an opaque value drawn by `ui.hiddenTextAt`. |
| FontString `SetText` (the game's lines) | None: a C call that runs no Lua | ItemLite swaps item wording when the modifier key changes. |
| `GetOwner`, `GetName`, `GetParent` | The owner can be protected or forbidden | Quest-log buttons and chat links (Quest), captures. Owners pass `util.canModify` first. |
| `IsForbidden`, `IsProtected`, `GetWidth` (as a probe) | None | `util.canModify`: forbidden or protected frames are left alone, as is a frame whose width read fails; a failed check counts as restricted. |
| `IsShown` | **Secret** in principle | Throughout, mostly through `util.call`. |
| `GetAlpha`, `SetAlpha` | **Secret** (alpha). `SetAlpha` runs no Blizzard Lua, though other addons' hooks on it run | Keeps the game's tooltip at alpha 0 under the panel and restores it. A secret alpha restores the game's tooltip. |
| `GetWidth`, `GetHeight`, `GetPadding`, `SetPadding` | **Secret** (geometry). `SetPadding` runs no Lua | Sizes the hidden game tooltip to cover the panel, so comparisons and screen clamping treat the pair as one (Native). Checked before any arithmetic. |
| `GetNumPoints`, `GetPoint`, `ClearAllPoints`, `SetPoint` | **Secret** (anchors). `SetPoint` fires hooks, the addon's own included | Anchors comparisons to the panels, anchors GameTooltip to the cursor tracker when it starts following (not every frame), places the health bar. Snapshots through `util.framePoints` need every part readable. |
| `IsClampedToScreen`, `SetClampedToScreen`, `GetEffectiveScale` | **Secret** in principle (scale) | Cursor follow unclamps the game's tooltip while the panel keeps itself on screen. |
| `Show` | None: GameTooltip has no OnShow script | The refit fallback and padding release (Native), relayout after a wording switch (ItemLite). |
| `Hide` | **Taint**: runs `GameTooltip_OnHide` | The early hide when a unit's tooltip starts fading (Native, Cursor), outside combat only. The editor's and options page's hover help also hide GameTooltip, as most addons do. |
| `SetOwner`, `SetText`, `AddLine`, `Show` (hover help) | As any addon's hover help | Explanations in the style editor and options page, outside the tooltips hovered in play. |

### The health bar

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `GameTooltipStatusBar`: `IsShown`, `GetParent`, `SetParent`, `GetNumPoints`, `GetPoint`, `ClearAllPoints`, `SetPoint`, `GetHeight`, `SetHeight`, `GetStatusBarTexture` | Moving a protected bar would be blocked, so `util.canModify` is checked first; the bar's value is secret but never read | Borrows the game's bar into the unit panel and returns it as it was (Unit). |

### Units and auras

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `UnitExists`, `UnitGUID`, `UnitTokenFromGUID`, `UnitName`, `UnitLevel`, `UnitEffectiveLevel`, `UnitClass`, `UnitRace`, `UnitFactionGroup`, `UnitReaction`, `UnitIsUnit`, `UnitIsPlayer`, `UnitIsTapDenied`, `UnitIsPVP`, `UnitIsDeadOrGhost`, `UnitIsAFK`, `UnitIsDND`, `UnitCreatureType`, `UnitClassification`, `GetGuildInfo` | **Secret** for some units, mostly in combat | Unit panels: name, level, class color, badges, reaction, guild (Game). All through `util.call`; a secret result reads as missing. |
| `UnitHealth`, `UnitHealthMax` | **Secret** in Forever | Not used by the panels. Recorded by `/ptip capture` in debug builds only, results guarded. |
| `C_UnitAuras.GetAuraDataByIndex`, `C_UnitAuras.GetAuraDataByAuraInstanceID` | **Secret** (fields such as stacks, duration, and expiration) | Aura panels (Game, Aura). Fields read through `readable` and `util.number`. |
| `GetQuestDifficultyColor` | **Secret** in principle | Level colors on units and quests. |

### Spells, items, quests, and other game data

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `C_Spell.GetSpellName`, `C_Spell.GetSpellTexture`, `GetSpellInfo`, `GetSpellTexture` | Low: static data | Spell names and icons (Game, Samples). |
| `GetSpellBonusDamage`, `GetSpellBonusHealing` | **Secret** in principle (player stats) | The spell power rows. |
| `C_Item.GetItemInfo`, `GetItemInfoInstant`, `GetItemNameByID`, `GetItemIconByID`, `GetDetailedItemLevelInfo`, `GetItemCount`, `IsEquippedItem`, `GetItemLocation`, `GetStackCount`, `RequestLoadItemDataByID`, `DoesItemExistByID` | Low: static data and the player's bags | Item panels, disenchant names, stack prices, and the editor's lookup by ID. Through `pcall`, each result checked. |
| `C_QuestLog.GetInfo`, `GetLogIndexForQuestID`, `GetTitleForQuestID`, `GetQuestInfo`, `IsOnQuest`, `IsQuestFlaggedCompleted`, `RequestLoadQuestByID` | Low | Quest panels, quest levels, and the samples. |
| `GetMacroInfo`, `GetNumMacros`, `GetMacroSpell`, `GetMacroItem`, `GetMacroIndexByName` | Low | Macro panels and `#showtooltip`. |
| `GetPetActionInfo` | Low | Pet ability panels. |
| `GetProfessions`, `GetProfessionInfo`, `GetNumSkillLines`, `GetSkillLineInfo` | Low | The player's gathering and Enchanting skill. |
| `C_Texture.GetAtlasInfo` | Low; each field validated | The elite dragon art on units. |
| `C_CurrencyInfo.GetCoinTextureString`, `GetCoinTextureString` | Low | Money text in sell prices. |
| `NumTaxiNodes`, `TaxiNodeName`, `TaxiNodeCost`, `TaxiNodeGetType`, `BreakUpLargeNumbers` | Low | Recorded by `/ptip capture` in debug builds. |

### The addon's own frames and the game's UI

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `CreateFrame`, `CreateColor`, `NineSliceUtil.ApplyLayoutByName`, `SetPortraitTexture` | None: addon-owned frames | Panels, the editor, the report window, and the cursor tracker GameTooltip hangs from while following. The editor's scanner is an addon-created `GameTooltip`, `PrettyTooltipScanner`. |
| `PixelUtil.GetPixelToUIUnitFactor`, `PixelUtil.GetNearestPixelSize`, `GetPhysicalScreenSize`, `GetCursorPosition` | **Secret** in principle; checked before arithmetic | Pixel snapping, cursor follow, the editor's dragging. |
| `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterAddOnCategory`, `InterfaceOptions_AddCategory` | None known | Registers the options page. |
| `Settings.OpenToCategory`, `InterfaceOptionsFrame_OpenToCategory` | Does not open in combat; not called then | `/ptip options` and the editor's More options. In combat the player is told instead. |
| `HideUIPanel(SettingsPanel)`, `ShowUIPanel(ColorPickerFrame)` | Low: on the player's click, through the game's panel manager | Leaves the settings window for the editor; opens the color picker. |
| `UISpecialFrames` (`tinsert`) | Low: the addon's frame names in a shared Blizzard list, as most addons add | Escape closes the editor and the report window. |
| `C_Timer.After` | None | Deferred refits and restores (Hooks, Native). |
| `C_AddOns.GetAddOnInfo`, `GetAddOnMetadata`, `GetAddOnMemoryUsage`, `UpdateAddOnMemoryUsage` | None | Whether DialogueUI, EllesmereUI, Questie, and Auctionator are installed; the report's version line; `/ptip perf`. |
| `GetLocale`, `GetBuildInfo`, `GetTime`, `date`, `debugprofilestop`, `InCombatLockdown`, `IsAltKeyDown`, `IsControlKeyDown`, `IsShiftKeyDown` | None | The language, version, aura timers, profiling, combat checks, and modifier keys. |

### Constants and other addons

| API | Taint / secret potential | Use in the addon |
| --- | --- | --- |
| `Enum.TooltipDataType`, `Enum.TooltipDataLineType`, `Enum.ItemClass` | None: read-only | The tooltip and line types the readers compare against. |
| The game's strings, about 150 (`ITEM_*`, `SPELL_*`, `TOOLTIP_*`, `DAMAGE_SCHOOL*`, and `ITEM_MOD_*` and `TOOLTIP_ITEM_STAT_*` through `_G`) | None: read-only constants | Every reader matches the client's text against them, in the client's language. |
| `RAID_CLASS_COLORS`, `LOCALIZED_CLASS_NAMES_MALE`, `STANDARD_TEXT_FONT`, `GameTooltipText`, `GameTooltipHeaderText`, `GameFontHighlightSmall`, `QuestScrollFrame`, the chat frames, `NUM_CHAT_WINDOWS`, `NUM_PET_ACTION_SLOTS`, `MAX_ACCOUNT_MACROS` | None: read-only | Class colors, default fonts, the quest log's buttons, the chat frames to hook. |
| `LibStub` (LibSharedMedia), `Auctionator.API.v1.GetAuctionPriceByItemID`, `QuestieLoader` | Those addons' own; called through `pcall` | Extra fonts, auction prices, Questie's quest wording. |

## Automated checks

The tests exercise secret values, inaccessible tables, secret nested API fields, secret anchors and cursor positions, failed permission checks, protected and forbidden tooltips, reader and key failures, native health-bar return, and diagnostic redaction (`unit/safe_values.lua`, `unit/safe_integration.lua`, `unit/safe_health_bar.lua`). The `elune-combat` capture replays a spell on cooldown in combat, and `unit/combat_hidden_line.lua` repeats it in every client language. `unit/fade.lua`, `unit/fade_in_combat.lua`, and `unit/cursor_combat.lua` check that the addon never hides the game's tooltip as it fades, in combat or out of it. The harness's secret stand-in refuses indexing, concatenation, arithmetic, ordering, length, and `tostring`; it cannot catch `==` comparisons, which were checked by reading the code. Existing captures and editor sample outputs check normal behavior.

## Client verification

1. Enable `/console scriptErrors 1` and `/console taintLog 2`, then `/reload` for a fresh session.
2. Exercise unit and aura tooltips, action buttons, bags and equipment comparisons, quest links, and cursor-follow transitions into and out of combat. Include the native-tooltip modifier, the tooltip details modifier, and the health-bar option.
3. Repeat with the normal addon set, especially tooltip, unit-frame, and skin addons. A clean run with PrettyTooltip alone does not establish compatibility with every other addon.
4. Log out to flush diagnostics and inspect `Logs/taint.log` for blocked or forbidden actions and the originating stack.
5. Restore the previous diagnostic settings afterward; `/console taintLog 0` stops taint logging.

## Client results

On 2026-10-19 two sessions with `/console taintLog 2`, each with several fights alongside EllesmereUI, AtlasLoot, Baganator, Questie, and other addons, logged no blocked action and no taint from PrettyTooltip in tooltip or combat code. Its only entries were two kinds every addon produces: Blizzard's `CloseWindows` reading the `PrettyTooltipEditor` name the addon registers in `UISpecialFrames` (inside `securecall`, on login, logout, and Escape), and the chat frame reading `SLASH_PRETTYTOOLTIP1` and `SLASH_PRETTYTOOLTIP2` to register `/ptip`. The log does not report reads of fields inside the tooltip processor's data tables, so it neither confirmed nor ruled out the item rewrite path, since removed (see [Resolved](#resolved)).

## Sources

Blizzard's exported [FrameScript API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua) defines the secret-value and table-access checks. The `classic_beta` [tooltip processor](https://github.com/Gethe/wow-ui-source/blob/classic_beta/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua) shows how callbacks are isolated and which line fields it reads after them, and [GameTooltip.xml](https://github.com/Gethe/wow-ui-source/blob/classic_beta/Interface/AddOns/Blizzard_GameTooltip/Classic/GameTooltip.xml) and [GameTooltip.lua](https://github.com/Gethe/wow-ui-source/blob/classic_beta/Interface/AddOns/Blizzard_GameTooltip/Classic/GameTooltip.lua) define its scripts and what `GameTooltip_OnHide` writes. These sources describe engine interfaces, not proof of a clean run on a player's client; optional APIs remain feature-detected.
