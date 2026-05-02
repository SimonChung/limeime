# iPad Keyboard Layout Converter — Rules

The script
[`scripts/build_ipad_layouts.py`](../scripts/build_ipad_layouts.py)
generates the `*_ipad.json` keyboard layouts under
[`LimeIME-iOS/LimeKeyboard/Layouts/`](../LimeIME-iOS/LimeKeyboard/Layouts)
from their phone equivalents. This document captures the rules the
script applies so that a future tweak (or hand-edited layout) can be
reasoned about without reverse-engineering the code each time.

Run from the repo root:

```bash
python3 scripts/build_ipad_layouts.py
```

Output: every JSON file listed in `JOBS` is regenerated under
`LimeIME-iOS/LimeKeyboard/Layouts/` with the `_ipad.json` suffix.
Existing files are overwritten.

---

## 1. Output file conventions

| Field | Value | Notes |
|---|---|---|
| `id` | source `id` + `"_ipad"` | The runtime layout-loader looks for the `_ipad` variant first when running on an iPad host. |
| `defaultWidthPercent` | `7.0` | A safety fallback; every generated key supplies its own `widthPercent`. |
| `rows` | transformed per §3–§4 | |

Each `*_ipad.json` is written with `indent=2`, `ensure_ascii=False`, and
a trailing newline. UTF-8 (no BOM) is the only acceptable encoding.

---

## 2. Layout categories

This script handles **IM layouts only**. English, symbol, and number layouts
(`lime_abc`, `lime_english*`, `lime_email`, `lime_url`, `lime_number`,
`lime_shift`, `symbols1/2/3`) are maintained separately and must not be
added to `JOBS`.

Full per-row transform pipeline applied to all of:

```
lime_phonetic, lime_phonetic_shift
lime_array, lime_array_shift
lime_array_number, lime_array_number_shift
lime_cj, lime_cj_shift
lime_cj_number, lime_cj_number_shift
lime_dayi, lime_dayi_shift
lime_dayi_sym, lime_dayi_sym_shift
lime_et26, lime_et26_shift
lime_et_41, lime_et_41_shift
lime_ez, lime_ez_shift
lime_hs, lime_hs_shift
lime_hsu, lime_hsu_shift
lime_wb, lime_wb_shift
```

---

## 3. Bottom row — always replaced with `IPAD_BOTTOM_ROW`

For **every** layout, every row marked `isBottomRow: true` is replaced
wholesale with the standard iPad bottom row:

| Position | Code | Label / Icon | Width % | Notes |
|---|---|---|---|---|
| 1 | `-200` | `globe` icon | 8.0 | Globe / IM switcher; longPress=-100 (options menu) |
| 2 | `-2` | `@string/label_symbol_key` | 10.0 | Switch to symbols |
| 3 | `-99` | `mic` icon | 7.0 | Voice input |
| 4 | `32` | `space.bar` icon | 57.0 | Space (repeatable) |
| 5 | `-2` | `@string/label_symbol_key` | 10.0 | Symbols mirror (right side) |
| 6 | `-3` | `keyboard.chevron.compact.down` icon | 8.0 | Dismiss; longPress=-100 |

Total: 8+10+7+57+10+8 = 100%.

`；\n：` was moved off the bottom row onto the asdf row (see §4a) to give
the space bar more width. **All layouts share the same bottom row** — there
is no per-layout customization of `IPAD_BOTTOM_ROW`.

`lime_wb` special case: the source content row contains a `-2` (123/symbol
shortcut). On iPad that key is replaced with `abc (-9)` in the content row so
users can return to alphabetic mode directly. The bottom row stays standard.

---

## 4. IM layout transforms

