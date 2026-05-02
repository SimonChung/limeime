# LimeIME-iOS Layout Parameters

Every magic number that affects keyboard-extension geometry, font size,
spacing, special-case colors, or animation timing lives in
[LayoutMetrics.swift](../LimeIME-iOS/LimeKeyboard/LayoutMetrics.swift).
The four keyboard source files (`KeyboardViewController.swift`,
`KeyboardView.swift`, `CandidateBarView.swift`, `PopupKeyboardView.swift`)
read those constants and never inline a literal of their own.

This document explains what each constant controls, what region of the
keyboard it affects, and why it has its current value. Use it as a
reference when tuning visuals — change the value in `LayoutMetrics.swift`
once and every reference picks it up.

> **Out of scope.** Theme palette colors live in
> [`KeyboardPalette`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift) — that
> file is already a single-source-of-truth definition by theme index 0–5.
> User preferences (font scale 0.8–1.2, key-size scale 0.8–1.2, etc.) are
> sourced from `UserDefaults` and applied as multipliers on top of the
> values listed below.

---

## Section index

1. [`TouchTrap`](#touchtrap) — keyboard-extension hit-gate workaround
2. [`CandidateBar`](#candidatebar) — chrome of the candidate strip
3. [`ComposingPopup`](#composingpopup) — keyname overlay (iPhone vs iPad)
4. [`Vestigial`](#vestigial) — retired surfaces kept for API compatibility
5. [`KeyboardRow`](#keyboardrow) — row heights and per-key gaps
6. [`Key`](#key) — labels, icons, shadow on a normal key
7. [`Gesture`](#gesture) — long-press, swipe, repeat, multi-tap timings
8. [`PopupKeyboard`](#popupkeyboard) — long-press mini keyboard
9. [`KeyPreview`](#keypreview) — iOS-native callout above the pressed key
10. [`GlobePreview`](#globepreview) — globe / dismiss key preview bubble
11. [`InlineMenu`](#inlinemenu) — in-extension UIAlertController replacement
12. [`Toast`](#toast) — transient reverse-lookup notification
13. [Expanded candidates panel](#expanded-candidates-panel) — reuses CandidateBar/ComposingPopup directly

---

## TouchTrap

Custom keyboard extensions silently drop touches that land on fully
transparent pixels (see [IOS_CANDI_TOUCH.md §Resolution](IOS_CANDI_TOUCH.md)
for the full root-cause investigation). The `fill` constant is a
near-invisible neutral grey — high enough alpha to satisfy the touch
gate, low enough that it does not tint the shared keyboard blur backdrop.

| Constant | Default | Effect |
|----------|---------|--------|
| `fill`   | `UIColor(white: 0.5, alpha: 0.01)` | Background applied to every interactive control whose visible content is sparse (candidate buttons, chevron, expanded-panel collapse). Empty bar pixels stay clear. |

---

## CandidateBar

Idiom-agnostic structural pieces of the candidate strip above the keys.
The keyname-overlay sizing and the candidate-cell font sizes are not
here — those are in [`ComposingPopup`](#composingpopup) so per-idiom
values stay grouped.

| Constant | Default | Effect |
|----------|---------|--------|
| `candidateHPad` | `10` | Horizontal padding inside each candidate cell. The selection pill is positioned relative to this. |
| `dividerWidth` | `1` | Width of `moreSep`, the thin separator just left of the chevron. |
| `dividerHeight` | `20` | Visible height of `moreSep`. |
| `Chevron.iconSize(isPad:)` | iPhone `18`, iPad `22` | SF Symbol point size of the more-chevron at the bar's trailing edge. iPad uses a larger glyph to match the larger candidate text. |
| `Chevron.buttonWidth(isPad:)` | iPhone `40`, iPad `52` | Width of the chevron button's frame. **The real knob for the chevron's left/right padding** — visible padding around the glyph = `(buttonWidth - iconSize) / 2` (iPhone ≈ 11pt, iPad ≈ 15pt). Independent of bar height (the previous `width == height` rule made the chevron a 58–74pt square holding an 18pt icon, leaving ~20pt of empty space on each side and growing with font scale for no reason). The expanded panel's collapse chevron mirrors this width via the same selector. |
| `pillCornerRadius` | `6` | Corner radius of the selection pill drawn inside `CandidateButton.pillView`. |
| `pillPadX` | `4` | Pill width = title-label width + 2 × pillPadX. |
| `pillPadY` | `2` | Pill height = title-label height + 2 × pillPadY (clamped to row height). |
| `pagingDragThreshold` | `20` | Minimum pan-translation distance before a drag is treated as a paged scroll instead of a tap. |
| `darkThemePill` | `UIColor(white: 0.23, alpha: 1)` | Theme 1 (Dark) overrides the palette's `candiHighlight` with this elevated grey for Android parity. |
| `composingCodeDimAlpha` | `0.5` | Alpha applied to `palette.candiText` when rendering an inactive composing-code candidate (raw English letters cell). |
| `separatorAlpha` | `0.2` | Alpha applied to `palette.candiText` when painting the `moreSep` divider and the expanded-panel separator. |

---

## ComposingPopup

The single active composing-popup surface on **both iPhone and iPad** —
the keyname strip overlaid on the leading region of the candidate bar.
This is the RC3 Option A solution from
[IPAD_ASSIST_BAR.md §8](IPAD_ASSIST_BAR.md). Per-idiom values live in
`Phone` and `Pad` sub-enums; layout values that happen to be identical on
both idioms live directly under `ComposingPopup`.

### Per-idiom sizing

iPhone hardware uses `Phone`; iPad hardware uses `Pad`. The keyboard view
captures `isPad` once via `UIDevice.current.userInterfaceIdiom`; the
controller uses `traitCollection.userInterfaceIdiom == .pad`
(see the file-level comment in `LayoutMetrics.swift` for why each path
uses the source it does).

| Constant | iPhone (`Phone.*`) | iPad (`Pad.*`) | Effect |
|----------|--------------------|----------------|--------|
| `stripHeight` | `22` | `28` | Reserved height of the keyname overlay at the top of the candidate bar. Candidate glyphs are biased down by half this value so they do not overlap the keyname. |
| `stripFontSize` | `14` | `18` | Strip-label font size. Multiplied by `candidateFontScale` at use-site. STHeiti TC is the chosen face — see the comment on `composingStripFont` in `CandidateBarView.swift` for the Bopomofo-tone-glyph rationale. |
| `candidateFontSize` | `22` | `26` | Candidate-cell font size. Multiplied by `candidateFontScale`. |
| `composingCodeFontSize` | `16` | `22` | Composing-code (raw English letters) cell font size. Uses PingFang TC for tone-mark legibility. |
| `barBaseHeight` | `58` | `74` | Resting height of the candidate bar before `candidateFontScale` is applied. |

### Shared layout (identical on both idioms)

| Constant | Default | Effect |
|----------|---------|--------|
| `labelLeading` | `8` | Leading inset of the keyname label inside the bar. |
| `labelTrailingInset` | `-4` | Trailing inset of the keyname label relative to `moreSep` (negative = leaves a gap). |
| `labelTopInset` | `0` | Top inset relative to the bar's top edge. |
| `labelHeightPad` | `2` | Padding added to the strip-label's height beyond `ceil(font.lineHeight)`. STHeiti tone glyphs (ˇ ˋ ˊ ˙) render at the top of the em-box and would clip without this. |
| `textAlpha` | `0.75` | Alpha applied to `palette.candiText` for the keyname text. |

### Per-idiom selectors

Helper functions for callers that already have an `isPad` flag on hand:

```swift
LayoutMetrics.ComposingPopup.stripHeight(isPad: isPad)
LayoutMetrics.ComposingPopup.stripFontSize(isPad: isPad)
LayoutMetrics.ComposingPopup.candidateFontSize(isPad: isPad)
LayoutMetrics.ComposingPopup.composingCodeFontSize(isPad: isPad)
LayoutMetrics.ComposingPopup.barBaseHeight(isPad: isPad)
```

---

## Vestigial

Two historical composing-popup surfaces. Both have been retired but
their constants are kept because the controller still instantiates the
underlying `UILabel`s for API compatibility (the toast and
`showComposingPopup` paths call into them; the labels are simply hidden
or never rendered).

### `Vestigial.InKeyboardComposingPopup`

The original iPhone composing strip above the candidate bar. Replaced
by the candidate-bar overlay (see `ComposingPopup`).
`effectiveComposingPopupHeight` is hardcoded to `0` in
`KeyboardViewController`; the label is always hidden.

| Constant | Default | Effect (when active — currently inert) |
|----------|---------|----------------------------------------|
| `baseHeight` | `22` | Reserved height of the strip before `candidateFontScale`. |
| `labelFontSize` | `15` | Strip-label font size, multiplied by `candidateFontScale`. |
| `leadingInset` | `6` | Horizontal inset on both sides of the strip's label. |

### `Vestigial.AssistBarLabel`

The iPad assist-bar (`UIInputViewController.inputAssistantItem`) approach.
iOS silently ignores assist-bar mutations from keyboard extensions — see
[IPAD_ASSIST_BAR.md §8](IPAD_ASSIST_BAR.md) for the architectural reset
that moved the composing keyname into the candidate bar instead.

| Constant | Default | Effect (when the bar would render — never does) |
|----------|---------|-------------------------------------------------|
| `composingLabelFontSize` | `14` | Label font in the assist-bar trailing group. |
| `composingLabelWidth` | `220` | Label frame width. |
| `composingLabelHeight` | `32` | Label frame height. |

---

## KeyboardRow

Row heights and per-key gap geometry. Per-idiom values are grouped under
`Phone` and `Pad` sub-enums (mirroring `ComposingPopup`). The pre-scale
row height is the appropriate value for that orientation × idiom; a user
preference (`keySizeScale`, 0.8–1.2) multiplies it at runtime.

### Per-idiom row heights and gaps

| Constant | iPhone (`Phone.*`) | iPad (`Pad.*`) | Effect |
|----------|--------------------|----------------|--------|
| `portraitRow` | `50` | `64` | Every row except the bottom row, in portrait. |
| `portraitBottomRow` | `54` | `68` | The row containing space / return, in portrait. |
| `landscapeRow` | `36` | `60` | Every row except the bottom row, in landscape. (iPhone 36 matches Android's 36 dip landscape.) |
| `landscapeBottomRow` | `38` | `64` | Bottom row in landscape. |
| `keyHGap` | `5` | `7` | Horizontal gap between adjacent keys. |
| `keyVGap` | `2` | `4` | Vertical gap between rows (and between row top/bottom and the row content view). |
| `keyCornerRadius` | `6` | `8` | Corner radius on every key button. |

### Idiom-agnostic

| Constant | Default | Effect |
|----------|---------|--------|
| `splitGapFraction` | `0.06` | Fraction of row width reserved as the central gap when iPad split-keyboard mode is active. |
| `fallbackRowHeight` | `54` | Per-row height assumed inside `applyHeight()` when the keyboard view has not yet measured itself. |

### Per-idiom selectors

```swift
LayoutMetrics.KeyboardRow.keyHGap(isPad: isPad)
LayoutMetrics.KeyboardRow.keyVGap(isPad: isPad)
LayoutMetrics.KeyboardRow.keyCornerRadius(isPad: isPad)
```

The four row-height constants are read directly via the sub-enum path
(`KeyboardRow.Phone.portraitRow` / `KeyboardRow.Pad.portraitRow`); the
keyboard view picks between them once at init and stores the
already-resolved value in a local `let`.

---

## Key

Per-key chrome — text, icon, shadow, popup indicator dot. Per-idiom font
and icon sizes live under `Phone` and `Pad`; chrome that does not vary
by idiom (shadow, popup indicator, shift icon, dismiss icon) lives
directly under `Key`. Font weights are still hard-coded inside
`KeyboardView.swift` (regular for primary, light for the small primary
in dual-label keys) — only the *sizes* are parameterized here.

### Per-idiom sizing

| Constant | iPhone (`Phone.*`) | iPad (`Pad.*`) | Effect |
|----------|--------------------|----------------|--------|
| `singleLabelFontSize` | `22` | `24` | Font size for keys with one label only. |
| `primaryLabelFontSize` | `16` | `20` | Small primary label (the letter sitting above the bopomofo sublabel). |
| `sublabelFontSize` | `22` | `24` | Larger sublabel (the bopomofo glyph). |
| `iconSize` | `20` | `26` | SF Symbol point size for every icon key (excluding the dismiss key). |

### Idiom-agnostic

| Constant | Default | Effect |
|----------|---------|--------|
| `shadowOpacity` | `0.3` | Shadow opacity on every key button. |
| `shadowOffsetY` | `1` | Vertical shadow offset (px). |
| `dismissIconSize` | `28` | SF Symbol point size for the keyboard-dismiss key (larger than other icons for legibility). |
| `shiftIconSize` | `20` | SF Symbol point size for the shift / shift.fill / capslock.fill icons. |
| `popupIndicatorFontSize` | `11` | Font size of the "…" indicator at the bottom-right of keys with a popup keyboard. |
| `popupIndicatorTrailingInset` | `-3` | Trailing inset (negative) for the "…" indicator. |
| `popupIndicatorBottomInset` | `-2` | Bottom inset (negative) for the "…" indicator. |
| `dualLabelWidthMargin` | `-4` | Negative inset applied to the dual-label container so it never touches the button's edges. |

### Per-idiom selectors

```swift
LayoutMetrics.Key.singleLabelFontSize(isPad: isPad)
LayoutMetrics.Key.primaryLabelFontSize(isPad: isPad)
LayoutMetrics.Key.sublabelFontSize(isPad: isPad)
LayoutMetrics.Key.iconSize(isPad: isPad)
```

---

## Gesture

Long-press hold thresholds, swipe distances, repeat cadence, and the
multi-tap (T9) window. All durations are in seconds.

| Constant | Default | Effect |
|----------|---------|--------|
| `popupKeyboardHoldDuration` | `0.4 s` | Hold time before a key with a popup keyboard pops it up. |
| `dualRowHoldDuration` | `0.4 s` | Hold time before iPad dual-row top-key shows the secondary preview. |
| `specialKeyHoldDuration` | `0.5 s` | Hold time before the dismiss / globe key shows the options menu. |
| `spaceLongPressDuration` | `0.5 s` | Hold time before the space key opens the LIME IM picker. |
| `spaceSwipeThreshold` | `30 pt` | Horizontal pan distance before a space-bar drag is recognized as a left/right swipe (cycles IM). |
| `dualRowSwipeThreshold(landscape:)` | landscape `16`, portrait `24` | Vertical pan distance before an iPad dual-row top-key downward slide commits the secondary glyph. Smaller in landscape to match the shorter row. |
| `repeatStartDelay` | `0.4 s` | Hold time before a repeating key (backspace, arrow keys) starts firing repeats. |
| `repeatInterval` | `0.1 s` | Interval between subsequent repeats. |
| `multiTapTimeout` | `0.8 s` | Window during which tapping the same multi-code key cycles through `codes[]` instead of starting a new selection. |

---

## PopupKeyboard

Geometry of the long-press mini keyboard panel that appears above a key
with a `popupKeyboard` reference (e.g. accent variants, punctuation).

| Constant | Default | Effect |
|----------|---------|--------|
| `keyHeight` | `44` | Each popup key is this tall. |
| `keyMinWidth` | `40` | Minimum popup key width; per-key text width can extend beyond this. |
| `hPad` | `8` | Horizontal padding inside the popup panel. |
| `vPad` | `8` | Vertical padding inside the popup panel. |
| `spacing` | `4` | Spacing between adjacent popup keys (horizontal) and adjacent rows (vertical). |
| `panelCornerRadius` | `12` | Popup-panel corner radius. |
| `panelShadowOpacity` | `0.28` | Popup-panel shadow opacity. |
| `panelShadowOffsetY` | `3` | Popup-panel shadow vertical offset. |
| `panelShadowRadius` | `8` | Popup-panel shadow blur radius. |
| `keyCornerRadius` | `6` | Per-key corner radius inside the popup. |
| `keyFontSize` | `22` | Per-key font size. |
| `keyShadowOpacity` | `0.22` | Per-key shadow opacity. |
| `keyShadowOffsetY` | `1` | Per-key shadow vertical offset. |
| `keyShadowRadius` | `1` | Per-key shadow blur radius. |
| `keyExtraWidth` | `20` | Width added to the key text width to size the button (acts as horizontal padding around the glyph). |
| `edgeMargin` | `4` | Margin from the keyboard-view edges when positioning the popup. |
| `yOffsetFromKey` | `6` | Vertical gap between the popup's bottom edge and the source key's top edge. |

---

## KeyPreview

iOS-native callout bubble shown above a pressed key on iPhone (iPad keys
are large enough that press-state colour change suffices, matching
Apple's stock iPad keyboard behavior).

The bubble is wider than the key and tapers down through an S-curve neck
to match the key's exact width.

| Constant | Default | Effect |
|----------|---------|--------|
| `widthFactor` | `1.45` | Bubble width = key width × this factor (clamped to a minimum). |
| `heightFactor` | `1.4` | Bubble height = key height × this factor (clamped). |
| `minWidthLandscape` | `56` | Minimum bubble width in landscape. |
| `minWidthPortrait` | `64` | Minimum bubble width in portrait. |
| `minHeightLandscape` | `50` | Minimum bubble height in landscape. |
| `minHeightPortrait` | `64` | Minimum bubble height in portrait. |
| `neckHeight` | `12` | Vertical extent of the S-curved neck between bubble and key. |
| `cornerRadius` | `10` | Bubble corner radius. |
| `edgeMargin` | `4` | Window-edge margin when clamping the bubble's horizontal position. |
| `shadowOpacity` | `0.22` | Bubble shadow opacity. |
| `shadowOffsetY` | `1` | Bubble shadow vertical offset. |
| `shadowRadius` | `3` | Bubble shadow blur radius. |
| `initialScale` | `0.88` | Starting scale of the spring-in animation. |
| `appearDuration` | `0.08 s` | Spring-in duration. |
| `disappearDuration` | `0.08 s` | Fade-out duration. |
| `springDamping` | `0.7` | Spring damping ratio. |
| `springInitialVelocity` | `0.5` | Spring initial velocity. |
| `contentWidthInset` | `-8` | Inset (negative = subtract from container width) applied to the centred content. |
| `neckCurveFar` | `0.55` | Bezier control-point factor for the *outer* (bubble-side) neck curve. |
| `neckCurveNear` | `0.45` | Bezier control-point factor for the *inner* (key-side) neck curve. |
| `primaryFontSize(isTall:isLandscape:)` | tall portrait `13`, tall landscape `12`, wide portrait `12`, wide landscape `11` | Small primary label (the letter on top of bopomofo) inside the preview bubble. |
| `sublabelFontSize(isTall:isLandscape:)` | tall portrait `28`, tall landscape `22`, wide portrait `20`, wide landscape `16` | Sublabel (the bopomofo glyph) inside the preview bubble. |
| `singleFontSize(isLandscape:)` | portrait `26`, landscape `20` | Single-label font size when the key has no sublabel. |
| `horizontalDualSpacing` | `3` | Stack spacing in the wide layout (horizontal primary-then-sublabel). |

---

## GlobePreview

Brief flash of the globe icon shown for ~0.4 s when the user long-presses
the globe / dismiss key, satisfying Apple's globe-affordance requirement
before the inline options menu opens.

The done key's exact frame is not directly readable from the controller,
so the bubble is positioned via approximation factors.

| Constant | Default | Effect |
|----------|---------|--------|
| `approxKeyWidthFactor` | `0.15` | Estimated done-key width = keyboard width × this factor. |
| `approxKeyHeightLandscape` | `38` | Estimated done-key height in landscape. |
| `approxKeyHeightPortrait` | `56` | Estimated done-key height in portrait. |
| `bubbleWidthLandscape` | `44` | Bubble width in landscape. |
| `bubbleWidthPortrait` | `52` | Bubble width in portrait. |
| `bubbleHeightLandscape` | `50` | Bubble height in landscape. |
| `bubbleHeightPortrait` | `64` | Bubble height in portrait. |
| `tipHeight` | `8` | Height of the triangular tip below the bubble. |
| `tipHorizontalRadius` | `6` | Half-width of the triangular tip. |
| `cornerRadius` | `10` | Bubble corner radius. |
| `edgeMargin` | `4` | Window-edge margin when clamping the bubble's position. |
| `iconSizeLandscape` | `22` | Globe SF Symbol point size in landscape. |
| `iconSizePortrait` | `28` | Globe SF Symbol point size in portrait. |
| `shadowOpacity` | `0.22` | Bubble shadow opacity. |
| `shadowOffsetY` | `1` | Bubble shadow vertical offset. |
| `shadowRadius` | `3` | Bubble shadow blur radius. |
| `appearDuration` | `0.08 s` | Fade-in duration. |
| `dismissDelay` | `0.4 s` | How long the bubble stays visible before fade-out. |
| `dismissDuration` | `0.1 s` | Fade-out duration. |

---

## InlineMenu

Custom UIView panel that replaces `UIAlertController` (presenting alerts
from a keyboard extension can advance to the next input mode in some iOS
versions). Used for the long-press dismiss/globe options menu, the
LIME-internal IM picker, etc.

| Constant | Default | Effect |
|----------|---------|--------|
| `cornerRadius` | `12` | Panel corner radius. |
| `backgroundAlpha` | `0.97` | Alpha on `UIColor.systemBackground`. |
| `shadowOpacity` | `0.2` | Panel shadow opacity. |
| `shadowRadius` | `8` | Panel shadow blur radius. |
| `shadowOffsetY` | `-2` | Panel shadow vertical offset (negative = above the panel). |
| `buttonHeight` | `50` | Height of each item button in the menu. |
| `buttonFontSize` | `17` | Item button font size. |
| `separatorHeight` | `0.5` | Hairline separator height between items. |
| `edgeInset` | `8` | Inset from the keyboard view's edges on all four sides. |
| `appearDuration` | `0.2 s` | Slide-in animation duration. |
| `appearTranslationY` | `20` | Vertical offset (slide-up distance) at the start of the appear animation. |

---

## Toast

Transient banner shown in the composing strip when a reverse-lookup
result is fetched (e.g. user looks up the bopomofo for a Chinese glyph).

| Constant | Default | Effect |
|----------|---------|--------|
| `displayDuration` | `2.0 s` | How long the toast stays visible before clearing the composing label. |

---

## Expanded candidates panel

The expandable candidate panel that replaces the keyboard view when the
user taps the chevron at the bar's trailing edge. Its first row must
stay **pixel-identical** to the collapsed candidate bar (the user
perceives the panel as the bar growing in place), so the panel reads
its layout values directly from `CandidateBar` and `ComposingPopup` —
**no `ExpandedPanel` enum exists**. Adding one would invite drift the
moment somebody tunes the bar without remembering to mirror the change.

Mapping at the call sites in [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift):

| Panel piece | Reuses |
|---|---|
| moreSep mirror width | `CandidateBar.dividerWidth` |
| moreSep mirror visible height | `CandidateBar.dividerHeight` |
| Keyname-strip mirror leading inset | `ComposingPopup.labelLeading` |
| Keyname-strip mirror trailing inset | `ComposingPopup.labelTrailingInset` |
| Keyname-strip mirror height padding | `ComposingPopup.labelHeightPad` |
| Collapse-chevron horizontal `contentEdgeInsets` | `CandidateBar.chevronHorizontalInset` |
| Strip-label font (per-idiom) | `ComposingPopup.stripFontSize(isPad:)` |
| Reserved keyname strip height (per-idiom) | `ComposingPopup.stripHeight(isPad:)` |
| Row height (per-idiom, fontScale-applied) | `candidateBarHeight` (computed from `ComposingPopup.barBaseHeight(isPad:)`) |
| Collapse-chevron square size | `candidateBarHeight` (so the reserved zone matches the bar's chevron) |

If a constant in this list ever needs to differ between the panel and
the bar, that is a strong signal the design has changed and the new
constant deserves its own named home — not a duplicate alongside the
existing one.

---

## How to add a new constant

1. Decide which section it belongs to. If it's a per-idiom value that
   doesn't fit `ComposingPopup`, prefer adding the variant pair to an
   existing `func foo(isPad:)` selector rather than introducing a new
   sub-enum (keeps the call-site idiom-agnostic).
2. Add the constant to `LayoutMetrics.swift` with a one-line comment.
3. Add a row to the relevant table in this document.
4. Replace every literal at the call sites with the new constant. Run
   `grep -nE 'CGFloat = [0-9]|UIFont\.systemFont|withAlphaComponent'` on
   the keyboard files to spot remaining literals.
5. Build the keyboard target to verify nothing was missed.

## Out-of-scope literals you might still see

The following are NOT layout magic numbers and are intentionally not in
`LayoutMetrics.swift`:

- **Sentinel / accumulator initial values** (`var x: CGFloat = 0`, etc.).
- **User preference defaults** (`keyboardSize = 1.1`, `candidateFontScale = 1.1`,
  `vibrateLevel = 40`). These are tuning knobs the user controls; the
  defaults are written next to where the pref is read.
- **Hex color literals inside `KeyboardPalette`**. The palette is its own
  single-source-of-truth definition keyed by theme index 0–5 — see
  [`KeyboardView.swift`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift).
- **Font weights** (`.regular`, `.light`, `.medium`). These are typed
  enum cases, not magic numbers; if the design ever needs to vary them
  per-idiom or per-region, that decision belongs in a typography enum
  outside the scope of "layout".
