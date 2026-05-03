# Candidate Bar and Expanded Panel Layout

This document explains the geometry of the candidate bar
([CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift))
and the expanded candidates panel
([KeyboardViewController.swift `reloadExpandedCandidates`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift)).
The two surfaces share the same metrics for "expand-in-place" parity —
when the user taps the chevron, row 1 of the panel must look
pixel-identical to the bar that was there a moment ago.

For the raw constants and per-idiom values, see
[LAYOUT_PARAM.md](LAYOUT_PARAM.md). This doc focuses on *how the pieces
fit together*.

---

## 1. The candidate bar

```
 ┌──────────────────────────────────────────────────────────────┬─┬─────┐
 │ ㄉㄚˊ                                                       │ │     │   ← keyname strip (top)
 │ ─────────────────────────────────────────────────────────── │ │  ▾  │   ← chevron
 │   答    打    搭    達    大    ...                         │ │     │
 └──────────────────────────────────────────────────────────────┴─┴─────┘
   ↑                                                            ↑ ↑     ↑
   leading region                                          moreSep │     trailing edge
   (keyname overlay sits on top of                                 │
    the candidate scroll view)                          chevron button
                                                        (Chevron.buttonWidth)
```

### Composition

| Subview | Owner | Z-order | Role |
|---|---|---|---|
| `composingLabel` | bar (`CandidateBarView`) | top | Renders the composing keyname (e.g. `ㄉㄚˊ`) during composition, **and** the reverse-lookup result (e.g. `日=ㄇㄧˋ; ㄖˋ`) after a candidate is committed. Same font, same color, same position. |
| `scrollView` | bar | middle | Horizontally-scrolling container for the candidate cells. Spans from the bar's leading edge to `moreSep.leadingAnchor`. |
| `stackView` | inside `scrollView` | — | Holds the `CandidateButton` instances back to back (no spacing between them). |
| `moreSep` | bar | top | 1pt × 20pt vertical hairline divider between the candidate area and the chevron. |
| `moreButton` | bar | top | The chevron button (downward chevron when collapsed). Pinned to the bar's trailing edge with a fixed width. |

### Bar height (per idiom × font scale)

```
candidateBarHeight = LayoutMetrics.ComposingPopup.barBaseHeight(isPad:)
                   * candidateFontScale
```

Defaults:

| Idiom | `barBaseHeight` | At fontScale 1.1 |
|---|---|---|
| iPhone | 58 | ≈64pt |
| iPad | 74 | ≈81pt |

### Chevron button — width independent of bar height

The chevron button is *not* a bar-height square. It uses an explicit
per-idiom width so the visible left/right padding around the chevron
glyph doesn't blow up at large font scales:

| Idiom | `Chevron.iconSize` | `Chevron.buttonWidth` | Padding each side |
|---|---|---|---|
| iPhone | 18 | 40 | (40 − 18) / 2 = 11pt |
| iPad | 22 | 52 | (52 − 22) / 2 = 15pt |

The button height still tracks the bar height (so the whole bar's
trailing region is tappable), but width is constant. The reclaimed
horizontal space goes to the candidate scroll view, fitting more
cells on row 1.

### Why `moreSep` is anchored to `moreButton.leadingAnchor` (not a fixed offset)

```swift
moreSep.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor)
```

Zero-gap abutment. If the chevron's button width is later tuned, the
moreSep follows automatically. The expanded panel does the same with
`sep.trailingAnchor == collapseBtn.leadingAnchor`, so the divider
position stays in sync between the two surfaces.

---

## 2. The keyname strip overlay

The keyname strip is the most subtle piece of the design. It is
rendered **inside** the bar (overlaid on top of the leading region of
the candidate scroll view) — not in a separate band above the bar.

### Why an overlay and not a separate band

Two earlier surfaces failed (see
[IPAD_ASSIST_BAR.md §8](IPAD_ASSIST_BAR.md) for the full story):

