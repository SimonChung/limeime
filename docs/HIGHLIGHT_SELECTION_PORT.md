# Plan: Port Candidate Highlight Selection from Android → iOS

## Context

The Android LimeIME candidate bar draws a colored "highlight" behind the currently-selected candidate and uses a separate text color for that cell. The selection index is seeded automatically when new suggestions arrive (index 1 if it is an exact code match, else index 0 for composing-code / runtime-built phrase, else -1) and is advanced by DPAD keys and by touch.

The iOS port already tracks `selectedCandidate: Mapping?` in `KeyboardViewController` (seeding logic at `KeyboardViewController.swift:1051–1055` already mirrors Android), and `Mapping` even carries an unused `highLighted` field. But `CandidateBarView` renders every UIButton with the same background and text color — no visual highlight is drawn, and the selection index is never forwarded to the bar. As a result, users see no indication of which candidate will be picked by the default selection key / space.

Goal: replicate Android's visual highlight (selected cell gets a tinted background pill + bolder foreground color) with correct seeding, updates, and scroll-into-view — without adding new features beyond what Android already does.

Out of scope: DPAD / hardware-arrow navigation (iOS keyboard extensions do not receive those events from a soft keyboard); the expanded candidate grid's 2D navigation; composing-text character highlight. Those can be tackled later.

## Android reference (source of truth)

| Concern | Android location |
|---|---|
| Selection state | `CandidateView.mSelectedIndex` (`CandidateView.java:83`) |
| Initial seed on new suggestions | `setSuggestions()` (`CandidateView.java:1156, 1182–1196`) |
| Highlight background draw | `doDraw()` (`CandidateView.java:991–1000`) using `mDrawableSuggestHighlight` |
| Highlighted text color per record type | `CandidateView.java:1026–1058` (`mColorComposingCodeHighlight`, `mColorNormalTextHighlight`) |
| Touch-to-select | `CandidateView.java:969–971` |
| Drawable used for highlight | `drawable/ic_suggest_scroll_background_hl.xml` (selector, wired via `suggestHighlight` style attr — `styles.xml:361, 384, 407, 428, 450, 472, 494`) |

### Normal candidate list vs. associated (related / punctuation / English) list

Android deliberately uses **different selection-index seeding** for the two list kinds:

- **Normal candidate list** — produced from a live composing buffer. `setSuggestions()` at `CandidateView.java:1182–1196` runs the three-case rule below:
  1. `count > 1 && suggestions[1].isExactMatchToCodeRecord` → `mSelectedIndex = 1`
  2. else if `count > 0 && (suggestions[0].isComposingCodeRecord || suggestions[0].isRuntimeBuiltPhraseRecord)` → `mSelectedIndex = 0`
  3. else `mSelectedIndex = -1`
- **Associated candidate list** — related phrases (`RECORD_RELATED_PHRASE`, shown after a word commits), Chinese punctuation (`RECORD_CHINESE_PUNCTUATION_SYMBOL`), and English suggestions (`RECORD_ENGLISH_SUGGESTION`). These always fall into case 3 above because their first record is neither composing-code nor runtime-phrase, so `mSelectedIndex = -1` → **no default highlight**. The draw loop at `CandidateView.java:1038–1045` also swaps to `mColorSelKeyShifted` (vs. `mColorSelKey`) for these record types, so even the numeric selkey label color differs between the two list kinds.
- The inline comment at `CandidateView.java:1194` states this rule explicitly: `// no default selection for related phrase, chinese punctuation symbols1 and English suggestions`.

**Why the difference**: for the normal list the user is mid-composition and the default-pick must be obvious so that pressing space / the first selkey does the right thing. For associated lists the user has **already** committed a word and is just browsing optional continuations — Android's UX intent is that the user must actively tap a suggestion; nothing is pre-armed for accidental commit.

### iOS already has the split — use it

`KeyboardViewController` funnels the two kinds through different entry points, and the seeding logic must respect that split:

- **Normal path** — `setSuggestions(_ list:)` at `KeyboardViewController.swift:1044–1063`. This is the **only** place that should run the three-case seeding rule. It is called from `submitToSearch` (line 1038) after a composing-buffer search.
- **Associated paths** — all call `showCandidates(_ list:)` directly, never `setSuggestions`:
  - Chinese punctuation: line 1168
  - Related phrases after commit: line 1374 (sets `isShowingRelatedPhrases = true` at 1372)
  - English suggestions: line 1411

  These must pass `selectedIndex = -1` so the bar shows **no** highlight, matching Android. The `showCandidates` signature therefore needs to accept an optional index (default `-1`) and the three associated callsites stay on the default.

iOS's current `setSuggestions` at lines 1051–1055 only covers rules 1 and a broader "first non-composing" fallback (which would wrongly highlight index 0 when only a composing-code record and a related record are present). It must be aligned with the three-case Android rule.

## iOS current state (gap analysis)

Relevant files / lines already in the tree:

- `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift`
  - `setCandidates(_:)` at line 137 — rebuilds buttons, no selection awareness.
  - `makeCandidateButton(mapping:index:)` at lines 167–224 — renders each candidate; uses `palette.candiText` / `palette.candiBackground` only.
  - `candidateTapped(_:)` at line 226–231 — delegates tap by `Mapping`, not by index.
- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`
  - `selectedCandidate: Mapping?` at line 24 — already exists.
  - Seeding at `setSuggestions(_:)` 1044–1063 — partially matches Android; needs rule 3.
- `LimeIME-iOS/LimeKeyboard/KeyboardView.swift`
  - `struct KeyboardPalette` at line 8 with `candiBackground`, `candiText` — needs one additional color (`candiHighlight`) for the selection pill.
- `LimeIME-iOS/Shared/Models/Mapping.swift`
  - `highLighted: Bool` field at line 18 — currently unused; do **not** repurpose it for this feature (it is a per-record server-side flag with different semantics on Android; selection state belongs to the view).

## Recommended approach

Keep selection state in the view (mirroring Android `CandidateView`), driven by the controller. No architectural changes.

1. **Add a highlight color to `KeyboardPalette`** (`KeyboardView.swift`):
   - New field `candiHighlight: UIColor` on each of the 6 palettes.
   - Light themes: `candiText.withAlphaComponent(0.12)` (soft tint).
   - Dark theme (theme 1): `candiText.withAlphaComponent(0.18)`.
   - This matches Android's drawable-based tinted background without introducing theme-specific asset files.

2. **Track `selectedIndex` inside `CandidateBarView`** (`CandidateBarView.swift`):
   - Add `private var selectedIndex: Int = -1`.
   - Extend `setCandidates(_ mappings: [Mapping], selectedIndex: Int = -1)` so the controller can pass the seed index in one call. Keep the single-arg form as a thin wrapper that defaults to `-1` for safety.
   - Add `func setSelectedIndex(_ index: Int)` that updates state and re-applies styling **without** rebuilding the button stack (so we do not reset scroll offset mid-session). Use per-button style updates only.
   - Store a reference to each candidate `UIButton` (e.g. `private var candidateButtons: [UIButton] = []`) alongside `candidates`, populated during `rebuildButtons()`.

3. **Render the highlight** in `makeCandidateButton` + a new `applyHighlightStyle(button:index:mapping:)` helper:
   - For index == `selectedIndex` and index ≥ 0:
     - Button background: `palette.candiHighlight` with corner radius ~6pt (set `btn.layer.cornerRadius = 6; btn.layer.masksToBounds = true`).
     - Text color: `palette.candiText` at full opacity (even when composing-code — mirrors Android switching to `mColorComposingCodeHighlight`). For the two-label stack case, update both `skLabel.textColor` (stay dim) and `wordLabel.textColor`.
   - For index != `selectedIndex`: current behavior (no background, dimmed text for composing-code).
   - Call this helper once per button in `rebuildButtons()` and again from `setSelectedIndex(_:)` so a mid-session selection change is cheap.

4. **Scroll-into-view on selection change** (mirrors `CandidateView.selectNext/Prev`'s `scrollNext/scrollPrev`):
   - After `setSelectedIndex(_:)`, compute `selectedButton.frame` in `scrollView` coordinate space and call `scrollView.scrollRectToVisible(_, animated: true)` only if the rect falls outside `scrollView.bounds`. No-op when `selectedIndex < 0`.

5. **Wire the controller to push the seed index — but keep normal vs. associated paths distinct** (`KeyboardViewController.swift`):
   - **Normal path** (`setSuggestions(_:)`, lines 1044–1063): replace the selection block at 1050–1055 with the exact three-case Android rule (see "Normal candidate list vs. associated…" above). Produce both a `selectedCandidate: Mapping?` **and** a `selectedIdx: Int`. Call `showCandidates(list, selectedIndex: selectedIdx)`.
   - **Signature change**: extend `showCandidates(_ list: [Mapping], selectedIndex: Int = -1)`. Forwards to `candidateBar.setCandidates(list, selectedIndex: selectedIndex)`.
   - **Associated paths must stay on `-1`** (matches Android's "no default selection" for these three record kinds). Leave the three existing call sites unchanged so they pick up the default:
     - punctuation at line 1168
     - related phrases at line 1374 (the one under `isShowingRelatedPhrases = true`)
     - English suggestions at line 1411
     This is the single most important distinction in this port — do not fall into the trap of "just reuse the seeding rule everywhere."
   - In `tryPickBySelkey(code:)` (around 1560–1571) and anywhere else `selectedCandidate` gets reassigned mid-session, also call `candidateBar.setSelectedIndex(newIndex)` so the highlight tracks state changes. Guard this so it is a no-op when `isShowingRelatedPhrases == true` or when the currently displayed list is a punctuation / English suggestion list — those stay un-highlighted even if a selkey happens to commit them.

6. **Touch update** in `candidateTapped(_:)` (CandidateBarView.swift:226):
   - Before the delegate call, `setSelectedIndex(sender.tag)` so a touch visibly flashes the highlight (matches Android `mSelectedIndex = i` inside `doDraw`). This is cosmetic since the cell is about to be committed, but it keeps the animation stable when haptic fires.

7. **Do not introduce DPAD/arrow navigation on iOS** — left/right/up/down keys are not available to a soft keyboard extension the same way as Android. If a physical keyboard is attached, `UIKeyCommand` could be added later as a separate task.

## Files to modify

- `LimeIME-iOS/LimeKeyboard/KeyboardView.swift` — add `candiHighlight` to `KeyboardPalette` (6 entries, lines ~8–96).
- `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift` — add selection state, `setSelectedIndex`, `applyHighlightStyle`, scroll-to-visible; extend `setCandidates`; update `candidateTapped`.
- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` — tighten `setSuggestions(_:)` to the Android three-case rule; propagate index through `showCandidates(_:)`; push updates through the selkey path.

