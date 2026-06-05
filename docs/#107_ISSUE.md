# Issue #107: Android IME switch/startup takes about seven seconds on Samsung A52

GitHub issue: https://github.com/lime-ime/limeime/issues/107
Reporter: `ejmoog`
Status: Open / self-triaged in this doc as a plausible Android startup-performance bug
Last updated: 2026-06-05T23:57:10+08:00

## Problem statement

The reporter says switching the active input method to Trime or gcin shows the keyboard immediately, but switching to LIME takes about seven seconds before the keyboard appears.

Verbatim report excerpt:

> 當我把輸入法切換到trime或gcin時，它們都是立即彈出，然而切換到lime2026卻需要七秒鐘。
>
> 三星A52，版本6.1.16。

Reported environment:

- Device: Samsung A52
- LIME version: 6.1.16
- Android version: not yet provided
- Scope: Android IME activation/switching latency, not an app crash report

This is a plausible Android performance bug because the user compares the same device and switching action against other IMEs and reports a large visible delay. There is not yet evidence that this is a regression versus an earlier LIME version.

## Reproduction details from report

1. On Samsung A52, switch the active input method to Trime or gcin.
2. Observe that those keyboards appear immediately.
3. Switch the active input method to LIME version 6.1.16.
4. LIME appears after about seven seconds.

Unknowns to confirm:

- Android OS version and Samsung One UI version.
- Whether the delay happens every time or only on first activation after install/reboot/process kill.
- Whether it happens in all apps/fields or only specific text fields.
- Active LIME table and enabled-table count.
- Whether this is a clean install, upgrade from older LIME, or after restoring/importing a database.
- Logcat timing around `net.toload.main.hd2026` while switching IMEs.

## Initial code-path assessment

The Android IME service is declared as `.LIMEService` in `LimeStudio/app/src/main/AndroidManifest.xml:113-125`. The current Android build uses `applicationId "net.toload.main.hd2026"` and namespace `net.toload.main.hd`, with `versionName '6.1.16'` and `targetSdkVersion 36` in `LimeStudio/app/build.gradle:28-40`.

Likely startup path to inspect before attempting a fix:

- `LIMEService.onCreate()` (`LIMEService.java:362-420`) constructs `SearchServer`, initializes preferences, creates `LIMEPreferenceManager`, initializes vibration/audio services, and calls `buildActivatedIMList()`.
- `SearchServer(Context)` (`SearchServer.java:162-184`) creates or opens the shared `LimeDB`, resets in-memory caches via `initialCache()`, then starts emoji-category preload on a background thread.
- `SearchServer.initialCache()` (`SearchServer.java:1282-1299`) clears and recreates the mapping/English/emoji/key-name/remap caches.
- `LIMEService.onInitializeInterface()` (`LIMEService.java:428-437`) calls `initialViewAndSwitcher(false)`, `initCandidateView()`, and `mKeyboardSwitcher.resetKeyboards(true)`.
- `LIMEService.onCreateInputView()` (`LIMEService.java:503-545`) calls `initialViewAndSwitcher(true)` and returns the embedded candidate/input container. The actual inflation/setup work is inside `initialViewAndSwitcher()`.
- `LIMEService.initialViewAndSwitcher()` (`LIMEService.java:4905-4965`) may inflate `R.layout.inputcandidate`, set up keyboard/candidate/emoji views, apply dynamic/accent colors, create/update `LIMEKeyboardSwitcher`, call `buildActivatedIMList()`, and load keyboard/IM config lists from `SearchServer`/`LimeDB` when needed.
- `LIMEService.onStartInput()` / `onStartInputView()` (`LIMEService.java:734-813`) both enter `initOnStartInput()`.
- `LIMEService.initOnStartInput()` (`LIMEService.java:820-900+`) reads database-backed keyboard/IM config lists, resets keyboards, loads settings, rebuilds activated IM state, and applies input-type-specific mode selection.
- `buildActivatedIMList()` (`LIMEService.java:3577-3651`) queries `SearchSrv.getImConfigList(...)` and rewrites the activated IM lists from database-backed IM configuration when `SearchSrv` is available.

Potentially expensive or device-sensitive areas:

- Repeated database queries for activated IM and keyboard configuration during `buildActivatedIMList()` / `initOnStartInput()`.
- Input view inflation and keyboard-switcher rebuild on first display or theme/dynamic-color changes.
- Initial DB open/upgrade/bootstrap and emoji-category preload contention on slower devices or restored databases.
- Samsung-specific IME lifecycle behavior around switching input methods, especially if the LIME process is cold-started.

