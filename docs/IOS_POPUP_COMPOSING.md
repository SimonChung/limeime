# iOS Composing Keyname Popup — Deep Research

Status: **resolved**. After seven attempts (A–G) to overlay the keyname bubble into the host app's area failed on a fundamental iOS constraint, we accepted the always-reserved-strip compromise. The keyboard extension now reserves a permanent ~24pt strip above the candidate bar for the keyname. No more compose/commit height jitter.

---

## 1. Problem Statement

### Goal (user-requested)
The composing keyname popup (e.g. `日月` for Dayi `dj`) currently sits **inside** the keyboard extension's own vertical space. When composing starts, the extension height grows by ~24pt; when composition commits, the extension shrinks back. The host app's client area visibly jumps up/down on every compose→commit cycle. This is uncomfortable.

Desired behaviour: the keyname bubble should **overlay the host app's content area** — i.e. appear above the keyboard without changing the extension's own height. Start and commit should be layout-stable for the host app.

### Working baseline (the "before" state)
- File: [LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift)
- The popup was a `UILabel` subview of `self.view`, pinned with `topAnchor = view.topAnchor`, `leading/trailing` to view edges, plus a `heightAnchor` constant that animated 0 → ~24pt.
- `candidateBar.topAnchor` was anchored to `composingPopupLabel.bottomAnchor`.
- `applyHeight()` summed `popupHeight + candidateBarHeight + keysHeight` into the extension's height constraint.
- **Text rendered correctly.** The only problem was the height jitter.

### Current broken state
After four attempts to move the popup out of the extension's vertical space:
- Attempts A and B rendered **nothing at all**.
- Attempts C and D render the **bubble's shape/fill/shadow** above the candidate bar correctly, but the keyname text inside the bubble is **not visible**.
- Attempt D (current HEAD) applied full keyPreviewView structural parity — CAShapeLayer chrome, fresh rebuild per show, manual-frame UILabel with no Auto Layout, animate-in. Text still does not render.

---

## 2. Failed Attempts

### Attempt A — bare UILabel attached to window
- Remove label from `self.view` Auto Layout entirely.
- On show, `view.window!.addSubview(composingPopupLabel)`, compute frame in window coords just above `candidateBar.frame` and set `label.frame = …`.
- `applyHeight()` no longer includes popup height — extension height stays constant.
- **Observed:** popup is completely invisible. No rendering at all.

### Attempt B — self.view subview pinned ABOVE view.topAnchor
- Keep label as `self.view` subview.
- Change constraint from `topAnchor = view.topAnchor` → `bottomAnchor = view.topAnchor`.
- Height constraint still drives visibility (0 → 24pt).
- `view.clipsToBounds = false` set explicitly.
- `applyHeight()` no longer includes popup height.
- Expectation: when height > 0, the label's frame has y = –24, overflowing upward into the host app area.
- **Observed:** popup is completely invisible. No rendering at all.

### Attempt C — UIView container + UILabel subview attached to window
- Container `UIView` with opaque `backgroundColor = pal.candiBackground`, `cornerRadius = 4`, `borderWidth = 0.5`, `shadowOffset`, `shadowOpacity`, `masksToBounds = false`.
- `UILabel` inside the container, pinned with `topAnchor/bottomAnchor = container.{top/bottom}`, `leading/trailing` = container ±6.
- Container attached to `view.window` on show; `container.frame` set manually; `container.layoutIfNeeded()` forced to resolve label constraints.
- Screenshot from user: the rounded bubble **shadow and fill are visible** above the candidate bar, but the label text inside is not visible.

