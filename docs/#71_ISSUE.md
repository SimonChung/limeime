# Issue #71: Switching to English keyboard leaves stale composing code as output on Android and iOS

## Problem statement

Issue #71 was originally reported as a request for a convenient way to clear the current composing code. After the 6.1.7 candidate-bar dismiss fix, the remaining problem is a cross-platform bug in the Chinese/English keyboard switch behavior during active composition.

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

## Current observations

Relevant Android file:

- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`

Relevant iOS file:

- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`

The soft-keyboard Chinese-to-English key is handled by `onKey()` through `KEYCODE_SWITCH_TO_ENGLISH_MODE`, which calls `switchKeyboard(primaryCode)`.

Inside `switchKeyboard(...)`, the current master branch first tries to auto-commit active composing text before changing modes:

```java
if (mComposing != null && mComposing.length() > 0) {
    getCurrentInputConnection().commitText(mComposing, 1);
    finishComposing();
}
clearComposing(false);
```

That behavior matches the remaining report: the raw composing code is committed/leaked when the user expected the language switch to cancel it.

By contrast, the candidate-bar dismiss path now calls `dismissCandidateComposing()`, which hides the popup, calls `clearComposing(true)`, and then calls `InputConnection.finishComposingText()`. That path is closer to the desired cancel semantics.

The physical-keyboard `switchChiEng()` path also uses `clearComposing(false)` before toggling mode. It should be reviewed for parity, because `false` does not force-clear the system composing buffer.

On iOS, the `LimeKeyCode.switchToEnglish` key path calls `switchChiEng(toEnglish: true)`. That function dismisses popups, exits symbol mode if needed, clears shift state, then calls:

```swift
clearComposing(force: false)
```

iOS simulates active composition by inserting inline composing characters into the host document and tracking their length in `composingLength`. The candidate-bar dismiss path already uses `cancelActiveComposingFromCandidateDismiss()`, which deletes the inline composing characters before resetting state. The Chinese-to-English switch path does not use that force/delete behavior, so active raw code can remain in the editor after the layout changes to English.

## Likely root cause

The Chinese/English switch path does not consistently treat active composition as a cancel operation. For this issue, switching from Chinese composition to English should cancel active composition and remove inline composing text, not preserve or commit it.

On Android, `switchKeyboard(...)` commits `mComposing` via `InputConnection.commitText(mComposing, 1)` before calling `clearComposing(false)`, so the stale raw code becomes normal editor text rather than being cleared.

On iOS, `switchChiEng(toEnglish:)` calls `clearComposing(force: false)`. Because the iOS composing simulation has already inserted the composing code inline into the host document, clearing state without deleting inline composing characters can leave the stale raw code as normal editor text.

## Proposed solution

Route Chinese-to-English switching through the same safe composition-cancel semantics used by candidate-bar dismiss, or explicitly cancel before switching mode:

1. On Android, for `KEYCODE_SWITCH_TO_ENGLISH_MODE`, if `mComposing.length() > 0`, do not call `commitText(mComposing, 1)`.
2. On Android, clear LIME state and the active Android composing state, likely by reusing/extracting the `dismissCandidateComposing()` logic or calling `clearComposing(true)` plus `finishComposingText()` on the current `InputConnection`.
3. On iOS, make `switchChiEng(toEnglish: true)` cancel active composition with the same semantics as candidate-bar dismiss, likely by reusing `cancelActiveComposingFromCandidateDismiss()` or a smaller shared helper that deletes inline composing characters before resetting state.
4. Keep any raw-code commit behavior limited to explicit user actions that mean “commit raw input”, not language-mode switching.
5. Review the Android physical-keyboard `switchChiEng()` path and iOS IM-switch paths so soft, physical, and internal IM switching are consistent.

## Follow-up questions

- Should switching from Chinese to symbol/emoji modes also cancel instead of commit active composing code, or is this issue limited to the explicit Chinese/English switch key?
- Should language switching always cancel active composition, or should this become a setting if some users rely on the previous auto-commit behavior?

## Verification plan

1. Start composing a code sequence that has not been committed yet.
2. Tap the Chinese/English switch key while composition is active.
3. Verify that the composing/candidate state is cleared.
4. Verify that no raw code or stale text is inserted into the target editor.
5. Repeat with the candidate-bar dismiss button and confirm both paths behave consistently.
6. Repeat with at least one table where the typed code has valid candidates and one where it does not.
7. Repeat on iOS with the `abc` / Chinese toggle while composing, including iPhone and iPad layouts if possible.
8. Repeat with a physical keyboard Chinese/English switch shortcut, if supported, to confirm parity.
