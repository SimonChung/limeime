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
