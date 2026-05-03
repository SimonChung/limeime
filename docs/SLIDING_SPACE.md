# Sliding Space Bar — Caret Movement

## Implemented behaviour (iOS)

`SpaceKeyButton` uses raw touch tracking (`touchesBegan/Moved/Ended`) to disambiguate tap,
swipe, and long-press without UIKit interference.  A horizontal swipe past
`LayoutMetrics.Gesture.spaceSwipeThreshold` moves the text cursor:

| direction | action |
|-----------|--------|
| ← left    | `textDocumentProxy.adjustTextPosition(byCharacterOffset: -N)` |
| → right   | `textDocumentProxy.adjustTextPosition(byCharacterOffset: +N)` |

Caret movement accelerates with slide distance (see tiers below).
IM switching is via the Globe key tap (`advanceToNextInputMode()`) or the Globe long-press menu.

---

## Architecture

### `SpaceKeyButton` (KeyboardView.swift)

Raw touch tracking with three phases:

- **Tap**: `touchesEnded` fires `onTap` if no action was suppressed.
- **Long-press**: a `Timer` fires `onLongPress` after `spaceLongPressDuration`; cleared on any drag.
- **Slide**: once `abs(dx) >= deadZone`, long-press is cancelled and `onCaretMove(delta)` is emitted
  each time the finger crosses a step boundary.

### Acceleration tiers

`stepsForDisplacement(_:)` maps absolute displacement to total step count using three linear tiers:

| Travel beyond dead zone | Step size | Effective speed |
| --- | --- | --- |
| 0 – 60 pt | 8 pt / step (`stepPx`) | 1× |
| 60 – 140 pt | 4 pt / step (`stepPx / 2`) | 2× |
| 140 pt + | 2 pt / step (`stepPx / 4`) | 4× |

`lastCaretStep` tracks the last emitted total so each `touchesMoved` call emits only the
incremental delta.

### Wiring

```
SpaceKeyButton.onCaretMove(delta)
  → KeyboardView.delegate?.keyboardView(_:didMoveCaretBy:)
    → KeyboardViewController.keyboardView(_:didMoveCaretBy:)
      → textDocumentProxy.adjustTextPosition(byCharacterOffset: steps * delta)
```

`KeyboardViewController` no-ops when `mComposing` is non-empty (cursor movement while the
engine holds uncommitted text produces undefined results on some apps).

### `LayoutMetrics.Gesture` constants

| Constant | Value | Purpose |
| --- | --- | --- |
| `spaceSwipeThreshold` | 12 pt | Initial dead zone before caret tracking begins |
| `spaceCaretStepPx` | 8 pt | Base step size (tier 1) |
| `spaceLongPressDuration` | 0.5 s | Long-press delay |

---

## Constraints and edge cases

- **Composing active**: `adjustTextPosition` while the engine holds uncommitted text produces
  undefined results on some apps.  Current behaviour: no-op.
- **Long-press**: unaffected — `tapSuppressed` is not set until the dead zone is crossed.
- **Haptics**: `UIImpactFeedbackGenerator(.light)` per caret step (Apple does this on stock
  keyboard) is not yet wired up.
- **Accessibility**: VoiceOver handles caret via its own gesture; no conflict.

---

## Android backport

### Current Android behaviour

`LIMEService.swipeLeft()` (line 3683) calls `handleBackspace()`.
`LIMEService.swipeRight()` (line 3677) is a no-op stub.
These are called by the soft-keyboard framework's `KeyboardView.OnKeyboardActionListener`
`onSwipeLeft`/`onSwipeRight` callbacks, which fire only after the touch is released and
provide no continuous position data.

### Feasibility

Android's `InputConnection` exposes the same primitive:

```java
getCurrentInputConnection().sendKeyEvent(
    new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DPAD_LEFT));
```

But the `onSwipeLeft`/`onSwipeRight` callbacks are single-fire and the stock
`KeyboardView` does not expose continuous touch deltas to the service.

**Path forward**: attach a custom `OnTouchListener` to the space `Key`'s view (or subclass
`KeyboardView` to override `onTouchEvent`) and replicate the iOS step-accumulation logic
against `MotionEvent.ACTION_MOVE`.  This is a larger refactor because Android's
`KeyboardView` is deprecated and LIME already uses a custom layout; the touch override should
be straightforward in `LIMEKeyboardBaseView`.

### Backport effort summary

| Task | Estimate |
|------|----------|
| Android: touch intercept in `LIMEKeyboardBaseView` | ~3 h |
| Android: `InputConnection` caret step dispatch | ~1 h |
| Android: acceleration tiers matching iOS | ~30 min |
| Shared `LayoutMetrics`-style constant in Android (`dimens.xml`) | ~30 min |
