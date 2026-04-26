# iOS Function-Key Split — Design Plan

**Last updated:** 2026-04-22
**Status:** proposal — awaiting trigger decision from user

---

## Context

Today palette[0] (Light) and palette[1] (Dark) render every key in one colour — the "Chinese-IME style" called out in [IOS_LIGHT_DARK.md §3/§4/§9](IOS_LIGHT_DARK.md). This was chosen against a bopomofo reference screenshot where all keys are flat white.

The user's screenshot shows the native iOS English keyboard on a **flat (non-blurred)** backdrop: letter keys white, function keys (`shift`, `backspace`, `123`, `😀`, `return`) a noticeably darker gray. The user's observation of native iOS:

- **Flat backdrop**  → function keys rendered in a distinct gray (split).
- **Blurred backdrop** → function keys the same colour as letter keys (unified).

Goal: reproduce this dual behaviour in palettes[0]/[1] without regressing palettes[2]–[5] (already opaque + split) or the bopomofo "all-white" aesthetic.

---

## What the code looks like today

Site: [KeyboardView.swift](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift)

- `KeyboardPalette` exposes `normalKey` and `modifierKey`. For palette[0]/[1] they are **identical** (see [KeyboardView.swift:31-53](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L31-L53)).
- `applyButtonStyle` at [KeyboardView.swift:603](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L603) already switches on `keyDef.isModifier` — so once the two colours differ, rows are rendered correctly automatically.
- `KeyboardView.backgroundColor = .clear` (init + `applyTheme`, [KeyboardView.swift:264, 282](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L264)) lets the `UIInputView(.keyboard)` blur show through.

So the *rendering* change is tiny: make `modifierKey` differ from `normalKey` in palettes[0]/[1] and (optionally) switch based on a runtime trigger.

---

## Proposed colour values (iOS semantic, no hex literals)

Light split (palette[0]):

| Slot | Expression | Resolved |
|---|---|---|
| `normalKey` (letter) | `iosLight(.systemBackground)` | `#FFFFFF` |
| `modifierKey` (function) | `iosLight(.systemGray3)` | `#C7C7CC` |
| `pressedKey` | `iosLight(.systemGray5)` | `#E5E5EA` (unchanged) |

Dark split (palette[1]):

| Slot | Expression | Resolved |
|---|---|---|
| `normalKey` (letter) | `iosDark(.systemGray4)` | `#3A3A3C` (unchanged) |
| `modifierKey` (function) | `iosDark(.systemGray2)` | `#636366` |
| `pressedKey` | `iosDark(.systemGray)` | `#8E8E93` (bumped so pressed stays lighter than function) |

These match what Apple's English keyboard uses on a flat backdrop.

---

## The one real decision: what flips the style?

We can't directly query "is the blur currently producing a flat pixel" from `UIInputViewController` — iOS doesn't expose it. We need a proxy. Three realistic options:

### Option A — Always split (recommended)

Palettes[0]/[1] always use the split colours above. When the UIInputView blur *is* showing real host content, `systemGray3` over blur reads almost the same as `systemBackground` over blur (both get tinted by the blur), so the split is subtle; on a flat backdrop the split reads clearly — matching the user's screenshot.

- **Pros:** matches native iOS English keyboard exactly; zero runtime detection; one code path.
- **Cons:** loses the explicit "all-white bopomofo" look on Chinese layouts (the split will still be visible, just subtler).

### Option B — Split only for English QWERTY layouts

Trigger by layout id: `lime_english` / `lime_english_number` / shifted variants → split; bopomofo / cj / array / etc. → unified.

- **Pros:** preserves bopomofo unified look; English layout matches native.
- **Cons:** two styles of chrome inside one palette; jarring when switching between IM and English via the globe key.

### Option C — Runtime backdrop detection

Render a 1×1 probe, sample colour at two offsets behind the blur, compare variance; flat → split, varied → unified.

- **Pros:** exactly matches the user's mental model.
- **Cons:** fragile, expensive per layout pass, coordinate-space snapshot APIs are restricted inside keyboard extensions, breaks WYSIWYG across host apps.

**Recommendation: Option A.** The colour math under the blur is forgiving enough that the split looks right in both conditions — native iOS uses the same approach for its English keyboard and it doesn't feel out of place on Chinese layouts.

---

## Implementation (assuming Option A)

Single file: [LimeIME-iOS/LimeKeyboard/KeyboardView.swift](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift)

1. Palette[0] at [KeyboardView.swift:31-41](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L31-L41):
   - `modifierKey: iosLight(.systemGray3)` (was `.systemBackground`).
2. Palette[1] at [KeyboardView.swift:43-53](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L43-L53):
   - `modifierKey: iosDark(.systemGray2)` (was `.systemGray4`).
   - `pressedKey: iosDark(.systemGray)` (was `.systemGray2`) so the pressed-state still reads lighter than the function key baseline.
3. No other code changes. `applyButtonStyle`, `keyUp`, `SpaceKeyButton.restoreColor` already branch on `isModifier` / `normalKey` correctly.
4. Update [IOS_LIGHT_DARK.md §3/§4/§9](IOS_LIGHT_DARK.md) so the tables and the "no modifier/letter split" note reflect the new values.

No changes needed in [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) or [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) — they don't paint function keys.

---

## Verification

1. Build `LimeKeyboard` on iPhone 15 simulator (iOS 17/18).
2. Light system, palette[0], English QWERTY: shift/backspace/123/😀/return render as a flat mid-gray; letter keys white; space key white. Compare side-by-side with native iOS English keyboard — should be indistinguishable.
3. Light system, palette[0], bopomofo: function keys still subtly darker; letter keys unchanged.
4. Dark system, palette[1]: function keys lighter than letter keys by one step.
5. Press a function key → pressed-state colour still reads as "lighter than the resting function-key colour" (not the reverse).
6. Palettes[2]–[5]: unchanged.
7. `LimeTests` scheme passes.

---

## If Option A is rejected

- **Option B** adds ~10 lines: `KeyboardView` picks a secondary "unified" palette when `layout.id.hasPrefix("lime_english") == false`. Rebuild on `setLayout`.
- **Option C** requires a new `BackdropSampler` utility, a `CADisplayLink`-driven re-probe, and graceful fallback when snapshotting fails. Meaningfully larger scope.