1. **In-keyboard `composingPopupLabel` strip above the bar** — wasted
   ~22pt of vertical space all the time (even when not composing). The
   constants are kept in `LayoutMetrics.Vestigial.InKeyboardComposingPopup`
   but the height is forced to 0 at runtime.
2. **iPad assist-bar `assistBarComposingLabel`** — silently ignored by
   iOS for keyboard extensions. Constants kept in
   `LayoutMetrics.Vestigial.AssistBarLabel`; never rendered.

The active solution (RC3 Option A) is the overlay strip: zero extra
vertical space above the bar, candidate glyphs are biased down to clear
the keyname text region.

### Strip metrics (per idiom)

| Idiom | `stripHeight` | `stripFontSize` | Font face |
|---|---|---|---|
| iPhone | 22 | 14 | STHeitiTC-Light |
| iPad | 28 | 18 | STHeitiTC-Light |

Font choice is documented inline on `composingStripFont`
([CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift)):
PingFang TC and SF render Bopomofo tone marks (`ˇ ˋ ˊ ˙`) as
near-invisible IPA-style accents. STHeiti TC is the only system font
on iOS where the tone glyphs render at a glance-readable size without
per-character scaling.

### Strip layout constraints

| Anchor | Value | Effect |
|---|---|---|
| `composingLabel.leadingAnchor` | `bar.leadingAnchor + 8` | 8pt left margin (`ComposingPopup.labelLeading`). |
| `composingLabel.trailingAnchor` | `moreSep.leadingAnchor − 4` | Strip ends 4pt before the divider (`labelTrailingInset`). |
| `composingLabel.topAnchor` | `bar.topAnchor + 0` | Top-flush. |
| `composingLabel.heightAnchor` | `ceil(font.lineHeight) + 2` | Padded by 2pt (`labelHeightPad`) so STHeiti tone glyphs at the top of the em-box don't get clipped against the input view's top boundary. |

The strip's *visible* height (from `composingStripHeight`) is independent
of the label's *frame* height — the label can be taller (full lineHeight
+ pad) so the glyph isn't clipped, while the bias inset on candidate
cells uses the smaller `composingStripHeight` to save vertical space.

### Reverse lookup reuse

After the user commits a candidate, the same `composingLabel` strip is
reused to show that candidate's codes in the configured lookup IM (e.g.
`日=ㄇㄧˋ; ㄖˋ`). The strip stays visible until the next keystroke or
a dismiss-button tap — there is no auto-dismiss timer.

**Implementation guard** (`KeyboardViewController`): `isShowingReverseLookup: Bool`
is set to `true` by `showReverseLookup(_:)` and cleared by `didPress` /
`cancelComposing`. While the flag is `true`, `hideComposingPopup()` is a
no-op, preventing post-commit cleanup (related-phrase fetch, `clearSuggestions`)
from racing away the result before the user can read it.

**Key naming**: the UserDefaults key is `"\(activeIM)_im_reverselookup"` where
`activeIM` equals the IM's `tableNick` from the database (e.g. `"phonetic"`,
`"dayi"`, `"array"`). The Settings UI must use matching keys — the phonetic
IM's key is `phonetic_im_reverselookup`, **not** `bpmf_im_reverselookup`.

---

## 3. Candidate cell bias — why glyphs sit "low"

Each candidate cell is a `CandidateButton` (a `UIButton(type: .custom)`
with full bar height). The candidate glyph is rendered as the button's
`titleLabel`, which by default would center vertically inside the
button — putting it right where the keyname strip is.

To clear the strip, the button uses asymmetric vertical
`contentEdgeInsets`:

```swift
let bias = composingStripHeight / 2
btn.contentEdgeInsets = UIEdgeInsets(
    top: bias,         // +bias: shift content rect down by bias
    left: cellHPad,    // (10pt)
    bottom: -bias,     // -bias: extend content rect bias pixels below button (net: rect shifts down, size unchanged)
    right: cellHPad
)
```

Because `top + bottom = 0`, the content rect has the same *size* as
the button frame, but its center is shifted down by `bias` pixels.
The centered title label follows.

