# #65 — Android assoc/related add-entry dialog covered by soft keyboard

Issue: https://github.com/lime-ime/limeime/issues/65

## Type
Usability / UX bug (dialog layout + IME insets).

## Problem statement
In the assoc/related table editor, the **Add entry** dialog is bottom-anchored and becomes mostly hidden behind the soft keyboard when an input field is focused.

## Likely root cause
The dialog/sheet content is not handling IME insets (keyboard height) and/or not scrollable, so the focused field and action button(s) fall under the keyboard.

## Proposed fix
- Convert the dialog to a `BottomSheetDialogFragment` (if not already), or ensure the existing bottom sheet uses:
  - `WindowInsetsCompat.Type.ime()` + `systemBars()` padding,
  - scrollable content (`NestedScrollView` / `RecyclerView`),
  - `adjustResize`-compatible behavior.
- Ensure the primary action button stays visible (e.g. pinned within a container that applies insets).

## Verification plan
- Open assoc/related editor → tap `+` → focus each field.
- Confirm all fields and the submit action remain visible above the keyboard.
- Repeat on gesture nav + 3-button nav, and on at least one physical device.
