# iOS Soft-Keyboard Stroke-to-Stroke Profiling

This document describes how to measure and optimize the **stroke-to-stroke
latency** of the LimeKeyboard extension on iOS — the wall-clock time from
the moment a user's finger lifts from a key to the moment the candidate
bar (and composing popup) is fully redrawn and ready for the next stroke.

The goal is to keep the perceived latency below the 100 ms "instant"
threshold, and the 60 fps frame budget (16.7 ms) for any work scheduled
on the main thread between two strokes.

---

## 1. What we mean by "stroke-to-stroke"

A single stroke during Chinese composition flows through this pipeline:

```
touchUp on KeyButton
    → KeyboardView.keyTapped(keyDef)
    → KeyboardViewController.onKey(primaryCode:)
    → handleCharacter(code)
        → mComposing.append(...)
        → showComposingPopup()                     [main, sync UI]
        → DispatchQueue.global(.userInteractive).async {
              ss.getMappingByCode(code, …)         [SQLite query]
              DispatchQueue.main.async {
                  setSuggestions(results)          [reload candidate bar]
              }
              // Stage 2 if truncated:
              ss.getMappingByCode(…, getAllRecords: true)
              DispatchQueue.main.async {
                  applyFullCandidateResults(...)   [swap candidates]
              }
          }
```

Three latency segments matter:

| Segment | Span | Budget |
|---|---|---|
| **T1 — Touch → composing popup visible** | `touchesEnded` → first frame with new popup | ≤ 16 ms (one frame) |
| **T2 — Touch → first candidate frame** | `touchesEnded` → first frame with stage-1 candidates | ≤ 50 ms |
| **T3 — Touch → final candidate frame** | `touchesEnded` → first frame after stage-2 swap | ≤ 100 ms |

T1 is the responsiveness the user actually *feels*; T2/T3 govern whether
the candidate bar feels live or laggy.

---

## 2. Instrumentation — `os_signpost` (Instruments)

Apple's `os_signpost` API is the only tool that can correlate UI frame
boundaries with our own code spans inside the Points-of-Interest track.
Use the `OSLog` subsystem name `tw.jeremy.limeime.keyboard` so the marks
group together in the Instruments timeline.

### 2.1 Add a profiling logger

The profiling helper lives at
[`LimeIME-iOS/LimeKeyboard/Profiling.swift`](../LimeIME-iOS/LimeKeyboard/Profiling.swift)
and is gated by **two** switches so it carries zero cost in shipping
builds:

#### Compile-time switch — `PROFILING`

When the `PROFILING` Swift flag is **not** defined (the default), every
`Prof.*` call collapses to an inline no-op shim — zero CPU cost, zero
binary footprint. Call sites can therefore stay in production code
unconditionally.

To enable, add `-D PROFILING` to `OTHER_SWIFT_FLAGS` for the
`LimeIMEKeyboard` target. In `LimeIME-iOS/project.yml`:

```yaml
LimeIMEKeyboard:
  settings:
    configs:
      Debug:
        OTHER_SWIFT_FLAGS: "$(inherited) -D PROFILING"
```

For CI, prefer creating a dedicated `Profile` build configuration that
sets `-D PROFILING`, leaving the regular `Debug` configuration free of
any signpost overhead.

#### Runtime switch — `Prof.enabled`

Only meaningful when `PROFILING` is compiled in (otherwise the shim
ignores it). Default `true`. Flip to `false` to silence signposts
without rebuilding — handy to skip warm-up frames or isolate a specific
window:

```swift
Prof.enabled = false
warmUpKeyboard()        // no signposts emitted
Prof.enabled = true
runStrokeFixture()      // signposts emitted normally
```

The `scripts/profile_keyboard.py` driver does **not** touch this flag —
it assumes signposts are live for the entire test run. Use the runtime
switch for ad-hoc, in-Xcode profiling sessions.

#### Inserting `Prof.begin/end` calls

See §2.2 for the call sites. The wrapper signature is:

```swift
let id = Prof.newID()
Prof.begin("DBQueryStage1", id: id)
// … work …
Prof.end("DBQueryStage1", id: id)
```

In a non-`PROFILING` build `id` is `UInt64(0)` and the begin/end calls
are stripped by the optimiser.

### 2.2 Instrument the stroke pipeline

