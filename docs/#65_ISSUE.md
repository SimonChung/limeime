# #65 — Android table-editor add/edit sheets covered by soft keyboard

Issue: https://github.com/lime-ime/limeime/issues/65

## Type
Usability / UX bug (dialog layout + IME insets).

## Problem statement
In the assoc/related table editor, the **Add entry** dialog is bottom-anchored and becomes mostly hidden behind the soft keyboard when an input field is focused.

The same layout pattern is used by the IM table editor **Add** and **Edit** sheets, and by the related/assoc **Edit** sheet, so the keyboard-inset fix must cover all four manage sheets:

- IM table editor add sheet
- IM table editor edit sheet
- Related/assoc add sheet
- Related/assoc edit sheet

## Likely root cause
The dialog/sheet content is not handling IME insets (keyboard height) and is not scrollable. The affected sheet layouts use a fixed `LinearLayout` root with the primary action at the bottom, so focused fields and action button(s) can fall under the keyboard.

## Proposed fix
- The dialogs are already `BottomSheetDialogFragment`s. Ensure the existing bottom sheets use:
  - `WindowInsetsCompat.Type.ime()` + `systemBars()` padding,
  - scrollable content (`NestedScrollView` / `RecyclerView`),
  - `adjustResize`-compatible behavior.
- Ensure the primary action button stays visible (e.g. pinned within a container that applies insets).

## Verification plan
- Open assoc/related editor → tap `+` → focus each field.
- Open assoc/related editor → open an existing row for edit → focus each field.
- Open an IM table editor → tap `+` → focus each field.
- Open an IM table editor → open an existing row for edit → focus each field.
- Confirm all fields and the submit action remain visible above the keyboard in each sheet.
- Repeat on gesture nav + 3-button nav, and on at least one physical device.