### Where the glyph ends up (iPhone, fontScale 1.0)

```
y =  0  ┬─────── bar.top, strip.top
        │  ㄉㄚˊ  ← keyname text
y = 22  ┼─────── strip.bottom (composingStripHeight)
        │   7pt padding
y = 29  ┼─────── glyph.top
        │   答    ← candidate glyph (≈22pt lineHeight)
y = 51  ┼─────── glyph.bottom
        │   7pt padding
y = 58  ┴─────── bar.bottom (candidateBarHeight)
```

The glyph is **symmetrically centered in the post-strip area** (7pt
padding above and below). Total visible spread from bar.top is 29pt of
"strip + padding" above the glyph and 7pt below — looks lopsided when
the strip is empty, balanced when it shows a keyname.

### Selection pill (`CandidateButton.pillView`)

The selection pill is drawn on an inner `UIView` sized to hug the
title label, not the full button frame:

```swift
pillView.frame = label.frame.insetBy(dx: -pillPadX, dy: -pillPadY)
                                       // (-4)         (-2)
```

Why an inner view: the button frame fills the full bar height for a
comfortable tap target (any tap inside the bar registers, not just on
the glyph), but if the pill matched the button frame, it would draw a
huge highlight box covering the keyname strip area. The inner view
keeps the pill compact around the glyph regardless of the surrounding
button frame.

---

## 4. The expanded candidates panel

When the user taps the chevron, the `KeyboardView` is hidden and a
panel takes its place. The panel must:

1. Look like the bar grew in place — row 1 pixel-identical to the bar.
2. Stack additional rows below row 1 efficiently.
3. Reuse every metric from the bar so visual changes propagate.

### Panel placement

```swift
panel.topAnchor.constraint(equalTo: candidateBar.topAnchor)
panel.leading/trailing/bottomAnchor == view.leading/trailing/bottomAnchor
```

The panel covers the candidate-bar AND keyboard-view area while it's
visible. The collapse chevron (chevron.up) and a moreSep mirror sit at
the panel's top-right, geometrically identical to the bar's chevron and
moreSep.

### Row heights — the asymmetry

This is the most important geometric subtlety:

| Row | Height | Bias | Why |
|---|---|---|---|
| Row 1 | `candidateBarHeight` (e.g. 58 iPhone, 74 iPad) | `stripHeight / 2` | Mirrors the collapsed bar exactly so expand-in-place feels seamless. The keyname strip area is reserved at the top. |
| Rows 2+ | `candidateBarHeight − stripHeight` (e.g. 36 iPhone, 46 iPad) | 0 | No keyname above these rows, so reserving strip space would be permanent whitespace. Glyphs are centered in the shorter row with symmetric padding. |

The wrap loop tracks the current row's height and bias and updates
them on the first wrap:

```swift
var rowH    = firstRowH      // candidateBarHeight
var rowBias = stripH / 2

for candidate in expandedCandidates {
    // ... compute btnW ...
    if needsWrap {
        x = 0
        y += rowH                // advance by OLD row's height
        rowH = restRowH          // shorter from now on
        rowBias = 0              // no strip-bias from now on
    }
    btn.frame = CGRect(x: x, y: y, width: btnW, height: rowH)
    btn.contentEdgeInsets.top    =  rowBias
    btn.contentEdgeInsets.bottom = -rowBias
    // ...
}
```

### Where rows 2+ glyphs land (iPhone)

```
y = 58  ┬─────── row 2 top (= row 1 bottom)
        │   7pt padding
y = 65  ┼─────── glyph.top
        │   答      ← candidate glyph (≈22pt)
y = 87  ┼─────── glyph.bottom
        │   7pt padding
y = 94  ┴─────── row 2 bottom (rowH = 36pt)
```

Symmetric padding above and below the glyph, no wasted strip area.

### Wrap point — must use chevron button width, NOT bar height

```swift
let chevronZone = LayoutMetrics.CandidateBar.Chevron.buttonWidth(isPad: isOnPad)
let rowMaxX = panelWidth - chevronZone - expandedSepWidth
```