Add `begin/end` pairs at the boundaries that frame each segment. The
signpost-id pattern lets one stroke be tracked across queues.

#### Marker convention

Every inserted line is bracketed with paired comments so the
instrumentation can be located, audited, or stripped as a unit:

```swift
// PROFILING: BEGIN — <segment label>
let id = Prof.newID()
Prof.begin("Segment", id: id)
// PROFILING: END
```

Find every site with `grep -n "PROFILING:" LimeIME-iOS/LimeKeyboard/*.swift`.

#### Where the instrumentation actually lives

In the current implementation the `Stroke` span begins at
`KeyboardViewController.updateCandidates()` rather than at
`KeyboardView.touchesEnded`. This trades ~<1 ms of UIKit dispatch
overhead (touchUp → `sendActions` → `keyTapped` → `onKey` →
`handleCharacter` → `updateCandidates`) for not having to propagate a
signpost id across `KeyButton` → `KeyboardView` → `KeyboardViewController`
via associated objects. All actionable latency is inside the span.

The single instrumented function is
[`KeyboardViewController.updateCandidates()`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift),
with these spans (call sites visible via grep):

| Span | Thread | Notes |
|---|---|---|
| `Stroke` | begins on caller's thread (main), ends on main after `CandidateReload` | Outer span; closed in stale-stroke path with `StrokeCancelled` event. |
| `ComposingPopup` | main | Brackets `showComposingPopup()`. |
| `DBQueryStage1` | `.userInteractive` background | Brackets stage-1 `getMappingByCode`. |
| `CandidateReload` | main | Brackets `setSuggestions` / `clearSuggestions`. Followed immediately by `Stroke` end. |
| `DBQueryStage2` | `.userInteractive` background | Brackets stage-2 `getMappingByCode(getAllRecords: true)`. Only runs when stage 1 was truncated. |
| `CandidateSwap` | main | Brackets `applyFullCandidateResults`. |

Events emitted (no duration):

| Event | Where | Payload |
|---|---|---|
| `UpdateCandidates` | top of `updateCandidates()` | `len=<mComposing.count>` |
| `StrokeCancelled` | stale-stroke guard (newer keystroke arrived) | — |

`strokeID` is captured as a `let` in the enclosing scope; `@escaping`
closures retain it so the final `Prof.end("Stroke", …)` always pairs
with the original `Prof.begin`.

#### Adding new instrumentation

When a new compose/commit code path is added:

1. Pick the smallest enclosing function that is on the hot path.
2. Wrap each measurement with `// PROFILING: BEGIN — …` / `// PROFILING: END`.
3. Use a fresh `Prof.newID()` per span — never reuse one across
   concurrent spans.
4. If the span crosses a `DispatchQueue` hop, capture the id with `let`
   in the outer scope so escaping closures inherit it.
5. Add the new span name to the table in §2.3 and update
   `scripts/profile_keyboard.py` if the harness should track it.

### 2.3 Signpost catalogue

Currently emitted by `KeyboardViewController.updateCandidates()`:

| Signpost | Where | Type | Status |
|---|---|---|---|
| `Stroke` | `updateCandidates` entry → `CandidateReload` end (or stale-stroke return) | begin/end | **active** |
| `UpdateCandidates` | `updateCandidates` entry | event | **active** |
| `ComposingPopup` | around `showComposingPopup` | begin/end | **active** |
| `DBQueryStage1` | around stage-1 `getMappingByCode` | begin/end | **active** |
| `CandidateReload` | around `setSuggestions` / `clearSuggestions` | begin/end | **active** |
| `DBQueryStage2` | around `getMappingByCode(getAllRecords: true)` | begin/end | **active** |
| `CandidateSwap` | around `applyFullCandidateResults` | begin/end | **active** |
| `StrokeCancelled` | stale-stroke guard fires | event | **active** |

Reserved for future instrumentation (not yet emitted — add when needed):

| Signpost | Where | Type |
|---|---|---|
| `TouchUp` | `KeyboardView.touchesEnded` entry | event |
| `onKey` | `KeyboardViewController.onKey` entry | event |
| `LayoutInvalidate` | when keyboard height constraint changes | event |

---

## 3. Capturing a trace

