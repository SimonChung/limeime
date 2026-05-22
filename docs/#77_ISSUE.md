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

## Likely root cause

There are two likely sentinel-handling gaps:

1. Tapping the visible `...` candidate goes through the normal candidate selection path instead of being treated as a request for more candidates.
2. The expanded candidate panel can be seeded from a list that still includes `hasMoreMark` if the user enters expansion before the background full-query result has replaced `mCandidateList`, or if a related-phrase path is still using the truncated list.

The stage-2 full query path itself appears intended to remove the sentinel because `getAllRecords: true` should not append `hasMoreMark`.

## Conservative fix plan

1. Treat `Mapping.isHasMoreMarkRecord` as UI-only in all candidate-selection entry points:
   - In `CandidateBarView.candidateTapped(_:)`, call `candidateBarViewDidRequestMore(_:)` instead of `didSelect` when the tapped mapping is `hasMoreMark`.
   - In `KeyboardViewController.expandedCandidateTapped(_:)`, ignore or re-route `hasMoreMark` rather than calling `pickCandidateManually(_:)`.
2. Filter `hasMoreMark` before showing expanded candidates:
   - When using `mCandidateList` in `candidateBarViewDidRequestMore(_:)`, remove sentinel entries before `showExpandedCandidates(...)`.
   - Keep the selected-index calculation based on the filtered list.
3. If the full stage-2 fetch is still pending when the user requests more, either:
   - show the filtered current list immediately and allow the pending full-query swap to update the bar, or
   - issue/await a full `getMappingByCode(... getAllRecords: true)` for the current composing code before showing expansion.
4. Add tests or manual checks for both normal candidate and related-phrase more flows.

## Verification plan

- Find an iOS table/code path with more than the initial candidate limit so the bar shows `...`.
- Tap the `...` candidate entry itself: it should open/fetch the second-stage candidates and must not commit literal `...`.
- Tap the fixed chevron while `...` is visible: the expanded list should not contain a `...` candidate after second-stage data is available.
- Repeat the same path for related phrases if the related list can exceed the initial limit.
- Confirm normal candidate selection, composing-code commit, and expanded-panel candidate taps still work.

## Follow-up / retest condition

This is maintainer-created, so no public reporter retest request is needed. Keep the issue open until the iOS fix is implemented and verified in a newer iOS build/TestFlight or maintainer-confirmed local build.
