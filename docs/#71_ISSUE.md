# Issue #71: Switching to English keyboard leaves stale composing code as output on Android and iOS

## Problem statement

Issue #71 was originally reported as a request for a convenient way to clear the current composing code. After the 6.1.7 candidate-bar dismiss fix, the remaining user-visible problem was the Chinese/English keyboard switch behavior during active composition.

When the user is composing code and switches to the English keyboard, LIME IME should cancel the active composition and leave no text to output. The current behavior leaves the stale composing code as output after switching to English.

This is analogous to the candidate-bar dismiss behavior fixed in 6.1.7: dismissing/cancelling the current composition should clear the composing buffer, not commit or leak the raw code.

## Expected behavior

- If there is active composing code and the user switches to English keyboard mode, cancel the composition.
- Do not commit the stale composing code to the editor.
- Leave no output from the cancelled composition.
- The behavior should be consistent with the candidate-bar dismiss action introduced/fixed around 6.1.7.

## Actual behavior

- During active composition, switching to English keyboard mode leaves the stale composing code as output.
- The user then has to manually delete the leaked code, which defeats the purpose of using the switch key as a quick cancel path.

## Current fix status

The relevant fix is included in bulk commit `3d5d9c5` (`refactor: keyboard quality pass, prefs cleanup, emoji default 5 (#71)`) and is present in test APK `LIMEHD2026-6.1.8.apk`.

Relevant Android file:

- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`

Android changed `switchKeyboard(int primaryCode)` so `KEYCODE_SWITCH_TO_ENGLISH_MODE` cancels active composition instead of committing stale raw code:

```java
if (primaryCode == KEYCODE_SWITCH_TO_ENGLISH_MODE) {
    if (mComposing != null && mComposing.length() > 0) {
        clearComposing(true);
        InputConnection ic = getCurrentInputConnection();
        if (ic != null) ic.finishComposingText();
    } else {
        clearComposing(false);
    }
} else if (mComposing != null && mComposing.length() > 0) {
    getCurrentInputConnection().commitText(mComposing, 1);
    finishComposing();
    clearComposing(false);
} else {
    clearComposing(false);
}
```

Relevant iOS file:

- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`

iOS changed `switchChiEng(toEnglish:)` so switching to English uses the candidate-dismiss cancel path:

```swift
if toEnglish {
    cancelActiveComposingFromCandidateDismiss()
} else {
    clearComposing(force: false)
}
```

This keeps legacy auto-commit behavior for other switch paths while making the explicit Chinese-to-English switch behave as a cancel operation.

Reporter `ejmoog` confirmed on 2026-05-22 that Android APK `6.1.8` implements the requested Chinese/English switch behavior: "安裝了6.1.8，功能已實現，感謝！" The reporter then closed the issue as completed. No separate iOS or physical-keyboard verification was provided in the issue thread.

## Root cause addressed

The Chinese/English switch path previously did not consistently treat active composition as a cancel operation. For this issue, switching from Chinese composition to English should cancel active composition and remove inline composing text, not preserve or commit it.

The 6.1.8 code change addresses the two known soft-keyboard paths; reporter verification in this issue covers the Android APK path:

1. Android `KEYCODE_SWITCH_TO_ENGLISH_MODE` now calls `clearComposing(true)` and `finishComposingText()` when composition is active, instead of committing `mComposing`.
2. iOS `switchChiEng(toEnglish: true)` now calls `cancelActiveComposingFromCandidateDismiss()` instead of only `clearComposing(force: false)`.

## Implemented solution

The implemented behavior routes explicit Chinese-to-English switching through safe composition-cancel semantics while leaving other switch modes on the legacy commit/clear path.

No remaining #71 watch item is needed. Broader product questions such as symbol/emoji switching, physical-keyboard parity, or making language-switch behavior configurable should be tracked separately only if they are requested or reproduced in a new issue.

## Verification result

Reporter `ejmoog` tested Android APK `6.1.8` and confirmed the requested function is implemented. Original Android-focused verification checklist used for the retest request:

1. Start composing a code sequence that has not been committed yet.
2. Tap the Chinese/English switch key while composition is active.
3. Verify that the composing/candidate state is cleared.
4. Verify that no raw code or stale text is inserted into the target editor.
5. Repeat with the candidate-bar dismiss button and confirm both paths behave consistently.
6. Repeat with at least one table where the typed code has valid candidates and one where it does not.
7. iOS soft-keyboard and physical-keyboard parity were not verified by this reporter thread; treat those as out of scope for #71 unless a new report provides evidence.

Follow-up status: resolved/closed after reporter confirmation on Android APK `6.1.8`. No active watch is needed unless the reporter reopens or new related evidence appears.