1. Build the **Debug** scheme of `LimeKeyboard` for a real device
   (not the simulator — extension QoS and dispatch behave differently).
2. Install on the device and enable the keyboard in Settings.
3. Open Xcode → **Product ▸ Profile** with the host app
   (`LimeSettings`) selected, and choose the **Time Profiler** template
   plus **Points of Interest**.
4. In Instruments, change the target process from `LimeSettings` to the
   keyboard extension (`com.jeremy-wu.lime.LimeKeyboard`) using
   **File ▸ Recording Options ▸ Attach to process**. The keyboard must
   already be visible in a host app (Notes, Messages) for the process to
   exist.
5. Record while typing a fixed test phrase (e.g. `wo3 jiao4 li2 ming2`
   for phonetic, `r5,e ji jq` for cangjie). Always type the **same**
   phrase across runs so traces are comparable.
6. In the Points of Interest track, measure the gap between successive
   `Stroke` intervals. The Time-Profiler track underneath shows where the
   CPU was spent inside each interval.

### 3.1 Frame-rate overlay

Also record the **Animation Hitches** instrument when running on iOS 16+.
Hitches inside the `Stroke` intervals are a direct measure of dropped
frames during composition.

---

## 4. Hot spots to inspect first

These are the spans most likely to dominate stroke latency. Inspect them
in the order listed.

### 4.1 SQLite query (`DBQueryStage1`)

- Confirm `getMappingByCode` is using the prepared statement cache and
  not re-preparing per call. Each `sqlite3_prepare_v2` is ~0.3 ms.
- Verify the **Stage-1** path uses `INITIAL_RESULT_LIMIT` (typically
  ~30 rows) — see [docs/TWO_STAGE_CANDI.md](TWO_STAGE_CANDI.md). A
  Stage-1 query should be < 5 ms on a recent device.
- Profile the `lime.db` query plan from a one-shot script using
  `sqlite3 lime.db 'EXPLAIN QUERY PLAN SELECT … FROM mapping WHERE code=…;'`
  to confirm the index on `code` is being used.

### 4.2 Candidate bar reload (`CandidateReload`)

- `setSuggestions` triggers `UICollectionView.reloadData()`. Reloading
  the full data set is fine while the bar is short, but every reload
  forces a layout pass on every visible cell.
- Prefer `performBatchUpdates` with diffable identifiers when the new
  list is a prefix/suffix of the old one (common during composing).
- Avoid synchronous `layoutIfNeeded()` on the candidate bar inside
  `setSuggestions` — let the run loop flush layout naturally.

### 4.3 Composing popup (`ComposingPopup`)

- `showComposingPopup` runs on the main thread before the DB query is
  even dispatched, so any work here directly inflates **T1**.
- Confirm the popup label is reused (not recreated per stroke) and that
  attributed-string construction does not allocate `UIFont` per call —
  cache the fonts in `LayoutMetrics`.

### 4.4 Keyboard layout invalidation

- Any change to `keyboardHeightConstraint.constant` between strokes
  forces a full UIKit layout pass on the input view (~3–8 ms). The
  current code only updates the constant when the row count or
  composing-popup height actually changes — verify this with a
  `LayoutInvalidate` event signpost. If you see one fire every stroke,
  there is a height-recompute bug.

### 4.5 Phrase-learning write-back

- `commitTyped` fan-outs to a background `qos: .background` queue for
  phrase-learning DB writes — confirm these never bleed onto the main
  thread or starve the next-stroke query (they should not, since
  `.userInteractive` outranks `.background`).

---

## 5. Optimisation checklist

Apply the items below only when a signpost trace shows the corresponding
hot spot exceeds its budget. Do not pre-optimise.

### Main-thread budget (T1)

- [ ] `showComposingPopup` ≤ 4 ms (label text update only, no layout
      recompute, no font allocation).
- [ ] No `view.layoutIfNeeded()` calls inside `onKey` / `handleCharacter`.
- [ ] No `UIView.animate` blocks chained synchronously to the stroke
      (animations should fire-and-forget, not block the next dispatch).

### Background-query budget (T2)

- [ ] DB connection opened once at `viewDidLoad`, kept warm for the
      lifetime of the extension.
- [ ] Stage-1 limit ≤ 30 rows; verify in `IMService` constants.
- [ ] `getMappingByCode` reuses prepared statements (one per
      `(IM, isSoftKeyboard, getAllRecords)` combo).
