# Issue #88: LIME v6.1.12 crashes / cannot be used on Android 13

## Problem statement

Community reporter `peter8777555` reports that LIME v6.1.12 cannot be used on a Samsung A71 4G running Android 13. After installing and opening the app, Android shows that 「萊姆輸入法」 repeatedly stops. The same reporter says older versions v5.2.4 and v6.0.0 worked, and they are currently using v6.0.2 as a workaround.

Live issue state checked 2026-05-26: issue is open, labeled `bug`, assigned to `jrywu`, and has one `limeimetw` acknowledgement asking for crash-scope details and logcat/crash stack evidence. Reporter follow-up now confirms the crash happens when opening the 「萊姆輸入法」 settings app. The original reporter reproduced it after upgrading from LIME v6.0.0 to v6.1.12, while another reporter (`ejmoog`) added that uninstalling and reinstalling v6.1.12 also crashes, but installing v6.1.12 over an existing LIME 6 install can still work.

## Likely root cause

Unknown pending crash evidence, but the failure scope has narrowed. The report is consistent with an Android settings-app startup crash introduced somewhere between the reporter's currently usable v6.0.2 workaround and failing v6.1.12. Repository inspection shows the v6.1.12 Android package is `applicationId` `net.toload.main.hd2026`, versionName `6.1.12`, with launcher settings activity `.ui.LIMESettings` and input method service `.LIMEService`.

Reporter evidence now points to a settings-app startup crash that can occur after at least some upgrade and reinstall paths. `ejmoog`'s report that reinstalling v6.1.12 crashes, while an in-place install over an existing LIME 6 setup can work, makes first-run / fresh data-directory initialization a stronger suspect, but does not rule out upgrade-path state differences. Settings startup constructs `SearchServer`, `DBServer`, and `LimeDB`, then immediately builds the IM navigation list through `ManageImController.getImConfigFullNameList()` before showing the setup tab. SearchServer/LimeDB startup also initializes caches and preloads emoji category pages. Without a stack trace, keep this as a hypothesis only; possible areas include first-run database creation/default table or emoji data initialization, bundled database/resource loading, upgrade-vs-reinstall preference/database state, and settings-fragment navigation with empty/fresh data.

Do not assume this is fixed by a newer APK until a relevant crash stack/reproducer is available and a targeted change lands.

## Proposed solution / investigation plan

1. Reproduce a clean install of v6.1.12 on Android 13 (Samsung/One UI if available) and capture `adb logcat` while launching 「萊姆輸入法」 settings.
2. If local reproduction is not available, ask the reporters for either an Android bug report or a short `adb logcat` capture filtered around `net.toload.main.hd2026` / `AndroidRuntime`.
3. Distinguish the failing entry point:
   - launching the LIME settings app after a clean install;
   - launching settings after an in-place upgrade from LIME 6.x;
   - enabling or switching to the keyboard;
   - restoring/importing existing data;
   - first-run initialization with an empty data directory vs migrated preferences/database.
4. Compare the startup paths between v6.0.2 and v6.1.12, focusing first on settings launch and first-run DB/resource initialization: `LIMESettings.onCreate()`, `SearchServer` constructor, `DBServer.getInstance()`, `LimeDB` constructor/`ensureCurrentDatabase()`, and initial IM config/navigation loading.
5. If the stack points to database restore/migration or bundled/default table initialization, reproduce with both clean install and upgrade-from-6.0.x data.
6. Prepare a focused Android fix and verify on an Android 13 device/emulator before asking the reporter to retest.

## Follow-up questions

Already answered / added publicly:

- `peter8777555` confirmed the crash happens when opening the 「萊姆輸入法」 settings app.
- `peter8777555` reproduced it after upgrading from LIME v6.0.0 to v6.1.12, and is currently using v6.0.2 normally.
- `ejmoog` reported the same issue after uninstalling and reinstalling v6.1.12; their in-place upgrade over an existing LIME 6 install can still work.
- No crash stack is available yet; `peter8777555` asked for a complete path/instructions to find the requested crash/logcat evidence.

Still useful:

1. Confirm whether the IME keyboard itself also crashes when enabled/switched to after a clean install, or whether the observed failure is limited to opening settings.
2. Obtain `adb logcat` / Android bug report evidence for `net.toload.main.hd2026` around the settings launch crash.
3. If a developer can reproduce locally, compare clean-install vs upgrade behavior before asking reporters for more steps.

## Verification plan

- Reproduce on Android 13 if possible, preferably with a Samsung/One UI environment or a comparable Android 13 emulator/device.
- Test clean reinstall of v6.1.12 early, because `ejmoog` reports uninstall/reinstall is sufficient to reproduce the crash.
- Test in-place upgrade from an existing LIME 6 install separately, because reporter evidence now differs between upgrade and reinstall paths.
- Verify both app launch (`.ui.LIMESettings`) and IME activation/input (`.LIMEService`).
- After a targeted fix lands in a new Android APK, ask the reporter(s) to retest with the direct APK link and confirm whether the settings launch crash is resolved for both clean install and upgrade paths.

## Current follow-up status

Open / pending crash stack or local reproduction. New corroborating reporter evidence points toward a v6.1.12 clean-install / first-run settings crash. No retest request yet because no relevant fix APK exists for this issue.
