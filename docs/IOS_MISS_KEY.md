# iOS LimeKeyboard — Missed-Key Investigation & Fix Plan

## Symptom (reported)

When the user types fast, the keyboard occasionally drops a keypress in the middle of a run. The missed keystroke is silent — no character is inserted and no composing-popup tick is emitted for it — even though the user's finger clearly contacted the key.

Initially this was attributed to the haptic feedback path (see [docs/IOS_HAPTIC.md](IOS_HAPTIC.md)). After fixing the haptic generator pattern (pre-warmed stored generator + 25 ms throttle), the missed-key symptom **persists**, and a sharper observation rules haptics out as the dominant cause:

> Symbol keys never miss. Only compose keys miss.

Both kinds of key fire the same `fireHaptic()` at `.touchDown` (see [LimeIME-iOS/LimeKeyboard/KeyboardView.swift:953](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift#L953)). If haptics were starving touch dispatch, symbol keys would miss too. They don't — so the differentiator must be something that **only compose keys do**.

## What is different about a compose key

A symbol-key tap calls `insertText`/`deleteBackward` directly through `UITextDocumentProxy` and is done. No DB hop. No candidate reload. Main-thread time per tap ≈ haptic + button press-state colour flip.

A compose-key tap routes through [`KeyboardViewController.updateCandidates()`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1381-L1469):

```
keyUp → keyboardKeyTapped → didPress → onKey(primaryCode:) → handleCharacter(code)
      → mComposing.append(...)                                  [main, sync, cheap]
      → updateCandidates()
            → showComposingPopup()                              [main, sync, visible work]
            → DispatchQueue.global(.userInteractive).async {
                  ss.getMappingByCode(code, …)                  [bg, SQLite]
                  DispatchQueue.main.async {
                      setSuggestions(results)                   [main, HEAVY]
                  }
                  // optional second hop for stage-2 truncation:
                  ss.getMappingByCode(code, getAllRecords: true) [bg, SQLite]
                  DispatchQueue.main.async {
                      applyFullCandidateResults(...)             [main, medium]
                  }
              }
```

The two main-thread chunks that come back later — `setSuggestions(...)` and `applyFullCandidateResults(...)` — are what symbol keys do not have. Inside `setSuggestions` the dominant cost is `CandidateBarView.rebuildButtons()`.

## The hot spot — `CandidateBarView.rebuildButtons()`

[`CandidateBarView.swift:629-664`](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift#L629-L664):

```swift
private func rebuildButtons() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    candidateButtons.removeAll(keepingCapacity: true)

    for (index, mapping) in candidates.enumerated() {
        let btn = makeCandidateButton(mapping: mapping, index: index)
        stackView.addArrangedSubview(btn)
        btn.heightAnchor.constraint(equalTo: stackView.heightAnchor).isActive = true
        candidateButtons.append(btn)
        applyHighlightStyle(button: btn, index: index, mapping: mapping)
    }
    // … plus visibility-flag updates for the bar chrome …
}
```

Per stroke this:

1. Tears down **every** existing candidate cell (`removeFromSuperview` × N).
2. Allocates **N** fresh `UIButton`s.
3. `addArrangedSubview` × N — each call invalidates the `UIStackView`'s layout.
4. Activates a fresh `heightAnchor.constraint(equalTo:)` per button — each constraint activation walks the AutoLayout graph again.
5. Applies highlight styling to each.

For N = 20–50 candidates this is a real chunk of synchronous main-thread time. It runs **every stroke**, even when 80–100 % of the candidates are unchanged from the previous stroke (which is the common case during composition — a new stroke usually just appends one row, the rest of the list is the same).

[docs/IOS_PROFILING.md §4.2](IOS_PROFILING.md) already names this hot spot — it just doesn't prescribe the fix.

## Why this drops touches

`rebuildButtons()` runs on the main thread. While it is executing, the main runloop **cannot dispatch the next `.touchDown`/`.touchUp`**. UIKit buffers incoming touch events.

Two coalescing/dropping modes can then bite:

1. **Hit-test against a frame that is changing.** `addArrangedSubview` invalidates layout on the candidate bar; if a touch's hit-test runs against a partially-laid-out view tree, the result is undefined.
2. **`touchBegan`/`touchEnded` pair compression.** If a user's quick finger-tap produces both `.touchBegan` and `.touchEnded` while the main thread is mid-rebuild, UIKit can merge / drop them in the dispatch queue — the keyboard button never sees a complete press cycle, so `keyDown` and `keyUp` never fire, so `fireHaptic` and `didPress` don't either. From the user's point of view: silently swallowed.

Mode (2) explains why the user sees **no haptic and no character output** for the missed key, not a half-finished one.

## What we can do — in priority order

### P1 — Diffable rebuild instead of teardown-and-rebuild

**Largest single win.** Convert `rebuildButtons` to a diff-based update:

- Reuse existing `UIButton` cells in place (update title, tag, highlight only).
- Allocate new cells only when the new candidate list is longer than what's already on screen.
- Remove trailing cells when the new list is shorter.
- Activate the height constraint **once** per cell at allocation time, never again.

Sketch:

```swift
private func setCandidates(_ next: [Mapping]) {
    candidates = next

    // Grow: allocate any new cells needed at the tail.
    while candidateButtons.count < next.count {
        let i = candidateButtons.count
        let btn = makeCandidateButton(mapping: next[i], index: i)
        stackView.addArrangedSubview(btn)
        btn.heightAnchor.constraint(equalTo: stackView.heightAnchor).isActive = true
        candidateButtons.append(btn)
    }
    // Shrink: hide / remove the tail.
    while candidateButtons.count > next.count {
        let last = candidateButtons.removeLast()
        last.removeFromSuperview()
    }
    // Update in place — cheap.
    for (i, mapping) in next.enumerated() {
        configure(candidateButtons[i], mapping: mapping, index: i)
        applyHighlightStyle(button: candidateButtons[i], index: i, mapping: mapping)
    }
    updateChromeVisibility(hasCandidates: !next.isEmpty)
}
```

Common-case cost per stroke drops from "N button allocations + N constraint activations + N `addArrangedSubview`" to "0–2 allocations + N label updates" — typically a ~10× reduction. The main thread frees up enough for queued touches to drain.

### P2 — Defer the reload one runloop tick

**Quickest experiment, ships in one line.** In [`updateCandidates()`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1426-L1443), the stage-1 result currently runs `setSuggestions` synchronously inside the `DispatchQueue.main.async` block. Wrap that block's body in a second `DispatchQueue.main.async`:

```swift
DispatchQueue.main.async { [weak self] in
    DispatchQueue.main.async { [weak self] in        // <— extra hop
        guard let self = self, self.currentSearchID == sid else { … }
        results.isEmpty ? self.clearSuggestions() : self.setSuggestions(results)
    }
}
```

One runloop hop = invisible to the user (the candidate bar updates ~16 ms later) but gives UIKit one full iteration to dispatch any queued `touchDown`/`touchUp` events **before** the heavy reload locks the main thread again.

If this alone substantially reduces dropped keys it confirms the main-thread-starvation hypothesis. If it does not, P1 is still needed but the root cause is elsewhere and we should profile before changing more code.

### P3 — Don't call `showComposingPopup` twice per stroke

[`KeyboardViewController.swift:1397`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1397) calls it eagerly for T1 latency; [`KeyboardViewController.swift:1521`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift#L1521) calls it again inside `setSuggestions`. The second call is only useful when `mComposing` changed between the two — which it usually didn't, since the DB query doesn't alter `mComposing`. Skip the second call when `mComposing` is unchanged.

Small saving, but every freed millisecond of main-thread time helps.

### P4 — Pre-cache the candidate-cell height constraint

Once P1 lands, the cell list grows/shrinks in place. The height constraint is then created once per cell and stays installed for the cell's lifetime. AutoLayout never re-walks it per stroke. Comes for free with P1.

### P5 — Capture a baseline trace before changing more code

`docs/IOS_PROFILING.md` §3 has the workflow wired (`Stroke`, `CandidateReload`, `ComposingPopup`, `CandidateSwap` signposts). On the WJIP17 device, record one fast-typing burst trace and confirm:

- `CandidateReload` p95 dominates the inter-stroke gap (expected on the current code).
- After P2 ships, `CandidateReload` still dominates — but is now off the main runloop's "dispatch touches" hot path because the deferred-hop pattern gives touches priority. The dropped-key rate falls.
- After P1 ships, `CandidateReload` p95 itself shrinks.

Per `docs/IOS_PROFILING.md` §5: don't apply optimisations beyond P2 until a trace shows the budget is being exceeded.

## Recommended sequencing

1. **Ship P2** as a same-day experiment on the WJIP17 device. One-line change, fully reversible.
2. **Test fast-typing burst** with the existing typing-pad / Notes app. Confirm whether dropped keys reduce.
3. If P2 reduces drops:
   - Capture a baseline `Stroke` / `CandidateReload` trace per [docs/IOS_PROFILING.md](IOS_PROFILING.md) §3.
   - Implement P1 (diffable rebuild).
   - Re-capture trace, compare `CandidateReload` p95.
4. If P2 does **not** reduce drops:
   - Stop guessing. Capture the trace first. The hypothesis is wrong somewhere.
   - Possible alternates to investigate: (a) gesture-recognizer interactions with the candidate-bar pan/scroll, (b) `cancelsTouchesInView` settings on the keyboard's gesture recognizers, (c) `UIInputViewController` host-app coalescing under fast input.

## What this plan deliberately does NOT do

- **Does not change the touch path itself.** `keyDown/keyUp` already use `.touchDown` / `.touchUpInside` which is the fastest UIKit can dispatch. Adding lower-level `touchesBegan` overrides would not help.
- **Does not move the haptic off main.** That change is already shipped (see [docs/IOS_HAPTIC.md](IOS_HAPTIC.md)). Symbol keys with haptic on confirm haptic is not the bottleneck for missed keys.
- **Does not introduce a touch-coalescing queue.** UIKit already does that correctly when the main thread isn't blocked. The fix is to **stop blocking the main thread**, not to add a parallel touch queue.

## Verification once both P1 and P2 are in

- Type a long fast burst (e.g. `wo3jiao4li2ming2wo3jiao4li2ming2…`) at maximum speed on the WJIP17 device, with haptic on, and confirm every keystroke produces a haptic tick and a character/compose update — zero silent drops.
- Compare side-by-side with the iOS system keyboard for any residual perceptual difference.
- Capture an Instruments trace and confirm `CandidateReload` p95 is < 10 ms.

## Session log

### 2026-05-21 / 2026-05-22 — P2 applied; diagnostic counter attempted but inconclusive

**P2 applied** at [`KeyboardViewController.updateCandidates()`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) — extra `DispatchQueue.main.async` hop wrapping the stage-1 reload, with stale-stroke check re-done inside the inner block. Compiles clean (BUILD SUCCEEDED on iPhone 17 Pro iOS 26.5 simulator). Deployed to the WJIP17.

**Result of P2 on device: drops still occur.** Per the doc's own "If P2 does not reduce drops" guidance, this means main-thread starvation from `CandidateReload` is **not the dominant cause** — the reload is heavy but is not what blocks the next touchDown. The bottleneck must be earlier on the compose path. Most likely candidate: the **synchronous chain inside `keyDown`** —

```
keyDown → fireHaptic → didPress → onKey → handleCharacter → updateCandidates → showComposingPopup()
```

`showComposingPopup()` runs synchronously on the main thread *before* the DB query is dispatched. It does:

- `searchServer?.keyToKeyname(code)` — synchronous call into `LimeDB.keyToKeyName(...)` ([SearchServer.swift:116-119](../LimeIME-iOS/Shared/Search/SearchServer.swift#L116-L119)) which holds a per-table cache but takes a lock + map lookup
- `candidateBar.composingText = display` — fires `applyComposingText()` ([CandidateBarView.swift:476-483](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift#L476-L483)) which mutates a label and calls `bringSubviewToFront`
- `expandedComposingLabel?.attributedText = …` — NSAttributedString allocation per stroke

This entire chain blocks the touch dispatcher just like `rebuildButtons()` does — but P2 didn't touch it. **A natural next experiment is to defer `showComposingPopup()` itself one runloop tick** (or move only the UI-update half off-main while keeping `mComposing` correctness eager).

### Diagnostic probe attempt — no logs observed

Added three `os_log` calls (`keyDown`, `touchCancel`, `handleChar`) tagged `subsystem:tw.jeremy.limeime category:misskey`. After deploy to the WJIP17, Console.app showed no entries. Suspects:

1. **`type: .info` is filtered to disk by default** — fixed mid-session by switching to `.default`, but no retest before sign-off.
2. **Extension binary cached** — installing the LimeIME app via Xcode does not always swap the keyboard extension's running binary. The Console-empty result is consistent with the keyboard still running the *pre-probe* build. **Reliable refresh on iOS:** remove the LimeIME app from the home screen, then reinstall via the LimeIME scheme. Also disable + re-enable the keyboard in Settings → General → Keyboards.
3. **Console filter syntax** — try plain text `misskey` instead of `subsystem:tw.jeremy.limeime` if the structured filter shows nothing.
4. **NSLog fallback** — if `os_log` continues to produce nothing after a clean reinstall, swap to `NSLog("[misskey] keyDown code=%d", code)`. NSLog uses the legacy logging system, always streams to Console, no level filtering.

All three probes have been reverted at end of session — re-add via the markers in the next session's first 5 minutes.

### Important gotcha — Xcode scheme selection

**Always launch via the LimeIME scheme. Never the LimeKeyboard scheme.**

The LimeKeyboard scheme attaches the debugger directly to the keyboard extension process. On iOS 26.x device the debugger-attached path produces a hard crash on **switching to Chinese mode**:

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
    reason: '-[_NSXPCDistantObject ___nsx_pingHost:]: unrecognized selector
            sent to instance 0x103188730'
```

This is the same family as the iOS 26 simulator §10 fault in [docs/IOS_PROFILING.md](IOS_PROFILING.md#10-ios-26-simulator-blocker-verified-may-2026) — the XPC inspection layer that gets injected when a debugger is attached to a keyboard extension calls a selector the extension's `NSXPCInterface` does not implement. Apple's own keyboard extensions reportedly have the same crash under the same setup. **Not a real-user bug**; runs cleanly when the extension is unattended.

**The LimeIME scheme puts the debugger on the settings app** and lets the keyboard extension run unattended — same way it runs for end users. No `nsx_pingHost:` crash; missed-key behaviour can be observed normally.

### Pre-existing constraint conflict (separate issue, non-fatal)

Reproducibly observed in console during keyboard layout:

```
"<NSLayoutConstraint UIInputView.height == 956 (UIView-Encapsulated-Layout-Height)>",
"<NSLayoutConstraint CandidateBarView.height == 63.8>",
"<NSLayoutConstraint UIView.height == 50> × 4 + <UIView.height == 54>",
"<KeyboardView.bottom == UIInputView.bottom>",
…
Will attempt to recover by breaking constraint <UIView.height == 54>
```

`UIInputView` is force-sized to 956 pt by `UIView-Encapsulated-Layout-Height`, but `CandidateBarView` (63.8 pt) plus the five rows of `KeyboardView` (50 + 50 + 50 + 50 + 54 = 254 pt) sum to only 317.8 pt. UIKit auto-recovers by stretching the bottom row.

None of this session's edits touch keyboard sizing — this is pre-existing. Likely fix candidates: change `KeyboardView.bottom == UIInputView.bottom` to `lessThanOrEqual`, or set `view.heightAnchor` constraint at a high priority so UIInputView shrinks to fit. **Out of scope for the missed-key investigation** — separate ticket.

## Next-session entry point

1. **Confirm reinstall protocol works.** Remove LimeIME from home screen, reinstall via LimeIME scheme, verify keyboard re-enabled in Settings. Without this, no diagnostic build will actually run on the device.
2. **Re-add the three `os_log` probes** (or fall back to `NSLog`). Grep markers: `DIAG: missed-key`.
3. **Reproduce the drop with Console streaming.** Count `keyDown` / `handleChar` / `touchCancel` lines vs visible characters → bucket the failure as per the table in the session-end summary.
4. If hypothesis (2) lights up — `keyDown` count = taps but `handleChar` < taps, or both = taps but characters < taps — apply the next targeted fix: **defer `showComposingPopup` one runloop tick** (mirror of P2 but on the eager half of the compose path) and re-test.
5. If hypothesis (1) lights up — `keyDown` count < taps — investigate gesture recognizers on candidate-bar pan / dual-row iPad / popup long-press; check `cancelsTouchesInView` settings.
6. If `touchCancel` lines appear during drops, that's hypothesis (3) — UIKit pre-empted; trace gesture-recognizer arbitration.
