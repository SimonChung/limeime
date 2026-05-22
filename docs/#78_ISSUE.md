# Issue #78: iOS optional suggestion candidates should not intercept functional keys

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

## Follow-up questions

No public follow-up is required before implementation because this is maintainer-created and already labeled `bug` + `Usability`. During implementation verification, capture exact reproduction sequences for:

- English prediction candidate visibility + Backspace / Space.
- Related phrase visibility after a Chinese commit + Backspace / Space.
- Normal composing candidates, to confirm existing candidate-selection behavior is not regressed.

## Verification plan

- Add focused iOS unit tests if the keyboard controller can be tested with a mock `textDocumentProxy`; otherwise perform manual simulator/device verification.
- English mode:
  - type an English prefix that shows predictions;
  - press Backspace and confirm text deletes immediately, predictions refresh or dismiss, and no candidate is committed/selected;
  - press Space and confirm a space is inserted without selecting a suggestion.
- Chinese related phrase mode:
  - commit a Chinese word that shows related suggestions;
  - press Backspace and confirm text deletes immediately rather than only hiding the bar;
  - press Space and confirm a normal space is inserted.
- Regression-check normal composing candidates where Space/Enter are still supposed to commit/select candidates.
- After the fix lands in an iOS build/TestFlight or other tester-available build, request verification against the exact sequences above; do not close solely from labeling or implementation without maintainer/reporter confirmation.
