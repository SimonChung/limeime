# Android IME Startup Profiling

This document records the local emulator profiling run for Issue #107, where a reporter saw LIME 2026 take about seven seconds to appear after switching input methods on a Samsung A52.

## Profiling Run

Date: 2026-06-06

Device: Android Studio Running Devices, Pixel 9 Pro API 36 emulator

Build: temporary instrumented debug APK, `net.toload.main.hd2026`, version `6.1.16`

Flow:

1. Select LatinIME.
2. Force-stop LIME for the first run.
3. Focus the launcher Google search field with Computer Use.
4. Switch the focused field to `net.toload.main.hd2026/net.toload.main.hd.LIMEService`.
5. Capture filtered logcat timing lines.
6. Repeat once without force-stopping LIME for a warm comparison.

Artifacts:

- `.Codex/txt/issue107_emulator_profile_logcat.txt`
- `.Codex/txt/issue107_emulator_warm_profile_logcat.txt`
- `.Codex/txt/issue107_emulator_profile_summary.md`

The temporary instrumentation was removed after profiling, and the emulator was reinstalled with a clean rebuilt debug APK.

## Cold-ish Run

The emulator did not reproduce the reported seven-second delay. The LIME-side work from service creation through visible keyboard setup was around one second.

Measured timings:

- `LIMEService.onCreate()` total: 115 ms.
- `SearchServer` constructor total: 36 ms.
- `PreferenceManager.setDefaultValues(...)`: 15 ms.
- `buildActivatedIMList()` during `onCreate()`: 12 ms.
- `onInitializeInterface()` total: 485 ms.
- `initialViewAndSwitcher(false)` inside `onInitializeInterface()`: 483 ms.
- First `setupEmojiKeyboardView()`: 418 ms.
- `onStartInput()` total: 18 ms.
- `initOnStartInput()` from `onStartInput()`: 17-18 ms.
- `onCreateInputView()` total: 354 ms.
- `initialViewAndSwitcher(true)` inside `onCreateInputView()`: 351 ms.
- Second `setupEmojiKeyboardView()`: 345 ms.
- `onStartInputView()` total: 5 ms.
- `initOnStartInput()` from `onStartInputView()`: 3 ms.
- `SearchServer.prefetchCache(array10)`: 108 ms, asynchronous.

The DB/config reads were small in this run:

- `SearchSrv.getImConfigList(...)`: 0-9 ms per measured call.
- `SearchSrv.getKeyboardConfigList()` plus switcher set: 1 ms.
- `SearchSrv.getAllImKeyboardConfigList()` plus switcher set: 0-1 ms.

## Warm Comparison

The warm comparison had the same shape, with lower startup and view setup costs:

- `LIMEService.onCreate()` total: 54 ms.
- `SearchServer` constructor total: 7 ms.
- `onInitializeInterface()` total: 195 ms.
- First `setupEmojiKeyboardView()`: 173 ms.
- `onStartInput()` total: 28 ms.
- `onCreateInputView()` total: 259 ms.
- Second `setupEmojiKeyboardView()`: 246 ms.
- `onStartInputView()` total: 6 ms.
- `SearchServer.prefetchCache(array10)`: 51 ms, asynchronous.

## Interpretation

The local emulator result does not explain a seven-second Samsung A52 delay by itself. It does confirm that LIME currently performs duplicated startup work during IME activation.

Confirmed lifecycle duplication:

- `onStartInput()` calls `super.onStartInputView(attribute, restarting)`.
- `initOnStartInput(attribute)` runs once from `onStartInput()` and again from `onStartInputView()`.
- `initialViewAndSwitcher(false)` runs during `onInitializeInterface()`.
- `initialViewAndSwitcher(true)` runs again during `onCreateInputView()`.

On this emulator, repeated emoji keyboard setup was the largest measured synchronous cost before the visible keyboard. DB open and config reads were not the bottleneck here.

## Follow-up Targets

Priority targets to test with a focused fix:

1. Correct `onStartInput()` to call `super.onStartInput(attribute, restarting)` instead of `super.onStartInputView(attribute, restarting)`.
2. Ensure `initOnStartInput(attribute)` runs once for a visible input session unless a specific lifecycle case requires otherwise.
3. Avoid rebuilding the input view twice on first activation if `onInitializeInterface()` already created a valid view.
4. Defer or cache nonessential emoji keyboard setup so the first visible keyboard is not blocked by repeated `setupEmojiKeyboardView()` work.
5. Re-run the same profiling flow on a slower Android device, preferably Samsung A52 or a lower-performance emulator profile, before concluding this fully covers Issue #107.

## Caveats

- This was an Android emulator run, not the reporter's Samsung A52.
- The active input table was `array10`, with only three IM config rows observed.
- The run used temporary logging instrumentation, not a system trace.
- ADB IME switching and launcher search field focus may not exactly match the reporter's manual IME picker path.
- The measured warm run still restarted the service process after switching away from LIME, so it is best treated as a lower-cost comparison rather than a fully hot in-process switch.
