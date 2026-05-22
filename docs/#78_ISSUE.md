# Issue #78: iOS optional suggestion candidates should not intercept functional keys

## Current status

Maintainer-created issue #78 was created by `limeimetw` and closed by `jrywu` on 2026-05-22 after `jrywu` reported a local cross-platform fix in commit `2e278c46`. A GitHub API lookup found no remote commit with SHA `2e278c46`, so this document records the maintainer-local resolution status rather than a tester-available build.

Reported fix scope from the maintainer comment:

- iOS English-prediction Backspace now reaches the English deletion path before generic candidate clearing.
- Related/association browse-only suggestion bars no longer require a separate Backspace tap before deletion; iOS uses a shared browse-only classifier/helper and Android pre-clears candidate state before sending Backspace.
- iOS Enter now dismisses stale browse-only related/symbol bars when composing is empty.
- Chinese-punctuation Backspace and normal composing flows are intended to remain unchanged.

Implementation checks reported by the maintainer: iOS Simulator build and Android `compileDebugJava` are clean. Manual visual verification on the iPhone simulator is still pending before TestFlight / tester-available delivery. No public retest request is needed yet because this is a maintainer-created tracking issue.

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

## Root cause and resolution

The suspected root cause was addressed by the maintainer's local fix, but behavioral confirmation is still pending manual verification because the fixing commit was not yet available on the remote. The likely issue remains that optional browse-only suggestion lists needed different handling from normal composing candidates in functional-key paths. In particular, `handleBackspace()` could clear a visible English prediction or related suggestion bar before performing the key's normal action.

Per the maintainer's closing comment, the reported local fix promotes English prediction Backspace handling ahead of generic candidate clearing, adds shared browse-only suggestion classification/dismissal for iOS, and mirrors the related-phrase Backspace behavior on Android by clearing candidate state before sending the delete key. These exact implementation details should be re-checked once the commit is pushed.

## Implemented local fix

Per `jrywu`'s closing comment, local commit `2e278c46` reportedly addressed three sub-bugs the maintainer says are documented in `docs/CANDI_FUNCTION_KEYS.md`:

- iOS Backspace on English prediction: the `mEnglishOnly && !tempEnglishWord.isEmpty` branch now runs before generic `hasCandidatesShown` clearing.
- Related-phrase Backspace requires multiple taps: iOS uses `isBrowseOnlySuggestionList` / `dismissBrowseOnlySuggestionBar()`, while Android pre-clears `hasCandidatesShown` before issuing `KEYCODE_DEL`.
- iOS Enter does not leave stale related/symbol bars visible when composing is empty: `handleEnterOrSpace(isEnter:)` dismisses browse-only bars in that path.

A GitHub API lookup found no remote commit with SHA `2e278c46` when this doc was updated, so code-level verification should be repeated once the local commit is pushed.

## Follow-up

No public follow-up is required because this is maintainer-created and was closed by the maintainer after a local fix. Before any TestFlight or public retest note, finish/record manual visual verification and confirm the fixing commit is pushed to a tester-available branch/build. Capture exact reproduction sequences for:

- English prediction candidate visibility + Backspace / Space.
- Related phrase visibility after a Chinese commit + Backspace / Space.
- Normal composing candidates, to confirm existing candidate-selection behavior is not regressed.

## Verification plan

Maintainer-reported checks already completed: iOS Simulator build and Android `compileDebugJava`. Remaining verification before broader delivery:

- Confirm commit `2e278c46` or its equivalent is pushed to the remote and included in the intended iOS/TestFlight build.
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
- After the fix lands in an iOS build/TestFlight or other tester-available build, request verification only if the maintainer wants external confirmation; the GitHub issue itself is already maintainer-closed.