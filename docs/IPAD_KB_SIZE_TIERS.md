# IPAD_KB_SIZE_TIERS — Per-size iPad keyboard tiers (13" / 11" / 7")

Status: PLAN — not yet implemented

Sibling docs:

- [`IPAD_KEYBOARD.md`](IPAD_KEYBOARD.md) — current iPad layout (13" only).
- [`IPAD_KB_LAYOUT_COVERTER.md`](IPAD_KB_LAYOUT_COVERTER.md) — `scripts/build_ipad_layouts.py` rules.

This document is additive: the 13" plan stands. This plan adds two
smaller tiers (iPad 11" and iPad mini) on top of it.

---

## 1. Goal

Today's `_ipad.json` files render correctly on the iPad 13" (12.9") but
the cells are visibly **too tall** on iPad 11" and especially on iPad
mini, because the same dimension constants and the same 14-cell layouts
are used on much narrower screens.

The user-facing requirement:

1. **5 rows on every iPad tier, every layout.** Apple drops to 4 rows
   on smaller iPads but that surrenders the dedicated digit row, which
   is daily-driver value for Chinese IMs that use 40+ root keys
   (Dayi, ET41).
2. **Cells must stay close to square** — not "tall" — on every tier.
   This is the actual readability constraint, more important than
   matching a specific cell count.
3. **Phone behavior bit-for-bit unchanged.** **iPad 13" behavior
   bit-for-bit unchanged** (today's shipped layout = the new `large`
   tier).
4. **No 4-row variant.** No layout family is dropped; user keeps the
   IM they have.

---

## 2. The square-cell invariant

Cell width on iPad is fundamentally tied to screen width:

```
cell_width = (printable_target / 100) × screen_width
```

With a fixed `printable_target = 7%` (see §7 for why), cell widths come
out to:

| Device | Screen width (portrait) | 7% cell width |
|---|---|---|
| iPad 13" / Pro 12.9" / Air 13" | 1024 pt | **71.7 pt** |
| iPad 11" / Pro 11 / Air 11 | 834 pt | **58.4 pt** |
| iPad mini | 744 pt | **52.1 pt** |

For cells to be **square**, `row_height ≈ cell_width`. So row height
**must be tied to screen width per tier**:

| Tier | Row height (portrait) | Resulting cell aspect |
|---|---|---|
| `.large` (iPad 13") | 72 pt | 71.7 / 72 ≈ 1.00 |
| `.medium` (iPad 11") | 58 pt | 58.4 / 58 ≈ 1.01 |
| `.small` (iPad mini) | 52 pt | 52.1 / 52 ≈ 1.00 |

**This invariant works regardless of cell count.** A 14-cell EZ row on
iPad mini gets 52×52 pt cells. An 11-cell English row on iPad mini gets
67.6×52 pt cells (wider, more comfortable). Both are usable.

Aspect ratio is solved structurally by row height, **not by trimming
cells**. Cell-count trimming becomes secondary — we trim only when it
is "free" (root-protected scaffolding cells exist), to keep modifier
widths reasonable, not to chase a specific count.

---

## 3. Three device tiers — but only for dimensions, not layouts

```swift
enum IPadSizeClass {
    case large    // SSE >= 870pt — iPad 13" / iPad Pro 12.9" / iPad Air 13"
    case medium   // 750–869pt    — iPad 11" (Pro / Air / 11)
    case small    // < 750pt      — iPad mini
}
```

Detected once per layout-rebuild from `min(screen.width, screen.height)`
(orientation-stable). Re-evaluated in `viewWillLayoutSubviews` and
`traitCollectionDidChange`. Cached on `LayoutLoader.iPadSizeClass`.

Phone path is unchanged. iPad 13" path is unchanged (`.large` returns
today's values).

---

## 4. Layout-file strategy: TWO variants, not three

Three tiers do **not** require three sets of layout files. The layout
variants are:

```
phone JSON
   │
   ▼  scripts/build_ipad_layouts.py    (existing — Chinese IMs only, 13" tier)
*_ipad.json                            (full tier — used by .large only)
   │
   ▼  scripts/trim_ipad_layout.py      (new — single trim ruleset)
*_ipad_narrow.json                    (narrow tier — used by both .medium and .small)
```

`LayoutLoader` fall-through:

```
.small  → _ipad_narrow → _ipad → bare
.medium → _ipad_narrow → _ipad → bare
.large  → _ipad → bare
phone   → bare
```

A narrow file is **optional** — layouts without one fall through to
the full `_ipad.json`. Cache key includes the resolved file name so a
phone-side cache entry can never leak.

`prefetchCommonLayouts()` should also try the narrow variant when
running on `.medium` or `.small`.

The fact that `.medium` and `.small` share the same layout file doesn't
mean they look identical: their `KeyboardView` dimension constants
differ (§5), so the narrow layout renders at 58×58 pt cells on iPad 11"
and at 52×52 pt cells on iPad mini.

---

## 5. KeyboardView / CandidateBarView dimension constants

`KeyboardView`, `CandidateBarView`, and the parts of
`KeyboardViewController` that read those constants are rewritten so each
constant is a 4-tuple `(phone, padSmall, padMedium, padLarge)` resolved
through one `IPadSizeClass.current`-aware getter.

Per-tier values (portrait — landscape resolves to the same values):

| Constant | phone | small (mini) | medium (11") | large (13") |
|---|---|---|---|---|
| `rowHeightPortrait` | 50 | **52** | **58** | **72** |
| `bottomRowHeightPortrait` | 54 | 56 | 62 | 76 |
| `keyHGap` / `keyVGap` | 5 / 2 | 5 / 3 | 6 / 3 | 7 / 4 |
| `keyCornerRadius` | 6 | 6 | 7 | 8 |
| `keySingleLabelFont` (regular) | 22 | 21 | 22 | 24 |
| `keyLabelFont` (light) | 16 | 18 | 19 | 20 |
| `keySublabelFont` (regular) | 22 | 21 | 22 | 24 |
| `baseCandidateFontSize` | 22 | 26 | 28 | 30 |
| `baseComposingCodeFontSize` | 16 | 19 | 21 | 22 |
| `candidateHPad` | 10 | 12 | 14 | 16 |
| Candidate-bar height anchor | 42 | 50 | 54 | 60 |

The row-height values for iPad tiers are calibrated to the §2 invariant
(row height ≈ 7% × screen width).

**`idiomMultiplier` is deleted** — it was the prior phone × 1.5 hack and
would compound with these.

User preferences still apply on top:

- `keySizeScale` (0.8–1.2) multiplies the resolved row height.
- `font_size` pref multiplies label fonts via `fontScale`.

---

## 6. The trim ruleset (single configuration, produces `_narrow`)

`scripts/trim_ipad_layout.py` is a separate ~150-line script. It does
**not** extend `build_ipad_layouts.py`. It walks finished `_ipad.json`
files and emits `_ipad_narrow.json` siblings.

The trimmer is layout-family-agnostic. Same code path runs over Chinese
IM, English/ABC, and symbols layouts — what differs per layout is the
IM root set (§6.2).

### 6.1 The trim predicate

A cell is **trimmable** iff ALL of these hold:

1. Its `code` is positive (`> 0` — not a modifier like -1, -5, -9, -200).
2. `chr(code).lower()` is **not** in the layout's IM root set
   (case-folded so HS uppercase letters match).
3. Its `label` contains `\n` (the dual-slide form). Single-glyph labels
   are never scaffolding.
4. Its `popupKeyboard` is empty.

### 6.2 IM root sets

Verbatim from `LimeDB.swift` constants (Chinese IMs hard-coded), plus
three derived from per-IM `Database/<im>.db` SQLite seeds for `ez` /
`hs` / `wb` (frozen here so the trimmer never opens a DB):

```python
IM_ROOTS = {
    "lime_phonetic":      "1qaz2wsx3edc4rfv5tgb6yhn7ujm8ik,9ol.0p;/-",
    "lime_cj":            "qwertyuiopasdfghjklzxcvbnm",
    "lime_cj_number":     "qwertyuiopasdfghjklzxcvbnm",
    "lime_dayi":          "1234567890qwertyuiopasdfghjkl;zxcvbnm,./",
    "lime_dayi_sym":      "1234567890qwertyuiopasdfghjkl;zxcvbnm,./",
    "lime_array":         "qazwsxedcrfvtgbyhnujmik,ol.p;/",
    "lime_array_number":  "qazwsxedcrfvtgbyhnujmik,ol.p;/",
    "lime_et26":          "qazwsxedcrfvtgbyhnujmikolp,.",
    "lime_et_41":         "abcdefghijklmnopqrstuvwxyz12347890-=;',./",
    "lime_hsu":           "azwsxedcrfvtgbyhnujmikolpq,.",
    "lime_wb":            ",./mn",
    # Derived from Database/{ez,hs}.db (2026-05 read):
    "lime_ez":            "',-./0123456789;=[\\]abcdefghijklmnopqrstuvwxyz",
    "lime_hs":            "',-./0123456789;=[\\]abcdefghijklmnopqrstuvwxyz",
    # Empty for non-IM layouts (English-family + symbols):
    "lime_english":       "",
    "lime_abc":           "",
    "lime_email":         "",
    "lime_url":           "",
    "lime_english_number": "",
    "lime_number":        "",
    "lime_shift":         "",
    "symbols1":           "",
    "symbols2":           "",
    "symbols3":           "",
}
```

Shift variants reuse the base IM's set (strip `_shift_ipad` to derive).

### 6.3 Row-class detection

| Row class | Detection rule |
|---|---|
| `digit` | codes 48 (`0`) AND 49 (`1`) both present, OR codes 33 (`!`) AND 41 (`)`) both present |
| `qwerty` | last printable code ∈ {112, 80} (`p` or `P`) |
| `asdf` | row contains code 10 (Enter) and is not bottom |
| `zxcv` | row contains code 122 or 90 (`z` or `Z`) |
| `bottom` | `isBottomRow == true` |
| `other` | none of the above (passed through) |

### 6.4 Per-row trim logic — replace-with-spacer in place

The trimmer **does not remove cells**. It **replaces** trimmable cells
with transparent spacer cells (`code: 0`, `label: ""`, `sublabel: ""`,
`icon: ""`, `widthPercent` unchanged) at their original positions. The
output row has the same length and the same per-cell widths as the
source — only specific cells flip to spacer mode.

This preserves:

- **Modifier widths.** `[Tab]` stays at 9%, `[abc]` at 11.5%, `[⇧]` at
  15%, `[↩]` at 11.5%, `[⌫]` at 9%. They are never inflated.
- **Letter / root widths.** Every printable cell stays at 7%.
- **Letter-block alignment.** q starts at 9% (Tab width), a starts at
  11.5% (abc width), z starts at 15% (shift width) — exactly the
  full-tier QWERTY stagger, on every iPad tier.
- **Row sums.** Each row still totals 100% — spacers have the same
  widthPercent as the cells they replace.

What changes visually: scaffolding cells become invisible blank zones.
The right edge of trimmed rows becomes "ragged" (qwerty/asdf may end
in 1–3 transparent slots before the keyboard's right edge), but
modifiers and letters never move.

| Row class | Trim action |
|---|---|
| `digit` | Two-ended walk (§ below); trimmed cells → spacer in place. |
| `bottom` | Replaced wholesale with `BOTTOM_NARROW` template (§6.6). |
| `other` | Passed through. |
| `qwerty` / `asdf` / `zxcv` | Right-tail walk; trimmed cells → spacer in place. |

**Right-tail walk** (qwerty / asdf / zxcv):

1. Identify trailing modifier (`⌫` for qwerty when no digit row, `↩`
   for asdf, right `⇧` for zxcv). Stop walks before reaching it.
2. Scan leftward from the cell before the trailing modifier.
3. While trimmable AND quota is non-zero: replace cell with spacer,
   decrement quota, advance one cell left.
4. Stop on first non-trimmable cell. Do not skip past it.

**Two-ended walk** (digit row):

1. Compute `digit_zone` = `[min_idx, max_idx]` of cells with `code` in
   48–57. The walk only touches cells **strictly outside** this zone
   so mid-zone scaffolding (e.g. ET41's `%|5` `^|6` between 1–4 and
   7–0) is preserved.
2. Identify trailing `⌫` and stop the right walk before it.
3. Left walk (cells `0` … `min_idx − 1`, L→R): replace with spacer
   while trimmable AND `digit_left` quota non-zero.
4. Right walk (cells `max_idx + 1` … last-non-modifier, R→L): replace
   with spacer while trimmable AND `digit_right` quota non-zero.

The trimmer never drops `[Tab]`, `[abc]`, or `[⇧]`. The IM-toggle key
(`[abc]` / `[中]`) is always reachable on every tier, so users can
switch to English/abc-mode the same way they do today. The `.?123`
key on the bottom row keeps its single job (toggle to symbol layout)
and is never overloaded.

### 6.5 Drop quotas

```python
DROP_QUOTA_NARROW = {
    "digit_left":  1,
    "digit_right": 2,
    "qwerty":      3,
    "asdf":        2,
    "zxcv":        1,
}
```

Quotas are **upper bounds** — the walk stops on the first
non-trimmable cell anyway, so a layout with fewer trimmable
scaffolding cells produces fewer spacer replacements.

### 6.5b Cap-overflow modifier drop (cap = 13 visible cells)

After the standard right-tail trim (§6.4), the trimmer enforces a
**hard cap of 13 visible cells per row** at narrow tier. If a row's
post-trim visible count exceeds 13, the trimmer converts the row's
**leading modifier** to a spacer to bring it down to 13:

| Row | Modifier dropped if visible > 13 |
|---|---|
| qwerty | `[Tab]` (code 9) → spacer |
| asdf | `[abc]` / `[中]` / `[EN]` (code -9) → spacer |
| zxcv | right `[⇧]` (code -1) → spacer |
| digit | (no overflow possible — digit row has at most 13 visible after the two-ended walk) |

In practice only `lime_ez` and `lime_hs` qwerty rows trigger this rule
— their root sets include all 3 brackets `[`, `]`, `\` so the standard
trim drops nothing, leaving 14 visible cells. `[Tab]` → spacer brings
each row to 13. No other IM, no other row hits the overflow.

The asdf and zxcv lines exist for forward-compatibility — if a future
IM ever ships a 14-cell asdf or 13-cell zxcv with all roots, the rule
already handles it. None of today's IMs exercise these branches.

Letter alignment is preserved: when `[Tab]` becomes a spacer at narrow
tier, the q-cell still starts at 9% (the spacer occupies Tab's slot at
its original 9% widthPercent). Same logic for `[abc]` (11.5%) and
right-`[⇧]` (15%).

### 6.6 Bottom-row template

```python
BOTTOM_FULL    = [globe(8), .?123(10), mic(7), space(57), .?123(10), dismiss(8)]    # large tier
BOTTOM_NARROW = [globe(9), .?123(11), mic(7), space(56), .?123(9),  dismiss(8)]    # narrow tier
```

The narrow bottom row keeps `[mic]` because LimeIME's mic dictation
is a frequently-used feature; users switching to a 7" iPad mini still
expect mic access. (Apple's iPad mini stock keyboard drops mic — we
deviate.) `.?123` is the symbol toggle on every tier; `[abc]` /
`[中]` on the asdf row remains the IM toggle.

### 6.7 Width preservation (no re-normalization needed)

Because spacer replacement keeps each cell's `widthPercent` unchanged,
the row already sums to 100%. **No `normalize_im_row_widths` pass is
required after trim.** Every cell — modifier, letter, IM root, or
spacer — keeps the width set in the source `_ipad.json`.

Printable cells therefore remain at exactly 7% on every tier. Cell
absolute width comes from §2 (`row_height ≈ 7% × screen_width`):

- 13" full: 7% × 1024 = 71.7pt × 72pt row height → square
- 11" narrow: 7% × 834 = 58.4pt × 58pt row height → square
- mini narrow: 7% × 744 = 52.1pt × 52pt row height → square

`lime_wb` keeps its proportional scaling (it has very few keys and
3-key rows at ~33% each — the spacer mechanism doesn't apply because
nothing is trimmable).

### 6.8 Skip-write-on-no-op

If trimming produces output byte-identical to the source (no
trimmable cells exist — e.g. `lime_wb`, `symbols1/2/3`), **don't
write the narrow file**. The fall-through in `LayoutLoader` handles
its absence. Keeps the bundle clean.

---

## 7. WB exception (no-op for the trimmer)

`lime_wb_ipad.json` has 2 content rows + bottom (3 + 4 cells, 5 stroke
keys). No cell has `\n` in its label → trim predicate matches nothing →
trimmer is a no-op at every tier.

`lime_wb_ipad_shift.json` ships an anomalous CJ-style 14/13/12 layout
that doesn't match the base. Recommend treating as opaque input and
flagging for source cleanup separately.

---

## 8. File counts

iPad ships **fewer files than today** under this plan, because the
English-family and symbol-page collapse (§A.12, §A.13) eliminates 9 of
the 23 currently-shipped `*_ipad.json` variants.

| Category | iPad files today | iPad files (this plan) | Net change |
|---|---|---|---|
| Chinese IM (`*_ipad.json`) | 24 (12 IMs × 2 with `_shift`) | 24 (unchanged) | — |
| English-family (`*_ipad.json`) | 7 hand + auto-generated | 2 (`lime_english_ipad`, `lime_abc_ipad`) | **−5 files** |
| Symbol pages (`*_ipad.json`) | 3 (`symbols1/2/3`) | 1 (`symbols1`) | **−2 files** |
| Plus `_shift` variants of the deleted English-family | ~5 | 0 | **−~5 files** |
| **Total `*_ipad.json` (large tier)** | ~33 | **~26** | **−7** |
| Narrow tier `*_ipad_narrow.json` (new, generated) | — | ~22 | **+22** |
| **Grand total iPad layout files** | ~33 | **~48** | **+15** |

Hand-edit count drops from today's number to about **9** (`lime_english_ipad`,
`lime_abc_ipad`, `symbols1_ipad`, plus their respective `_shift` variants
that already exist). All Chinese IM `_ipad.json` and all
`_ipad_narrow.json` files are build artifacts.

Re-running the full pipeline:

```bash
python3 scripts/build_ipad_layouts.py
python3 scripts/trim_ipad_layout.py
```

iPhone behavior is unchanged: all `lime_email.json`, `lime_url.json`,
`symbols2.json`, `symbols3.json`, etc. continue to ship as today and
load on iPhone via `LayoutLoader` (the `_ipad` suffix fallback only
applies when `hostIsPad`).

---

## 9. Rollout order

1. **Code-side foundations.** Add `IPadSizeClass` enum + resolver, with
   all three tiers returning today's iPad values. No visible change.
   Verify on 13" / 11" / mini.
2. **Apply narrow dimensions** (§5) — `.medium` and `.small` get the
   smaller row heights. Cells become roughly square on those devices,
   but still using the 13" layout files. Visible improvement on 11" and
   mini.
3. **Collapse English-family and symbol layouts on iPad** (§A.12, §A.13).
   - In `KeyboardViewController`: when `hostIsPad`, redirect every
     English-family layout selection (`lime_english`, `lime_email`,
     `lime_url`, `lime_english_number`, `lime_number`, `lime_shift`) to
     `lime_english_ipad` (or `lime_abc_ipad` for the abc-toggle case).
   - In `KeyboardViewController`: when `hostIsPad`, force
     `symbolLayouts = ["symbols1"]` and the `.?123` toggle becomes a
     single-state switch.
   - Delete `lime_email_ipad.json`, `lime_url_ipad.json`,
     `lime_english_number_ipad.json` (+ `_shift`), `lime_number_ipad.json`
     (+ `_shift`), `lime_shift_ipad.json`, `symbols2_ipad.json`,
     `symbols3_ipad.json` from the bundle.
   - Test that iPhone behavior is unchanged (these files still ship as
     `*.json` without the `_ipad` suffix).
4. **ET_41 source swap** (§A.6) — modify `build_ipad_layouts.py` to
   move `=(ㄦ)` from digit row to qwerty for `lime_et_41` (and
   `_shift`). Regenerate `lime_et_41_ipad.json` and verify the result
   on 13" hardware. ET_41 narrow tier counts will balance to
   12/12/12/12.
5. **Generate narrow layouts** — write `trim_ipad_layout.py`, run it,
   land the `*_ipad_narrow.json` files. Narrow layout now active on
   `.medium` and `.small`.
6. **Test** on iPad 11" + iPad mini hardware. Measure final
   `BOTTOM_NARROW` widths against the rendered keyboard.
7. **Update sibling docs** (`IPAD_KEYBOARD.md`, `IPAD_KB_LAYOUT_COVERTER.md`)
   to cross-reference this doc and remove references to the deleted
   English-family / symbol files.

Each step is independently shippable. Steps 1–2 alone fix the
"iPad mini cells too tall" complaint without touching layouts. Step 3
removes 9 files from the iPad bundle (English-family + symbols2/3
collapse) and is a clean simplification independent of trim work.

---

## 10. Out of scope

- Changing the row count on any iPad tier (always 5 rows).
- Apple Pencil / hover behavior.
- Floating mini-keyboard (no Apple extension hook).
- macOS Catalyst.
- Android (`LimeStudio/`).
- Any DB / IM-table edit. The §6.2 derivation reads SQLite read-only at
  *plan* time; the trimmer ships with frozen string constants and never
  opens a DB at runtime.

---

## 11. Open questions

### 11.1 Bottom row `mic` on narrow tier

Apple's iPad mini stock keyboard drops `mic` from the bottom row.
LimeIME has full mic dictation and many users use it. Default in
§6.6: **keep `mic`**. Drop only if user prefers exact Apple parity.

### 11.2 Should the SSE threshold separate iPad 11" from iPad mini?

The plan combines them into the narrow tier (single `_ipad_narrow.json`).
The `.medium` vs `.small` distinction exists only for dimension
constants (row height, fonts). If iPad 11" users prefer the full
13"-tier layout (more cells, slightly tall), the threshold can move
from `< 870` to `< 800` so only the iPad mini gets narrow. Default
keeps the threshold at 870 — iPad 11" cells today are visibly tall and
this fixes them.

---

## 12. Invariants this plan preserves

1. Five rows on every iPad tier, every layout, every IM.
2. Phone behavior bit-for-bit unchanged.
3. iPad 13" behavior bit-for-bit unchanged (`.large` returns today's
   values).
4. **Cells stay close to square at every tier** (row height ≈ 7% ×
   screen width — §2 invariant).
5. No cell that is an IM root is ever dropped (§6.1 predicate, rule 2).
6. `build_ipad_layouts.py` stays focused on its existing job and grows
   no new arguments.
7. WB stays a no-op for the trimmer.
8. A missing tier file is graceful — `LayoutLoader` falls through.

---

## Appendix A — Narrow layouts per IM (verified against shipped JSONs)

This appendix is **verified against the actual `*_ipad.json` files
shipped today** (read 2026-05). Source rows below are the ground
truth; narrow rows are computed by applying §6 trim rules.

### A.0 Notation

- Single-glyph cell: `q`
- IM-sublabel cell: `q(ㄆ)` — primary on top, IM character below
- Dual-slide scaffolding: `~|`` — top glyph (slide-down) | bottom glyph (direct tap)
- 3-layer cell (et26 / hsu): `q\tㄗ(ㄟ)` — top + middle + sublabel
- Modifier: `[Tab]` `[abc]` `[⇧]` `[↩]` `[⌫]` `[globe]` `[mic]` `[空白]` `[.?123]` `[123]` `[中]` `[EN]` `[dismiss]`

Bottom row is always 6 cells; standard `BOTTOM_FULL` at large tier and
`BOTTOM_NARROW` at narrow tier (§6.6). Omitted from per-IM tables.

### A.0.1 iPad layout inventory (revised — fewer files than today)

**iPad ships fewer English-family and symbol layout files than iPhone.**
On iPad, all six English-family layouts (`lime_english_*`, `lime_email`,
`lime_url`, `lime_number`, `lime_shift`) collapse to a single
`lime_english_ipad.json` (+ `lime_abc_ipad.json` for the IM-toggle
direction). All three symbol pages collapse to a single
`symbols1_ipad.json`. The controller redirects all English-family
contexts to `lime_english_ipad` when `hostIsPad`, and forces
`symbolLayouts = ["symbols1"]` on iPad.

Files shipped on iPad (each base + `_shift` unless noted):

- **Phonetic-family Chinese IM** (digit row): `lime_phonetic`,
  `lime_dayi`, `lime_dayi_sym`, `lime_et26`, `lime_et_41`, `lime_hsu`.
- **CJ-family Chinese IM** (no digit row): `lime_array`, `lime_cj`.
  Qwerty ends in ⌫; only 2 brackets in qwerty.
- **CJ-family + digit row**: `lime_array_number`, `lime_cj_number`.
  Same alpha rows as parent + digit row + 3 brackets in qwerty.
- **High-density Chinese IM**: `lime_ez`, `lime_hs`. Brackets and
  most ASCII punct as IM roots.
- **WB stroke**: `lime_wb` (base only — 2 content rows, 5 stroke keys).
  `lime_wb_shift` ships an anomalous full layout — see §A.10.
- **English** (single layout): `lime_english_ipad` + `lime_abc_ipad`.
  No `_email`, `_url`, `_english_number`, `_number`, `_shift` `_ipad`
  variants ship — controller redirects those contexts to
  `lime_english_ipad`.
- **Symbol page** (single layout): `symbols1_ipad` only. No
  `symbols2_ipad`, `symbols3_ipad` — controller forces single-page
  behavior on iPad.

**Files NOT shipped on iPad (existing today, deleted by this plan):**

- `lime_email_ipad.json` (and `_shift` if any)
- `lime_url_ipad.json`
- `lime_english_number_ipad.json` (+ `_shift`)
- `lime_number_ipad.json` (+ `_shift`)
- `lime_shift_ipad.json`
- `symbols2_ipad.json`
- `symbols3_ipad.json`

iPhone behavior is unchanged — these layouts continue to ship as
`lime_email.json`, `lime_url.json`, etc., and are loaded on iPhone
when `hostIsPad == false`.

### A.0.2 Narrow-tier visible cell counts (single trim, both `.medium` and `.small`)

Format: digit / qwerty / asdf / zxcv (visible non-spacer cells per row;
total row length unchanged from full). Bottom row always 6.

| IM | Full (today) | Narrow (visible cells) |
|---|---|---|
| `lime_phonetic` | 14 / 14 / 13 / 12 | 12 / 11 / 12 / 12 |
| `lime_dayi` | 14 / 14 / 13 / 12 | 11 / 11 / 12 / 12 |
| `lime_dayi_sym` | 14 / 14 / 13 / 12 | 11 / 11 / 12 / 12 |
| `lime_array` | — / 14 / 13 / 12 | — / 12 / 12 / 12 |
| `lime_array_number` | 14 / 14 / 13 / 12 | 11 / 11 / 12 / 12 |
| `lime_cj` | — / 14 / 13 / 12 | — / 12 / 11 / 11 |
| `lime_cj_number` | 14 / 14 / 13 / 12 | 11 / 11 / 11 / 11 |
| `lime_et26` | 14 / 14 / 13 / 12 | 11 / 11 / 11 / 12 |
| `lime_et_41` | 13 / 14 / 13 / 12 (post-swap, see §A.6) | 12 / 12 / 12 / 12 |
| `lime_hsu` | 14 / 14 / 13 / 12 | 11 / 11 / 11 / 12 |
| `lime_ez` | 14 / 14 / 13 / 12 | 13 / 13 / 13 / 12 (qwerty `[Tab]`→spacer per §6.5b) |
| `lime_hs` | 14 / 14 / 13 / 12 | 13 / 13 / 11 / 12 (qwerty `[Tab]`→spacer per §6.5b) |
| `lime_wb` | 3 / 4 (no-op) | 3 / 4 (no-op) |
| `lime_english` + `lime_abc` (English-only on iPad — see §A.12) | 14 / 14 / 13 / 12 | 11 / 11 / 11 / 11 |
| `symbols1` (sole symbol page on iPad — see §A.13) | 14 / 14 / 13 / 14 (no-op) | 14 / 14 / 13 / 14 (no-op) |

Modifiers `[Tab]` `[abc]` `[⇧]` `[↩]` `[⌫]` are present and unchanged
in width on every IM at every tier — they are never dropped. The
visible-cell count is `(source_count − spacer_count)`. Trimmed cells
become transparent spacers (§6.4) at their original positions.

### A.1 `lime_phonetic`

Source (`lime_phonetic_ipad.json`):

```
digit  (14): ~|` 1(ㄅ) 2(ㄉ) 3(ˇ) 4(ˋ) 5(ㄓ) 6(ˊ) 7(˙) 8(ㄚ) 9(ㄞ) 0(ㄢ) -(ㄦ) +|= [⌫]
qwerty (14): [Tab] q(ㄆ) w(ㄊ) e(ㄍ) r(ㄐ) t(ㄔ) y(ㄗ) u(一) i(ㄛ) o(ㄟ) p(ㄣ) 『|「 』|」 ||、
asdf   (13): [abc] a(ㄇ) s(ㄋ) d(ㄎ) f(ㄑ) g(ㄕ) h(ㄘ) j(ㄨ) k(ㄜ) l(ㄠ) ;(ㄤ) 。|， [↩]
zxcv   (12): [⇧] z(ㄈ) x(ㄌ) c(ㄏ) v(ㄒ) b(ㄖ) n(ㄙ) m(ㄩ) ,(ㄝ) .(ㄡ) /(ㄥ) [⇧]
```

Cells flipped to spacer at narrow tier:

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``), cell 12 (`+\|=`) | 12 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cell 11 (`。\|，`) | 12 |
| zxcv | none | 12 |

Narrow (`lime_phonetic_ipad_narrow.json`):

```
digit  (14): [spacer] 1(ㄅ) 2(ㄉ) 3(ˇ) 4(ˋ) 5(ㄓ) 6(ˊ) 7(˙) 8(ㄚ) 9(ㄞ) 0(ㄢ) -(ㄦ) [spacer] [⌫]
qwerty (14): [Tab] q(ㄆ) w(ㄊ) e(ㄍ) r(ㄐ) t(ㄔ) y(ㄗ) u(一) i(ㄛ) o(ㄟ) p(ㄣ) [spacer] [spacer] [spacer]
asdf   (13): [abc] a(ㄇ) s(ㄋ) d(ㄎ) f(ㄑ) g(ㄕ) h(ㄘ) j(ㄨ) k(ㄜ) l(ㄠ) ;(ㄤ) [spacer] [↩]
zxcv   (12): [⇧] z(ㄈ) x(ㄌ) c(ㄏ) v(ㄒ) b(ㄖ) n(ㄙ) m(ㄩ) ,(ㄝ) .(ㄡ) /(ㄥ) [⇧]
```

### A.2 `lime_dayi`

Source (`lime_dayi_ipad.json`):

```
digit  (14): ~|` 1(言) 2(牛) 3(目) 4(四) 5(王) 6(門) 7(田) 8(米) 9(足) 0(金) …|— +|= [⌫]
qwerty (14): [Tab] q(石) w(山) e(一) r(工) t(糸) y(火) u(艸) i(木) o(口) p(耳) 『|「 』|」 ||、
asdf   (13): [abc] a(人) s(革) d(日) f(土) g(手) h(鳥) j(月) k(立) l(女) ;(虫) 。|， [↩]
zxcv   (12): [⇧] z(心) x(水) c(鹿) v(禾) b(馬) n(魚) m(雨) ,(力) .(舟) /(竹) [⇧]
```

Cells flipped to spacer at narrow tier:

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``), cell 11 (`…\|—`), cell 12 (`+\|=`) | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cell 11 (`。\|，`); `;(虫)` is a root → walk stops | 12 |
| zxcv | none (all `,(力)` `.(舟)` `/(竹)` are roots) | 12 |

Narrow (`lime_dayi_ipad_narrow.json`):

```
digit  (14): [spacer] 1(言) 2(牛) 3(目) 4(四) 5(王) 6(門) 7(田) 8(米) 9(足) 0(金) [spacer] [spacer] [⌫]
qwerty (14): [Tab] q(石) w(山) e(一) r(工) t(糸) y(火) u(艸) i(木) o(口) p(耳) [spacer] [spacer] [spacer]
asdf   (13): [abc] a(人) s(革) d(日) f(土) g(手) h(鳥) j(月) k(立) l(女) ;(虫) [spacer] [↩]
zxcv   (12): [⇧] z(心) x(水) c(鹿) v(禾) b(馬) n(魚) m(雨) ,(力) .(舟) /(竹) [⇧]
```

### A.3 `lime_array` (no digit row)

Source (`lime_array_ipad.json`) — qwerty has only 2 brackets and ends in `[⌫]`:

```
qwerty (14): [Tab] q(1⇡) w(2⇡) e(3⇡) r(4⇡) t(5⇡) y(6⇡) u(7⇡) i(8⇡) o(9⇡) p(0⇡) 『|「 』|」 [⌫]
asdf   (13): [abc] a(1−) s(2−) d(3−) f(4−) g(5−) h(6−) j(7−) k(8−) l(9−) ;(0−) 。|， [↩]
zxcv   (12): [⇧] z(1⇣) x(2⇣) c(3⇣) v(4⇣) b(5⇣) n(6⇣) m(7⇣) ,(8⇣) .(9⇣) /(0⇣) [⇧]
```

Array roots include `;`, `,`, `.`, `/` (with sublabels) — all protected.

| Row | → spacer | Visible |
|---|---|---|
| qwerty | cells 11, 12 (2 brackets) | 12 |
| asdf | cell 11 (`。\|，`) | 12 |
| zxcv | none | 12 |

Narrow (`lime_array_ipad_narrow.json`):

```
qwerty (14): [Tab] q(1⇡) w(2⇡) e(3⇡) r(4⇡) t(5⇡) y(6⇡) u(7⇡) i(8⇡) o(9⇡) p(0⇡) [spacer] [spacer] [⌫]
asdf   (13): [abc] a(1−) s(2−) d(3−) f(4−) g(5−) h(6−) j(7−) k(8−) l(9−) ;(0−) [spacer] [↩]
zxcv   (12): [⇧] z(1⇣) x(2⇣) c(3⇣) v(4⇣) b(5⇣) n(6⇣) m(7⇣) ,(8⇣) .(9⇣) /(0⇣) [⇧]
```

### A.3.1 `lime_array_number`

Source (`lime_array_number_ipad.json`) — has digit row + 3rd bracket
(`||、`); digit cells use dual-slide form (no IM sublabels):

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 …|— +|= [⌫]
qwerty (14): [Tab] q(1⇡) w(2⇡) e(3⇡) r(4⇡) t(5⇡) y(6⇡) u(7⇡) i(8⇡) o(9⇡) p(0⇡) 『|「 』|」 ||、
asdf   (13): [abc] a(1−) s(2−) d(3−) f(4−) g(5−) h(6−) j(7−) k(8−) l(9−) ;(0−) 。|， [↩]
zxcv   (12): [⇧] z(1⇣) x(2⇣) c(3⇣) v(4⇣) b(5⇣) n(6⇣) m(7⇣) ,(8⇣) .(9⇣) /(0⇣) [⇧]
```

Digit-zone protection (§6.4) keeps digit cells 1–10 even though
chr('1')…chr('0') aren't in array roots.

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``), cell 11 (`…\|—`), cell 12 (`+\|=`) | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cell 11 (`。\|，`) | 12 |
| zxcv | none | 12 |

Narrow:

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 [spacer] [spacer] [⌫]
qwerty (14): [Tab] q(1⇡) w(2⇡) e(3⇡) r(4⇡) t(5⇡) y(6⇡) u(7⇡) i(8⇡) o(9⇡) p(0⇡) [spacer] [spacer] [spacer]
asdf   (13): [abc] a(1−) s(2−) d(3−) f(4−) g(5−) h(6−) j(7−) k(8−) l(9−) ;(0−) [spacer] [↩]
zxcv   (12): [⇧] z(1⇣) x(2⇣) c(3⇣) v(4⇣) b(5⇣) n(6⇣) m(7⇣) ,(8⇣) .(9⇣) /(0⇣) [⇧]
```

### A.4 `lime_cj` (no digit row)

Source (`lime_cj_ipad.json`) — qwerty has only 2 brackets and ends in `[⌫]`:

```
qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(卜) u(山) i(戈) o(人) p(心) 『|「 』|」 [⌫]
asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) ；|： 。|， [↩]
zxcv   (12): [⇧] z(重) x(難) c(金) v(女) b(月) n(弓) m(一) <|, >|. ?|/ [⇧]
```

CJ root set is letters only — every punct cell is trimmable.

| Row | → spacer | Visible |
|---|---|---|
| qwerty | cells 11, 12 (2 brackets) | 12 |
| asdf | cell 10 (`；\|：`), cell 11 (`。\|，`) | 11 |
| zxcv | cell 10 (`?\|/`) only — quota 1 | 11 |

Narrow (`lime_cj_ipad_narrow.json`):

```
qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(卜) u(山) i(戈) o(人) p(心) [spacer] [spacer] [⌫]
asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) [spacer] [spacer] [↩]
zxcv   (12): [⇧] z(重) x(難) c(金) v(女) b(月) n(弓) m(一) <|, >|. [spacer] [⇧]
```

### A.4.1 `lime_cj_number`

Source (`lime_cj_number_ipad.json`) — like `lime_cj` + digit row + 3rd
bracket:

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 …|— +|= [⌫]
qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(卜) u(山) i(戈) o(人) p(心) 『|「 』|」 ||、
asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) ；|： 。|， [↩]
zxcv   (12): [⇧] z(重) x(難) c(金) v(女) b(月) n(弓) m(一) <|, >|. ?|/ [⇧]
```

| Row | → spacer | Visible |
|---|---|---|
| digit | cells 0, 11, 12 | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cells 10, 11 (2 punct) | 11 |
| zxcv | cell 10 (`?\|/`) only | 11 |

Narrow:

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 [spacer] [spacer] [⌫]
qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(卜) u(山) i(戈) o(人) p(心) [spacer] [spacer] [spacer]
asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) [spacer] [spacer] [↩]
zxcv   (12): [⇧] z(重) x(難) c(金) v(女) b(月) n(弓) m(一) <|, >|. [spacer] [⇧]
```

### A.5 `lime_et26`

Source (`lime_et26_ipad.json`) — has 3-layer cells in qwerty/asdf/zxcv:

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 …|— +|= [⌫]
qwerty (14): [Tab] q\tㄗ(ㄟ) w\tㄘ(ㄝ) e(ㄧ) r(ㄜ) t\tㄊ(ㄤ) y(ㄔ) u(ㄩ) i(ㄞ) o(ㄛ) p\tㄆ(ㄡ) 『|「 』|」 ||、
asdf   (13): [abc] a(ㄚ) s(ㄙ) d\t˙(ㄉ) f\tˊ(ㄈ) g\tㄓ(ㄐ) h\tㄏ(ㄦ) j\tˇ(ㄖ) k\tˋ(ㄎ) l\tㄌ(ㄥ) ；|： 。|， [↩]
zxcv   (12): [⇧] z(ㄠ) x(ㄨ) c\tㄒ(ㄕ) v\tㄑ(ㄍ) b(ㄅ) n\tㄋ(ㄣ) m\tㄇ(ㄢ) <|, >|. ?|/ [⇧]
```

ET26 roots include `,` and `.` — `<|,` and `>|.` are roots; `?|/` is not.

| Row | → spacer | Visible |
|---|---|---|
| digit | cells 0, 11, 12 | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cells 10 (`；\|：`), 11 (`。\|，`) | 11 |
| zxcv | none — `<\|,` is root, walk stops | 12 |

Narrow:

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 [spacer] [spacer] [⌫]
qwerty (14): [Tab] q\tㄗ(ㄟ) w\tㄘ(ㄝ) e(ㄧ) r(ㄜ) t\tㄊ(ㄤ) y(ㄔ) u(ㄩ) i(ㄞ) o(ㄛ) p\tㄆ(ㄡ) [spacer] [spacer] [spacer]
asdf   (13): [abc] a(ㄚ) s(ㄙ) d\t˙(ㄉ) f\tˊ(ㄈ) g\tㄓ(ㄐ) h\tㄏ(ㄦ) j\tˇ(ㄖ) k\tˋ(ㄎ) l\tㄌ(ㄥ) [spacer] [spacer] [↩]
zxcv   (12): [⇧] z(ㄠ) x(ㄨ) c\tㄒ(ㄕ) v\tㄑ(ㄍ) b(ㄅ) n\tㄋ(ㄣ) m\tㄇ(ㄢ) <|, >|. ?|/ [⇧]
```

### A.6 `lime_et_41`

ET_41 needs a **source-layout adjustment** to balance narrow-tier
counts. The digit row of today's `lime_et_41_ipad.json` ends with two
roots `-(ㄥ) =(ㄦ)` that block the right-walk trim entirely — narrow
tier digit ends at 13 visible cells, while every other row trims down
to 12. To balance, **`=(ㄦ)` is relocated from the digit row to the
qwerty row** (replacing the rightmost bracket cell `||、`).

This is a one-rule special case in the converter (`build_ipad_layouts.py`
ET_41 path). It changes the **large 13" tier** display as well — `=(ㄦ)`
appears in qwerty row 2 instead of digit row 1 on every iPad. ET_41
users still have full access to `=`-as-IM-root; just from a different
position. The 41-key invariant is preserved.

#### Revised source (`lime_et_41_ipad.json` — proposed)

```
digit  (13): ~|` 1(˙) 2(ˊ) 3(ˇ) 4(ˋ) %|5 ^|6 7(ㄑ) 8(ㄢ) 9(ㄣ) 0(ㄤ) -(ㄥ) [⌫]
qwerty (14): [Tab] q(ㄟ) w(ㄝ) e(一) r(ㄜ) t(ㄊ) y(ㄡ) u(ㄩ) i(ㄞ) o(ㄛ) p(ㄆ) =(ㄦ) 『|「 』|」
asdf   (13): [abc] a(ㄚ) s(ㄙ) d(ㄉ) f(ㄈ) g(ㄐ) h(ㄏ) j(ㄖ) k(ㄎ) l(ㄌ) ;(ㄗ) 。|， [↩]
zxcv   (12): [⇧] z(ㄠ) x(ㄨ) c(ㄒ) v(ㄍ) b(ㄅ) n(ㄋ) m(ㄇ) ,(ㄓ) .(ㄔ) /(ㄕ) [⇧]
```

ET_41 digit row is **13 cells** (one shorter than other digit-row IMs);
qwerty stays at 14 with `=(ㄦ)` in position 11. The `||、` bracket cell
is dropped entirely from the source layout — ET_41 doesn't use it.
Width re-normalization at large tier: digit row's 12 printable × 7% +
⌫ at 16% = 100% (⌫ widens to absorb the freed 7%); qwerty stays at
standard widths.

ET_41 roots include `-`, `=`, `;`, `,`, `.`, `/`. Now `=(ㄦ)` lives in
qwerty.

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``) only — right walk hits `-(ㄥ)` root | 12 |
| qwerty | cells 12, 13 (2 brackets) — cell 11 `=(ㄦ)` is root, stops walk | 12 |
| asdf | cell 11 (`。\|，`) — `;(ㄗ)` is root | 12 |
| zxcv | none — `,(ㄓ)` is root | 12 |

Narrow (`lime_et_41_ipad_narrow.json`):

```
digit  (13): [spacer] 1(˙) 2(ˊ) 3(ˇ) 4(ˋ) %|5 ^|6 7(ㄑ) 8(ㄢ) 9(ㄣ) 0(ㄤ) -(ㄥ) [⌫]
qwerty (14): [Tab] q(ㄟ) w(ㄝ) e(一) r(ㄜ) t(ㄊ) y(ㄡ) u(ㄩ) i(ㄞ) o(ㄛ) p(ㄆ) =(ㄦ) [spacer] [spacer]
asdf   (13): [abc] a(ㄚ) s(ㄙ) d(ㄉ) f(ㄈ) g(ㄐ) h(ㄏ) j(ㄖ) k(ㄎ) l(ㄌ) ;(ㄗ) [spacer] [↩]
zxcv   (12): [⇧] z(ㄠ) x(ㄨ) c(ㄒ) v(ㄍ) b(ㄅ) n(ㄋ) m(ㄇ) ,(ㄓ) .(ㄔ) /(ㄕ) [⇧]
```

ET_41 narrow visible cell counts: **12 / 12 / 12 / 12** (perfectly
balanced). The §A.0.2 cell-count table should be updated from `13 / 11
/ 12 / 12` to `12 / 12 / 12 / 12` once this swap is in place.

#### Trade-off acknowledged

ET_41's digit row at large tier is one cell shorter than other Chinese
IMs. Visually different from phonetic/dayi/cj_number/array_number digit
rows (which keep 14 cells). Acceptable because:

1. ET_41 is the only IM that has 5/6 as scaffolding (not roots) inside
   the digit zone, so it was already structurally different.
2. Trimmer stays purely "spacer-in-place" — no per-IM cell-moving
   rules at trim time.
3. Narrow tier benefit (clean 12/12/12/12) outweighs the 13" tier
   asymmetry.

### A.7 `lime_hsu`

Source (`lime_hsu_ipad.json`):

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 …|— +|= [⌫]
qwerty (14): [Tab] q w(ㄠ) e\tㄧ(ㄝ) r\tㄖ(ㄚ) t(ㄊ) y(ㄚ) u(ㄩ) i(ㄞ) o(ㄡ) p(ㄆ) 『|「 』|」 ||、
asdf   (13): [abc] a\tㄘ(ㄟ) s\t˙(ㄙ) d\tˊ(ㄉ) f\tˇ(ㄈ) g\tㄍ(ㄜ) h\tㄏ(ㄛ) j\tˋ(ㄐㄓ) k\tㄎ(ㄤ) l\tㄌ(ㄦㄥ) ；|： 。|， [↩]
zxcv   (12): [⇧] z(ㄗ) x(ㄨ) c\tㄒ(ㄕ) v\tㄑ(ㄔ) b(ㄅ) n\tㄋ(ㄣ) m\tㄇ(ㄢ) <|, >|. ?|/ [⇧]
```

HSU roots include `,` and `.` — `<|,` is a root, walk stops on zxcv.

| Row | → spacer | Visible |
|---|---|---|
| digit | cells 0, 11, 12 | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cells 10 (`；\|：`), 11 (`。\|，`) | 11 |
| zxcv | none | 12 |

Narrow:

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 [spacer] [spacer] [⌫]
qwerty (14): [Tab] q w(ㄠ) e\tㄧ(ㄝ) r\tㄖ(ㄚ) t(ㄊ) y(ㄚ) u(ㄩ) i(ㄞ) o(ㄡ) p(ㄆ) [spacer] [spacer] [spacer]
asdf   (13): [abc] a\tㄘ(ㄟ) s\t˙(ㄙ) d\tˊ(ㄉ) f\tˇ(ㄈ) g\tㄍ(ㄜ) h\tㄏ(ㄛ) j\tˋ(ㄐㄓ) k\tㄎ(ㄤ) l\tㄌ(ㄦㄥ) [spacer] [spacer] [↩]
zxcv   (12): [⇧] z(ㄗ) x(ㄨ) c\tㄒ(ㄕ) v\tㄑ(ㄔ) b(ㄅ) n\tㄋ(ㄣ) m\tㄇ(ㄢ) <|, >|. ?|/ [⇧]
```

### A.8 `lime_ez`

Source (`lime_ez_ipad.json`) — uses brackets `[` `\` `]` and most ASCII
punct as IM roots:

```
digit  (14): ~|` 1(|) 2(車) 3(糸) 4(言) 5(貝) 6(雨) 7(ㄇ) 8(八) 9(耳) 0(鳥) 儿(-) =(母) [⌫]
qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(、) u(山) i(戈) o(人) p(心) [(匚) ](]) \(ㄏ)
asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) ;(寸) '(Ｌ) [↩]
zxcv   (12): [⇧] z(Ｚ) x(又) c(金) v(女) b(月) n(弓) m(一) ,(／) .(＼) /(ㄥ) [⇧]
```

`儿(-)` and `=(母)` in digit row are single-glyph cells (no `\n`) →
predicate rule 3 fails → not trimmable.

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``) only | 13 |
| qwerty | none — `[`, `]`, `\` all roots; **§6.5b cap-overflow drops `[Tab]`** | 13 |
| asdf | none — `;` and `'` both roots | 13 |
| zxcv | none — `,`, `.`, `/` all roots | 12 |

Narrow:

```
digit  (14): [spacer] 1(|) 2(車) 3(糸) 4(言) 5(貝) 6(雨) 7(ㄇ) 8(八) 9(耳) 0(鳥) 儿(-) =(母) [⌫]
qwerty (14): [spacer] q(手) w(田) e(水) r(口) t(廿) y(、) u(山) i(戈) o(人) p(心) [(匚) ](]) \(ㄏ)
asdf   (13): unchanged from source
zxcv   (12): unchanged from source
```

EZ at narrow tier: 13/13/13/12 — `[Tab]` slot becomes a spacer in
qwerty so the row hits the §6.5b cap of 13. Other rows already at or
below 13. Cells are physically smaller on iPad mini (52×52pt) but
square — necessary cost of preserving every EZ root.

### A.9 `lime_hs`

Source (`lime_hs_ipad.json`) — lowercase unshifted letter labels; same root
set as EZ:

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 _|- +|= [⌫]
qwerty (14): [Tab] q w e r t y u i o p {|[ }|] |\|\
asdf   (13): [abc] a s d f g h j k l ；|： 。|， [↩]
zxcv   (12): [⇧] z x c v b n m >|. <|, ?|/ [⇧]
```

HS asdf scaffolding `；|：` `。|，` are full-shape codes (65306, 65292)
NOT in HS roots (which has ASCII `;` only) → trimmable. HS qwerty
brackets `{|[` `}|]` `|\|\` ARE in roots (`[`, `]`, `\` ∈ HS roots) →
not trimmable.

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``) only — `_\|-` and `+\|=` are roots | 13 |
| qwerty | none — all 3 brackets are roots; **§6.5b cap-overflow drops `[Tab]`** | 13 |
| asdf | cells 10 (`；\|：`), 11 (`。\|，`) — full-shape, not in roots | 11 |
| zxcv | none — `>\|.` code 46 is root | 12 |

Narrow:

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 _|- +|= [⌫]
qwerty (14): [spacer] Q W E R T Y U I O P {|[ }|] |\|\
asdf   (13): [abc] A S D F G H J K L [spacer] [spacer] [↩]
zxcv   (12): unchanged from source
```

HS at narrow tier: 13/13/11/12 — `[Tab]` slot becomes a spacer per
§6.5b cap-overflow rule.

### A.10 `lime_wb`

Source (`lime_wb_ipad.json`):

```
r0 (3): 一 丨 丿
r1 (4): [abc] 丶 ㄣ [⌫]
```

No `\n` cells → trimmer is no-op. Narrow = source. No
`lime_wb_ipad_narrow.json` written (skip-write-on-no-op, §6.8).

`lime_wb_ipad_shift.json` ships an anomalous full 14/13/12 layout that
doesn't match the base — flagged for separate source cleanup.

### A.11 `lime_dayi_sym`

Source byte-identical to `lime_dayi`. Narrow identical to A.2.

### A.12 English layout — only `lime_english_ipad`

**iPad collapses the English layout family to a single file.**
`KeyboardViewController` today picks between 6 English-family layouts
based on user pref (`numberRowInEnglish`) and text-input context
(email, URL, number, shift): `lime_english`, `lime_english_number`,
`lime_email`, `lime_url`, `lime_number`, `lime_shift`.

On iPad these distinctions are moot — every English-family layout
already includes the 5-row scaffold with the digit row, so they all
collapse to the same visual keyboard. We ship only:

- `lime_english_ipad.json` — the canonical English layout
- `lime_abc_ipad.json` — IM-toggle sibling (asdf modifier toggles back
  from Chinese IM to English)

When `hostIsPad`, the controller redirects all 6 English-family layout
selections (`lime_english`, `lime_english_number`, `lime_email`,
`lime_url`, `lime_number`, `lime_shift`) to `lime_english_ipad` (or
`lime_abc_ipad` for the abc-toggle case). The other 5 `*_ipad.json`
files are **not shipped** — they're deleted from the bundle, and the
controller never asks for them on iPad.

Source (`lime_english_ipad.json`):

```
digit  (14): ~|` !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 _|- +|= [⌫]
qwerty (14): [Tab] q w e r t y u i o p {|[ }|] |\|\
asdf   (13): [中] a s d f g h j k l :|; "|, [↩]
zxcv   (12): [⇧] z x c v b n m <|, >|. ?|/ [⇧]
```

`IM_ROOTS = ""` → every `\n`-label cell is trimmable, subject to quotas.

| Row | → spacer | Visible |
|---|---|---|
| digit | cell 0 (`~\|\``), cell 11 (`_\|-`), cell 12 (`+\|=`) | 11 |
| qwerty | cells 11, 12, 13 (3 brackets) | 11 |
| asdf | cells 10 (`:\|;`), 11 (`"\|,`) | 11 |
| zxcv | cell 10 (`?\|/`) — quota 1, walk stops | 11 |

Narrow (`lime_english_ipad_narrow.json` + `lime_abc_ipad_narrow.json`):

```
digit  (14): [spacer] !|1 @|2 #|3 $|4 %|5 ^|6 &|7 *|8 (|9 )|0 [spacer] [spacer] [⌫]
qwerty (14): [Tab] q w e r t y u i o p [spacer] [spacer] [spacer]
asdf   (13): [中] a s d f g h j k l [spacer] [spacer] [↩]
zxcv   (12): [⇧] z x c v b n m <|, >|. [spacer] [⇧]
```

(`lime_abc_ipad` substitutes asdf modifier `[中]` for the abc-toggle
direction; structure otherwise identical.)

### A.13 Symbol layout — only `symbols1_ipad`

**iPad collapses the 3-page symbol keyboard to a single page.**
`KeyboardViewController` today maintains `symbolLayouts =
["symbols1", "symbols2", "symbols3"]` and pages through them via the
`.?123` toggle.

On iPad, only `symbols1_ipad.json` ships. When `hostIsPad`, the
controller forces `symbolLayouts = ["symbols1"]` and the `.?123`
toggle is a single-state switch (toggles to symbol layout, toggles
back). No paging.

The other 2 layout files (`symbols2_ipad.json`, `symbols3_ipad.json`)
are **not shipped** on iPad — deleted from the bundle.

Source (`symbols1_ipad.json`):

```
r0 (14): ` 1 2 3 4 5 6 7 8 9 0 < > [⌫]
r1 (14): [Tab] [ ] { } # % ^ * + = \ ~ [spacer]
r2 (13): - / : ; ( ) $ & @ £ ¥ [arrow.up] [↩]
r3 (14): [spacer] … . , ? ! ' " _ € [arrow.left] [arrow.down] [arrow.right] [spacer]
```

No `\n` cells → trimmer is no-op. Narrow = source. No `*_narrow.json`
written for `symbols1` (skip-write-on-no-op).

#### Trade-off acknowledged

Some symbols only present on `symbols2` (extended Latin / diacritics)
and `symbols3` (CJK punctuation) are unreachable on iPad with this
plan. Mitigations:

- The most-used CJK punctuation cells (`【`, `】`, `『`, `』`, `「`, `」`)
  are already accessible directly from Chinese-IM keyboards on iPad
  (qwerty right-edge bracket cluster on full tier; via long-press popups
  on narrow tier).
- Less-used glyphs (math, currency, marks) are accessible via the
  iOS-level emoji/symbol picker if needed.
- If a future user request brings them back, we can add a 4-row
  `symbols2_ipad.json` and reinstate paging via the existing controller
  code path. The plan stays minimal.

### A.14 Bottom row (every IM, every tier)

Always 6 cells (`globe`, `.?123`, `mic`, `space`, `.?123`, `dismiss`).
Per-tier widths from §6.6. Identical structure across IMs and tiers;
only widths differ between `BOTTOM_FULL` and `BOTTOM_NARROW`.

---

## Appendix B — Cap-12 alternative (deferred)

This appendix records the cap-12 design discussed during planning. It
was **not adopted** — the spec ships with cap=13 (§6.5b). This is kept
as a reference in case future user feedback indicates the iPad mini
narrow tier needs even tighter cell counts.

### B.1 Why cap-12 doesn't work cleanly under spacer-in-place trim

EZ and HS each have **46 IM root keys** distributed across the 4
content rows. Today's source layout puts:

| Row | EZ roots | Cap=12 fits? |
|---|---|---|
| digit | 12 (`1`–`0`, `-`, `=`) | ✓ exact |
| qwerty | **13** (`q`–`p`, `[`, `]`, `\`) | **✗ overflow by 1** |
| asdf | 11 (`a`–`l`, `;`, `'`) | ✓ (1 spare) |
| zxcv | 10 (`z`–`m`, `,`, `.`, `/`) | ✓ (2 spare) |
| **Total** | **46** | — |

`lime_hs` matches: same 46-root distribution.

EZ qwerty's 13 roots cannot be reduced via spacer-in-place trim — every
right-edge cell is a root. To reach cap=12, one root must be *displaced*
to another location.

### B.2 Three displacement strategies (none simple)

**B.2.a Per-IM source-layout rebalancing.** Move `\(ㄏ)` from EZ qwerty
to asdf (which has a spare slot). Same for HS. Resulting source:

```
EZ digit  (14): ~|` 1(|) 2(車) 3(糸) 4(言) 5(貝) 6(雨) 7(ㄇ) 8(八) 9(耳) 0(鳥) 儿(-) =(母) [⌫]
EZ qwerty (14): [Tab] q(手) w(田) e(水) r(口) t(廿) y(、) u(山) i(戈) o(人) p(心) [(匚) ](]) [spacer]
EZ asdf   (13): [abc] a(日) s(尸) d(木) f(火) g(土) h(竹) j(十) k(大) l(中) ;(寸) '(Ｌ) \(ㄏ) [↩]   ← would need 14 cells
EZ zxcv   (12): [⇧] z(Ｚ) x(又) c(金) v(女) b(月) n(弓) m(一) ,(／) .(＼) /(ㄥ) [⇧]
```

Asdf becomes 14 cells (12 roots + abc + ↩) — overflows the 13-cell
asdf source. Need to also relocate `[abc]` or `[↩]` to fit. Cascading
restructure.

**B.2.b iPhone-like bottom-row absorption.** Move modifiers (`[Tab]`,
`[abc]`, both `[⇧]`, `[⌫]`, `[↩]`) to a **fat bottom row** (~9–10 cells
instead of 6), so the alpha rows hold pure-root content only. Bottom
row design:

```
[globe(7)] [.?123(7)] [abc(7)] [⇧(8)] [⌫(7)] [space(28)] [↩(7)] [⇧(8)] [mic(6)] [dismiss(8)]
```

Then alpha rows can hit cap=12. EZ qwerty becomes pure 12 roots
(q-p + [ + ]) since `[Tab]` and `\(ㄏ)` move out — `\` to asdf,
`[Tab]` to bottom (or dropped).

Trade-offs:

- iPhone-conventional but iPad-unconventional placement of modifiers.
- `[⌫]` further from typing zone — slower error correction.
- Hand-authored narrow files (no trim script can derive this).
- Per-IM root reshuffling required for EZ/HS.
- ~5× more implementation complexity than the cap=13 plan.

**B.2.c Long-press popup spillover.** Trimmer drops 1 EZ qwerty root
to spacer; the displaced root (e.g. `\(ㄏ)`) becomes accessible via a
long-press popup on `[abc]` or another modifier. Reuses existing
`popupKeyboard` infrastructure. Hidden from view — discovery cost.

### B.3 Why none was adopted

1. **One-cell benefit.** EZ qwerty drops from 13 → 12 cells on iPad
   mini. At 7% printable target, 1 cell of width difference is ~4pt on
   the iPad mini screen. Not perceptually significant.
2. **EZ and HS are niche.** Together <5% of LimeIME users. The cost
   (per-IM root reshuffling, hand-authored narrow files, or hidden
   popups) is disproportionate.
3. **The spacer-in-place plan is uniform.** Cap=13 with `[Tab]`-drop
   on overflow is one rule, applies cleanly across all IMs. No per-IM
   special cases (apart from the et_41 source swap, which is also a
   one-time converter rule).

### B.4 What would trigger reconsideration

If real iPad-mini users of EZ or HS report the 13-cell qwerty as
crowded, the cleanest path forward is **B.2.c (long-press popup)**:

- Add a small "displaced roots" popup attached to one alpha-row modifier
  (e.g. `[abc]` long-press on iPad mini).
- The trimmer is allowed to drop 1 IM-root cell from EZ/HS qwerty under
  cap=12.
- §A.8 / §A.9 narrow listings would change to:
  - `EZ narrow qwerty (14): [Tab] q-p [(匚) ](]) [spacer]` — `\(ㄏ)` accessible via long-press popup.
  - `HS narrow qwerty (14): [Tab] Q-P {|[ }|] [spacer]` — `|\|\` similarly relocated.

This is purely additive — does not change existing files or rules.
Does not require source-layout reshuffling. Does not move `[⌫]`.

If this becomes a need: revisit then. For now, ship cap=13.