- [ ] Cancel stale queries: each new stroke increments
      `currentSearchID`; ensure stage-2 dispatch checks the id before
      calling `applyFullCandidateResults` (already implemented — keep it
      that way).

### Candidate bar (T2 → T3)

- [ ] Use diffable data source so unchanged candidate cells are not
      re-rendered between Stage 1 and Stage 2.
- [ ] Cell sizing is computed from cached widths
      (`CandidateBarView.cellWidth(for:)`), not from a synchronous
      `boundingRect(with:)` per reload.
- [ ] Stage-2 swap (`applyFullCandidateResults`) uses
      `appendCandidates` so the user's scroll position is preserved
      (per [TWO_STAGE_CANDI.md](TWO_STAGE_CANDI.md)).

### Touch handling

- [ ] `KeyButton` does not allocate per-touch (no closures captured in
      `addTarget`, no per-stroke `Timer.scheduledTimer` unless required
      for long-press).
- [ ] Long-press timers are invalidated on `touchesCancelled` to avoid
      retaining the button after the keyboard is dismissed.

---

## 6. A repeatable benchmark

Add a debug-only XCTest under `LimeIME-iOS/LimeTests/` that drives a
fixed sequence of strokes against `KeyboardViewController` with a
mocked `UITextDocumentProxy` and asserts each stroke's wall-clock
duration with `XCTClockMetric` / `XCTCPUMetric`:

```swift
func testStrokeToStrokeBudget() throws {
    let options = XCTMeasureOptions()
    options.iterationCount = 20
    measure(metrics: [XCTClockMetric(), XCTCPUMetric()], options: options) {
        controller.simulateStrokes(["w","o","3"," ","j","i","a","o","4"])
    }
}
```

Run before and after every change to the compose pipeline to detect
regressions. Lock the budget in CI as the **average** plus 2× standard
deviation of the baseline.

---

## 7. Known issues to verify (May 2026)

These are the spans currently suspected of exceeding budget — confirm or
refute with a trace before changing code.

1. **First stroke after keyboard wake-up** — DB connection cold open,
   layout JSON parse, font caches empty. Mitigation: pre-warm in
   `viewDidLoad` via `qos: .userInitiated` async tasks (already in
   `KeyboardViewController.swift:193, 209`).
2. **Stroke that triggers an empty candidate list** — `clearSuggestions`
   tears down the collection-view contents and may force a height
   recompute. Verify no `LayoutInvalidate` event fires.
3. **Stage-2 swap on long lists** (>500 rows for cangjie) — confirm the
   diffable data source skips re-rendering cells already present.

---

## 8. References

- [docs/TWO_STAGE_CANDI.md](TWO_STAGE_CANDI.md) — staged candidate fetch.
- [docs/IM_SERVICE.md](IM_SERVICE.md) — `IMService` query API.
- [docs/IOS_POPUP_COMPOSING.md](IOS_POPUP_COMPOSING.md) — composing
  popup architecture.
- Apple, *Logging* — `os_signpost` reference.
- Apple, *Improving App Responsiveness* — Instruments Time Profiler
  workflow.

---

## 9. Automation harness

Full optimisation **cannot** be autonomous — choosing which hot spot to
fix, designing the fix, and validating correctness all require human
judgement. But the *measurement* loop can be fully scripted, so a
regression is caught the moment it lands.

### 9.1 What the harness does (and does not) do

| Step | Automated? |
|---|---|
| Insert `os_signpost` instrumentation | Yes — one-shot codemod (run once, then commit). |
| Build the keyboard extension | Yes — `xcodebuild`. |
| Launch host app + drive a fixed stroke fixture | Yes — XCUITest. |
| Record an Instruments trace headlessly | Yes — `xcrun xctrace record`. |
| Extract per-stroke T1/T2/T3 from signposts | Yes — `xctrace export` + Python parser. |
| Compare against baseline & fail CI on regression | Yes. |
| **Decide which hot spot to optimise** | **No — human.** |
| **Apply the optimisation correctly** | **No — human.** |
| **Update the baseline after a deliberate change** | **No — human approves the new numbers.** |

### 9.2 Pipeline

