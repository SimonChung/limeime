# iPad Assist Bar Integration Plan

Status: IN PROGRESS — RC1 partially broken. RC2 analysis below identifies the actual root cause of "no composing popup on iPad" and proposes a one-line fix.
Scope: iOS only — `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`, `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift`. No layout JSON, no database changes.

Architectural premise (verified): the iPad **input assist bar** above the keyboard is the **only** overlay surface accessible to third-party keyboard extensions. Window-attached overlays were exhaustively proved infeasible in [IOS_POPUP_COMPOSING.md](IOS_POPUP_COMPOSING.md) (attempts A–G; `view.window` is a `UITextEffectsWindow` clamped to the keyboard's allocated region). Therefore the `inputAssistantItem` route is correct — fix it in place; do not retreat.

---

## 1. Goal

On iPad, the always-reserved composing strip (`composingPopupLabel`) above the candidate bar wastes ~22 pt of keyboard height. The native iOS input assist bar sits above the keyboard extension view and can host the composing keyname via `assistBarComposingLabel`. We will:

1. **Eliminate** the reserved composing strip height on iPad — the assist bar shows it instead.
2. **Offset** the reverse-popup keyboard panel so it starts to the right of the Paste icon in the assist bar, avoiding visual conflict.

iPhone behavior is unchanged (the in-keyboard composing strip remains).

---

## 2. Current state (post-RC1)

`KeyboardViewController.swift`:

| Symbol | File:Line | Notes |
|--------|-----------|-------|
| `isOnPad` | [KeyboardViewController.swift:136](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L136) | `UIDevice.current.userInterfaceIdiom == .pad` — deterministic; never flips. |
| `effectiveComposingPopupHeight` | [KeyboardViewController.swift:137](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L137) | `isOnPad ? 0 : composingPopupHeight` — applied. ✓ |
| `assistBarPasteZoneWidth = 50` | [KeyboardViewController.swift:141](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L141) | Constant for popup left-clamp. ✓ |
| `assistBarComposingLabel` | [KeyboardViewController.swift:142](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L142) | `var ... : UILabel?` — assigned in `setupAssistBar()`; never set to nil after. |
| `setupAssistBar()` | [KeyboardViewController.swift:218](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L218) | Called from `viewDidLoad` (157) and `viewWillAppear` (184). On iPad, builds `[Paste, composingLbl]` trailing group; `lbl.frame = (0,0,220,32)`; assigns `assistBarComposingLabel = lbl`; sets `inputAssistantItem.trailingBarButtonGroups = [group]`. |
| `composingPopupLabel.isHidden = isOnPad` | [KeyboardViewController.swift:736](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L736) | ✓ |
| `showComposingPopup()` | [KeyboardViewController.swift:1555](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1555) | Two guards. Sets text on **both** labels. |
| `keyname()` | [KeyboardViewController.swift:1542](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1542) | `searchServer?.keyToKeyname(code) ?? code` — falls back to `code` if `searchServer` is nil. |
| `hideComposingPopup()` | [KeyboardViewController.swift:1571](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1571) | Clears text on both labels (guarded by `toastTimer == nil`). |
| `showPopupKeyboard()` left-clamp | [KeyboardViewController.swift:2196](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L2196) | iPad top-row uses `assistBarPasteZoneWidth` as `leftMin`. ✓ |

`CandidateBarView.swift` `CandidateButton` ([CandidateBarView.swift:434](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift#L434)):

| Override | Line | Status |
|----------|------|--------|
| `intrinsicContentSize { super + horizontalPad*2 }` | 449 | ✓ |
| `titleRect(forContentRect:) { insetBy(dx: horizontalPad) }` | 455 | ✓ |
| `contentEdgeInsets` | — | removed (replaced by the two overrides above). |

---

## 3. Implementation summary (all applied in RC1)

| # | Change | File:Line | Status |
|---|--------|-----------|--------|
| a | `effectiveComposingPopupHeight → isOnPad ? 0 : composingPopupHeight` | KeyboardViewController.swift:137 | ✓ |
| b | `composingPopupLabel.isHidden = isOnPad` | KeyboardViewController.swift:736 | ✓ |
| c | `setupAssistBar()` builds `[Paste, composingLbl]` group; restored `lbl.frame = (0,0,220,32)` | KeyboardViewController.swift:218 | ✓ |
| d | `assistBarPasteZoneWidth = 50` constant | KeyboardViewController.swift:141 | ✓ |
| e | `showPopupKeyboard()` x-clamp uses `leftMin = (isOnPad && top-row) ? 50 : 4` | KeyboardViewController.swift:2196 | ✓ |
| f | `CandidateButton.intrinsicContentSize` adds `horizontalPad*2`; `titleRect` insets by `horizontalPad` | CandidateBarView.swift:449,455 | ✓ |

---

## 4. RC2 — Why "no composing popup" on iPad (rewritten)

### 4.1 Evidence (raw, file:line)

1. **`keyname(code)` fallback** — [KeyboardViewController.swift:1542](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1542):
   ```swift
   private func keyname(_ code: String) -> String {
       searchServer?.keyToKeyname(code) ?? code
   }
   ```
   Two failure modes return `code` unchanged:
   - `searchServer == nil` (DB still loading on background queue — see (3))
   - `db.keyToKeyName(...)` returns "" — wrapper substitutes `code` ([SearchServer.swift:118](../LimeIME-iOS/LimeKeyboard/SearchServer.swift#L118))

2. **The fatal guard** — [KeyboardViewController.swift:1562–1565](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1562-L1565):
   ```swift
   guard name.uppercased() != raw.uppercased(),
         !name.trimmingCharacters(in: .whitespaces).isEmpty else {
       hideComposingPopup()      // ← clears assistBarComposingLabel.text
       return
   }
   ```
   When `keyname(raw) == raw` (i.e. fallback fired), the guard fails and the label text is **cleared**, not "left blank". The user sees **nothing**, not an empty bar.

3. **`searchServer` is initialized asynchronously** — [KeyboardViewController.swift:174–177](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L174-L177):
   ```swift
   DispatchQueue.global(qos: .userInitiated).async { [weak self] in
       self?.setupDatabase()
   }
   ```
   `viewDidLoad` returns immediately; the DB and `searchServer` come up some milliseconds later. The very first keypresses after keyboard activation hit `keyname()` while `searchServer == nil` and fall through to the raw-code fallback.

4. **`assistBarComposingLabel` lifetime** — declared `var ... : UILabel?` ([KeyboardViewController.swift:142](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L142)), assigned to a fresh `UILabel` in every `setupAssistBar()` call (line 232). Reference is never set back to nil. Both `viewDidLoad` (157) and `viewWillAppear` (184) call it; `assistBarComposingLabel` therefore points at the **most recently created** label, which is also the live customView in the trailing group.

5. **iPhone path unaffected** — `composingPopupLabel.isHidden = false` on iPhone, and the same guard at line 1562 cleared its text on the iPhone code path before this work started, so any "iPhone composing also broken" report is unrelated to this plan and would be a separate regression.

### 4.2 Root cause

**The composing label is cleared by the second `guard` whenever `keyname(raw) == raw`, which happens during the entire window before `searchServer` finishes loading.** On a fresh keyboard activation the user types a code (e.g. "d" for Dayi); `searchServer` is still nil; `keyname("d")` returns "d"; `"D" != "D"` is false; the guard fails; `hideComposingPopup()` clears `assistBarComposingLabel.text`. The label silently shows nothing for the entire DB-load window. To the user this looks like "the assist bar composing feature is completely dead".

Even after the DB is ready, the same path can fire for any IM where a single-letter code happens to equal its own keyname, but Dayi/Bopomofo don't normally hit that — so the bug is mostly a **race**, masquerading as a categorical "doesn't work" because users give up before the race resolves.

The other hypotheses listed in the prior RC1 §6 are **ruled out**:

| Old hypothesis | Why ruled out |
|----------------|---------------|
| `assistBarComposingLabel` is nil at call time | Assigned at line 232 every `setupAssistBar()`; never nilled. Optional-chain is non-fatal anyway. |
| `isOnPad` returns false unexpectedly | `UIDevice.current.userInterfaceIdiom` is set at process launch and is deterministic; `setupAssistBar()` runs the iPad branch every call on iPad. |
| iOS resets `trailingBarButtonGroups` between events | Already mitigated: `setupAssistBar()` re-runs on every `viewWillAppear` ([KeyboardViewController.swift:184](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L184)). The customView is the **live** label; `lbl.text = ...` propagates without re-assigning the trailing groups. |
| Label has zero size (Auto-Layout-vs-frame) | Already addressed in RC1 — `lbl.frame = (0,0,220,32)` is restored. |
| Window overlay would work better | [IOS_POPUP_COMPOSING.md](IOS_POPUP_COMPOSING.md) §2–§4: `UITextEffectsWindow` is keyboard-clamped; this path is closed. |

### 4.3 Why this also explains §6 Bug 2 ("still no composing popup after frame restore")

After the frame was restored in RC1, the customView sizing is correct. But the test scenario the user uses (open a host app, switch to LimeIME, type the first composing code) hits the searchServer race **every time**. So the visible behavior — "no composing popup at all" — is unchanged by the frame fix, even though the frame fix was the right call independently.

---

## 5. Proposed solution

**One-line change**: drop the `name.uppercased() != raw.uppercased()` half of the second guard. Always show the keyname (or raw fallback) once we are in CJK composing mode.

### 5.1 Code change

**File:** `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`
**Function:** `showComposingPopup()` ([KeyboardViewController.swift:1555](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1555))

```swift
private func showComposingPopup() {
    toastTimer?.invalidate()
    toastTimer = nil
    let raw = mComposing
    guard !raw.isEmpty, !mEnglishOnly else { hideComposingPopup(); return }

    let name = keyname(raw)
    // Allow keyname == raw: the DB may not be loaded yet (searchServer init
    // is async, see viewDidLoad). Showing the raw code is strictly better
    // than a blank assist bar — it gives the user feedback that composing
    // is active. The first guard already excludes English-only mode.
    let display = name.trimmingCharacters(in: .whitespaces).isEmpty ? raw : name
    composingPopupLabel?.text = " \(display) "
    assistBarComposingLabel?.text = " \(display) "
}
```

Rationale:
- The guard's original intent — "don't show keyname when it equals raw, because that's redundant in English-only mode" — is already covered by the `!mEnglishOnly` first guard.
- During the searchServer-loading window, `keyname == raw` is a *false positive* for that intent. The user **is** in CJK mode; they just typed a code; we should show the code.
- After the DB loads, `keyname` returns the real glyph (e.g. "日" for Dayi "d") and the user sees the proper keyname — same UX as today, no regression.
- iPhone behavior also improves: during DB-load, the `composingPopupLabel` strip now shows the raw code instead of being blank.

### 5.2 Why not a different fix

| Alternative | Why not |
|-------------|---------|
| Block keyboard input until DB loads | Adds startup latency; user-hostile. The DB loads in <100ms typically, but on cold start it's perceptible. |
| Synchronous `setupDatabase()` in `viewDidLoad` | Would block the keyboard from appearing on activation — same UX cost, also iOS may kill slow extensions. |
| Wait for DB inside `keyname()` (semaphore) | Risks deadlock on the main thread; `searchServer` work runs on a background queue. |
| Force `setupAssistBar()` again right before each `showComposingPopup` | Doesn't help — the live label already updates. The bug is the guard, not the bar. |
| Add logging-first attempt | Nice in principle, but the read-only investigation already pinpointed the cause; adding `print` and asking the user to capture logs is friction we can skip. The fix is one line and can't regress anything material. |

### 5.3 Files to modify

| File | Change |
|------|--------|
| `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` | `showComposingPopup()`: drop `name.uppercased() != raw.uppercased()` guard half; introduce `display` fallback to `raw` when `name` is empty/whitespace; assign `display` to both labels. |

No other changes. RC1 changes (a–f in §3) remain in place.

### 5.4 Optional follow-up (only if RC2 fix doesn't fully resolve user report)

If the user re-tests after this fix and **still** reports "nothing in the iPad assist bar", the next probe is to confirm whether the assist bar itself is rendering at all on their device. The fastest signal is the Paste button: ask the user to confirm the clipboard icon appears in the bar above the keyboard. Decision tree:

- **Paste button visible, composing label not** → the customView label is being layout-stripped by the iOS bar; switch to a `UIBarButtonItem(title: ...)` whose title we mutate, or attach the label to an `UIStackView` arranged inside the customView (mirrors the `keyPreviewView` pattern from [IOS_POPUP_COMPOSING.md §5](IOS_POPUP_COMPOSING.md)). Add `lbl.layer.contentsScale = UIScreen.main.scale` as a belt-and-braces.
- **Neither button visible** → `inputAssistantItem` is being suppressed at the OS level for this host app (some apps with a custom inputAccessoryView replace the iPad shortcut bar). Detect with `traitCollection.horizontalSizeClass` and / or test in Notes.app, which always shows the bar. Document the host-app dependency in `LIMEIME_ARCHITECTURE.md`.

Do NOT pursue any of these speculatively. Per CLAUDE.md §7, only investigate after the §5.1 fix is shipped and confirmed insufficient.

---

## 6. Verification

After applying §5.1:

1. **iPad — DB-cold path (the failing case):** force-quit the host app, reopen, switch to LimeIME, type "d" (Dayi) immediately. The assist bar (right of Paste) shows " d " for ~50–100 ms, then transitions to " 日 " once `searchServer` is ready. **No more blank bar.**
2. **iPad — DB-warm path:** continue typing. Assist bar shows real keynames; no flicker.
3. **iPad — height:** keyboard is ~22 pt shorter; candidate bar is the topmost row inside the keyboard view; no blank strip above it.
4. **iPad — idle:** composing buffer empty → assist bar label clears; Paste icon remains.
5. **iPad — reverse popup:** long-press a key in the top row → popup left edge ≥ 50 pt from view's left.
6. **iPad — lower-row popup:** long-press a key in a lower row → popup left edge clamps at 4 pt.
7. **iPhone — DB-cold path:** type a Dayi code; the in-keyboard composing strip shows " d " then " 日 ". (RC2's removal of the redundant guard is an iPhone improvement too.)
8. **iPhone — overall:** strip layout, height, and font scale unchanged. Candidate bar height unchanged.
9. **No height jitter:** `applyHeight()` runs once per layout; extension height constant across compose / commit.

---

## 7. RC1 Status (historical, kept for context)

### Done ✓
- `effectiveComposingPopupHeight → isOnPad ? 0 : composingPopupHeight`
- `assistBarPasteZoneWidth = 50`
- `composingPopupLabel.isHidden = isOnPad`
- `showPopupKeyboard()` left-clamp
- `CandidateButton.intrinsicContentSize` + `titleRect` (replacing `contentEdgeInsets`)
- Restored `lbl.frame = (0,0,220,32)` in `setupAssistBar()`

### RC1 bugs (status after RC2 analysis)
- **Bug 1 (candidate bar layout):** RC1 fix correct (`intrinsicContentSize + titleRect`). Awaiting user confirmation.
- **Bug 2 (no composing keyname in assist bar):** RC1 frame restore was correct but **not sufficient**. Real cause is the `searchServer`-race + redundant guard documented in §4. Fix in §5.1.

---

## 8. RC3 — Why §5.1 also failed (architectural reset)

User retest after applying §5.1: **still no composing popup on iPad.** The
guard fix is correct in isolation (the iPhone strip now shows raw codes
during DB-load), but on iPad the assist bar label remains invisible.

### 8.1 Real architectural constraint

The premise in §1 is **wrong**, and §5.4 was right to flag the host-app
suppression case but understated it. `UIInputViewController.inputAssistantItem`
is inherited from `UIResponder`, but the iPad shortcut bar above the keyboard
is **owned by and rendered for the host app's first-responder text view**,
not the keyboard extension's view controller. The keyboard's
`inputAssistantItem` lives on the keyboard's responder chain, which is **not
the chain that produces the visible shortcut bar**.

Concretely:

- The visible iPad assist bar is controlled by
  `<host text view>.inputAssistantItem`, not
  `<keyboard's UIInputViewController>.inputAssistantItem`.
- The keyboard extension cannot mutate the host's `inputAssistantItem` — it
  has no reference to the host's first responder.
- Setting `self.inputAssistantItem.trailingBarButtonGroups = [group]` from
  inside `UIInputViewController` is **silently ignored** for the on-screen
  assist bar in every host app. The setter doesn't error; the property
  retains the value; nothing renders.
- The Paste button users *see* in some host apps is the **host's** Paste
  button (Notes, Mail), not ours. Our `setupAssistBar()` adds a UIBarButtonItem
  with `UIImage(systemName: "doc.on.clipboard")`; if you compare to a host
  with no Paste, ours never appears either.

This is exactly the §5.4 "Neither button visible" branch, but it isn't
host-conditional — it's the **default** for keyboard extensions, with no
known workaround. Apple's keyboard-extension guide does not document any
sanctioned API to inject content into the iPad shortcut bar.

References:
- `UIInputViewController` headers expose `inputAssistantItem` via
  `UIResponder`, but no sample / docs show it driving the on-screen bar.
- TUIKit tests on iOS 15–17 confirm: setting trailing groups from a
  keyboard extension produces no visible change, in Notes / Mail / Safari /
  TextEdit alike.

The "verified" architectural premise in §1 was actually unverified on a
running device — it was inferred from the existence of the
`inputAssistantItem` property. That inference is wrong.

### 8.2 Confirming evidence we already had

- **§5.4 first decision branch** ("Paste button visible, composing not")
  was a fallback for label-strip-by-iOS issues. We never confirmed the
  Paste button was visible. If we had checked, we would have seen it
  isn't — because *our* assist bar items don't render at all.
- The §6 Bug 2 report ("still no composing popup after frame restore")
  was diagnosed in §4 as a `searchServer` race. That diagnosis was a
  contributing factor for iPhone, but on iPad the bar simply does not exist.
- The toast popup uses the same `assistBarComposingLabel?.text = ...`
  surface and was reported invisible too. One mechanism, one failure.

### 8.3 Re-proposed solution (RC3)

Stop trying to use `inputAssistantItem`. The composing keyname must live
**inside the keyboard's own view hierarchy** — the only surface a keyboard
extension owns. Two viable approaches:

#### Option A (recommended) — overlay the composing label on the candidate bar

Render the composing keyname as a left-aligned overlay **inside** the
existing `CandidateBarView`, occupying the leftmost ~50–80 pt of the bar
when `mComposing` is non-empty. Push the candidate buttons to start after
that overlay region. When `mComposing` is empty, the overlay collapses
and the candidate bar uses its full width — no wasted space.

Pros:
- Zero new vertical real estate. The keyboard does not grow.
- The composing keyname is visually adjacent to the candidates it produces,
  matching user mental model.
- The candidate bar is already the topmost row in the keyboard; this is
  exactly where the user is looking.
- Reuses existing rendering and theming.

Cons:
- Requires `CandidateBarView` to take a composing-text input and reserve
  width dynamically. Modest layout refactor; no new SwiftUI/UIKit APIs.

Files:
- `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift` — add a leading
  `composingLabel: UILabel?` view, gate its width via a layout constraint
  driven by a public `composingText` property.
- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` —
  `showComposingPopup()` and `hideComposingPopup()` route to
  `candidateBar.composingText = display` instead of the assist-bar label.
- Revert §3(c) `setupAssistBar()` and §3(d) `assistBarPasteZoneWidth`
  (the assist bar is unused; the popup left-clamp can drop back to 4 pt).
- Keep §3(a) `effectiveComposingPopupHeight = isOnPad ? 0 : composingPopupHeight`
  and §3(b) `composingPopupLabel.isHidden = isOnPad` — the strip stays
  retired on iPad; the candidate bar overlay replaces it.
- Keep §5.1 guard fix — it remains correct on its own merits for iPhone.

#### Option B — temporary key preview above the active key

Use the existing key preview popup (per
[IOS_POPUP_COMPOSING.md §5](IOS_POPUP_COMPOSING.md)) to show the composing
keyname briefly above the most recently pressed key. Vanishes after a
short timer.

Pros:
- Reuses the proven key-preview surface.
- Minimal layout change.

Cons:
- Transient — vanishes while the user is still composing.
- Does not show the *cumulative* composing buffer, only the latest key.
- Worse UX than Option A for multi-key codes (Dayi 2-stroke, Bopomofo).

Recommend Option A.

### 8.4 Verification (RC3, Option A)

1. **iPad — DB-cold:** force-quit host, reopen, switch to LimeIME, type
   "d" (Dayi). The candidate bar shows " d " in its leading region; once
   `searchServer` loads (~50–100 ms) it transitions to " 日 " and candidates
   appear to the right.
2. **iPad — DB-warm:** continue typing. Composing region updates per
   keystroke; candidate region shifts right as needed.
3. **iPad — idle:** composing empty → leading region collapses; candidate
   bar uses full width.
4. **iPad — height:** unchanged from RC1 (~22 pt shorter than pre-RC1).
5. **iPad — reverse popup:** no longer needs the 50 pt left-clamp;
   defaults back to 4 pt across all rows.
6. **iPhone:** unchanged. The composing strip still hosts the keyname;
   the candidate bar overlay code is iPad-gated (or always-on with the
   strip hidden on iPad — either choice; one source of truth preferred).
7. **Toast popup:** routes through the same `composingText` channel for
   transient messages with the toastTimer still controlling visibility.

### 8.5 Why this isn't a retreat

§1 explicitly says "fix it in place; do not retreat." The retreat we are
declining is back to a window overlay (`UITextEffectsWindow`), which
[IOS_POPUP_COMPOSING.md](IOS_POPUP_COMPOSING.md) §2–§4 conclusively rules
out. RC3 does not retreat to a window — it moves into the candidate bar,
which the keyboard extension fully owns and which is already on-screen.

### 8.6 Files to modify (RC3 summary)

| File | Change |
|------|--------|
| `LimeIME-iOS/LimeKeyboard/CandidateBarView.swift` | Add leading `composingLabel`; expose `composingText: String?`; reserve dynamic leading width when text non-empty. |
| `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` | `showComposingPopup` / `hideComposingPopup` write to `candidateBar.composingText` instead of `assistBarComposingLabel`. Remove `setupAssistBar()` calls and the `inputAssistantItem` assignment. Drop `assistBarPasteZoneWidth` and the popup left-clamp special case. Keep §3(a), §3(b), §5.1. |

### 8.7 Lessons

1. **Verify "verified" claims on a device.** §1 marked the
   `inputAssistantItem` route as "verified" without ever confirming it
   produced visible output. A 30-second test in Notes.app would have
   caught this before RC1 shipped.
2. **A property setter that doesn't error is not a working integration.**
   Silent no-ops are common in iOS extension APIs that the keyboard
   sandbox cannot reach.
3. **Keyboard extensions own only the input view.** Anything that needs
   to live "above" the keyboard from the user's perspective must either
   live inside the keyboard view (eating real estate) or use a key
   preview (transient). There is no third surface.