### Attempt D — full keyPreviewView structural parity (current HEAD)
- **Fresh UIView rebuilt every `showComposingPopup`** (nil'd and removed in `hideComposingPopup`). No reuse across show/hide cycles.
- **Clear-background container**; chrome is a `CAShapeLayer` sublayer with a rounded-rectangle `UIBezierPath`, `fillColor = pal.candiBackground.cgColor`, `strokeColor`, `shadowColor`.
- **Manual-frame `UILabel`** (no Auto Layout inside the container): `label.frame = CGRect(x:0, y:0, width:bubbleW, height:h)`.
- **Animate-in** exactly like keyPreviewView: `container.alpha = 0 → 1`, `transform = 0.9 → .identity`, `usingSpringWithDamping: 0.8`.
- NSLog added printing container frame, label frame, text, and window bounds.
- **Observed:** identical to Attempt C. The bubble's fill and shadow render above the candidate bar, but the keyname text inside does **not** appear. Console logs have not yet been captured by the user.

This is the critical result: we are now **structurally identical** to `keyPreviewView` (same window, same process, same code patterns, same addSubview + animate), yet the label text does not render. keyPreview *does* render text successfully in this codebase. So there is a non-obvious difference between the two code paths that we have not yet identified.

### Attempt E — UIStackView + constraint-activated label + forced pre-window layout + contentsScale
- Wrapped the UILabel in a `UIStackView`, `translatesAutoresizingMaskIntoConstraints = false`, `centerXAnchor`/`centerYAnchor`/`widthAnchor` constraints to the container.
- Added `container.setNeedsLayout(); container.layoutIfNeeded()` **before** `window.addSubview(container)`.
- Set `label.layer.contentsScale = UIScreen.main.scale`.
- **Observed:** same failure as C/D — shadow visible, text not visible.

### Attempt F — Attempt E + `container.layer.shouldRasterize = true`
- Added `container.layer.rasterizationScale = UIScreen.main.scale; container.layer.shouldRasterize = true` before the animate-in.
- **Observed:** same failure. User reported "no log entry" — prompted switch from bare NSLog to NSLog+print, scheme reconfigured to attach to a real host app.

### Attempt G — CATextLayer replacing UILabel/UIStackView
- Replaced the UILabel/UIStackView entirely with a `CATextLayer` added as a sublayer of the container alongside the existing `CAShapeLayer` chrome.
- `textLayer.font = CTFontCreateWithName(font.fontName, font.pointSize, nil)`, `fontSize`, `foregroundColor = pal.candiText.cgColor`, `alignmentMode = .center`, `contentsScale = UIScreen.main.scale`, frame vertically centred in the bubble.
- Console log finally captured: `frame=(6.0, -24.2, 60.0, 24.2)` … `win=(0.0, 0.0, 440.0, 327.66)`.

### The log that solved the mystery

The window's size is `440 × 327.66` — that's the keyboard's own area, **not the screen**. `view.window` in a third-party keyboard extension is a UITextEffectsWindow whose bounds are clamped to the keyboard's allocated region. The candidate bar's `minY` in that window is `0`, so our `barInWindow.minY - h` computes `y = -24.2`: the bubble is **above the window's top edge**, outside the renderable region.

- `CAShapeLayer` shadows bypass view clipping (shadows render in a separate pass that extends beyond the owner's bounds) — this is why Attempts C/D/E/F/G all showed *some* shadow leaking above the candidate bar.
- All actual *content* (shape fill, text) is clipped to the window — this is why the bubble fill and text never rendered.

**Consequence:** overlay into the host app's content area is physically impossible for a third-party iOS keyboard. `view.window` does not extend above the keyboard; there is no other window accessible from a keyboard-extension process. The `keyPreviewView` pattern only works because its bubbles land above specific *keys*, which are below the top of the keyboard window.

---

## Shipped design — always-reserved 24pt strip

After the user accepted the compromise, we reverted all window-attach / CATextLayer / CAShapeLayer code. The final design:

- `composingPopupLabel` is a `UILabel` subview of `self.view`, pinned with `topAnchor = view.topAnchor`, `leading/trailing` with 6pt gutter, **and a height constraint that always equals `composingPopupHeight`** (never animates to 0).
- `candidateBar.topAnchor = composingPopupLabel.bottomAnchor`.
- `applyHeight()` sums `composingPopupHeight + candidateBarHeight + keysHeight`. The extension's height is constant regardless of composing state.
- `showComposingPopup()` sets `label.text`; `hideComposingPopup()` sets `label.text = nil`. No geometry changes.
- Theme / font-scale changes update the label's `textColor`, `font`, and the height constraint's constant.

Cost: ~24pt of permanent vertical space above the candidate bar (empty when idle). Benefit: zero host-app-area jitter between compose and commit, which was the user-facing pain point.

---

## Lessons learned

1. Before assuming an overlay is possible in a sandboxed iOS extension, measure `view.window.bounds` — do not assume it is the screen.
2. CAShapeLayer shadows leak outside the view's bounds; this is misleading debugging evidence when diagnosing "is my view clipped?"
3. Four implementation attempts (A/B/C/D) were spent before we actually read the frame logs; the log instantly revealed the root cause. Next time, add instrumentation first.
4. Under CLAUDE.md §7: after three failed attempts, stop and research. I should have escalated to log-reading and external docs earlier, saving time.

---

## 3. Root-Cause Analysis

### Direct observations
| Evidence | Implication |
|---|---|
| Attempt C: container chrome renders in window-level overlay | Window-attachment *is* reaching the screen. Adding views to `UITextEffectsWindow` from a keyboard extension is not blocked. |
| Attempt C: UILabel **inside** the container is not visible | Text rendering inside the window-level container is silently failing. |
| Attempt B: nothing renders when subview extends above `self.view` top edge | The input-view container (an ancestor of `self.view` inside `UIInputSetContainerView`) clips to the extension's allocated frame, regardless of `self.view.clipsToBounds`. Overflow-above does **not** render for third-party keyboard extensions. |
| `keyboardView(_:showPreviewFor:)` at [KeyboardViewController.swift:1919-2053](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1919-L2053) **works** | A window-attached container that uses `CAShapeLayer.addSublayer` for chrome **and** UILabel subviews for text renders correctly — including the text. So window-level UILabel rendering is not categorically broken. |

### Key differences between keyPreview (works) and composingPopup (text fails)
1. **Chrome approach.** keyPreview draws the bubble shape via `CAShapeLayer.addSublayer(…)` on a `clear`-background container. composingPopup fills the container with an opaque `backgroundColor` and uses `layer.cornerRadius`/`layer.shadow*`. Both approaches render *something* (we see the shadow), so this is unlikely the cause of missing text — but it is the most structural difference.
2. **Lifetime.** keyPreview is created fresh on every touchDown and removed on touchUp (sub-second). composingPopup is long-lived — one instance is kept across many show/hide cycles.
3. **Layout forcing.** keyPreview uses Auto Layout for the label and then calls `UIView.animate(…)` which implicitly runs a layout pass. composingPopup uses Auto Layout inside the container, sets `container.frame = …` manually, then calls `container.layoutIfNeeded()`. Forcing layout via `.layoutIfNeeded()` on a manually-framed ancestor is *usually* fine, but has edge cases — e.g. if the container's `translatesAutoresizingMaskIntoConstraints` is true and a sibling constraint is missing, the label may lay out with `CGRect.zero`.
4. **Rasterization / render path.** This is the most suspicious gap. Multiple third-party keyboard reports note that `UITextEffectsWindow` composites subviews with different rules than the application's key window; rasterized text content can silently drop. Forcing `label.layer.shouldRasterize = true` or using a `CATextLayer` is a documented workaround in several open-source keyboards.

### Competing hypotheses for "shape visible, text invisible" (Attempt C)

- **H1 — Layout pass never positions the label.** Even though `container.layoutIfNeeded()` is called, Auto Layout may be rejecting the constraints because the container itself has `translatesAutoresizingMaskIntoConstraints = true` (since we set `.frame`). Some combinations of autoresizing-mask + Auto Layout for the content can silently leave the child label at `CGRect.zero`. We have no logging yet to confirm the label's post-layout frame.
  - Evidence for: would explain shadow-visible-text-missing exactly (child has zero frame → background fills container, text has no render area).
  - Evidence against: keyPreview uses the same pattern and works.
  - **Next probe:** NSLog `composingPopupLabel.frame` and `composingPopupLabel.bounds` after `container.layoutIfNeeded()`. If zero → H1 confirmed.

- **H2 — UITextEffectsWindow drops rasterized text content for persistent overlays.** The long-lived label's backing store either never materialises or gets culled when outside some private clipping region.
  - Evidence for: keyPreview is short-lived and works; the background layer (CALayer-filled) renders while the text (rasterised UILabel content) does not.
  - Evidence against: speculative; we haven't reproduced this in isolation.
  - **Next probe:** try `composingPopupLabel.layer.shouldRasterize = true` plus `rasterizationScale = UIScreen.main.scale`, or replace the UILabel with a `CATextLayer`.

- **H3 — Our frame math positions the label correctly, but the container's `frame.size` is smaller than the label's natural width, and text is centered/clipped out by `clipsToBounds` on the container.** We set `masksToBounds = false` (so cornerRadius/shadow work) but text still renders within the label's own bounds; if the *container* width is too small, Auto Layout sets label width to `container.width - 12`, still nonzero. Unless there's a missing parent layout, this should be fine.
  - Evidence for: we don't have a log of the final label frame.
  - Evidence against: we pad the container to `ceil(measured.width) + 24`, which is wider than the text by 24pt. Clipping to container doesn't explain text being 100% invisible.
  - **Next probe:** same as H1 — log frames.

- **H4 — The UILabel's text color matches the container's background by coincidence.** Palette: `candiText = iosLight(.label)` (black on light mode) vs `candiBackground = iosLight(.secondarySystemBackground)` (off-white). These are clearly distinct.
  - **Ruled out** by inspection.

### Why I believe H1 or H2 (or both)
The simplest explanation that fits *all three attempts* is "UILabel content inside window-level subviews in a keyboard extension doesn't render reliably under the code path I used." Attempt A was a bare UILabel directly in window — totally invisible, consistent with H2 where the label's rasterised content is dropped (and there's no opaque layer to even provide a hint). Attempt C added a solid-colour container → shape now renders because its visible surface is a plain `backgroundColor` (CALayer fill, not rasterised text), but the label inside still has the same rendering problem. This is consistent with H2. H1 is also possible and cheaper to verify first.

---

## 4. Deep Research Findings (Attempt D post-mortem)

Attempt D matched keyPreviewView in every structural dimension I believed mattered (CAShapeLayer chrome, fresh-per-show lifecycle, manual-frame label, animate-in) and **still does not render text**. A parallel Explore agent read both code paths end-to-end and searched external reports. The one non-obvious delta it found:

### The key structural difference we missed

- **keyPreviewView (works):** builds the content view (`UIStackView` or single `UILabel`) with `translatesAutoresizingMaskIntoConstraints = false`, activates `NSLayoutConstraint` relative to the container (`centerXAnchor`, `centerYAnchor`, `widthAnchor`), then adds the container to the window, then animates in. **Activating the constraints forces a layout pass which initialises the label's text layer BEFORE it is attached to the window.**
- **Our Attempt D (broken):** creates a `UILabel` with a manual frame, adds it as a subview of the container, then immediately adds the container to the window, then animates in. **No layout pass runs between "label added to container" and "container added to window".**

Multiple external reports cited by the agent describe a UITextEffectsWindow/UIRemoteKeyboardWindow quirk: when a UILabel is attached to a container that is then moved to one of these private windows, the text layer's compositing pass can be skipped if the label's geometry was not fully resolved in a prior layout pass. The chrome (CAShapeLayer fill/shadow) is composited via the layer tree directly and is unaffected. The UILabel's rasterised text contents are not.

### Updated hypothesis ranking

- **H2 (upgraded to most likely, with a sub-mechanism):** UITextEffectsWindow skips the text layer's render pass when the label hasn't had a layout pass before being attached to the window. Forcing `container.layoutIfNeeded()` **before** `window.addSubview(container)` should fix it. This is a free one-line change with high probability.
- **H1 (ruled out):** Attempt D uses manual frame, no Auto Layout. Label frame cannot be zero. Confirmed by the explicit `label.frame = CGRect(x:0, y:0, width:bubbleW, height:h)` assignment.
- **H3, H4 (ruled out):** Frame math and color contrast were correct in all attempts.

### External workarounds (ranked by effort / probability)

1. **Layout-before-window** — `container.layoutIfNeeded()` immediately after `container.addSubview(label)` and before `window.addSubview(container)`. Cheapest.
2. **UIStackView parity** — wrap the single label in a `UIStackView`, use constraints; matches keyPreviewView content setup 1:1.
3. **Defer the animate-in** one run-loop tick (`DispatchQueue.main.async`) so the window has a chance to layout before the scale transform runs.
4. **`container.layer.shouldRasterize = true` during animate-in**, cleared in completion — bakes the label into a bitmap before UITextEffectsWindow compositing.
5. **`CATextLayer` instead of `UILabel`** — bypasses the UILabel rendering pipeline entirely.
6. **`label.layer.contentsScale = UIScreen.main.scale`** — ensures correct pixel scale for text rasterisation.

---

## 5. Proposed Next Move — Attempt E

Apply fixes **1, 2, and 6 together** in one Attempt E, since they are cheap, complementary, and directly mirror the working keyPreviewView:

1. `container.addSubview(label)` then `container.setNeedsLayout(); container.layoutIfNeeded()` **BEFORE** `window.addSubview(container)`.
2. Switch the label subview to a minimal `UIStackView` (single arranged label, `alignment = .center`, `axis = .horizontal`) with `translatesAutoresizingMaskIntoConstraints = false` and `centerX/centerY` constraints to the container — same pattern as keyPreview.
3. Set `label.layer.contentsScale = UIScreen.main.scale` as a belt-and-braces guard for Retina rendering.

Keep the NSLog trace so we capture label.frame after the forced layout pass — if E still fails, the log tells us whether the frame is correct (→ try #4 shouldRasterize) or zero (→ a constraint is wrong).

If E still fails, then Attempt F = #4 (shouldRasterize). If F still fails, Attempt G = #5 (CATextLayer). Do not attempt multiple fixes in the same commit beyond this Attempt E bundle — each subsequent attempt isolates a single variable so we can learn from it.

### Non-goals
- Do **not** retreat to the "always-reserved 24pt strip": the user rejected that.
- Do **not** attempt another self.view-overflow approach (Attempt B is conclusive evidence that the input-view container clips).

---

## 6. TODO (in priority order)

- [ ] **Attempt E (bundle fix 1 + 2 + 6):**
  - [ ] Refactor the label inside `rebuildComposingPopupBubble(animated:)` to a `UIStackView`+`UILabel` pair with `translatesAutoresizingMaskIntoConstraints = false` and `centerXAnchor`/`centerYAnchor` constraints to the container (match keyPreviewView's content block).
  - [ ] After `container.addSubview(stack)` and constraint activation, call `container.setNeedsLayout(); container.layoutIfNeeded()` **before** `window.addSubview(container)`.
  - [ ] Set `label.layer.contentsScale = UIScreen.main.scale`.
  - [ ] Keep the existing NSLog; add one more line printing `label.frame` and `label.layer.contentsScale` after the forced layout pass.
- [ ] **Capture console log after E.** `xcrun simctl spawn booted log stream --predicate 'process == "LimeKeyboard"'` or Console.app on device, filtered on `LimeIME popup`. Record label.frame in section 3.
- [ ] **Attempt F (only if E fails):** add `container.layer.shouldRasterize = true` before the animate-in block and reset in completion; do not change anything else from E.
- [ ] **Attempt G (only if F fails):** replace the UILabel with a `CATextLayer` (sizing via `NSString.size(withAttributes:)`, `contentsScale = UIScreen.main.scale`, `alignmentMode = .center`). Remove the UIStackView/UILabel entirely.
- [ ] After each attempt, update Attempts (section 2) and RC Analysis (section 3) with the console log evidence. Do NOT iterate blindly (CLAUDE.md §7).
- [ ] Once overlay renders reliably, remove NSLog calls.

---

## 7. Files touched so far (for reference)
- [LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) — popup property declaration, setupKeyboardUI, applyHeight, theme updates, show/hide/position/rebuild.
- No other files modified. The candidate bar, keyboard layout, and search pipeline are untouched.