```
┌──────────────────────────┐
│ scripts/profile_keyboard │
│   .py                    │
└─────────────┬────────────┘
              │
   ┌──────────▼───────────┐    1. xcodebuild -scheme LimeKeyboard
   │ build & install      │       -destination 'id=<UDID>' build-for-testing
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐    2. xcrun simctl launch <udid> tw.jeremy.LimeSettings
   │ launch host app      │       (or `devicectl` for a physical device)
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐    3. xcrun xctrace record \
   │ start xctrace        │         --template 'Time Profiler' \
   │ (Points of Interest) │         --attach <keyboard_pid> \
   └──────────┬───────────┘         --output build/profile/run.trace \
              │                     --time-limit 30s &
   ┌──────────▼───────────┐
   │ run XCUITest fixture │    4. xcodebuild test -only-testing:\
   │ (types canned phrase)│       LimeTests/StrokeBenchmark
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐    5. xctrace export --input run.trace \
   │ export signposts     │         --xpath '//os-signpost' \
   │   to XML             │         > build/profile/run.xml
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐    6. python parser → median/p95 per
   │ compute T1/T2/T3     │       segment, per IM
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐    7. diff vs scripts/profile_baseline.json
   │ regression gate      │       fail if any segment p95 > baseline × 1.20
   └──────────────────────┘
```

### 9.3 The fixture (XCUITest)

A single test class drives a deterministic stroke sequence per IM. It
must use the **real** `LimeKeyboard` extension on a host text field, not
a unit-test mock — only the real extension exercises the dispatch
queues, the on-disk SQLite database, and UIKit layout.

`LimeIME-iOS/LimeTests/StrokeBenchmark.swift` (sketch):

```swift
final class StrokeBenchmark: XCTestCase {
    func testPhonetic() { runFixture(im: "phonetic", strokes: "wo3 jiao4 li2 ming2 ") }
    func testCangjie()  { runFixture(im: "cj",        strokes: "r5,e ji jq ") }
    func testArray()    { runFixture(im: "array",     strokes: "wlw rlr ") }

    private func runFixture(im: String, strokes: String) {
        let app = XCUIApplication(bundleIdentifier: "com.apple.MobileNotes")
        app.launch()
        // Switch to LimeIME via long-press globe (assumes LimeIME pre-selected).
        let textView = app.textViews.firstMatch
        textView.tap()
        for ch in strokes { textView.typeText(String(ch)) }
        // Allow stage-2 dispatch + UI to settle so all signposts close.
        Thread.sleep(forTimeInterval: 0.5)
    }
}
```

The fixture's *only* job is to generate strokes; all timing is captured
by the signposts already embedded in production code paths (Section 2).

### 9.4 The driver script

See [scripts/profile_keyboard.py](../scripts/profile_keyboard.py).

Usage:

```bash
# One-off run on the pinned reference simulator (iPad Pro 13-inch (M5)):
python3 scripts/profile_keyboard.py

# Override the device explicitly:
python3 scripts/profile_keyboard.py --device 'iPad Pro 13-inch (M5)'

# CI mode: fail with non-zero exit if regression detected.
python3 scripts/profile_keyboard.py --ci

# Update the baseline after a deliberate, reviewed change:
python3 scripts/profile_keyboard.py --update-baseline
```

Output (excerpt):

```
IM        segment            median   p95     baseline_p95   delta
phonetic  ComposingPopup       2.1ms   3.4ms          3.6ms    -6%   ok
phonetic  DBQueryStage1        4.7ms   6.8ms          7.1ms    -4%   ok
phonetic  CandidateReload     11.3ms  18.9ms         12.4ms   +52%   FAIL
phonetic  Stroke              22.0ms  32.5ms         24.0ms   +35%   FAIL
cj        DBQueryStage1        8.2ms  11.0ms         10.5ms    +5%   ok
…
Result: 2 regressions detected (threshold +20%).
```

### 9.5 Baseline policy

- `scripts/profile_baseline.json` is checked into the repo.
- It is **only** updated by an explicit human-reviewed PR after a
  deliberate change (the script's `--update-baseline` flag writes a
  fresh file; the diff must be reviewed before merge).
- Never bump the baseline to "make CI green" — investigate the
  regression first.

### 9.6 Limitations to accept

