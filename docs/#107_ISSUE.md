# Issue #107: Android IME switch/startup takes about seven seconds on Samsung A52

GitHub issue: https://github.com/lime-ime/limeime/issues/107
Reporter: `ejmoog`
Status: Closed / reporter-confirmed fixed on Android APK `LIMEHD2026-6.1.17.apk`
Last updated: 2026-06-08T18:45:00+08:00

## Problem statement

The reporter says switching the active input method to Trime or gcin shows the keyboard immediately, but switching to LIME 2026 takes about seven seconds before the keyboard appears.

Verbatim report excerpt:

> 當我把輸入法切換到trime或gcin時，它們都是立即彈出，然而切換到lime2026卻需要七秒鐘。
>
> 三星A52，版本6.1.16。

Known environment:

- Device: Samsung A52
- LIME version: 6.1.16
- Android / One UI version: Android 14 / One UI 6.0 (provided in the 6.1.17 confirmation)
- Symptom scope: Android IME activation / first visible keyboard after switching input methods

This should be treated as a real Android performance bug report, not a vague UX complaint: the reporter compares the same device and same IME-switch action against Trime/gcin and reports a multi-second visible delay. It is not yet proven to be a regression versus an earlier LIME build because the report does not include an older-LIME baseline.

## Reproduction details from report

1. On Samsung A52, switch the active input method to Trime or gcin.
2. Observe that those keyboards appear immediately.
3. Switch the active input method to LIME version 6.1.16.
4. LIME appears after about seven seconds.

Historical information requested before the 6.1.17 confirmation:

- Android OS / One UI version. Reporter later provided Android 14 / One UI 6.0.
- Whether the delay happens every switch or only after cold process start, reboot, install/update, or process kill.
- Whether the delay happens in all apps/text fields or only specific host apps / field types.
- Active input table and enabled-table count.
- Clean install vs upgrade vs old database restore/import.
- Logcat timestamps around `net.toload.main.hd2026` from IME selection to first keyboard display.

These are no longer active asks for #107 because the reporter confirmed APK `6.1.17` is fast enough. Keep them only as a checklist if a new startup-latency report or reopened issue appears.

## Root-cause hypothesis and shipped 6.1.17 scope

The strongest code-level hypothesis before the 6.1.17 confirmation was not simply “startup is slow”; it was that LIME did too much synchronous IME/session initialization before the first keyboard could be shown, and some of that work appeared duplicated on each activation. The shipped 6.1.17 optimization (`537a66c`, `#107 Optimize LimeIME startup without changing init path`) deliberately preserved the existing IME init routing. Because the reporter later confirmed the switch is fast enough on 6.1.17, the lifecycle/superclass-call hypothesis below is retained only as a regression-contingency note, not as active #107 work.

The most suspicious concrete path is:

1. `LIMEService.onCreate()` constructs `SearchServer` synchronously before any keyboard view can be shown.
   - `LIMEService.java:362-420`
   - `SearchServer(Context)` opens or reopens `LimeDB`, clears/recreates caches, then starts emoji-category preload.
   - `SearchServer.java:162-184`, `initialCache()` at `SearchServer.java:1282-1299`.
   - `onCreate()` then initializes default preferences and calls `buildActivatedIMList()`.

2. `buildActivatedIMList()` is database-backed when `SearchSrv` exists.
   - `LIMEService.java:3577-3651`
   - It calls `SearchSrv.getImConfigList(null, LIME.IM_FULL_NAME)` every time it rebuilds the active-IM list.
   - This is invoked from at least `onCreate()`, `initialViewAndSwitcher()`, and `initOnStartInput()`.

3. `initialViewAndSwitcher(true)` is heavy and runs on the first input-view creation path.
   - `LIMEService.java:4905-4965`
   - It inflates `R.layout.inputcandidate`, wires keyboard/candidate views, calls `setupEmojiKeyboardView()`, applies follow-system accent colors, constructs/updates `LIMEKeyboardSwitcher`, rebuilds the activated IM list, and may query both keyboard and IM-keyboard config lists from the database.

4. `initOnStartInput()` repeats more database/config and keyboard reset work.
   - `LIMEService.java:820-990`
   - It calls `SearchSrv.getAllImKeyboardConfigList()` (`LIMEService.java:866-871`), `mKeyboardSwitcher.resetKeyboards(...)`, `loadSettings()`, and `buildActivatedIMList()` again before selecting the field-specific keyboard mode.

5. `onStartInput()` appears to call the wrong superclass method.
   - Current code: `super.onStartInputView(attribute, restarting);` in `onStartInput()` (`LIMEService.java:734-738`).
   - Expected pattern for `onStartInput()` is `super.onStartInput(attribute, restarting)`.
   - `onStartInputView()` later calls `super.onStartInputView(attribute, restarting)` and calls `initOnStartInput(attribute)` again (`LIMEService.java:745-762`).
   - This means a normal activation can run the input-view superclass path and LIME's `initOnStartInput()` work twice: once from `onStartInput()` and once from `onStartInputView()`.

This duplicate initialization is a concrete root-cause candidate: even if individual DB/config queries are normally small, doubling them and combining them with view inflation, keyboard reset, theme/accent work, and DB open/upgrade checks can produce a visible delay on a midrange Samsung device, especially on cold start or after database restore/import.

## Recent-change context

The slow path is partly legacy, but several 6.x-era changes increased the amount of work tied to first keyboard display:

- Embedded candidate view / always-fixed candidate UI changed `initialViewAndSwitcher()` to inflate and manage a larger combined `inputcandidate` container.
- Emoji keyboard UI setup is now part of first input-view wiring via `setupEmojiKeyboardView()`.
- Follow-system theme/accent support calls `applyFollowSystemAccentColors()` during `initialViewAndSwitcher()`.
- Recent config/list correctness fixes made the service rely more heavily on DB-backed IM/keyboard config reads instead of stale preference-only state.

