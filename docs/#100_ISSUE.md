# Issue #100: iOS contextual Enter/Send key light-on-light contrast regression

## Problem statement

Maintainer-created tracking issue #100 records an iOS keyboard visual/interaction bug: when the host text field requests a non-default return key type such as `Send`, `Search`, `Go`, `Next`, `Join`, `Route`, `Done`, or `Continue`, LIME's iOS keyboard programmatically replaces the normal Enter key content with a contextual primary-action label or icon. The highlighted/accent state with the blue background is readable and expected. The bug appears after the user hits Enter: in light theme, the key can return to an unhighlighted/restored gray modifier-key background while the action text/icon remains white, making the action hard to read.

## Current classification

- Type: bug / usability
- Platform: iOS
- Reporter/source: maintainer-created (`limeimetw`) from Jeremy's report
- Live labels: `bug`, `Usability`
- Live assignee: `jrywu`
- Public acknowledgement: none needed; maintainer-created tracking issue.

## Code paths inspected

- `LimeIME-iOS/LimeKeyboard/KeyboardView.swift`
  - `returnKeyType` is set by `KeyboardViewController` from `textDocumentProxy.returnKeyType` and rebuilds the keyboard when the host context changes.
  - `enterKeyOverride(for:)` returns contextual Enter-key substitutions for non-default return key types, including `.send` -> `Send`, `.search` / `.google` / `.yahoo` -> `magnifyingglass`, `.go` -> `arrow.right`, `.next` -> `Next`, `.join` -> `Join`, `.route` -> `Route`, `.done` -> `Done`, and `.continue` -> `Continue`.
  - `applyButtonStyle(...)` detects `enterKeyOverride(for:) != nil` and paints the contextual Enter key with `.systemBlue` rather than the normal modifier-key background.
  - `styleKeyContent(...)` detects the same override and uses `.white` foreground for the icon/label so it reads on the `.systemBlue` background.
  - `keyUp(...)` and `keyCancel(...)` restore only `keyDef.isModifier ? modifierKeyColor : normalKeyColor`, without checking the Enter-key override. For the contextual Enter key in light theme, this can leave the white override text/icon on the unhighlighted/restored light gray modifier background after release/cancel until the keyboard is rebuilt.

## Existing test coverage assessment

- Existing iOS tests include `KeyboardViewControllerTest.swift`, but this issue is a low-level `KeyboardView` styling-state regression around contextual Enter-key background restoration.
- No focused regression test was found that verifies the contextual Enter key keeps the same readable foreground/background combination after `applyButtonStyle(...)`, touch-down, `keyUp(...)`, and `keyCancel(...)` paths.
- The bug is easy to miss if testing only the initial highlighted/accent render state, because `applyButtonStyle(...)` sets the correct blue background before touch handling mutates/restores it.

## Code fragility assessment

The inspected code strongly supports the reported visual regression. The Enter-key override uses a special foreground/background pair during initial styling, but touch release/cancel restores the background through a separate generic path that does not share the same override-aware background decision. That duplicated styling decision is fragile and can diverge whenever a key has a special background independent of `keyDef.isModifier`.

## Likely root cause

`KeyboardView` has two separate background-selection paths for key styling. Initial render is override-aware (`enterKeyOverride(for:) != nil` -> `.systemBlue`), while release/cancel restoration is not override-aware (`keyDef.isModifier ? modifierKeyColor : normalKeyColor`). Because the override foreground remains white, a release/cancel after touching a contextual Enter key can restore the light-theme modifier background and produce a light-on-light contrast failure.

## Proposed fix / investigation plan

1. Centralize the normal/restored key-background decision in a helper such as `backgroundColor(for:)` or `normalBackgroundColor(for:)`.
2. Use that helper from `applyButtonStyle(...)`, `keyUp(...)`, and `keyCancel(...)` so contextual Enter keys restore to the same `.systemBlue` background used by initial render.
3. Consider whether the pressed state should remain `pressedKeyColor` or use an accent-specific pressed color; the minimum fix is preserving readable contrast after release/cancel.
4. Add regression coverage for a key with `code == 10` and non-default `returnKeyType` in light theme:
   - initial render uses accent background and readable foreground;
   - after touch release/cancel restoration, the accent background or another readable foreground/background pair remains;
   - default return key behavior still uses the normal JSON icon/modifier styling.
5. Manually verify several `UIReturnKeyType` values (`Send`, `Search`, `Go`, `Next`, `Done`) in light and dark themes.

## Platform impact analysis

### Confirmed reporter platform behavior

- Confirmed scope is iOS keyboard UI styling for contextual Enter/Return keys in light theme.
- The affected user-visible labels/icons are generated programmatically from the host input field's return-key type, not from the static keyboard layout JSON alone.

### Android impact

- Android is likely not affected by this exact bug. The identified code path is in `LimeIME-iOS/LimeKeyboard/KeyboardView.swift`, uses UIKit `UIReturnKeyType`, and is specific to the iOS keyboard view's touch restoration logic.
- No Android APK retest or Android issue-doc update is needed for this iOS-specific styling regression unless a separate Android contrast report appears.

### iOS impact

- iOS impact is direct and plausible for any input field that requests a contextual return key and any layout/theme where the overridden Enter key starts as an accent/primary-action key.
- Light theme is the highest-risk visual case because `modifierKeyColor` is a light system gray while the override text/icon remains white.

## Verification plan

- In an iOS host field with `returnKeyType = .send`, show the LIME keyboard in light theme.
- Confirm the `Send` key is readable on initial render.
- Tap/release the `Send` key and confirm it remains readable after release.
- Repeat with `.search` / `.go` / `.next` / `.join` / `.route` / `.done` / `.continue` contexts to verify both icon and label override paths.
- Verify dark theme and non-default color themes still maintain readable contrast.
- Verify default Enter/Return (`.default`) still renders/restores as the normal modifier key and still commits/dismisses according to existing behavior.
- Verify `.touchUpOutside` behavior if practical (drag off key and release) because it shares the `keyUp(...)` restoration path.
- Regression-test `keyCancel(...)` with a simulated/system `.touchCancel` path if practical so cancellation restoration is covered separately from normal release.

## Follow-up / retest condition

No community retest request is needed because #100 is maintainer-created. Close the issue after the iOS keyboard styling fix is implemented and verified locally or through the next iOS TestFlight/App Store QA path.