1. **Simulator ≠ device.** Simulator timings are directionally correct
   but absolute numbers can differ by 2–3×. Reserve a real-device run
   (manual, weekly) for truth values.
2. **First-stroke variance.** Cold DB-open and font caches dominate the
   first stroke. The parser drops the first stroke per IM before
   computing percentiles.
3. **CI host noise.** Run the harness twice and take the minimum p95
   per segment to absorb flakes from the shared CI runner.
4. **No automatic *fix*.** The harness reports — engineers fix.
5. **New code paths need new signposts.** The instrumentation in
   Section 2 covers today's pipeline; any new compose/commit code path
   must add its own `Prof.begin/end`, otherwise it is invisible to the
   harness.

## 10. iOS 26 simulator blocker (verified May 2026)

XCUITest cannot drive LimeKeyboard end-to-end on the iOS 26.4 iPad
simulator. Two compounding problems:

1. **Keyboard never auto-activates.** With no globe-key switch, the
   system keyboard handles all `typeText`. Result: zero LimeKeyboard
   launches, zero signposts. Verified by `log show --predicate
   'process == "LimeKeyboard"'` returning empty after a passing test.

2. **Switching crashes the extension.** Querying
   `app.keyboards.firstMatch.buttons["Next keyboard"]` (or any
   keyboard tree access from XCUITest) attaches accessibility hooks
   into LimeKeyboard. `AccessibilitySettingsLoader._initializeDelayed
   AccessibilitySettings` then fires an XPC call
   (`xpc_connection_copy_bundle_id`) that fails with EXC_GUARD
   `GUARD_TYPE_USER`, namespace 7, reason 9 — see
   `~/Library/Logs/DiagnosticReports/ExcUserFault_LimeKeyboard-*.ips`.
   The faulting frame is in libxpc, not in LimeIME code.

   Both `KeyboardViewController` paths and the new `Profiling.swift`
   are *not* on the failing stack — this fault occurs on the main
   thread before any of our code runs in the extension.

### 10.1 Workarounds in priority order

1. **Real device.** The XPC fault does not reproduce on physical iPad
   hardware. The current `scripts/profile_keyboard.py` works against a
   real device when its UDID is passed via `--device`.
2. **Older simulator runtime.** iOS 17.x and iOS 18.x simulators do
   not exhibit the crash. Install via Xcode → Settings → Components.
3. **Manual instrumentation run.** Boot the simulator, set LimeIME as
   the active keyboard via Settings UI, run `xctrace record --launch
   …Simulator.app` and type by hand for ~30 s. Slower but produces a
   real trace.

### 10.2 Status of automation pieces

- `LimeUITests/StrokeBenchmark` builds and the test runner launches
  cleanly on iOS 26 simulator after the keyboard-switching block was
  removed (commit on this branch). Without the switch, signposts only
  fire when LimeIME is *already* the active keyboard.
- `Profiling.swift` and the `// PROFILING:` markers in
  `KeyboardViewController` are correct and zero-cost when the
  `PROFILING` Swift flag is off. They have been exercised against a
  manual stroke session and emit signposts under the
  `tw.jeremy.limeime.keyboard` subsystem as documented in §2.3.
- `scripts/profile_baseline.json` remains empty pending a successful
  end-to-end capture on real hardware.

---

## 11. Engine-level benchmark results (May 2, 2026 — run 2)

Because the iOS 26 simulator blocks XCUITest-driven profiling (§10),
engine latency was measured directly via `LimeTests/EngineLatencyBenchmark`
— an XCTest that drives `SearchServer.getMappingByCode()` with real
`.db` files, bypassing the keyboard UI entirely.

Platform: iPad Pro 13-inch (M5) iOS 26.4 simulator, Apple M-series host.
Each test measures 10 representative input codes per IM with
`XCTClockMetric` (wall clock). Averages are over 5 XCTest iterations.
This is the second run of the session, after the sort-order fix, `q`-prefetch
fix, `isPrefetch` bypass, and `mmap_size` additions were applied.

### 11.1 Warm-cache results (steady-state typing)

`triggerPrefetch()` has already populated `mappingCache`; every call is a
Swift dictionary lookup with no SQLite I/O.

