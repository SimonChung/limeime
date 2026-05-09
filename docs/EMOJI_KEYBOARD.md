# Emoji Keyboard — iOS v1 (English layout only)

> **v1 scope** (this document): iOS only, emoji-launcher key on the **English keyboard layout only**, target Emoji 17.0.
>
> **v2 (deferred, separate plan)**: Android port + iOS phonetic/symbol-page coverage. The data rebuild and search pipeline below are deliberately platform-agnostic so v2 can adopt them with no schema change.

## Context

User asked whether LimeIME can add an emoji button on the keyboard that "links to the iOS emoji keyboard". The literal request — directly invoking Apple's system Emoji keyboard from a custom keyboard extension — is **not possible** through any public iOS API. The realistic, cross-platform interpretation is:

> Add a dedicated emoji key on the LimeIME keyboard that opens an **in-keyboard emoji panel** rendered by LimeIME itself, using a freshly-rebuilt `emoji.db` as the data source.

This is exactly what every third-party iOS keyboard does (Gboard, SwiftKey, etc.) and is the natural Android approach as well — Android has no separate "system emoji keyboard" to link to in the first place; emoji are emitted by whichever IME is active. So the universal design is: **same UX, same preference keys, same data source, parallel platform-native implementations.**

The current `emoji.db` is outdated (issue #29) — older Unicode/emoji version, no category data, and the `(tag, value)` keyword-row schema makes high-quality search hard. v1 therefore **rebuilds `emoji.db` from CLDR/emojibase up front**, including category, multilingual names, and keyword improvements.

### Why universal

- Both platforms already inject emoji into the candidate bar from the same `emoji.db`.
- Both platforms already share the `enable_emoji` / `enable_emoji_position` preference keys.
- Replacing the data source benefits both candidate-bar injection and the new panel, with one rebuild and a thin migration shim.
- Keeping the UX, preference names, and visual hierarchy identical reduces user confusion when switching devices and keeps the docs/screenshots reusable.

## Goal

- Add a dedicated emoji key on the LimeIME **English keyboard** layout's bottom row (iOS only, v1).
- Tapping it opens an emoji picker panel that **replaces** the keys area (candidate bar stays visible) — the regular keyboard rows (incl. space) are hidden while the emoji panel is shown.
- Panel UX **mirrors the iOS system Emoji keyboard**:
  - **Search bar** at the top (filter emoji by tag/name).
  - **Scrollable grid** of emoji glyphs, organized into **multiple categories** with section headers.
  - **Category tab strip** at the bottom for quick jump (Smileys, Animals, Food, Activities, Travel, Objects, Symbols, Flags — the standard 8 Unicode CLDR groups).
  - **ABC** button on the tab strip to dismiss the panel and return to the regular keyboard.
  - **Delete** key on the tab strip (so the user can correct a mistakenly inserted emoji without leaving the panel).
  - **No space key** while the emoji panel is active.
- Visibility of the button is gated by a new preference `enable_emoji_button` (default `true`).
- Data source is a rebuilt `emoji.db` (Emoji 17.0, see "Data rebuild" below). The same DB ships in `Database/` and is consumed unchanged by the existing candidate-injection path on both platforms.

## Non-goals (v1)

- Android port of the panel — deferred to v2 (the rebuilt `emoji.db` already drops in for Android's existing candidate-injection path with no Android code changes).
- Emoji-launcher key on the iOS phonetic, symbol, or other non-English layouts — deferred to v2.
- Switching to Apple's system Emoji keyboard (impossible from an iOS extension).
- Skin-tone modifier picker, recents/frequently-used row — follow-up work after v1 ships.

## Shared contract (must match exactly)

| Concept | Value |
|---|---|
| Preference key (visibility) | `enable_emoji_button` (Bool, default `true`) |
| Emoji-key special code | `-201` (opens the panel) |
| Panel-internal special codes | `-202` ABC (dismiss panel), `-5` delete (reuse existing), `-203..-210` category tabs |
| Commit method | Insert the emoji string at cursor (no composition) |
| Button glyph | `😀` literal label (fallback SF Symbol `face.smiling` if the system font can't render it) |
| Bottom-row position (iPhone) | English layout `lime_abc`: emoji key takes the **current `中` slot** (10% width, between `done` and `,`). The `中` key (`switchToIM = -10`) moves up to the home row (`k l m n o p q r s`) which currently ends at 90% width and has a 10% empty slot — `中` becomes the 10th key on that row. |
| Bottom-row position (iPad) | English layout `lime_abc_ipad`: trim `space` and add emoji key on the **right side** of the bottom row, balancing the system microphone key on the left. |
| Data source | New `emoji` table + `emoji_fts` index in rebuilt `emoji.db` (see [EMOJI_DB_V2.md](EMOJI_DB_V2.md)) |

## Data prerequisite — see [EMOJI_DB_V2.md](EMOJI_DB_V2.md)

This UI plan **depends on the data rebuild shipping first or in the same release**. The data side — Emoji 17.0 sources, schema with category + bilingual names, FTS5 index, legacy `en`/`tw` views, build script `.claude/scripts/build_emoji_db.py`, broader candidate-bar matching, and platform upgrade paths — is fully specified in [docs/EMOJI_DB_V2.md](EMOJI_DB_V2.md).

What this UI plan consumes from the rebuilt DB:

- `loadAllEmoji() -> [(value, group_name, sort_order)]` for the categorized panel grid.
- `searchEmoji(_:, locale:)` (FTS5-backed) for the panel search bar.
- The new `findEmojiForCandidate(_:, locale:, limit:)` is also rewired in v1 — it's an iOS-side change but it lives in `LimeDB.swift` and is detailed in [EMOJI_DB_V2.md](EMOJI_DB_V2.md). Listed here only because the iOS v1 PR will touch both files.

What's deliberately out of scope here: Emoji 17.0 build script, FTS5 schema details, Android cache wipe, GRDB FTS5 build settings — all in the DB plan.

## iOS implementation

| Concern | File | Notes |
|---|---|---|
| Key code enum | `LimeIME-iOS/Shared/Models/KeyLayout.swift` (L8-L26) | Add `case emojiPanel = -201`, `case emojiABC = -202`, `case emojiTab0..7 = -203..-210` to `LimeKeyCode` |
| iPhone English layout | `LimeIME-iOS/Shared/Models/KeyLayout.swift:158-198` (`static let english`) and `LimeIME-iOS/LimeKeyboard/Layouts/lime_abc.json` (+ `lime_abc_shift.json` to mirror) | (a) Append `中` (`switchToIM = -10`, label "中文", widthPercent 10) as the 10th key on the home/asdf row (currently `k l m n o p q r s` at 90% — the empty 10% slot at the right end). (b) Replace the bottom-row `中文` slot with the emoji launcher (`emojiPanel = -201`, label "😀", widthPercent 10, `isModifier: true`). All other bottom-row keys keep their current widths; total stays 100%. |
| iPad English layout | `LimeIME-iOS/LimeKeyboard/Layouts/lime_abc_ipad.json` (+ `lime_abc_ipad_shift.json` to mirror) | Trim `space` width by 10% and add the emoji launcher key on the **right side** of the bottom row to balance the system microphone key on the left. Exact placement follows the iPad layout's existing right-side modifier conventions. |
| Key dispatch | `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift:1027` (`onKey`) | `case LimeKeyCode.emojiPanel.rawValue: showEmojiPanel()`; `case .emojiABC.rawValue: hideEmojiPanel()`; tab cases scroll the grid; delete reuses existing `handleBackspace` |
| Panel container (new) | `LimeIME-iOS/LimeKeyboard/EmojiPanelView.swift` | Stack: `UISearchBar` (top) → `UICollectionView` grid w/ section headers → tab-strip footer (`UIStackView` of category buttons + ABC + delete) |
| Panel mount/dismiss | `LimeIME-iOS/LimeKeyboard/KeyboardView.swift` (mirror `expandedCandidatesPanel` ~L380) | When mounting: hide the keys-area `UIStackView`, add `EmojiPanelView` in the same slot so candidate bar stays anchored above. Restore on dismiss. |
| Emoji loader / search APIs | `LimeIME-iOS/Shared/Database/LimeDB.swift` | `loadAllEmoji()`, `searchEmoji(_:locale:)`, `findEmojiForCandidate(_:locale:limit:)` — all FTS5-backed. Spec lives in [EMOJI_DB_V2.md](EMOJI_DB_V2.md); this UI plan only consumes them. |
| Preference UI | `LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift:15` | `@AppStorage("enable_emoji_button") enableEmojiButton: Bool = true` toggle next to existing `enable_emoji` |
| Preference read | `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift:640` | Read `enable_emoji_button` alongside `enable_emoji` |
| Conditional render | `LimeIME-iOS/LimeKeyboard/KeyboardView.swift` (mirror `setGlobeKeyVisible` ~L380) | Hide the emoji-launcher key when toggle is off |
| Encoding | All edited/new Swift files | UTF-8 with BOM (Chinese strings in Settings labels) |

## Android (v2 — out of v1 scope)

Android panel UI is deferred to v2. The data-side fix from [EMOJI_DB_V2.md](EMOJI_DB_V2.md) ships to Android in the same release as the iOS UI work — issue #29's Android scenario (Array IM `國旗` candidate → no country flags) is fixed by the data rebuild alone, no Android UI code needed.

Special key codes `-201..-210` are reserved cross-platform so the Android v2 panel adopts them without renumbering.

## Approach (iOS v1)

### 1. Key definition & layout edits

A new key code `-201` (`emojiPanel`) is added to the **English layout** only. Codes `-202..-210` are reserved for the panel's internal chrome (ABC, 8 category tabs).

- **iPhone**: no `space`-trim. Move `中文` (`-10`) up to the home row's empty 10% slot (after `s`). Place the emoji launcher (10% width) at the bottom-row position vacated by `中文`.
- **iPad**: trim `space` by ~10%. Place the emoji launcher on the right side of the bottom row to visually balance the system microphone key on the left.

### 2. Dispatch

A `showEmojiPanel()` / `hideEmojiPanel()` pair in `KeyboardViewController`:

- `showEmojiPanel()`: hide the keys-area view, mount `EmojiPanelView` in its slot. Trigger an async load of the emoji dataset on first invocation (search dispatch queue); cache it so subsequent opens are instant.
- `hideEmojiPanel()`: tear down the panel and restore the keys-area view. Triggered by the ABC button on the tab strip.
- Both flows preserve the candidate bar (anchored above) and the current composing state.

### 3. Panel layout

```text
┌─────────────────────────────────────────────────┐
│ candidate bar (unchanged, stays anchored above) │
├─────────────────────────────────────────────────┤
│ 🔍 [ search emoji…                            ] │   ← search bar
├─────────────────────────────────────────────────┤
│                                                 │
│   😀 😃 😄 😁 😆 😅 🤣 😂      ← grid + section │
│   😊 🙂 🙃 😉 😇 😍 🥰 😘        headers per     │
│   ...                              category     │
│                                                 │
├─────────────────────────────────────────────────┤
│ [ABC] [😀][🐻][🍎][⚽][✈️][💡][🔣][🏳️] [⌫]    │   ← tab strip
└─────────────────────────────────────────────────┘
```

- **Search bar**: typing runs the FTS5 pipeline (see "Keyword matching") and updates the grid live. Empty query → restore the full categorized view.
- **Grid**: scrollable; one section per `group_name` (Smileys & Emotion, People & Body folded into Smileys for v1, Animals & Nature, Food & Drink, Travel & Places, Activities, Objects, Symbols, Flags); sticky section headers via collection-view supplementary view.
- **Tab strip** (always visible): leftmost = ABC (closes the panel and returns to the regular keyboard), then 8 category tabs (tap → scroll to that category's section), rightmost = delete (`-5`, reuses existing backspace handler).
- **No space key** is shown anywhere while the panel is mounted — matches the iOS system Emoji keyboard.
- Tapping an emoji cell commits the glyph to the active editor and keeps the panel open (sticky) so users can pick multiple emoji.
- Cell sizing ~44pt; ~8 columns on iPhone, more on iPad.

### 4. Data source

Consume the FTS5-backed APIs added in [EMOJI_DB_V2.md](EMOJI_DB_V2.md):

- `loadAllEmoji()` for the categorized grid, ordered `(group_name, sort_order)`.
- `searchEmoji(query, locale)` for the search bar — debounced ≥150 ms, run on the search dispatch queue.

### 5. Preference toggle

SwiftUI `@AppStorage("enable_emoji_button")` toggle in `PreferencesTabView.swift`, with bilingual label (English: "Show emoji panel button" / Traditional Chinese: "顯示 Emoji 鍵盤按鈕"). `KeyboardViewController` reads the preference at keyboard construction time and passes a flag to the layout-build step that hides the launcher key when `false`. Default `true`.

### 6. Encoding

Any Swift source file added or edited must be saved as **UTF-8 with BOM** (Chinese strings appear in the Settings toggle label and panel placeholder text).

## Risks / open questions

- **iPhone home-row reflow**: moving `中文` from the bottom row to the home row changes a long-standing layout. Verify muscle memory isn't disrupted; the bottom-row `中文` slot is a natural visual home for the emoji modifier key (same width, same row, modifier-style chrome).
- **iPad balance**: trimming `space` on iPad reduces typing area slightly. Verify the trimmed width still feels comfortable on both portrait and landscape iPad sizes; if too narrow on smaller iPads, fall back to trimming a side-key by 5% instead.
- **Panel height vs keyboard height**: the emoji panel (search + grid + tab strip) must match the keys-area height so the keyboard footprint doesn't jump. Verify on landscape iPad split keyboard.
- **Skin tones / recents / fuzzy search**: explicit non-goals for v1; follow-ups.
- Data-side risks (build reproducibility, FTS5 in GRDB, font fallback, CN drop) live in [EMOJI_DB_V2.md](EMOJI_DB_V2.md).

## Verification (iOS v1)

End-to-end manual test on iPhone (WJIP17 per `reference_ios_devices.md`) and iPad:

1. With `enable_emoji_button = true`, open LimeIME and switch to the **English** layout in a text field.
   - **iPhone**: confirm the bottom row's `中文` slot now shows the 😀 emoji-launcher key, and `中文` has moved up to the right end of the home row (after `s`). All other key positions unchanged.
   - **iPad**: confirm `space` is slightly narrower and the 😀 emoji-launcher appears on the right side of the bottom row, balancing the system mic key on the left.
   - Phonetic / symbol-page layouts are unchanged (no emoji key).
2. Tap the emoji key → the regular keys area is replaced by the emoji panel; candidate bar still visible above; **no space key is shown anywhere on screen**.
3. The panel shows: search bar at top, scrollable categorized grid in the middle, tab strip at the bottom (ABC | 8 category tabs | delete). Section/tab labels and search results show **English by default; Traditional Chinese (TW) labels appear** for users with a Chinese system locale (panel uses `name_tw` when locale is `zh-Hant`, otherwise `name_en`).
4. Tap each of the 8 category tabs in turn → the grid scrolls/jumps to the corresponding section.
5. Smoke-test that the panel search bar wires up to the FTS5 backend: type `flag` → country flags, `國旗` → country flags, empty query → categorized view. (Full search-quality matrix is in [EMOJI_DB_V2.md](EMOJI_DB_V2.md) verification §5.)
6. Tap the new home-row `中文` key → keyboard switches back to phonetic IM (same behavior as before, just from a different position).
7. Tap several emoji in succession → each glyph is committed to the document; the panel stays open (sticky behavior).
8. Tap the delete key on the tab strip → last character of the document is deleted; panel stays open.
9. Tap the ABC button → panel dismisses; the regular English keys return; cursor position preserved.
10. Rotate to landscape (iPhone + iPad) → search bar, grid, and tab strip lay out without clipping; column count adjusts on iPad.
11. In Settings, toggle `enable_emoji_button` off → reopen the keyboard → emoji-launcher key gone, but the English layout still has `中文` on the home row (the home-row reflow is permanent in v1, not gated by the toggle). Toggle back on → emoji key reappears in the bottom row.
12. Confirm preference `enable_emoji_button` persists across keyboard restarts.
13. Issue #29 end-to-end test (candidate-bar broadening + cache wipe + Android upgrade) lives in [EMOJI_DB_V2.md](EMOJI_DB_V2.md) verification §6-13.

## Decisions — resolved (UI side)

1. **Launcher key placement** ✅
   - iPhone: move `中文` from bottom row to the home row's empty 10% slot (after `s`); emoji launcher takes the vacated bottom-row position.
   - iPad: trim `space` by ~10%; emoji launcher on right side balancing the system mic key on left.
2. **Default for existing users** ✅ — `enable_emoji_button = true` (always visible).

(Data-side decisions — locales, target version, FTS5, legacy views, upgrade paths — are in [EMOJI_DB_V2.md](EMOJI_DB_V2.md).)

## Implementation order

This UI plan and [EMOJI_DB_V2.md](EMOJI_DB_V2.md) ship in the same iOS release (single PR or two-PR sequence with DB landing first):

1. **DB plan first** — build script, new schema, FTS5 APIs, candidate-bar rewiring, Android cache-wipe hook.
2. **UI plan (this doc) on top of it** — iPhone home-row reflow, iPad space-trim, emoji-launcher key, panel view, preference toggle.

Android emoji panel UI is deferred to v2; the DB plan's Android cache-wipe ensures issue #29 is fixed for Android users in the same release without an Android UI port.

## Cleanup note

This plan supersedes `docs/IOS_EMOJI_BUTTON_PLAN.md`. After exiting plan mode, that file should be deleted (I cannot delete files in plan mode).
