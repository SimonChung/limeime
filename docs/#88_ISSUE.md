# Issue #88: LIME v6.1.12 crashes / cannot be used on Android 13

## Problem statement

Community reporter `peter8777555` reports that LIME v6.1.12 cannot be used on a Samsung A71 4G running Android 13. After installing and opening the app, Android shows that 「萊姆輸入法」 repeatedly stops. The same reporter says older versions v5.2.4 and v6.0.0 worked, and they are currently using v6.0.2 as a workaround.

Live issue state checked 2026-05-25: issue is open, labeled `bug`, assigned to `jrywu`, and has one `limeimetw` acknowledgement asking for crash-scope details and logcat/crash stack evidence. No reporter follow-up is available yet.

## Likely root cause

Unknown pending crash evidence. The report is consistent with an Android startup/runtime crash introduced somewhere between the reporter's currently usable v6.0.2 workaround and failing v6.1.12. Repository inspection shows the v6.1.12 Android package is `applicationId` `net.toload.main.hd2026`, versionName `6.1.12`, with launcher settings activity `.ui.LIMESettings` and input method service `.LIMEService`. The current evidence does not yet identify whether the crash is in settings launch, IME service startup, restore/backup initialization, database migration, table loading, or another Android 13/Samsung-specific path.

Do not assume this is fixed by a newer APK until a relevant crash stack or reproducer is available and a targeted change lands.

## Proposed solution / investigation plan

1. Wait for or obtain a crash stack/logcat containing `net.toload.main.hd2026` / `萊姆輸入法` around the failure.
2. Distinguish the failing entry point:
   - launching the LIME settings app;
   - enabling or switching to the keyboard;
   - restoring/importing existing data;
   - first-run initialization after clean install vs upgrade.
3. Compare the startup paths between v6.0.2 and v6.1.12, focusing first on changes that run before or during `LIMESettings` and `LIMEService` initialization.
4. If the stack points to database restore/migration or bundled/default table initialization, reproduce with both clean install and upgrade-from-6.0.x data.
5. Prepare a focused Android fix and verify on an Android 13 device/emulator before asking the reporter to retest.

## Follow-up questions

Already asked publicly by `limeimetw`:

1. Does the crash happen when opening the 「萊姆輸入法」 settings app, or also when switching to the keyboard?
2. Was v6.1.12 a clean install or an upgrade from an older version?
3. If possible, provide a screenshot or Android crash/logcat stack containing `net.toload.main.hd2026` / `萊姆輸入法`.

## Verification plan

- Reproduce on Android 13 if possible, preferably with a Samsung/One UI environment or a comparable Android 13 emulator/device.
- Test both clean install of v6.1.12 and upgrade from v6.0.2/v6.0.0 data when evidence suggests an upgrade-only path.
- Verify both app launch (`.ui.LIMESettings`) and IME activation/input (`.LIMEService`).
- After a targeted fix lands in a new Android APK, ask the reporter to retest with the direct APK link and confirm whether the crash path is resolved.

## Current follow-up status

Open / pending reporter evidence. No retest request yet because no relevant fix APK exists for this issue.