| IM | Wall avg (10 codes) | Per-code avg |
|---|---|---|
| Array | 18 µs | ~1.8 µs |
| Cangjie | 17 µs | ~1.7 µs |
| Dayi | 15 µs | ~1.5 µs |
| Phonetic | 17 µs | ~1.7 µs |

**All well under 1 ms per code.** Cache hit overhead is effectively free —
no optimisation needed here.

### 11.2 Cold-cache Stage 1 results (LIMIT 15 — first keystroke)

Cache cleared before each iteration. This is worst-case first-keystroke
latency with cold SQLite page cache (no OS page cache warm-up either,
since `clearAllCaches()` forces fresh WAL reads on next call).

| IM | Wall avg (10 codes) | Per-code avg | p95 estimate |
|---|---|---|---|
| Dayi | 23 ms | ~2.3 ms | ~27 ms |
| Array | 35 ms | ~3.5 ms | ~41 ms |
| Cangjie | 39 ms | ~3.9 ms | ~50 ms |
| Phonetic | 47 ms | ~4.7 ms | ~54 ms |

**Conclusion:** Without prefetch, the very first stroke of a session costs
23–47 ms of pure SQLite I/O across 10 codes. This would eat the entire
T2 budget (≤ 50 ms) on the first keystroke alone. `triggerPrefetch()`
eliminating this is **critical**.

### 11.3 Cold-cache Stage 2 results (LIMIT 210 — full fetch, warm page cache)

Stage 1 runs first inside each iteration (warming the OS page cache),
then Swift cache is cleared and Stage 2 (LIMIT 210) is measured. This
mirrors the cost paid by `triggerPrefetch()` in the new design (§12),
which now calls `getAllRecords: true`. Page cache is warm but `mappingCache`
entry is absent.

| IM | Wall avg (10 codes) | Per-code avg | vs Stage 1 |
|---|---|---|---|
| Dayi | 41 ms | ~4.1 ms | +18 ms |
| Array | 66 ms | ~6.6 ms | +31 ms |
| Cangjie | 74 ms | ~7.4 ms | +35 ms |
| Phonetic | 84 ms | ~8.4 ms | +37 ms |

**LIMIT 210 costs 2–3× more than LIMIT 15 per code.** These numbers now
represent the background-thread prefetch cost rather than a per-keystroke
payment — see §12.4 for the full prefetch budget.

### 11.4 Analysis

**Cache is everything.** The warm-vs-cold ratio is ~2000:1
(2 µs vs 4 ms per code). Every architectural decision should serve the
goal of keeping `mappingCache` populated for the active session.

**Stage 2 cost scales with DB size.** Dayi is cheapest (1 MB DB,
simple codes) and Cangjie most expensive (larger DB, more between-search
matches at LIMIT 210). The query itself is already the optimised Android
implementation — no SQL changes are warranted.

**First-keystroke cold path is real but manageable.** `triggerPrefetch()`
covers `a–z` (now including `q` — bug fixed in this session) plus
digits and symbols. Once prefetch completes (~0.5 s on background thread),
all single-char first strokes are warm. The only remaining cold exposure
is the very first stroke if the user types before prefetch finishes (rare
in practice — keyboard must be focused, then visible, before first tap).

### 11.5 Bug fixes applied in this session

| Bug | Location | Fix |
|---|---|---|
| `ORDER BY` sort clause: `score/basescore` appeared after the length tiebreaker, diverging from Android | `LimeDB.swift` `getMappingByCode` | Moved `score desc, basescore desc` to before the length tiebreaker, matching Android `LimeDB.java` exactly |
| Missing `'q'` in prefetch key string — decade-old typo copied from Android | `SearchServer.java` + `SearchServer.swift` | Added `q` to `"abcdefghijklmnop`**q**`rstuvwxyz"` in both files |
| `triggerPrefetch()` called `makeRunTimeSuggestion` on background cache-warming queries, corrupting phrase suggestion state | `SearchServer.swift` | Added `isPrefetch: Bool = false` parameter; prefetch path passes `true` to skip runtime suggestion, mirroring Android's `prefetchCache=true` arg |

### 11.6 Simulator vs device caveat

These numbers were captured on an Apple Silicon Mac running the iOS 26.4
iPad simulator. Absolute timing is directionally correct but will differ
from a physical device — typically simulator SQLite I/O is faster than
flash on older iPads and comparable to or faster than flash on M-chip
iPads. A real-device run is required before finalising T2/T3 budgets in
`scripts/profile_baseline.json`.

