# Issue #114: Duolingo English candidate strip intermittently missing

## Live issue state

- Issue: https://github.com/lime-ime/limeime/issues/114
- Status: open / triaged as a plausible Android bug; reporter supplied environment details in comment `4697486430`
- Reporter: `SmithCCho`
- Current labels after triage: `bug`, `Usability`
- Assignee after triage: `jrywu`

## Problem statement

Reporter `SmithCCho` says that in the Duolingo Android app, LIME English candidates sometimes do not display correctly while Chinese candidates still display normally. The reporter later supplied device/version details: Samsung A16, Android 16 / One UI 8.5, LIME 6.1.18, and Duolingo 6.83.4; they noted earlier Duolingo versions had also shown the intermittent behavior. Only Duolingo is mentioned in the report so far.

The screenshots show the same Duolingo fill-in-the-blank style exercise around the text `Can I speak to you for fif____ minutes?`:

1. Abnormal English state: the LIME keyboard is in English/alphabet mode, `fif` is being composed/underlined in the exercise field, but the LIME candidate strip shows only the empty toolbar row (emoji/microphone area) and no English candidates.
2. Chinese state: switching to Chinese/table input in the same field shows table candidates normally.
3. Normal English state: another English attempt for `fif` shows the candidate strip with `fif`, `fifth`, `fifty`, `fifteen`, etc.

## Reproduction information from report

Confirmed from the report and follow-up comment `4697486430`:

- Platform/device: Android on Samsung A16.
- OS/UI: Android 16 / One UI 8.5.
- LIME version: 6.1.18.
- App context: Duolingo 6.83.4 exercise input field; reporter says earlier Duolingo versions had also shown the intermittent behavior.
- Input mode: English candidates are affected; Chinese candidates are visible.
- Failure is intermittent: sometimes the English candidate strip appears normally, sometimes it stays empty.
- Reporter says recording the failure is difficult because it is infrequent: Duolingo may show a different exercise type such as voice input, so the reporter only knows whether the issue recurs when the next word-input exercise appears.

Missing details to collect if more evidence is needed:

- Whether the problem reproduces after closing/reopening the Duolingo exercise, switching away from and back to LIME, or using another English prediction field.
- Whether Android logcat shows relevant `EditorInfo`, `InputConnection`, or LIME errors when candidates disappear.

## Related prior context

Issue #103 covered general Android English prediction visibility and ranking. That scope was reporter-confirmed fixed in Android APK `LIMEHD2026-6.1.17.apk`, and the current mutable state says #103 should remain closed unless new English-candidate evidence appears.

#114 is not the same as #103's exact-match/ranking issue: here the candidate list can be normal for the same prefix (`fif`) but intermittently disappears only in a specific app context. Treat this as a new app-specific English candidate display/state-sync bug rather than reopening #103 directly.

## Relevant Android code paths inspected

Primary source area:

- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`

Observed current behavior:

- `initOnStartInput(EditorInfo attribute)` disables prediction when the target text field advertises `TYPE_TEXT_FLAG_NO_SUGGESTIONS`, disables LIME prediction and uses completion behavior for `TYPE_TEXT_FLAG_AUTO_COMPLETE`, and otherwise allows English prediction in normal text fields.
- `updateEnglishPrediction()` builds candidates only when `mPredictionOn` and the English prediction preference are enabled.
- `updateEnglishPrediction()` checks the current `InputConnection` with `getTextBeforeCursor(...)` and `getTextAfterCursor(...)`; if the app returns context that does not match `tempEnglishWord` and the next character is not considered a boundary, the method can skip refreshing the candidate list.
- When English suggestions are shown, `buildEnglishPredictionCandidates(...)` always prepends the composing/self candidate, and `setEnglishPredictionSuggestions(...)` uses the no-highlight display path from the #103 fix.
- `clearSuggestions()` / empty-toolbar behavior can leave the embedded candidate area visible without candidate words, which is consistent with the abnormal screenshots.

Existing test coverage observed:

- `LIMEServiceTest.englishPredictionCandidatesKeepComposingWordWhenSuggestionsAreEmpty()` covers the #103 helper that keeps the typed word when dictionary suggestions are empty.
- `LIMEServiceTest.englishPredictionCandidatesKeepSuggestionsAfterComposingWord()` covers prepending the composing word before English suggestions.
- `CandidateViewTest.setSuggestionsWithoutHighlightLeavesNoSelectedCandidate()` covers the no-highlight English candidate display path.
- Current tests do not appear to cover app-specific `InputConnection` behavior where `getTextBeforeCursor(...)` / `getTextAfterCursor(...)` disagree with LIME's local `tempEnglishWord`, nor do they cover candidate-strip recovery/state rebuild if toggling Chinese/English mode turns out to be part of the failure path.

## Likely root cause / current hypothesis

Root cause is not confirmed yet.

The most likely investigation area is the interaction between Duolingo's exercise input field and LIME's English prediction state:

1. Duolingo may expose unusual `EditorInfo.inputType` flags, completion mode, or no-suggestions flags for some exercise states.
2. Duolingo's custom fill-in-the-blank field may return inconsistent cursor context through `InputConnection.getTextBeforeCursor(...)` / `getTextAfterCursor(...)` while the visible composing text still shows `fif` underlined.
3. LIME's `updateEnglishPrediction()` can then skip rebuilding English candidates or clear suggestions, leaving the empty toolbar row instead of the `fif` / `fifth` / `fifty` list.
4. Chinese table candidates use a different lookup path, so they can still work in the same app context.

This should stay a hypothesis until local reproduction or logcat evidence shows `EditorInfo` and `InputConnection` values during the bad state.

## Proposed investigation / solution direction

1. Reproduce in Duolingo with English prediction enabled and collect:
   - `EditorInfo.inputType`, `imeOptions`, and variation/flags when the field starts.
   - The `tempEnglishWord` value when `updateEnglishPrediction()` runs.
   - `getTextBeforeCursor(...)` / `getTextAfterCursor(...)` results when the candidate strip is empty vs normal.
2. If the editor context is inconsistent but `tempEnglishWord` is non-empty, consider making English prediction more resilient by still showing the composing/self candidate when the local composing buffer is valid, instead of silently leaving the candidate strip empty.
3. If mode-toggle recovery is implicated during reproduction, ensure toggling mode or restarting input clears/rebuilds English prediction state for the current composing text.
4. Add a focused regression test or testable helper around the `InputConnection`/`tempEnglishWord` gating logic so an app-specific context mismatch cannot hide all English candidates while a local English composition exists.

## Follow-up questions for reporter

Already collected from the reporter: Samsung A16, Android 16 / One UI 8.5, LIME 6.1.18, Duolingo 6.83.4, and the note that earlier Duolingo versions had also shown the intermittent behavior.

Only ask for additional details if they are needed for implementation/debugging:

1. Duolingo version.
2. Whether the failure happens only in this Duolingo exercise type, or also in other Duolingo text fields/apps.
3. If convenient and the issue recurs, a short screen recording showing the moment candidates disappear and whether leaving/re-entering the field restores them; the reporter noted this may be difficult because recurrence is infrequent and Duolingo alternates exercise types.
4. If local reproduction is not possible, a filtered logcat around the failure to inspect `EditorInfo` / `InputConnection` behavior.

Do not ask the reporter to retest the same APK as a fix verification. Request retest only after a newer APK contains a relevant change for this issue.

## Platform impact analysis

### Android

Confirmed reporter platform: Samsung A16 on Android 16 / One UI 8.5 with LIME 6.1.18. The likely affected implementation is Android `LIMEService` English prediction / candidate-strip state in app-specific input fields. Chinese table input uses separate candidate lookup and appears normal in the screenshots.

### iOS

No iOS behavior is reported. iOS uses a different keyboard implementation and English completion flow, so the Android `LIMEService` / `InputConnection` hypothesis does not directly apply. However, if the final product expectation is that English candidates should remain visible across app-specific fields, an iOS parity audit can be considered after the Android root cause is understood.

## Verification plan

After a candidate fix exists:

1. Install the new Android test APK.
2. In Duolingo, reproduce the same English exercise flow and type `fif`.
3. Verify the English candidate strip consistently shows the composing/self candidate and suggestions, for example `fif`, `fifth`, `fifty`, `fifteen`, when English prediction is enabled.
4. If reproduction shows mode toggling affects the bug, toggle LIME Chinese/English mode in the same field and verify candidates recover correctly.
5. Verify Chinese table candidates still display normally in the same field.
6. Regression-check #103 cases such as `salt` exact-match visibility and English no-highlight behavior.
7. Regression-check normal text fields outside Duolingo so the app-specific resilience does not show stale candidates in unrelated contexts.

## Backlog status

No `docs/BACKLOG.md` update yet. The report is plausible and tracked as a bug, but the exact fix direction is not confirmed until reproduction or logs identify whether the issue is `EditorInfo` classification, `InputConnection` context mismatch, candidate-strip visibility state, or a mode-toggle state reset problem.
