# Issue #71: Switching to English keyboard leaves stale composing code as output

## Problem statement

Issue #71 was originally reported as a request for a convenient way to clear the current composing code. After the 6.1.7 candidate-bar dismiss fix, the remaining problem is a bug in the Chinese/English keyboard switch behavior during active composition.

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

## Likely root cause

The Chinese/English keyboard switch path likely changes keyboard/input mode without invoking the same composition-cancel/clear logic used by candidate-bar dismiss. As a result, the composing buffer or raw preedit text is finalized/leaked instead of being explicitly cancelled.

Areas to inspect:

- Android keyboard mode switch handling for Chinese/English toggle.
- Composition/preedit clearing logic used by candidate-bar dismiss.
- Any code path that commits raw composing text when leaving Chinese composition mode.
- Cross-platform parity if the same composition state model is shared.

## Proposed solution

Route the Chinese/English switch behavior through the same safe composition-cancel logic used by candidate-bar dismiss, or explicitly clear/cancel the composing buffer before switching to English mode.

The fix should ensure that switching modes while composing does not call a raw-code commit path unless the user explicitly requested raw-code commit.

## Follow-up questions

- Does this reproduce only on Android, or also on iOS/desktop builds if applicable?
- Is the stale output inserted immediately on switch, or only after the next key/action?
- Should this behavior apply to all table input methods consistently?

## Verification plan

1. Start composing a code sequence that has not been committed yet.
2. Tap the Chinese/English switch key while composition is active.
3. Verify that the composing/candidate state is cleared.
4. Verify that no raw code or stale text is inserted into the target editor.
5. Repeat with the candidate-bar dismiss button and confirm both paths behave consistently.
6. Repeat with at least one table where the typed code has valid candidates and one where it does not.
