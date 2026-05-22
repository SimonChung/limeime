# Issue #78: iOS optional suggestion candidates should not intercept functional keys

## Current status

Maintainer-created tracking issue #78 is closed as fixed by `jrywu` on 2026-05-22. The closing comment records a local cross-platform fix in commit `2e278c46` (not yet visible on GitHub at the time this webhook ran) covering:

- iOS English prediction Backspace ordering;
- iOS/Android related-phrase Backspace dismiss-and-delete behavior;
- iOS Enter dismissal for stale related/symbol browse-only bars.

The maintainer reported iOS simulator build and Android `compileDebugJava` checks as clean. Manual visual verification on the iPhone 17 Pro Max simulator is still release QA before TestFlight, but no public acknowledgement or community retest request is needed because this was maintainer-created and maintainer-closed.

## Problem statement

Maintainer-created issue #78 tracks an iOS keyboard behavior problem: English prediction candidates and association/related candidates are optional suggestions, but some functional keys can treat them like active composing candidates.

Expected behavior when only optional suggestions are visible:

- Backspace should perform the normal Backspace/delete action.
- Space should insert a normal space.
- Enter and other functional keys should behave as they would with no active composing candidate, unless a user explicitly taps a suggestion.
- Optional suggestions should dismiss automatically when normal typing actions make them stale.

## Reproduction notes from current evidence

The issue body does not yet include a concrete table/word sequence. Current code inspection suggests two likely paths to verify:

1. English prediction path:
   - Switch the iOS keyboard to English mode with English prediction enabled.
   - Type enough letters for `UITextChecker` completions to populate the candidate bar.
   - Press Backspace.
   - Expected: one typed character is deleted and predictions refresh/dismiss as needed.
   - Suspected actual behavior: the first Backspace clears the prediction bar instead of deleting because `hasCandidatesShown` is true before the English deletion branch is reached.
2. Related/association phrase path:
   - Commit a Chinese candidate that produces related phrase suggestions.
   - With no active composing buffer and only related suggestions visible, press Backspace or Space.
   - Expected: Backspace deletes text; Space inserts a space.
   - Suspected actual Backspace behavior: the first Backspace clears or replaces the suggestion bar instead of deleting because `hasCandidatesShown` is true.

Space already has explicit browse-only handling for associated lists; Backspace appears to need the same optional-suggestion distinction.

## Code inspection

Relevant iOS paths on `master`:

- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`
  - `onKey(primaryCode:)` dispatches `LimeKeyCode.delete` to `handleBackspace()` and `LimeKeyCode.space` / `enter` to `handleEnterOrSpace(isEnter:)`.
  - `handleEnterOrSpace(isEnter:)` builds `isAssociatedList` from `isShowingRelatedPhrases`, `hasChineseSymbolCandidatesShown`, and `(mEnglishOnly && hasCandidatesShown)`, then avoids picking candidates for those browse-only lists.
  - `handleBackspace()` checks generic `hasCandidatesShown` before the English prediction buffer path. With no composing buffer, any visible candidate list that is not Chinese punctuation is cleared by `clearSuggestions()` instead of deleting text.
  - `updateRelatedPhrase(...)` marks related suggestions with `isShowingRelatedPhrases = true` and `hasCandidatesShown = true`.
  - `updateEnglishPrediction()` populates `mCandidateList`, sets `hasCandidatesShown = true`, and selects the first English suggestion, but does not set a separate browse-only flag.

The strongest suspicious branch is:

```swift
} else if hasCandidatesShown {
    // Case 3: composing empty, candidates shown → use clearSuggestions so autoChineseSymbol triggers
    clearSuggestions()

} else if mEnglishOnly && !tempEnglishWord.isEmpty {
    // Case 5: English prediction word → delete last char and re-query
    tempEnglishWord.removeLast()
    textDocumentProxy.deleteBackward()
    updateEnglishPrediction()
```

Because `hasCandidatesShown` is checked first, English prediction candidates can prevent the English deletion path from running. The same generic branch also affects related/association suggestions when there is no active composing buffer. Cases 1 and 2 already consume non-empty `mComposing`, so this branch is not the normal composing-candidate path; it is mainly relevant to optional suggestions with an empty composing buffer, while Chinese punctuation has its own earlier Case 4 branch.

## Likely root cause

Likely missing distinction/order handling for optional browse-only suggestion lists in `handleBackspace()`. `handleEnterOrSpace(isEnter:)` already recognizes optional associated lists and avoids selecting them, but Backspace still treats a visible related/English suggestion list as a reason to clear candidates before deleting text.

For English prediction specifically, the existing English deletion branch already has the desired state update (`tempEnglishWord.removeLast()`, `deleteBackward()`, `updateEnglishPrediction()`); the main bug appears to be that this branch is ordered after the generic `hasCandidatesShown` clearing branch.

## Proposed solution / investigation plan

- Move or otherwise prioritize the `mEnglishOnly && !tempEnglishWord.isEmpty` branch before the generic `hasCandidatesShown` branch so English prediction Backspace deletes the typed character and refreshes predictions.
- Add a helper such as `isBrowseOnlySuggestionList`, or a Backspace-specific classification similar to but not identical to `handleEnterOrSpace(isEnter:)`, so Backspace can differentiate:
  - Chinese punctuation behavior, where hiding punctuation without deleting may still be intentional;
  - related phrase suggestions;
  - English prediction suggestions.
- For related/association suggestions with no composing buffer, Backspace should dismiss stale optional suggestions as part of the normal delete flow, but still call `textDocumentProxy.deleteBackward()` once.
- Preserve the existing Space behavior that already inserts a normal space for associated/English suggestion lists.
- Consider whether Enter should insert newline for English/related suggestions consistently with the issue's “functional keys” wording; current code already avoids selection for `isAssociatedList`.

## Follow-up status

No public follow-up is required because this is a maintainer-created tracking issue and `jrywu` closed it with a fix summary in comment `4517860543` (`https://github.com/lime-ime/limeime/issues/78#issuecomment-4517860543`). Do not post a community retest request for this issue unless the maintainer explicitly asks or new external evidence appears.

The original verification sequences remain useful as release QA / regression checks before TestFlight or a public iOS build:

- English prediction candidate visibility + Backspace / Space.
- Related phrase visibility after a Chinese commit + Backspace / Space.
- Normal composing candidates, to confirm existing candidate-selection behavior is not regressed.

## Verification status

Maintainer-reported checks at closure:

- iOS simulator build: clean.
- Android `compileDebugJava`: clean.
- iPhone 17 Pro Max simulator manual visual verification: pending before TestFlight.

Scope note: this issue doc records maintainer-closed implementation status, not reporter-confirmed public-build verification. Keep it closed unless new iOS evidence appears or the maintainer reopens it for release QA follow-up.
