# TWO_STAGE_CANDI — Issue Tracker

## Background

The iOS keyboard uses a two-stage candidate fetch, mirroring Android's
`CandidateView.checkHasMoreRecords()` auto-upgrade path:

1. **Stage 1 (fast)** — `getMappingByCode(code)` returns up to `INITIAL_RESULT_LIMIT`
   items. When the list is truncated, LimeDB appends a sentinel record
   (`isHasMoreMarkRecord == true`, displayed as "…"). This fires on the main thread
   quickly so the user sees candidates immediately.

2. **Stage 2 (full)** — `getMappingByCode(code, getAllRecords: true)` returns up to
   `FINAL_RESULT_LIMIT` items (no sentinel). This fires from the same background
   `DispatchQueue.global` serial block, after stage 1 has been dispatched to main.
   When done it calls `applyFullCandidateResults` on the main thread.

**Problem:** When stage 2 arrives and replaces the candidate bar contents, the scroll
position resets to the beginning — any position the user had scrolled to is lost.

---

## Root Cause

`CandidateBarView.setCandidates` contained two lines that reset scroll:

```swift
scrollView.setContentOffset(.zero, animated: false)   // explicit reset
scrollSelectedIntoView(animated: false)               // scrolls to item 0 (x≈0)
```

`applyFullCandidateResults` must update the bar with the full list, and every path
to do so ultimately triggered these two lines.

A secondary issue: `setContentOffset(.zero)` was called **before** `layoutIfNeeded()`.
UIScrollView adjusts `contentOffset` internally during the layout pass (when
`contentSize` changes), so any offset we set before layout would be silently
overwritten. The fix is to call `layoutIfNeeded()` first, then `setContentOffset`
— layout adjustments have already fired, so our value wins.

---

## Attempts

### Attempt 1 — Subview append (do not call setCandidates)

Strip the "…" sentinel from `candidates`, compare prefixes, only `addArrangedSubview`
for net-new items. **Failed:** The "…" sentinel is at position N-1 in `candidates`
but the full list has a real item there, so `elementsEqual` failed → fell back to
`setCandidates` → scroll reset every time.

### Attempt 2 — Strip sentinel before comparison

Fixed the prefix comparison by doing `candidates.dropLast()` when last item is the
sentinel, then comparing against the shortened list. **Failed:** The "…" button was
the last *arranged subview* but removal was order-sensitive; emoji injection could
also shift positions. Still scrolled to head in testing.

### Attempt 3 — Save/restore offset around setCandidates

```swift
let savedOffset = scrollView.contentOffset
setCandidates(mappings, selectedIndex: selectedIndex)
scrollView.layoutIfNeeded()
scrollView.setContentOffset(CGPoint(x: min(savedOffset.x, maxX), y: 0), animated: false)
```

**Failed:** `setCandidates` sets offset to zero *and* calls `scrollSelectedIntoView`
which calls `scrollRectToVisible` for item 0 (x≈0). The restoration ran after both
of those, but `scrollRectToVisible` is asynchronous relative to `layoutIfNeeded` —
the UIScrollView re-adjusted on the next run-loop pass, overriding the restoration.

### Attempt 4 — Bypass setCandidates, async restore

```swift
let preservedX = scrollView.contentOffset.x
candidates = mappings
self.selectedIndex = ...
rebuildButtons()   // does not touch contentOffset
DispatchQueue.main.async {
    // restore after layout pass
    self.scrollView.setContentOffset(CGPoint(x: min(preservedX, maxX), y: 0), animated: false)
}
```

**Failed (still scrolled to head):** `rebuildButtons` → `stackView.arrangedSubviews.forEach
{ $0.removeFromSuperview() }` causes UIStackView to collapse → `scrollView.contentSize`
drops to zero → UIScrollView internally fires its own reset to `.zero` before the
async block runs. The async restoration arrived after that internal reset.

### Attempt 5 — Revert appendCandidates to pass-through (still two-stage)

After reverting `appendCandidates` to `setCandidates(mappings, selectedIndex:)`, the
two-stage fetch was still in place. Stage 2 still fires, still calls `showCandidates`
→ `setCandidates` → scroll reset. **Failed:** The scroll still reset on stage 2 arrival.

### Attempt 6 — Fix setCandidates ordering + restore two-stage ✅ RESOLVED

Two separate fixes were applied together:

