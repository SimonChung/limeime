# Issue #104 — Android Enter key commits related candidate after 6.1.16

## Problem statement

Community reporter `Limeroshenko` reports a regression in Android APK `6.1.16`: after committing a word, when the candidate strip still shows related/association candidates, pressing Enter commits the first/highlighted candidate instead of passing Enter through to the target app.

Expected behavior from the reporter's pre-6.1.16 usage: Enter should perform the editor action such as newline or search after the main word has already been committed.

Issue: https://github.com/lime-ime/limeime/issues/104
Evidence: reporter attached a video at https://github.com/user-attachments/assets/6173a1f7-c44e-4cf6-9ecf-aa6f4e49d48a

## Reproduction details from the report

1. Install/use Android LIME IME `6.1.16`.
2. Type and commit a word.
3. Leave the related/association candidate strip visible after the word.
4. Press Enter in an editor/search field.
5. Observed: LIME sends the first candidate from the candidate strip.
6. Expected: Enter should reach the editor and perform newline/search/action without forcing the user to delete the previous word just to clear the related candidate strip.

The report specifically compares against `6.1.15` and earlier behavior.

## Current code observations

Relevant Android code inspected in `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`:

- Soft-keyboard `onKey(...)` handles `MY_KEYCODE_ENTER` in the same candidate-selection branch as Space:
  - if `hasCandidatesShown` is true, it calls `pickHighlightedCandidate()`.
  - only when no candidate is picked does it send the raw Enter character.
- Physical-keyboard `onKeyDown(KEYCODE_ENTER, ...)` also checks `hasCandidatesShown` and calls `pickHighlightedCandidate()`, then blocks the key-up path with `hasEnterProcessed`.
- `commitTyped(...)` intentionally allows non-composing candidates such as related phrase or English suggestion records to commit even when `mComposing.length() == 0`.

This makes the reported symptom plausible when related candidates remain visible after a normal commit: the global `hasCandidatesShown` state is enough for Enter to select the highlighted related candidate, even though there is no active composing code.

## Existing coverage / gap

Relevant tests exist for Enter key constants, broad `onKey`/`onKeyDown` branches, `pickHighlightedCandidate()`, candidate lists, and related-phrase/search-server behavior, but the inspected tests do not appear to assert the user-facing path:

- after a committed word,
- with only related/association candidates visible,
- pressing Enter should pass through to the target editor action rather than commit a related candidate.

This missing regression case likely allowed the 6.1.16 behavior to ship without a guard.

## Likely root cause

Likely Android service/candidate-state regression or uncovered behavior in `LIMEService` Enter handling: Enter currently treats any visible candidate list as selectable, including related/association candidates left visible after the active composing text has already been committed.

The fix should distinguish active composition candidate selection from post-commit related/association suggestions. Enter should continue to commit an active composing candidate when appropriate, but should not consume Enter merely because post-commit related candidates are visible.

Root cause should remain marked as likely until reproduced on-device or covered by a focused Android service/instrumentation test.

## Proposed fix / investigation plan

1. Reproduce with Android `6.1.16` using a table/setting path that leaves related candidates visible after committing a word.
2. Add a focused regression test around `LIMEService` Enter behavior with `mComposing.length() == 0` and related candidates visible.
3. Adjust Enter handling so post-commit related/association candidates do not consume Enter.
4. Keep existing expected behavior for:
   - active composing candidate selection,
   - Space candidate commit behavior,
   - opt-in end-key behavior from `%limeendkey` / `@limeendkey@`,
   - physical-keyboard Enter if it shares the same state path.
5. Verify with normal text/newline fields and browser/search fields because the reporter specifically mentions newline/search actions.

## Follow-up questions

Current report is sufficient to classify this as a plausible Android regression. If reproduction is inconsistent, ask the reporter for:

- input table/IM used,
- whether related-phrase/association candidate settings are enabled,
- the exact app/input field used in the attached video.

Do not ask for retest until a newer APK/build contains a targeted fix.

## Platform impact analysis

### Android

Confirmed reporter platform. The inspected Android `LIMEService` candidate/Enter handling plausibly matches the symptom in `6.1.16`. Android needs a source fix plus an APK retest.

### iOS

Not reported. iOS has a separate Swift keyboard implementation, so Android `LIMEService.java` state handling does not directly apply. Still, iOS should receive a light parity audit for return-key behavior when related candidates remain visible after commit, especially if the intended product rule is that Enter/Search/Return should pass through once composition has ended.

## Verification plan

- Android unit/instrumentation coverage: simulate or construct post-commit related candidates visible with no composing code, press Enter, and verify no related candidate is committed and the editor action/newline path is allowed.
- Android manual: in a normal multiline text field, press Enter after committing a word with related candidates visible and confirm a newline occurs.
- Android manual: in a browser/search field, press Enter/Search after committing a word with related candidates visible and confirm search/action runs.
- Regression: active composing candidate selection with Space and valid selection keys still works; `%limeendkey`/`@limeendkey@` behavior from #96 remains unchanged.
- iOS audit: confirm return/search key behavior with visible related candidates after commit, or document that iOS behavior is already independent.

## Current follow-up status

- Classification: plausible Android bug / regression.
- Public issue: open, pending maintainer investigation.
- Retest condition: wait for a newer Android APK than `6.1.16` containing a targeted Enter/related-candidate fix before asking the reporter to retest.
