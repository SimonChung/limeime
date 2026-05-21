# iOS Haptic Feedback — Investigation & Fix Plan

## Symptoms (reported)

1. **Pulse feels longer than the iOS built-in keyboard**, even with the strength selector at the lowest setting ("特弱").
2. **When haptic is ON and the user types very fast, middle keys in a run get dropped** — the press doesn't register. With haptic OFF the same fast burst is fine. It feels like the haptic is "blocking" the next touch.

## Root-cause analysis

### Cause A — Generator is rebuilt from scratch on every keystroke, and `prepare()` is never called

[`LimeIME-iOS/LimeKeyboard/KeyboardView.swift:182-190`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L182-L190)

```swift
private var impactFeedback: UIImpactFeedbackGenerator {   // computed, not stored
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch vibrateLevel {
    case ..<30:   style = .light
    case 30..<50: style = .medium
    default:      style = .heavy
    }
    return UIImpactFeedbackGenerator(style: style)        // new instance each call
}
```

Fired on every `.touchDown` at [`KeyboardView.swift:953`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L953):

```swift
if feedbackVibration { impactFeedback.impactOccurred() }
```

The same anti-pattern exists in three more places:

| File | Lines | Notes |
| --- | --- | --- |
| [`KeyboardView.swift`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L182-L190) | 182–190, 690, 702, 953 | Key down, space-key tap, popup long-press |
| [`CandidateBarView.swift`](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift#L93-L101) | 93–101, 772, 779, 784, 789, 795 | Candidate tap, dismiss, emoji, options, more chevron |
| [`KeyboardViewController.swift`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1770-L1779) | 1770–1779 | Expanded-candidate panel chrome |

`grep` for `.prepare()` and `CHHapticEngine` in `LimeIME-iOS/` returns zero hits. The Taptic Engine is never warmed.

**Why this produces *both* symptoms:**

Apple's contract for `UIImpactFeedbackGenerator` is:

> The Taptic Engine takes ~100 ms to wake from idle. Hold one generator, call `prepare()` to warm the engine before you expect feedback, then `impactOccurred()` at the moment of impact. Without `prepare()`, the actuator may fire late or not at all.

Because LimeIME constructs a *fresh* generator each call and never primes it, the Taptic Engine cold-starts on every press. iOS internally queues each impact until the actuator is ready; the pulse then plays **after** the visible press. The user perceives this lag as the pulse "lasting longer" — it's not actually longer, it's *delayed*, smearing across the next event.

Apple also documents:

> Calling `impactOccurred()` in rapid succession may cause feedback to be skipped to protect the Taptic Engine.

Cold-restart + rapid succession is the worst case. The haptic subsystem rate-limits, the main thread spends time allocating + tearing down generators, and UIKit's `.touchDown` dispatcher (the event hooked at [`KeyboardView.swift:654`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L654)) falls behind. UIKit then **coalesces / drops intermediate touch events** — exactly the "middle key missed" the user is seeing.

So a *single* defect produces both reported symptoms.

### Cause B — The 5-step "vibration strength" selector collapses into only 3 actual intensities

[`LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift:60`](../LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift#L60)

```swift
private let vibLevelOptions = [10, 20, 40, 60, 80]
private let vibLevelLabels  = ["特弱", "弱", "中", "強", "特強"]
```

The mapping at [`KeyboardView.swift:184-188`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L184-L188):

| Setting value | UI label | `UIImpactFeedbackGenerator.FeedbackStyle` |
| --- | --- | --- |
| 10 | 特弱 | `.light` |
| 20 | 弱   | `.light` ← duplicate |
| 40 | 中   | `.medium` |
| 60 | 強   | `.heavy` |
| 80 | 特強 | `.heavy` ← duplicate |

So even the lowest setting ("特弱") still produces `UIImpactFeedbackGenerator(style: .light)`. `.light` is designed for UI affordances such as a slider tick or a "card selected" cue — it is **stronger and longer** than the haptic Apple uses on the system keyboard. The system keyboard uses a private CoreHaptics pattern shorter than any `UIImpactFeedbackGenerator` style.

Available softer alternatives:

- `UIImpactFeedbackGenerator(style: .soft)` — iOS 13+, noticeably softer than `.light`.
- `UISelectionFeedbackGenerator()` — the subtlest tick in the public API; designed for "selection changed". Closest in feel to the stock keyboard.

## Fix plan

### Step 1 — Hold one generator, prepare it, and reuse

Replace the computed `impactFeedback` in all three files with a stored generator pool that rebuilds **only when `vibrateLevel` changes**, and that is `prepare()`-warmed.

Pseudocode for [`KeyboardView.swift`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift):

```swift
// Owns one generator. Rebuilt only when vibrateLevel changes.
private var hapticGenerator: UIFeedbackGenerator?

var vibrateLevel: Int = 40 {
    didSet {
        guard oldValue != vibrateLevel else { return }
        rebuildHapticGenerator()
    }
}

private func rebuildHapticGenerator() {
    hapticGenerator = makeHapticGenerator(for: vibrateLevel)
    hapticGenerator?.prepare()        // warm engine for first press
}

private func makeHapticGenerator(for level: Int) -> UIFeedbackGenerator {
    switch level {
    case ..<15:  return UISelectionFeedbackGenerator()
    case ..<30:  return UIImpactFeedbackGenerator(style: .soft)
    case ..<50:  return UIImpactFeedbackGenerator(style: .light)
    case ..<70:  return UIImpactFeedbackGenerator(style: .medium)
    default:     return UIImpactFeedbackGenerator(style: .heavy)
    }
}

@inline(__always)
private func fireHaptic() {
    guard feedbackVibration, let gen = hapticGenerator else { return }
    if let impact = gen as? UIImpactFeedbackGenerator { impact.impactOccurred() }
    else if let sel = gen as? UISelectionFeedbackGenerator { sel.selectionChanged() }
    gen.prepare()                     // re-warm for the next press
}
```

Call `fireHaptic()` instead of `impactFeedback.impactOccurred()` everywhere it currently fires.

The same pattern goes into [`CandidateBarView.swift`](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift#L93-L101) and `fireHapticIfEnabled()` in [`KeyboardViewController.swift`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1770-L1779). The controller version also needs a `prepareHapticGenerator()` invocation when the keyboard appears (e.g. at the end of `viewWillAppear` or `applyPreferences()`), so the very first keypress is already warm.

### Step 2 — Re-map the 5 strength levels to 5 distinct intensities

Update the mapping in `makeHapticGenerator(for:)` (above) so each label is actually different:

| Value | UI label | New generator |
| --- | --- | --- |
| 10 | 特弱 | `UISelectionFeedbackGenerator()` |
| 20 | 弱   | `UIImpactFeedbackGenerator(style: .soft)` |
| 40 | 中   | `UIImpactFeedbackGenerator(style: .light)` |
| 60 | 強   | `UIImpactFeedbackGenerator(style: .medium)` |
| 80 | 特強 | `UIImpactFeedbackGenerator(style: .heavy)` |

This makes "特弱" feel close to the iOS system keyboard, gives "弱" a softer-than-light option, and preserves the existing feel of "中/強/特強" by shifting them up only one step (the previous duplication at the top end is removed).

### Step 3 — Belt-and-suspenders rate limit

Even after Step 1, fast burst typing can exceed the Taptic Engine's safe rate. Add a tiny throttle:

```swift
private var lastHapticAt: CFTimeInterval = 0
private let minHapticInterval: CFTimeInterval = 0.025   // 25 ms == 40 Hz ceiling

private func fireHaptic() {
    guard feedbackVibration, let gen = hapticGenerator else { return }
    let now = CACurrentMediaTime()
    guard now - lastHapticAt >= minHapticInterval else { return }
    lastHapticAt = now
    // … as above
}
```

25 ms is well below the perceptual threshold for "missing" a haptic cue, but it caps the worst-case rate that previously fed the touch-dispatch starvation.

## Expected outcome after fix

- **Perceived pulse length matches the iOS system keyboard.** Step 1 removes the cold-start latency; Step 2 makes the lowest setting use `UISelectionFeedbackGenerator`, which is the closest public-API match to Apple's keyboard tick.
- **No more dropped keys during fast typing.** Step 1 removes the per-press allocation cost; Step 3 caps the worst-case rate.
- **5 settings now feel like 5 settings**, not 3.

## Verification plan

1. Manual: type the same rapid burst (e.g. "asdfghjkl" repeated) on the iOS Simulator and a physical iPhone, with haptic OFF and with each of the 5 strength settings. Compare against the iOS built-in keyboard for both feel and dropped-key count.
2. Set a one-line `os_log` at the top of `fireHaptic()` and at the top of `keyDown(_:event:)` to confirm every `.touchDown` lands in `keyDown` (i.e. UIKit didn't drop it) during a fast burst.
3. Use Instruments → Time Profiler on the keyboard extension during a typing burst — confirm the main thread is no longer spending non-trivial time inside `UIImpactFeedbackGenerator.init`.

## Open question (for confirmation before implementing)

Should the 5-step mapping in Step 2 be the suggested "shift everything down a notch" (so "中" becomes `.light`, currently `.medium`), or should "中" stay at `.medium` and only the new "特弱"/"弱" tiers be added below? The former more closely matches Apple's keyboard at the *default* level; the latter is conservative — users who picked "中" today keep the same feel.