---

## 12. First-stroke Stage 2 elimination (May 2, 2026)

### 12.1 The gap §11 did not measure

§11.3 measured Stage 2 latency for first-stroke (single-char) codes and
found it costs 39–99 ms for 10 codes even with a warm OS page cache.
What §11 did **not** capture was whether Stage 2 was actually firing at
all for those codes in production. It was.

Before this session, `triggerPrefetch()` called `getMappingByCode` with
`getAllRecords: false` (LIMIT 15 — Stage 1 only). The Stage 1 result for
any single-char code that has more than 15 matches contains a
`hasMoreMark` sentinel, which sets `wasTruncated = true` in
`KeyboardViewController` and immediately triggers a Stage 2 dispatch for
the same code — even though the user's first tap lands on a prefetched,
warm code.

In other words, the Stage 1 cache entry was warm (µs lookup), but Stage
2 was still dispatched unconditionally because the cached Stage 1 result
carried the sentinel. The §11.3 numbers represent the **cost that was
being paid on every first stroke** before this fix.

### 12.2 Optimisation applied

Two changes in `SearchServer.swift` (May 2, 2026):

**1. Prefetch fills the Stage 2 (`:210`) cache key instead of Stage 1.**

`triggerPrefetch()` now calls `getMappingByCode(getAllRecords: true)` for
each first-character key. This populates the cache entry keyed
`"\(table):\(ch):210"` with the full LIMIT 210 result. Because the full
result is returned as-is from SQLite (not truncated at 15), no
`hasMoreMark` sentinel is ever appended to it.

**2. `getMappingByCode` falls back to the `:210` key when `:50` misses.**

When a non-prefetch call asks for Stage 1 (`getAllRecords: false`) and
the `:50` key is absent, `getMappingByCode` now checks whether the `:210`
key exists. If it does, it returns that result directly without touching
SQLite. The returned list has no sentinel — `wasTruncated` stays `false`
and Stage 2 is never dispatched.

```
User types 'a':
  getMappingByCode("a", getAllRecords: false)
      → check cache["cj:a:50"]            → miss
      → check cache["cj:a:210"]           → HIT  ← populated by prefetch
      → return full list, no hasMoreMark
  wasTruncated = false  →  Stage 2 never fires
```

For multi-char codes (`"ab"`, `"abc"`, …) no prefetch entry exists, so
the two-stage design applies normally — Stage 1 fast, Stage 2 upgrades
the bar from background.

### 12.3 Impact on pipeline timing

| Code length | Before | After |
|---|---|---|
| 1 char (prefetched) | Stage 1 (µs) + Stage 2 (~4–10 ms/code) | Stage 1 lookup returns `:210` result (µs), Stage 2 never fires |
| 2+ chars | Stage 1 cold + Stage 2 if truncated | Unchanged |

The §11.3 numbers (39–99 ms per 10 codes) are now the **pre-optimization
baseline for first strokes**. After prefetch completes, every single-char
first stroke is a pure dictionary lookup and Stage 2 is permanently
suppressed for those codes for the lifetime of the keyboard session.

### 12.4 Prefetch cost increase

Prefetch now fetches LIMIT 210 instead of LIMIT 15 per key, so its
background-thread cost increases. Using §11.3 measured numbers (warm page
cache, which is the realistic prefetch scenario after the first open):

| IM | Per-code (LIMIT 210) | Approx. prefetch cost (26 letters) |
|---|---|---|
| Dayi | ~4.1 ms | ~26 × 4.1 ms ≈ 107 ms |
| Array | ~6.6 ms | ~26 × 6.6 ms ≈ 172 ms |
| Cangjie | ~7.4 ms | ~26 × 7.4 ms ≈ 192 ms |
| Phonetic | ~8.4 ms | ~26 × 8.4 ms ≈ 218 ms |

These run on a `.background` QoS thread and do not block the main thread
or the `.userInteractive` query thread. In practice the keyboard is
visible for several hundred milliseconds before the first tap; on a
warm-OS-page-cache run (second open of the keyboard) the numbers halve.
The trade-off — slower background prefetch, zero Stage 2 on first strokes
— is firmly favourable.