These are hypotheses only. A logcat trace with timestamps is needed to identify whether the delay is before service creation, during DB/cache/bootstrap, during view inflation/keyboard reset, or during first `onStartInputView()`.

## Existing test coverage assessment

Relevant current coverage exists, but it does not directly gate the reported perceived IME switch latency:

- `PerformanceTest` benchmarks database/search/import/export style operations with production-size data, but it is not a cold IME-switch startup benchmark and likely does not measure Android framework IME activation to first visible keyboard.
- `LIMEServiceTest` covers many service logic paths and candidate/keyboard behavior, but the inspected section is not a latency regression test for `onCreate()` -> `onCreateInputView()` -> `onStartInputView()` under cold-start conditions.
- There is no confirmed device/emulator timing gate for "switch to LIME and keyboard becomes visible within N ms".

## Code fragility assessment

The startup path is moderately fragile because a single user-visible switch can touch Android IME lifecycle callbacks, preference reads, database-backed IM/keyboard config queries, input-view inflation, keyboard rebuild, dynamic-color/theme setup, and candidate/emoji UI initialization. Some of these steps are repeated across `onCreate()`, `onInitializeInterface()`, `onCreateInputView()`, and `initOnStartInput()`.

The current report is strong enough to track as a bug, but not enough to choose a code fix without timing evidence. A premature fix risks moving work between lifecycle callbacks without reducing the actual blocking interval.

## Likely root cause / hypotheses

Root cause is not confirmed yet. Leading hypotheses:

1. Cold-start database/cache initialization or IM-config queries block the IME lifecycle long enough to delay the first visible keyboard.
2. First input-view inflation plus keyboard-switcher rebuild is doing too much synchronously during `onCreateInputView()` / `onStartInputView()`.
3. A 6.1.x change such as always-embedded candidate view, dynamic/accent color setup, emoji keyboard setup, or repeated activated-IM rebuilds increased first-show work on some Samsung devices.
4. Device-local state such as restored/imported databases, many enabled tables, or stale/large DB content amplifies startup cost.

## Proposed investigation plan

1. Ask the reporter for Android/One UI version, whether the delay is first activation only or every switch, active table/enabled table count, clean install vs upgrade/restore, and a logcat capture around the switch.
2. Add temporary timing logs around:
   - `LIMEService.onCreate()`
   - `SearchServer` constructor / `LimeDB` open
   - `buildActivatedIMList()`
   - `onInitializeInterface()`
   - `onCreateInputView()` / `initialViewAndSwitcher()`
   - `onStartInputView()` / `initOnStartInput()`
3. Reproduce on a Samsung device or emulator matching the reporter's Android/One UI version once provided, comparing cold process start and warm switching.
4. Only after timing isolates the blocking segment, consider a focused fix such as caching activated IM config between calls, deferring nonessential preload/UI work, avoiding redundant keyboard resets, or moving long DB work off the first visible path.

## Follow-up questions for reporter

Public follow-up should request:

- Android version / One UI version.
- Whether the seven-second delay happens every time or only the first time after reboot/install.
- Whether it happens in every app/text field.
- Active input table and whether many tables are enabled.
- Whether version 6.1.16 was a clean install, upgrade, or after database restore/import.
- If possible, a logcat capture filtered around `net.toload.main.hd2026` while switching to LIME.

## Verification plan

Before a fix:

- Collect logcat timing evidence from reporter or local reproduction.
- Identify which lifecycle stage consumes the delay.
- Add or update instrumentation/manual performance checks that measure cold IME startup / first visible input view latency.

After a fix:

- Run Android compile checks and relevant instrumentation tests.
- On a device/emulator, compare cold and warm switch-to-LIME timing before/after the fix.
- Ask reporter to retest only after a newer APK contains the targeted startup-performance change.

## Platform impact analysis

### Android

Confirmed reporter platform. The issue is specific to Android IME activation and the LIME Android service/input-view startup path. Samsung A52 behavior may be device/vendor-sensitive, so Android investigation should avoid assuming all devices are affected until reproduced.

### iOS

N/A for the reported platform. iOS has a separate keyboard extension lifecycle and codebase, so this Android IME switching delay does not directly imply an iOS bug. No iOS action is needed unless a separate iOS startup-latency report appears.

## Backlog status

Do not add to `docs/BACKLOG.md` yet. The issue is triaged as a plausible bug, but the intended fix direction is not confirmed until timing evidence identifies the blocking path.

## Retest condition

Do not ask the reporter to retest version 6.1.16. Request retest only after a newer APK/build includes a clearly relevant startup-performance fix.