A row wraps when the next candidate's right edge would cross `rowMaxX`.
This must use `Chevron.buttonWidth` (40pt iPhone, 52pt iPad) — using
`candidateBarHeight` here (the historical pre-refactor mistake) would
over-reserve the right edge by ~22pt on iPad and push the last
fully-visible row-1 candidate to row 2.

### Selection pill in the panel

Computed manually (the panel doesn't use `CandidateButton`; it builds
plain `UIButton(type: .system)` cells):

```swift
let pillW = (btnW − 2 × cellHPad) + 2 × pillPadX     // hug glyph horizontally
let pillH = min(rowH, btnFont.lineHeight + 2 × pillPadY)
let pillX = cellHPad − pillPadX
let pillY = max(0, (rowH − pillH) / 2) + rowBias     // center vertically + apply row bias
```

`rowBias` is `stripH/2` for row 1 (so the pill matches row-1's biased
glyph) and 0 for rows 2+ (centered with the unbiased glyph).

### Collapse chevron — width is static, height tracks the bar

| Property | Source | Reason |
|---|---|---|
| `collapseBtn.widthAnchor.equalToConstant` | `Chevron.buttonWidth(isPad:)` | Same width as the bar's `moreButton`, so the collapsed/expanded chevrons sit at the same X. Doesn't change with font scale. |
| `collapseBtn.heightAnchor.equalToConstant` | `candidateBarHeight` (live ref `expandedCollapseHeightConstraint`) | Tracks the bar height so the chevron tap target spans the panel's first row. Updated in `applyFeedbackSettings` whenever the user changes `font_size`. |

Without the live height ref, font-scale changes would resize the bar
but not the chevron button — its leading edge (and the sep that
follows it) would drift relative to the bar's chevron, breaking
expand-in-place. Bug history is preserved in the comments around
[KeyboardViewController.swift:932](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L932).

---

## 5. Quick "what knob to turn" table

| Want to change | Knob in `LayoutMetrics` | Effect on bar | Effect on panel |
|---|---|---|---|
| Bar overall height | `ComposingPopup.{Phone,Pad}.barBaseHeight` | Bar grows/shrinks | Row 1 grows/shrinks; rows 2+ grow/shrink by same delta (since `restRowH = barBaseHeight − stripHeight`) |
| Reserved keyname-strip space | `ComposingPopup.{Phone,Pad}.stripHeight` | Glyph bias changes; padding around glyph in row 1 changes | Rows 2+ height changes (bigger strip → shorter rows 2+, same total bar) |
| Keyname text size | `ComposingPopup.{Phone,Pad}.stripFontSize` | Strip text glyph size | Same — panel uses bar's `composingStripFont` directly |
| Candidate cell glyph size | `ComposingPopup.{Phone,Pad}.candidateFontSize` | Candidate text glyph size | Same — panel computes from the same source |
| Chevron icon size | `CandidateBar.Chevron.{Phone,Pad}.iconSize` | Bar's chevron glyph size | Panel's collapse chevron glyph size (same constant) |
| Chevron button width / padding | `CandidateBar.Chevron.{Phone,Pad}.buttonWidth` | Bar chevron's tap target width and L/R padding around glyph | Panel chevron's tap target width AND row-wrap point on every row |
| Selection pill rounding | `CandidateBar.pillCornerRadius` | Bar pill rounding | Panel pill rounding |
| Selection pill text padding | `CandidateBar.pillPadX`, `pillPadY` | Bar pill X/Y inset around glyph | Panel pill X/Y inset around glyph |

---

## 6. Invariants the layout maintains

1. **Row 1 of the panel is pixel-identical to the collapsed bar.** Same
   height, same bias, same glyph baseline, same chevron position, same
   moreSep position.
2. **Rows 2+ have no wasted strip space.** The shorter `restRowH`
   gives back `stripHeight` pixels per row.
