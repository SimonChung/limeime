# HS Keyboard Layout Issue

Status: Fixed in layout data; focused Android and iOS layout tests pass.
Scope: Android + iOS HS / 華象直覺 keyboard layouts.

---

## 1. Symptom

The HS (`lime_hs`) unshifted keyboard layout appears to be shifted:

- Unshifted HS shows uppercase Latin letter keys.
- Shifted HS shows lowercase Latin letter keys.
- This affects Android XML layouts and iOS JSON layouts, including iPad variants.

This is likely a long-standing data issue in the layout files, not a runtime
shift-state bug.

---

## 2. Verified Evidence

### Android

Unshifted Android layout:

- `LimeStudio/app/src/main/res/xml/lime_hs.xml`
- Letter keys use uppercase ASCII codes and uppercase labels:
  - `Q` = `81`
  - `A` = `65`
  - `Z` = `90`

Shifted Android layout:

- `LimeStudio/app/src/main/res/xml/lime_hs_shift.xml`
- Letter keys use lowercase ASCII codes and lowercase labels:
  - `q` = `113`
  - `a` = `97`
  - `z` = `122`

So the Android files are inverted relative to normal keyboard convention.

### iOS Phone

Unshifted iOS layout:

- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs.json`
- Letter keys use uppercase ASCII codes and uppercase labels.

Shifted iOS layout:

- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_shift.json`
- Letter keys use lowercase ASCII codes with uppercase visual labels.

The shifted iOS visual labels are uppercase, but the emitted key codes are
lowercase, so the data still follows the same inversion pattern.

### iOS iPad

The iPad variants mirror the same issue:

- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_ipad.json`
  - letter key codes are uppercase (`Q` = `81`, etc.).
- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_ipad_shift.json`
  - letter key codes are lowercase (`q` = `113`, etc.).

---

## 3. Root Cause

The HS layout source data is inverted:

- `lime_hs*` unshifted files use uppercase key codes.
- `lime_hs*_shift` shifted files use lowercase key codes.

This is not caused by runtime shift handling. The key definitions themselves
are wrong before Android or iOS event handling sees them.

Candidate lookup may partially survive because both Android and iOS lowercase
query codes before database lookup, but the composing buffer, visual state, and
shift semantics remain wrong.

---

## 4. Proposed Fix

Normalize HS to match the rest of the keyboard family:

- Unshifted `lime_hs` layouts should emit lowercase Latin letters.
- Shifted `lime_hs_shift` layouts should emit uppercase Latin letters.
- Keep non-letter HS root keys (`0-9`, punctuation, brackets, space, return,
  delete, mode-switch keys) unchanged unless verification finds a separate bug.

Files to update:

- `LimeStudio/app/src/main/res/xml/lime_hs.xml`
- `LimeStudio/app/src/main/res/xml/lime_hs_shift.xml`
- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs.json`
- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_shift.json`
- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_ipad.json`
- `LimeIME-iOS/LimeKeyboard/Layouts/lime_hs_ipad_shift.json`

---

## 5. Plan TODO

- [x] Add or run a layout consistency check that asserts unshifted HS letter
      codes/labels are lowercase and shifted HS letter codes/labels are uppercase.
- [x] Fix Android HS XML letter codes and labels.
- [x] Fix iOS HS phone JSON letter codes and labels.
- [x] Fix iOS HS iPad JSON letter codes and labels.
- [ ] Verify HS typing on Android: unshifted letters compose lowercase roots;
      shifted letters compose uppercase only when shift is active.
- [ ] Verify HS typing on iOS phone and iPad with touch input, not physical
      keyboard input.
- [x] Check whether any docs that currently call HS uppercase intentional
      should be updated after the layout fix lands.

---

## 6. Notes

`docs/IPAD_KEYBOARD.md` says EZ and HS are excluded from iPad layout generation.
Do not regenerate HS iPad layouts through the iPad generator unless that rule is
explicitly changed. Fix the existing HS files directly or use a narrowly scoped
script that only transforms HS letter code case.
