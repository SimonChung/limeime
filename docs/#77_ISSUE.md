# Issue #77: iOS second-stage candidates leave `...` placeholder in candidate list

GitHub issue: https://github.com/lime-ime/limeime/issues/77

## Problem statement

The iOS keyboard's second-stage candidate flow can leave the `...` / `hasMoreMark` placeholder visible in the candidate bar or expanded candidate list after the user enters the second-stage/more-candidates flow.

The placeholder is a UI sentinel, not a real candidate. It should either trigger candidate expansion/fetching or be removed once the full candidate set is shown.

## Reproduction from report

1. Use the iOS LIME keyboard with an input method/code path that returns more candidates than the initial stage limit.
2. Type a code that displays the `...` second-stage candidate entry in the candidate bar.
3. Select/tap the `...` entry to enter the second-stage candidate flow.
4. Observe the candidate bar/list after second-stage candidates are loaded.

Expected: `...` is replaced by actual second-stage candidates.

Actual: `...` remains visible in the candidate list.

## Current classification

- Platform: iOS
- Area: candidate bar / second-stage candidates
- Labels at triage: `bug`, `Usability`
- Assignee after triage: `jrywu`
- Reporter/source: maintainer-created tracking issue (`limeimetw`)
- Public acknowledgement: not needed; this is a maintainer-created tracking bug.
- Current status: closed by `jrywu` on 2026-05-22 after local fix and simulator verification.

## Relevant code paths inspected

- `LimeIME-iOS/Shared/Database/LimeDB.swift`
  - `getMappingByCode(... getAllRecords: false)` appends a `Mapping.RecordType.hasMoreMark` sentinel with `word: "..."` when the initial result set is truncated.
  - `getRelatedByWord(... getAllRecords: false)` uses the same `hasMoreMark` sentinel for related phrases.
- `LimeIME-iOS/Shared/Models/Mapping.swift`
  - `Mapping.RecordType.hasMoreMark == 8`
  - `Mapping.isHasMoreMarkRecord` identifies the sentinel.
- `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift`
  - `candidateTapped(_:)` currently forwards every candidate, including `hasMoreMark`, through `delegate?.candidateBarView(_:didSelect:)`.
  - The fixed chevron invokes `candidateBarViewDidRequestMore(_:)`, but the visible `...` candidate itself is not handled specially in `CandidateBarView`.
- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`
  - `updateCandidates()` performs a stage-1 query and, when truncated, a stage-2 full query.
  - `applyFullCandidateResults(_:, sid:)` assigns `mCandidateList = full` and calls `candidateBar.appendCandidates(full, selectedIndex: idx)`, so a completed full query should no longer include the sentinel.
  - `candidateBarViewDidRequestMore(_:)` expands from `mCandidateList` without filtering `isHasMoreMarkRecord`; if expansion happens before the stage-2 full query updates `mCandidateList`, the expanded list may still contain the stage-1 `...` sentinel.
  - `candidateBarView(_:didSelect:)` forwards non-English suggestions directly to `pickCandidateManually(_:)`, so tapping the `...` sentinel can be treated like a real candidate unless guarded elsewhere.

## Two display paths affected

The `...` sentinel can appear in either of two UI surfaces, and the fix must
address both:

- **Path A — Candidate bar** (`CandidateBarView` horizontal strip).
  Populated by `setSuggestions` → `setCandidates` from stage 1 (with sentinel)
  and upgraded by `applyFullCandidateResults` → `appendCandidates` from stage 2
  (no sentinel). Race in (1) below causes stage 2 to be silently dropped, so
  the sentinel stays in the bar.
- **Path B — Expanded candidate panel** (`expandedCandidatesPanel`, opened by
  the fixed chevron or by tapping `...`).
  - Normal-candidate path: built directly from `mCandidateList` at
    `KeyboardViewController.swift:3232`. If stage 2 was dropped,
    `mCandidateList` is the truncated stage-1 list and the expanded grid
    carries the sentinel too. `expandedCandidateTapped(_:)` at
    `KeyboardViewController.swift:1766` then forwards a sentinel tap to
    `pickCandidateManually(_:)`.
  - Related-phrase path: at `KeyboardViewController.swift:3217` it kicks off
    a fresh `getRelatedByWord(... getAllRecords: true)` query, so the related
    expanded grid does **not** carry the sentinel. The bar itself can still
    carry it (no stage-2 upgrade for related phrases).

The two paths share most of the fix: make sure the canonical list
(`mCandidateList`) is the full stage-2 list before showing either surface, and
treat the sentinel as a UI control at every tap entry point.

## Likely root cause

There are three independent gaps. The dominant cause of the chronic "`...` always there" symptom is (1):

1. **Stage 2 is silently dropped by a dispatch-ordering race** (primary cause of #77).
   `updateCandidates()` in `KeyboardViewController.swift` dispatches the stage-1
   bar reload using a **nested** `DispatchQueue.main.async` (added per
   `docs/IOS_MISS_KEY.md` to absorb the queued touchDown/touchUp events before
   the candidate-bar reload locks the main thread). Stage 2 dispatches its
   `applyFullCandidateResults` with a single `DispatchQueue.main.async`.

   On a hot DB cache stage 2 finishes in a few ms. Main-queue order becomes:
   - M1 (stage-1 outer) fires → enqueues M2 (stage-1 inner) to the queue tail.
   - M3 (stage 2) fires next → `applyFullCandidateResults` guards on
     `hasCandidatesShown`, which is still `false` because the inner M2 has not
     run yet → **stage 2 bails out**.
   - M2 fires → `setSuggestions(results)` populates the bar **with the `...`
     sentinel** — and there is no further stage-2 follow-up to remove it.

   Net effect: the user sees `...` for the entire stroke, never replaced.

2. Tapping the visible `...` candidate goes through the normal candidate
   selection path (`candidateTapped(_:)` → `didSelect` →
   `pickCandidateManually`) instead of being treated as a request for more
   candidates.

3. The expanded candidate panel can be seeded from `mCandidateList` that still
   includes `hasMoreMark` if the user enters expansion before the stage-2
   result has replaced `mCandidateList`, or via the related-phrase path which
   uses the same sentinel but currently has no stage-2 upgrade.

The stage-2 DB query itself is correct: `getMappingByCode(code, getAllRecords:
true)` skips the sentinel append at `LimeDB.swift:690`. The bug is purely on
the iOS dispatch / sentinel-handling side, not the data layer.

## Why TWO_STAGE_CANDI did not surface this

`docs/TWO_STAGE_CANDI.md` fixed the scroll-position reset that occurred when
stage 2 replaced the bar contents. That work assumed `applyFullCandidateResults`
actually ran. It never reached the swap path during testing because the same
P2 nested-dispatch race documented above was already silently dropping stage 2
via the `hasCandidatesShown` guard. The doc says "stage 2 calls
`candidateBar.appendCandidates`" — true in code, but the guard makes that
conditional, and the condition fails in the race.

## Conservative fix plan

1. **Make stage 2 always land after stage 1's deferred reload** in
   `KeyboardViewController.updateCandidates()`.
   Two equivalent options; pick (a) for minimal diff:
   - (a) Dispatch the stage-2 main hop with the same nested-async pattern as
     stage 1 (outer `DispatchQueue.main.async { DispatchQueue.main.async { ... } }`)
     so M3 is always enqueued after M2 on the main queue.
   - (b) Chain the stage-2 swap from inside stage 1's inner M2 block (e.g.
     capture `fullResults` into a `pendingFullResults` variable consumed at the
     end of M2). This is more invasive but removes the ordering dependency.

2. **Relax the `applyFullCandidateResults` guard** in
   `KeyboardViewController.swift:1489`:
   - Drop the `hasCandidatesShown` check, or replace the early-exit clause with
     `guard currentSearchID == sid, !isShowingRelatedPhrases,
     !hasChineseSymbolCandidatesShown, !mEnglishOnly, !full.isEmpty else { return }`.
   - Rationale: if the same `sid` produced a non-empty full result for the
     current composing code, the bar must show it regardless of whether the
     stage-1 bar reload has landed yet. Stage 1 and stage 2 are by construction
     mutually consistent for one `sid`.
   - Set `hasCandidatesShown = true` inside `applyFullCandidateResults` for the
     case where stage 2 lands before stage 1 (so subsequent code paths that
     depend on `hasCandidatesShown` behave correctly).

3. **Treat `Mapping.isHasMoreMarkRecord` as UI-only in all candidate-selection
   entry points** (defense in depth even after fix 1+2 lands). Both display
   paths need this:
   - Path A (bar): in `CandidateBarView.candidateTapped(_:)`, call
     `candidateBarViewDidRequestMore(_:)` instead of `didSelect` when the
     tapped mapping is `hasMoreMark`.
   - Path B (expanded grid): in
     `KeyboardViewController.expandedCandidateTapped(_:)`
     (`KeyboardViewController.swift:1766`), guard
     `mapping.isHasMoreMarkRecord` — do nothing or re-route to
     `candidateBarViewDidRequestMore(_:)` instead of `pickCandidateManually(_:)`.

4. **Filter `hasMoreMark` before showing the expanded panel** (Path B):
   - In `candidateBarViewDidRequestMore(_:)` at
     `KeyboardViewController.swift:3207`, after capturing
     `let all = mCandidateList`, drop entries where `isHasMoreMarkRecord`
     before computing `idx` and calling `showExpandedCandidates(all,
     selectedIndex: idx)`. The selected-index seeding rule must be applied to
     the filtered list.
   - This is required because the expanded grid is built directly from
     `mCandidateList`, so any sentinel left in the canonical list leaks into
     Path B.
   - If the user opens the expanded grid while stage 2 is in flight, the
     filtered grid is still consistent with what the user sees; stage 2 will
     update `mCandidateList` on arrival but the grid itself does not currently
     re-bind. Reloading the grid on stage 2 (see fix 5) is a nice-to-have.

5. **Reload the expanded grid when stage 2 lands while it is visible** (Path
   B), mirroring the bar upgrade:
   - In `applyFullCandidateResults(_:sid:)`, after `mCandidateList = full`, if
     `isExpandedCandidatesVisible && !isShowingRelatedPhrases`, recompute the
     expanded list (filter sentinel, apply seed rule) and call
     `reloadExpandedCandidates()`.
   - Without this, a user who opens the expanded grid during stage 1 keeps
     looking at the truncated 15-item set even after stage 2 lands.

6. **If the full stage-2 fetch is still pending when the user requests more**,
   either:
   - show the filtered current list immediately and allow the pending
     full-query swap to update both the bar and (via fix 5) the grid, or
   - issue/await a full `getMappingByCode(... getAllRecords: true)` for the
     current composing code before showing expansion. Option (a) matches the
     responsiveness of the bar; option (b) trades a beat of latency for a
     never-truncated grid.

7. **Related-phrase path**: `getRelatedByWord(... getAllRecords: false)` also
   emits `hasMoreMark` into the bar but has no stage-2 upgrade for the bar.
   The expanded grid for related phrases is already correct
   (`KeyboardViewController.swift:3217` fetches with `getAllRecords: true` on
   demand), so the gap is only on Path A here. Either wire a stage-2 fetch
   into `updateRelatedPhrase(...)` (mirroring the candidate path) or always
   call related with `getAllRecords: true` to avoid the sentinel entirely. The
   former matches Android more closely; the latter is simpler.

8. **Constraints carried from TWO_STAGE_CANDI.md** — preserve in this fix:
   - Keep `CandidateBarView.setCandidates` ordering: `layoutIfNeeded()` BEFORE
     `setContentOffset(.zero)`.
   - Stage 2 must still go through `appendCandidates`, not a fresh
     `setCandidates`, so the scroll-offset preservation continues to work.

9. Add tests or manual checks for all four surfaces: bar (normal candidate),
   bar (related phrase), expanded grid (normal candidate), expanded grid
   (related phrase). Each must show no `...` after stage 2 settles, and taps
   on a stage-1 `...` must never commit literal `...`.

## Verification plan

Find an iOS table/code path with more than the initial candidate limit
(INITIAL_RESULT_LIMIT = 15) so stage 1 emits the `...` sentinel.

### Path A — Candidate bar

- Type the code and observe the bar without interacting:
  - Expected after fix: `...` is visible only for the brief stage-1 window
    (matching Android), then replaced by the full stage-2 list.
  - Pre-fix behaviour: `...` remains visible for the entire stroke.
- Confirm by `IOS_PROFILING` traces or log lines that
  `applyFullCandidateResults` actually runs (not bailed) for the same `sid`
  after stage 1.
- Tap the `...` cell in the bar during the brief stage-1 window: it should
  open the expanded panel (or trigger stage-2 fetch) and must not commit
  literal `...`.

### Path B — Expanded candidate panel

- Tap the fixed chevron while `...` is visible in the bar: the expanded grid
  must not contain a `...` cell (sentinel filtered before
  `showExpandedCandidates`).
- Open the expanded panel during the stage-1 window, keep it open, and let
  stage 2 land: the grid must reload to show the full set (per fix 5). If fix
  5 is deferred, at minimum confirm the displayed truncated set never carries
  a `...` cell.
- Tap a normal cell in the expanded grid: commits correctly.
- Open the related-phrase expanded grid (after committing a candidate that
  has related phrases beyond the initial limit): no `...` cell, full list
  available immediately (Path B for related is already fetched with
  `getAllRecords: true`).

### Regression guards

- Confirm normal candidate selection and composing-code commit still work.
- Confirm scroll-position preservation still works on stage-2 arrival (per
  `docs/TWO_STAGE_CANDI.md` — scroll right, type one more stroke, stage 2
  must not snap back to offset 0).
- Confirm `IOS_MISS_KEY.md` regression does not return: tap several keys
  rapidly during stage-1 reload — touch events must still be processed
  promptly.

## Resolution / follow-up status

Maintainer `jrywu` closed this issue on 2026-05-22 after posting the local-fix summary in issue comment `4517540556`. The implementation is recorded as commit `c828a2d2` and, per the maintainer's summary, addressed the two visible surfaces involved in this report:

- Candidate bar: stage-2 full-result application was deferred consistently with the stage-1 nested main-queue reload, `applyFullCandidateResults` can land for the current search id, and `hasCandidatesShown` is set when the full result is applied.
- Expanded grid: `hasMoreMark` / `...` sentinel records are filtered before display, and the visible grid is reloaded when stage 2 lands while it is open.
- Tap safety: candidate-bar and expanded-grid taps on the sentinel are routed/guarded as UI controls rather than committed as a literal candidate.

Verification noted by the maintainer: visual simulator check on iPhone 17 Pro Max with 注音 `ru` (ㄐㄧ); `...` no longer persists in the candidate bar or expanded grid. This local visual check verifies the reported persistence symptom for the maintainer-created tracking issue. The broader regression matrix above, including related-phrase paths and sentinel tap timing, remains useful if similar behavior is reported again, but no public reporter retest request or active watch is needed now unless new iOS evidence appears.