**Fix 1 — `setCandidates` ordering** (`CandidateBarView.swift`):
- Removed `scrollSelectedIntoView` from `setCandidates` entirely. A fresh candidate
  list always starts at offset 0; there is no reason to scroll to the selected item.
- Moved `layoutIfNeeded()` to run **before** `setContentOffset(.zero)` so layout
  adjustments fire first and our `.zero` wins unconditionally.

```swift
func setCandidates(_ mappings: [Mapping], selectedIndex: Int = -1) {
    candidates = mappings
    self.selectedIndex = ...
    rebuildButtons()
    scrollView.layoutIfNeeded()          // layout fires first
    scrollView.setContentOffset(.zero, animated: false)  // always wins
}
```

**Fix 2 — `appendCandidates` offset restore** (`CandidateBarView.swift`):
Because `setCandidates` now guarantees a fully-settled layout on return (no pending
async scroll calls, no `scrollRectToVisible` queued), reading `contentOffset.x` before
the call and writing it back after is safe and reliable:

```swift
func appendCandidates(_ mappings: [Mapping], selectedIndex: Int = -1) {
    let preservedX = scrollView.contentOffset.x
    setCandidates(mappings, selectedIndex: selectedIndex)
    guard preservedX > 0 else { return }
    let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
    guard maxX > 0 else { return }
    scrollView.setContentOffset(CGPoint(x: min(preservedX, maxX), y: 0), animated: false)
}
```

**Two-stage fetch restored** (`KeyboardViewController.swift`):
`applyFullCandidateResults` re-added; stage 2 calls `candidateBar.appendCandidates`
instead of `showCandidates`. Scroll position is preserved on stage 2 arrival.

---

## Current State (two-stage, scroll preserved ✅)

Stage 1 (fast) populates the bar via `setSuggestions` → `setCandidates`.
Stage 2 (full) upgrades the bar via `applyFullCandidateResults` → `appendCandidates`,
which preserves the user's scroll position. The scroll-reset bug is resolved.

---

## Possible Future Notes

- `scrollSelectedIntoView` is still used by `setSelectedIndex` (user taps a candidate
  or physical keyboard selection changes) — that path is correct and unaffected.
- The `layoutIfNeeded()` → `setContentOffset` ordering in `setCandidates` must be
  preserved in future refactors; reversing it will reintroduce the scroll-shift bug.

---

## Follow-up: stage-2 silently dropped (Issue #77)

### Symptom

iOS keeps the `...` (`hasMoreMark`) sentinel visible for the entire stroke.
Android replaces it almost immediately when stage 2 lands. See `docs/#77_ISSUE.md`.

### Root cause — dispatch ordering race introduced after this doc was written

After this doc resolved the scroll-reset, a separate change in
`docs/IOS_MISS_KEY.md` wrapped the stage-1 main-thread bar reload in a
**nested** `DispatchQueue.main.async` so UIKit could drain queued
touchDown/touchUp events before the candidate-bar reload locked the main
thread. Stage 2 was left as a single `DispatchQueue.main.async`.

Effective dispatch shape:

```swift
DispatchQueue.global { 
    results = stage1Query()
    DispatchQueue.main.async {        // M1
        DispatchQueue.main.async {    // M2  ← nested P2 deferral (IOS_MISS_KEY.md)
            setSuggestions(results)   //     sets hasCandidatesShown = true
        }
    }
    guard wasTruncated else { return }
    fullResults = stage2Query()       // sync on background, often only a few ms
    DispatchQueue.main.async {        // M3
        applyFullCandidateResults(fullResults, sid)  // guards on hasCandidatesShown
    }
}
```

Main-queue arrival order:

1. M1 enqueued at t=0
2. M3 enqueued at t = stage 2 query duration (often a few ms on a hot DB cache)

Actual run order can become:

- M1 fires → enqueues M2 to the queue tail.
- **M3 fires before M2** → `hasCandidatesShown == false` (M2 has not run yet)
  → `applyFullCandidateResults` bails out at the guard.
- M2 fires → `setSuggestions(results)` populates the bar **with the `...`
  sentinel** — and no stage-2 follow-up remains.

Net effect: stage 2 is silently dropped, `...` stays visible for the whole stroke.

### Why this doc did not detect it

The fixes in Attempt 6 were validated using inputs that exercised the
`appendCandidates` path. The race did not trigger when:

- The DB query was cold and stage 2 was slow enough for M2 to run first, or
- Debug builds were slow enough that the main queue drained M1→M2 between
  background hops.