3. **The chevron leading edge is at the same X on both surfaces.**
   Both use `Chevron.buttonWidth(isPad:)` for the button's width.
4. **The wrap point is the same on both surfaces.** Both use
   `Chevron.buttonWidth(isPad:) + dividerWidth` as the right-edge
   reserve.
5. **Font-scale changes propagate live.** The bar's
   `candidateBarHeightConstraint` and the panel's
   `expandedCollapseHeightConstraint` are both updated in
   `applyFeedbackSettings`. Anything else that depends on
   `candidateBarHeight` (like row 1 / rows 2+ heights inside
   `reloadExpandedCandidates`) is recomputed on the next reload —
   which `applyFeedbackSettings` triggers via
   `reloadExpandedCandidates()` when the panel is visible.

If a future change breaks one of these invariants, expand-in-place
will visibly judder. Test by:

1. Open a host app, start composing.
2. Tap the chevron to expand. Row 1 should not move.
3. Change `font_size` in Settings while the panel is open. Row 1 should
   resize in step with the bar; rows 2+ should resize proportionally.
4. Collapse the panel. The bar should be where it was before expansion.

---

## 7. Dismiss button — left-end clear control

### Purpose

A dismiss (✕) button at the **leading edge** of the candidate bar lets
the user cancel the current composing session in one tap — clearing
`mComposing` without modifying the document and hiding the candidate
list. The same button appears on the expanded panel's top-left corner.

### Bar layout

```
 ┌──┬───────────────────────────────────────────────────────┬─┬─────┐
 │  │ ㄉㄚˊ                                                │ │     │   ← keyname strip (top)
 │✕ │ ──────────────────────────────────────────────────── │ │  ▾  │
 │  │   答    打    搭    達    大    ...                   │ │     │
 └──┴───────────────────────────────────────────────────────┴─┴─────┘
   ↑                                                        ↑ ↑     ↑
dismiss btn                                            moreSep │  trailing
(no sep after)                                          chevron btn
```

The dismiss button is **narrower** than the chevron and does **not**
span the full bar height — it sits in the glyph zone only. There is no
separator between the dismiss button and the scroll view.

### Geometry

| Property | Value | Rationale |
|---|---|---|
| Width | `Chevron.buttonWidth(isPad:) / 2` (20pt iPhone, 26pt iPad) | Compact; less horizontal space consumed |
| Height | `barHeight − stripHeight = restRowH` (36pt iPhone, 46pt iPad) | Covers glyph + top/bottom padding; excludes strip zone |
| Center Y | `barCenterY + stripHeight / 2` | Aligned with the candidate glyph axis |
| Icon | `xmark` SF Symbol, `iconSize` = same as chevron | Reuses existing constant |
| `contentEdgeInsets` bias | **none** | Frame is already positioned at glyph center; no shift needed |
| Background | `candiText` at 10 % alpha, `cornerRadius` 6, `masksToBounds` | Makes button extent visible; no separator needed |

#### Where the dismiss button sits (iPhone, fontScale 1.0)

```
y =  0  ┬── bar.top / strip.top
        │   ㄉㄚˊ  (keyname strip, 22pt)
y = 22  ┼── strip.bottom    ← dismissButton.top
        │   7pt top padding   │
y = 29  ┼── glyph.top         │  height = restRowH = 36pt
        │   答  (~22pt)        │
y = 51  ┼── glyph.bottom      │
        │   7pt bot padding   │
y = 58  ┴── bar.bottom      ← dismissButton.bottom
```

The button is symmetric around the glyph center (y = 40), covering
both padding bands but stopping at the strip boundary above.

### Constraints in `CandidateBarView`

```swift
dismissButton.leadingAnchor.constraint(equalTo: leadingAnchor)
dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor,
    constant: composingStripHeight / 2)
dismissButton.heightAnchor.constraint(equalTo: heightAnchor,
    constant: -composingStripHeight)
dismissButton.widthAnchor.constraint(equalToConstant:
    Chevron.buttonWidth(isPad:) / 2)
```

Downstream anchors that moved:

