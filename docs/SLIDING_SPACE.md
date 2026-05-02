# Sliding Space Bar — Caret Movement

## Current behaviour

`SpaceKeyButton` uses raw touch tracking (`touchesBegan/Moved/Ended`) to disambiguate tap,
swipe, and long-press without UIKit interference.  A horizontal swipe past
`LayoutMetrics.Gesture.spaceSwipeThreshold` fires:

| direction | key code emitted | ViewController action |
|-----------|------------------|-----------------------|
| left  | `LimeKeyCode.prevIM` | `switchToNextActivatedIM(forward: false)` |
| right | `LimeKeyCode.nextIM` | `switchToNextActivatedIM(forward: true)`  |

This switches the active input method, which is rarely needed mid-sentence and conflicts
with the much more useful "slide to move cursor" pattern that Apple introduced in iOS 13 for
the stock keyboard's space bar.

---

## Proposed behaviour

Horizontal swipe on the space bar moves the text cursor instead of switching IMs.

| direction | action |
|-----------|--------|
| ← left    | `textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)` |
| → right   | `textDocumentProxy.adjustTextPosition(byCharacterOffset: +1)` |

IM switching moves to the **globe long-press menu** (already wired up at
`KeyboardViewController.swift:2818`) or the Globe key tap (`advanceToNextInputMode()`).

---

## iOS implementation

### 1. Continuous tracking (preferred)

Replace the single-fire threshold check with per-`touchesMoved` accumulation so the cursor
tracks the finger smoothly — matching the Apple stock keyboard feel.

```swift
// SpaceKeyButton additions
private var cumulativeDx: CGFloat = 0
private static let caretStepPx: CGFloat = LayoutMetrics.Gesture.spaceSwipeThreshold / 2

override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, !actionFired else { return }
    let dx = touch.location(in: self).x - touchBeganPoint.x
    // Accumulate and emit one caret step per threshold unit crossed
    let steps = Int(dx / SpaceKeyButton.caretStepPx)
    let pending = steps - caretStepsFired
    if pending != 0 {
        caretStepsFired = steps
        onCaretMove?(pending)   // new callback, negative = left
        longPressTimer?.invalidate(); longPressTimer = nil
        actionFired = true      // suppress tap on touchesEnded
    }
}
```

Add `var onCaretMove: ((Int) -> Void)?` alongside the existing callbacks.

### 2. Wire up in `makeSpaceButton`

```swift
btn.onCaretMove = { [weak self] steps in
    guard let self else { return }
    self.delegate?.keyboardView(self, didMoveCaretBy: steps)
}
// Remove onSwipeLeft / onSwipeRight assignments (IM switching)
```

Add `keyboardView(_:didMoveCaretBy:)` to `KeyboardViewDelegate`.

### 3. Handle in `KeyboardViewController`

```swift
func keyboardView(_ view: KeyboardView, didMoveCaretBy steps: Int) {
    guard mComposing.isEmpty else { return }   // no cursor move while composing
    textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
}
```

When composing is active, ignore (or alternatively commit composing first — TBD by UX
preference).

### 4. `LayoutMetrics` constant

Add `caretStepPx` to `LayoutMetrics.Gesture` so it is tunable in one place alongside
`spaceSwipeThreshold`.

### Constraints and edge cases

- **Composing active**: `adjustTextPosition` while the engine holds uncommitted text produces
  undefined results on some apps.  Safest is to no-op; alternatively commit composing first.
- **Long-press**: existing long-press (IM picker / switch chi/eng) is unaffected because
  `actionFired` is not set until the caret step threshold is crossed.
- **Haptics**: emit a light `UIImpactFeedbackGenerator(.light)` per caret step for tactile
  rhythm (Apple does this on stock keyboard).
- **Accessibility**: VoiceOver already handles caret via its own gesture; no conflict.

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
getCurrentInputConnection()
    .sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DPAD_LEFT));
```

or the higher-level:

```java
getCurrentInputConnection().commitCorrection(...)  // not useful here
// better:
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
| iOS implementation (steps 1–4 above) | ~2 h |
| Android: touch intercept in `LIMEKeyboardBaseView` | ~3 h |
| Android: `InputConnection` caret step dispatch | ~1 h |
| Shared `LayoutMetrics`-style constant in Android (`dimens.xml`) | ~30 min |