These changes are not individually blamed yet. The 6.1.17 fix targeted the lighter pre-display work that could be safely optimized without changing IME init routing: deferring full emoji content rendering, caching startup config snapshots/versions, and guarding emoji preload work. Since the reporter confirmed 6.1.17 is fast enough, lifecycle duplication and repeated synchronous work should be revisited only if a new regression report appears.

## Reopen-contingency measurements

Add temporary timing logs with elapsed milliseconds around these exact segments:

- `onCreate()` total.
- `new SearchServer(this)` and `new LimeDB(...)` / `openDBConnection(false)`.
- `PreferenceManager.setDefaultValues(...)`.
- `buildActivatedIMList()` and its `SearchSrv.getImConfigList(...)` query.
- `onInitializeInterface()` total.
- `onCreateInputView()` total.
- `initialViewAndSwitcher(true)`, split into layout inflation, `setupEmojiKeyboardView()`, `applyFollowSystemAccentColors()`, `buildActivatedIMList()`, `getKeyboardConfigList()`, and `getAllImKeyboardConfigList()`.
- `onStartInput()` total and whether it invokes the input-view superclass path.
- `onStartInputView()` total.
- `initOnStartInput()` total, split around `getAllImKeyboardConfigList()`, `resetKeyboards(...)`, `loadSettings()`, `buildActivatedIMList()`, and `initialIMKeyboard()`.

If a similar startup-latency issue is reopened or newly reported, the reported delay should be mapped to one of these stages before implementation. Without that timing split, a fix can easily move work between callbacks without reducing first-visible-keyboard latency.

## Contingent fix direction if startup latency returns

If a future report shows the 6.1.17 optimization is insufficient on another path, likely focused fixes after timing confirmation are:

1. Correct `onStartInput()` to call `super.onStartInput(attribute, restarting)` instead of `super.onStartInputView(attribute, restarting)`, then verify that initialization still happens exactly once through the correct Android IME lifecycle.
2. Avoid calling `initOnStartInput(attribute)` twice for one visible session. Keep field-specific mode setup in the callback that Android actually uses for the visible input view.
3. Cache active IM / keyboard config snapshots for the duration of a switch and invalidate them only when table settings change, instead of querying IM config in `onCreate()`, `initialViewAndSwitcher()`, and `initOnStartInput()` for the same activation.
4. Keep first keyboard display minimal: show the base keyboard first, then defer nonessential emoji/category preload, dynamic accent refresh, and full config refresh until after the keyboard is visible.
5. If logs show DB open/upgrade as the bottleneck, add a targeted DB-open/upgrade mitigation rather than UI refactoring.

## Existing test coverage assessment

Current tests do not directly protect this bug:

- `PerformanceTest` benchmarks database/search/import/export operations with real data, but it does not measure IME switch latency from Android framework activation to first visible keyboard.
- `LIMEServiceTest` covers service logic and candidate/keyboard behavior, but it does not assert callback ordering or that `initOnStartInput()` runs once per visible session.
- There is no current device/emulator timing gate for “switch to LIME and first keyboard frame visible within N ms”.

Useful regression coverage after any follow-up lifecycle/config fix:

- A lifecycle/unit-style test or source guard that `onStartInput()` calls `super.onStartInput(...)`, not `super.onStartInputView(...)`.
- A service test using a fake/stub `SearchServer` or instrumentation hooks to count `buildActivatedIMList()` / config-list calls during one activation.
- A manual/device performance checklist recording cold and warm IME switch timings before/after the fix.

## Platform impact analysis

### Android

Confirmed reporter platform. The Android service lifecycle is the relevant surface: `LIMEService`, `SearchServer`, `LimeDB`, keyboard-view inflation, keyboard-switcher reset, and DB-backed IM/keyboard config reads. Samsung A52/One UI may amplify the delay, but the duplicated initialization path is Android-wide unless later testing shows it is harmless on non-Samsung devices.

### iOS

No direct iOS impact from this report. iOS uses a separate keyboard-extension lifecycle and different codebase. Do not infer an iOS startup bug unless a separate iOS report or measurement shows similar first-show latency.

## Backlog status

The Android startup-performance fix direction is implemented in commit `537a66c4c21c` (`#107 Optimize LimeIME startup without changing init path`) and reporter-confirmed fixed on APK `LIMEHD2026-6.1.17.apk`. No active backlog or retest-watch item remains for #107 unless the issue is reopened or new startup-latency evidence appears.

## Public follow-up status

Initial public follow-up asked for Android/One UI version, cold-vs-warm behavior, app/field scope, active/enabled tables, upgrade/restore history, and logcat:

- https://github.com/lime-ime/limeime/issues/107#issuecomment-4633328574

Android APK `LIMEHD2026-6.1.17.apk` now contains the targeted startup-performance optimization (commit `537a66c4c21c`). Verified APK Contents metadata: blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes. Scoped retest request posted:

- https://github.com/lime-ime/limeime/issues/107#issuecomment-4641196799

Reporter `ejmoog` confirmed in https://github.com/lime-ime/limeime/issues/107#issuecomment-4644700954 that on Samsung A52 5G / Android 14 / One UI 6.0, APK `6.1.17` is now fast enough when switching from other input methods to LIME. Maintainer `jrywu` closed the issue as completed on 2026-06-08.

## Retest condition

No active retest condition remains. If the issue is reopened or a new report says LIME startup/switch latency is still slow, ask for Android/One UI version, cold-vs-warm scope, app/field scope, active IM table count, and a fresh logcat around IME selection.