No changes to `Mapping.swift`, `SearchServer.swift`, or `LimeDB.swift`.

## Verification

Build target: `LimeIMEKeyboard` extension inside `LimeIME-iOS/LimeIME.xcodeproj`.

1. **Build** via Xcode (Product → Build) with scheme `LimeIME`. Must compile both the container app and keyboard extension targets without warnings introduced by this change.
2. **On-device / simulator keyboard test** (attach keyboard to Notes or Messages):
   - Type a Zhuyin / Cangjie sequence that returns an exact match at index 1 → verify the cell at index 1 has the tinted pill and bolder text, while index 0 (composing code echo) stays grey/monospace with no pill.
   - Type a partial code so only composing-code / runtime-built phrase is present → index 0 is highlighted.
   - Trigger related-phrase mode (commit a word) → verify **no** cell is highlighted (rule 3).
   - Type an English-only suggestion stream → verify **no** highlight.
   - Tap a non-highlighted candidate → highlight briefly moves to it before commit; content commits correctly.
   - Scroll the candidate bar so the selected index is off-screen, then trigger a re-seed (type another key) → selected pill is auto-scrolled back into view.
3. **Theme coverage**: switch through all 6 themes via the settings tab and confirm the highlight is visible on each (contrast check against `candiBackground`).
4. **Regression**: selkey numeric commit (pressing `1`..`9`) still commits the correct candidate; composing popup label above the bar still updates; the expanded (chevron.down) panel still opens and closes.

If (3) shows poor contrast on any theme, tune that palette's `candiHighlight` alpha rather than diverging from the overall approach.