Once profiling (`docs/IOS_PROFILING.md`) made stage 1 faster and the DB cache
became hot in real usage, the race window widened and `...` became chronic.

### Two display paths affected

The sentinel can surface in either of two iOS candidate UIs, and the fix must
cover both:

- **Path A — Candidate bar** (`CandidateBarView`). The race below is the
  primary cause of chronic `...` here. Stage 2 must actually land so
  `appendCandidates` can replace the sentinel.
- **Path B — Expanded candidate panel** (`expandedCandidatesPanel`, opened
  via chevron or by tapping `...`). The grid is built from `mCandidateList`
  at `KeyboardViewController.swift:3232`. If stage 2 was dropped (Path A bug),
  `mCandidateList` still carries the sentinel and the grid does too.
  Additionally `expandedCandidateTapped(_:)` at
  `KeyboardViewController.swift:1766` does not currently skip sentinels.
  Related-phrase expanded grid is fine — it issues
  `getRelatedByWord(... getAllRecords: true)` on demand.

### Fix

Make stage 2 land **after** stage 1's deferred reload, remove the
`hasCandidatesShown` guard that drops it when ordering inverts, and ensure
the expanded grid stays consistent with the canonical list. See
`docs/#77_ISSUE.md` for the full plan. Minimum diff:

1. In `KeyboardViewController.updateCandidates()` — wrap stage 2's main hop in
   the same nested `DispatchQueue.main.async` pattern as stage 1:

   ```swift
   DispatchQueue.main.async { [weak self] in
       DispatchQueue.main.async { [weak self] in
           guard let self = self else { return }
           self.applyFullCandidateResults(fullResults, sid: sid)
       }
   }
   ```

   This guarantees M3 is enqueued after M2 because both are double-deferred and
   FIFO ordering on `DispatchQueue.main` is preserved.

2. In `KeyboardViewController.applyFullCandidateResults(_:sid:)` — drop the
   `hasCandidatesShown` guard (or replace with `currentSearchID == sid` + the
   list-mode guards). Set `hasCandidatesShown = true` inside this method for
   the case where stage 2 lands before stage 1. This is defense in depth in
   case the dispatch invariant is ever broken again.

3. (Path B) In `applyFullCandidateResults`, after `mCandidateList = full`, if
   `isExpandedCandidatesVisible && !isShowingRelatedPhrases`, recompute the
   expanded list (filter sentinel + apply Android seed rule) and call
   `reloadExpandedCandidates()`. Without this, a user who opens the expanded
   grid during stage 1 keeps looking at the truncated 15-item set even after
   stage 2 lands.

4. (Path B) In `candidateBarViewDidRequestMore(_:)`
   (`KeyboardViewController.swift:3207`) for the normal-candidate branch,
   filter `isHasMoreMarkRecord` out of `mCandidateList` before computing the
   selected index and calling `showExpandedCandidates(...)`.

5. (Both paths) Guard sentinel taps:
   - `CandidateBarView.candidateTapped(_:)` — route to
     `candidateBarViewDidRequestMore(_:)` when the mapping is `hasMoreMark`.
   - `KeyboardViewController.expandedCandidateTapped(_:)` — early-return /
     re-route when the mapping is `hasMoreMark` instead of calling
     `pickCandidateManually(_:)`.

### Constraints preserved

- `setCandidates` ordering (`layoutIfNeeded()` → `setContentOffset(.zero)`)
  must remain unchanged.
- Stage 2 must still go through `appendCandidates`, not a fresh `setCandidates`,
  so scroll-offset preservation continues to work.
- Stage 1 must still use its nested deferral (IOS_MISS_KEY.md requirement).

### Verification

Path A (bar):

- After fix: `...` visible only briefly during stage 1, then replaced by the
  full list. Matches Android behaviour.
- `IOS_PROFILING` `CandidateSwap` span must consistently appear when stage 1
  was truncated.

Path B (expanded grid):

- Open the expanded grid while `...` is in the bar: grid must not contain a
  `...` cell.
- Keep the grid open across the stage-1 → stage-2 transition: grid must
  reload to show the full set after stage 2 lands.
- Tap `...` in the bar or any sentinel that slips into the grid: must never
  commit literal `...`.

Regression guards:

- Scroll-position preservation across stage-2 swap (the original scenario of
  this doc) must still work.
- `IOS_MISS_KEY` rapid-tap responsiveness must not regress.