| Anchor | Old value | New value |
|---|---|---|
| `scrollView.leadingAnchor` | `bar.leadingAnchor` | `dismissButton.trailingAnchor` |
| `composingLabel.leadingAnchor` | `bar.leadingAnchor + labelLeading` | `dismissButton.trailingAnchor + labelLeading` |

### Visibility lifecycle

`dismissButton.isHidden` is toggled with `moreButton` / `moreSep` in
`rebuildButtons()` — hidden when there are no candidates.

### Delegate

```swift
protocol CandidateBarViewDelegate: AnyObject {
    func candidateBarView(_ view: CandidateBarView, didSelect mapping: Mapping)
    func candidateBarViewDidRequestMore(_ view: CandidateBarView)
    func candidateBarViewDidRequestDismiss(_ view: CandidateBarView)
}
```

`dismissTapped()` fires `delegate?.candidateBarViewDidRequestDismiss(self)`.

### Action in `KeyboardViewController`

```swift
func candidateBarViewDidRequestDismiss(_ view: CandidateBarView) {
    if isExpandedCandidatesVisible { hideExpandedCandidates() }
    cancelComposing()
}
```

`cancelComposing()` clears `mComposing`, empties the candidate list,
and hides the composing popup — no new clearing logic needed.

### Expanded panel — dismiss button at top-left

The panel's dismiss button uses **relative constraints off `collapseBtn`**
so it tracks font-scale changes automatically without a live constraint ref:

```swift
dismissBtn.centerYAnchor.constraint(equalTo: collapseBtn.centerYAnchor,
    constant: candidateBar.composingStripHeight / 2)
dismissBtn.heightAnchor.constraint(equalTo: collapseBtn.heightAnchor,
    constant: -candidateBar.composingStripHeight)
dismissBtn.widthAnchor.constraint(equalToConstant:
    Chevron.buttonWidth(isPad:) / 2)
```

When `expandedCollapseHeightConstraint.constant` is updated (font-scale
change), the dismiss button height and center follow automatically —
no separate `expandedDismissHeightConstraint` is needed.

### Row lead offset

The `dismissZone` uses half the chevron width (matching the actual
button) so panel row 1 starts at the same X as the collapsed bar:

```swift
let dismissZone = Chevron.buttonWidth(isPad: isOnPad) / 2   // = actual button width
var x: CGFloat  = dismissZone + hPad   // every row, including wraps
let rowMaxX     = panelWidth - chevronZone - expandedSepWidth  // unchanged
```

### Invariants preserved

+ **Row 1 pixel-identical to bar**: `dismissZone` = dismiss button width (no sep),
  matching the bar's leading region exactly.
+ **Rows 2+ no wasted strip space**: `restRowH` unchanged; only `rowLeadX`
  shifts the start X.
+ **Font-scale live**: dismiss button height auto-derives from
  `collapseBtn` via relative constraints; no additional update call needed.

### Files modified

| File | Change summary |
| --- | --- |
| `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift` | Add `dismissButton`; new delegate method; updated leading constraints; visibility toggled with `moreButton` |
| `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` | Implement `candidateBarViewDidRequestDismiss`; add dismiss btn to panel with relative constraints off `collapseBtn`; `dismissZone` in `reloadExpandedCandidates` |

No new `LayoutMetrics` constants — `Chevron.buttonWidth`, `Chevron.iconSize`,
`CandidateBar.dividerWidth`, and `CandidateBar.dividerHeight` are reused.

### Verification

1. Start composing → bar shows dismiss (✕) at left, chevron (▾) at right.
2. Tap ✕ → composing cleared, candidate bar empties.
3. Tap ▾ to expand → panel row 1 pixel-identical to bar (same leading zone).
4. Tap ✕ in expanded panel → panel collapses AND composing clears.
5. Change `font_size` in Settings while panel open → dismiss button height
   tracks bar height with no layout drift.
6. iPhone 20 × 36 pt; iPad 26 × 46 pt (at fontScale 1.0).