All IM layouts run through the same per-row pipeline. The `has_digit_row`
flag (derived at runtime from whether any content row is a 1–0 digit row
or !@#… symbol-shift row) controls only the qwerty row rightmost key.

| Source row | iPad transform applied |
|---|---|
| Digit row (1–0) | `augment_im_digit_row` |
| Qwerty row (ends with p/P) | `transform_qwerty_row` |
| Asdf row (ends with ;/:/l/L) | `prepend_abc_modifier` → `append_semicolon_key` → `append_fullshape_period` → `append_enter_key` |
| Zxcv row (contains z/Z) | `ensure_zxcv_shifts` → `apply_zxcv_punct_sliding` |

Each transform is **self-gating** — it detects its target row by code
pattern and is a no-op on all other rows. All rows then pass through
`normalize_im_row_widths`.

No-digit layouts (lime_array, lime_cj family) have no `isBottomRow` source
row; `IPAD_BOTTOM_ROW` is appended unconditionally after the loop.

Each transform is **self-gating** — it detects its target row by code
pattern and is a no-op on all other rows. All rows then pass through
`normalize_im_row_widths`.

#### Key width convention

| Key type | Width |
|---|---|
| Printable character (code ≥ 33, not a modifier) | exactly **7.0%** |
| Function / modifier key (shift, delete, Tab, abc, Enter, …) | **(100 − N×7) / F** — remaining space shared equally among the F function keys in the row |
| Overflow row (N×7 > 100%) | all keys share **100/total** equally |

`lime_wb` is the only exception: it has very few keys per row, so all
keys are scaled proportionally with `scale_row_to_100` instead.

---

#### Digit row — `augment_im_digit_row`

**Detects**: primary codes 48 (0) and 49 (1) both present.

Result depends on whether the source layout contains `-` (code 45) and `=` (code 61) keys.

Right of `0` — one of:
- Source `-` key (phonetic-style, `digit_dash ≠ None`)
- `"…\\n—"` fallback (no `-` in layout at all)
- Nothing (hs-style: `-` goes to zxcv row)

Left of ⌫ — one of:
- Source `=` key (layout has `=`)
- `"+\\n="` fallback (primary 61, longPress 43) when layout has no `=`

| Added / modified key | Code | Label | longPressCode | Position |
|---|---|---|---|---|
| Backtick/tilde prefix | 96 | `"~\\n`"` | 126 (tilde) | Prepended (left of 1) |
| Digit keys 1–0 (no sublabel) | 49–48 | `"!\\n1"` … `")\\n0"` | 33–41 | In-place — labels rewritten to symbol-on-top dual-slide |
| Digit keys 1–0 (has sublabel) | 49–48 | unchanged | 0 | IM-component sublabels (phonetic, dayi …) are preserved as-is |
| Harvested dash (no sublabel) | 45 | `"_\\n-"` | 95 (`_`) | Right of 0; phonetic-style only |
| Harvested dash (has sublabel) | 45 | source label | — | Right of 0; phonetic-style only |
| Em-dash/ellipsis fallback | 8212 | `"…\\n—"` | 8230 | Right of 0; only when layout has **no** `-` key at all |
| Harvested equals (no sublabel) | 61 | `"+\\n="` | 43 (`+`) | Left of ⌫; only when layout has `=` |
| Harvested equals (has sublabel) | 61 | source label | — | Left of ⌫; only when layout has `=` |
| Plus/equals fallback | 61 | `"+\\n="` | 43 (`+`) | Left of ⌫; only when layout has **no** `=` key |
| Delete | -5 | `delete.backward` icon | 0 | Appended (rightmost) |

---

#### Qwerty row — `transform_qwerty_row`

**Detects**: last primary code ∈ {112 (`p`), 80 (`P`)}.

Source keys `[` (91), `\` (92), `]` (93) are **moved** here if present in the layout
(stripped from other rows by `strip_promoted_keys`); CJK sliders are used as fallbacks.

The rightmost key depends on `has_digit_row`:

| Position | `has_digit_row=True` (source key / fallback) | `has_digit_row=False` |
|---|---|---|
| Leftmost (position 0) | Tab (9, always) | Tab (9, always) |
| Right of p | `[` (91) → `{\\n[` (longPress 123) if no sublabel, else `『\\n「` (12300, longPress 12302) | same |
| Right of `[` | `]` (93) → `}\\n]` (longPress 125) if no sublabel, else `』\\n」` (12301, longPress 12303) | same |
| Rightmost | `\` (92) → `\|\\n\` (longPress 124) if no sublabel, else `\|\\n、` (12289, longPress 124) | ⌫ (delete, code -5) |

---

#### Asdf row — four sequential transforms

**Detects** (all four): last primary code ∈ {59 (`;`), 108 (`l`), 76 (`L`)}.

1. `prepend_abc_modifier`: prepend `abc` key (code -9) at the left.
2. `append_semicolon_key`: add `；\n：` right of the last letter key.
   - Source `;` (59) **without sublabel** → upgraded in-place to full-shape `；\n：` (65306 tap, 65307 long-press).
   - Source `;` (59) **with sublabel** (IM component, e.g. phonetic `ㄤ`, array `0−`) → left unchanged; no extra key added.
   - **No `;` in the row** (last ∈ {108, 76}) → full-shape `；\n：` appended as fallback.
3. `append_fullshape_period`: detects last code ∈ {59, 65306, 108, 76}, appends `。\n，` (65292, longPress 12290).
4. `append_enter_key`: detects last code = 65292 (just added), appends Enter (code 10, icon `return`).

Result for layouts whose `;` has no sublabel (lime_hs and similar):
`abc | a…l ；\n：| 。\n，| ↩`

Result for layouts with no `;` (lime_hsu, lime_et26, lime_cj_number):
`abc | a…l ；\n：| 。\n，| ↩`

Result for layouts whose `;` is an IM component (lime_phonetic, lime_array):
`abc | a…l ;(sublabel) | 。\n，| ↩`  (full-shape ；\n：not added)

---

#### Zxcv row — `ensure_zxcv_shifts` → `apply_zxcv_punct_sliding`

**Detects**: primary codes include z (122) or Z (90).

`ensure_zxcv_shifts` steps applied in order:
1. Remove trailing delete (-5) if present.
2. Append promoted bottom-row symbols at 7% each (see §4a symbol promotion below).
3. Ensure shift (-1, icon `shift`, isSticky=true) at the **leading** position (prepend if absent).
4. Ensure shift (-1) at the **trailing** position (append if absent).

`apply_zxcv_punct_sliding` runs after `ensure_zxcv_shifts` and upgrades `,`, `.`, `/`
keys in the zxcv row to dual-slide when they carry no sublabel (promoted bottom-row
punctuation in hs-style layouts). Keys with IM sublabels (phonetic `ㄝ/ㄡ/ㄥ`,
et_41 `ㄓ/ㄔ/ㄕ`, ez full-shape) are left unchanged.

| Key | Code | Upgraded label | longPressCode |
|---|---|---|---|
| `,` (no sublabel) | 44 | `<\n,` | 60 (`<`) |
| `.` (no sublabel) | 46 | `>\n.` | 62 (`>`) |
| `/` (no sublabel) | 47 | `?\n/` | 63 (`?`) |

#### Bottom-row symbol promotion

`-` (45), `=` (61), `[` (91), `\` (92), and `]` (93) are **always** moved to fixed iPad rows and are never promoted to the zxcv row, regardless of layout style.

When the source zxcv row ends with delete (-5) (`source_zxcv_ends_with_delete` = True):
→ All printable keys from the phone bottom row **except** `-`, `=`, `[`, `\`, `]` are promoted to the zxcv row.
This covers layouts like lime_hs (which keeps -, =, ., ,, ', / in its bottom row);
only `.`, `,`, `'`, `/` go to zxcv — `-` and `=` go to the digit row.

When the source zxcv row does NOT end with delete (-5):
→ No extra symbols are promoted to zxcv (phonetic-style layouts already have their
  symbols in the source zxcv row). `-` and `=` still move to the digit row.

---

---

## 5. Per-key normalisation

`normalise_key(key)` runs on every key in every kept row. It guarantees:

| Field | Default if missing |
|---|---|
| `popupCharacters` | `""` |
| `longPressCode` | `0` |

`IPAD_BOTTOM_ROW` is a pre-normalised literal and does not go through
`normalise_key`.

---

## 6. Row width normalisation

`normalize_im_row_widths(row)` is called on every IM content row after all
transforms are applied:

1. Every printable key (code ≥ 33, not a modifier code) is set to exactly **7.0%**.
2. Function/modifier keys share the remaining `100 − N×7` percent equally.
3. **Overflow fallback**: if N×7 > 100 (e.g. lime_hs zxcv row with many promoted symbols), all keys share 100/total% equally instead.
4. The last key in the row absorbs any floating-point residual so the row sums to exactly 100.

`lime_wb` exception: uses `scale_row_to_100` (proportional scaling) because it
has very few keys per row and fixed 7% produces disproportionate results.

`IPAD_BOTTOM_ROW` is a pre-sized literal and is never passed through either function.

---

## 7. Transform pipeline summary

```text
For each source layout in JOBS:

    content_rows = non-bottom rows
    has_digit_row = any row matches digit (1–0) or symbol-shift (!@#…) detection

    bottom_syms = harvest_bottom_row_symbols(...)
    had_bottom_row = False

    For each row:
        If isBottomRow: replace with IPAD_BOTTOM_ROW; had_bottom_row = True
        Else:
            strip_promoted_keys
            normalise_key each key
            augment_im_digit_row        (digit row only — no-op when has_digit_row=False)
            transform_qwerty_row        (qwerty row only; rightmost = ⌫ when has_digit_row=False)
            prepend_abc_modifier        (asdf row only)
            append_semicolon_key        (asdf row only)
            append_fullshape_period     (asdf row only)
            append_enter_key            (asdf row only)
            ensure_zxcv_shifts          (zxcv row only)
            apply_zxcv_punct_sliding    (zxcv row only)
            normalize_im_row_widths  (scale_row_to_100 for lime_wb)

    If not had_bottom_row: append IPAD_BOTTOM_ROW

    id = source_id[:-6] + "_ipad_shift"  if source ends with "_shift"
       = source_id + "_ipad"             otherwise
```

---

## 8. JOBS list — what gets generated

26 IM layout files (13 layouts × 2 variants each). Full list in `JOBS` at
the bottom of
[`scripts/build_ipad_layouts.py`](../scripts/build_ipad_layouts.py).

**English, symbol, and number layouts are not generated here** — maintain
their `_ipad.json` files separately.

To add a new IM phone layout:

1. Add a `(source_stem, output_stem)` tuple to `JOBS`.
2. Add the source stem to `IM_LAYOUTS`.
3. Re-run the script.
4. Re-run the Xcode build so the new `_ipad.json` is bundled.

---

## 9. Invariants the converter maintains

1. Every output row sums to exactly 100% (after rounding fix-up).
2. Every key has every field the runtime decoder expects.
3. Every layout's bottom row is exactly `IPAD_BOTTOM_ROW` — globe / .?123 / mic / space(57%) / .?123 / dismiss. No per-layout customization.
4. All IM layouts have Tab at position 0 of the qwerty row; `[`/`『\n「` + `]`/`』\n」` at positions −3/−2; rightmost is `\`/`|\n、` when `has_digit_row=True`, or ⌫ when `has_digit_row=False`.
5. All IM layouts have abc modifier, `；\n：` (or source `;` with IM sublabel), `。\n，`, and Enter on the asdf row.
6. All IM layouts have shifts on both sides of the zxcv row.
7. `,` `.` `/` keys in the zxcv row without IM sublabels get dual-slide labels `<\n,` `>\n.` `?\n/`.
8. Printable keys are exactly 7% wide; function keys share the remaining width (lime_wb uses proportional scaling instead).
9. Output `id` is `source_id + "_ipad"` for base layouts, `base + "_ipad_shift"` for shift variants.
10. English, symbol, and number `_ipad.json` files are never written by this script.
