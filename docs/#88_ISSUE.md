# Issue #88: Android 13 Samsung A71 crash on opening LIME v6.1.12

Live issue: https://github.com/lime-ime/limeime/issues/88

## Status

- State at triage: open
- Labels after triage: `bug`
- Assignee after triage: `jrywu`
- Reporter: `peter8777555` (community report)
- Public acknowledgement: https://github.com/lime-ime/limeime/issues/88#issuecomment-4534430781
- Platform: Android
- Device/OS: Samsung A71 4G, Android 13
- Reported affected version: LIME v6.1.12
- Reported known-good versions: v5.2.4 and v6.0.0; reporter is currently using v6.0.2 as workaround
- Follow-up status: waiting for crash details/logcat or maintainer reproduction; do not ask for APK retest until a newer build contains a clearly relevant startup-crash fix.

## Problem Statement

A community reporter says LIME v6.1.12 installs successfully on Samsung A71 4G / Android 13, but when they open the app Android reports `萊姆輸入法 屢次停止運作` (the app repeatedly stops). Older releases v5.2.4 and v6.0.0 reportedly worked on the same device, and the reporter is temporarily using v6.0.2.

This is a plausible Android regression and likely blocks at least the settings/launcher app startup path for this device/version combination.

## Reproduction Notes From Report

1. Use Samsung A71 4G running Android 13.
2. Install LIME v6.1.12.
3. Open LIME after installation.
4. Android shows repeated app-stop/crash message: `萊姆輸入法 屢次停止運作`.
5. v5.2.4 and v6.0.0 were reportedly normal; v6.0.2 is being used as a fallback.

No crash stack trace, logcat, screenshot, or exact installation path was included in the initial report.

## Relevant Context Inspected

- v6.1.12 is the current GitHub Release and Android APK release asset: `LIMEHD2026-6.1.12.apk`.
- Android `LimeStudio/app/build.gradle` reports:
  - `applicationId "net.toload.main.hd2026"`
  - `compileSdkVersion 36`
  - `targetSdkVersion 36`
  - `minSdkVersion 21`
  - `versionName '6.1.12'`
- v6.1.12 release notes say this is the first 6.1 formal release with a redesigned settings app, new emoji keyboard/database, voice input changes, downloadable table/catalog changes, and backup/restore updates. Because the reporter crashes immediately after opening the app, the settings/launcher startup path is the first area to inspect, but the current report does not yet identify the crashing class or line.
- `AndroidManifest.xml` launcher activity is `.ui.LIMESettings`; IME service is `.LIMEService`.

## Likely Root Cause / Hypothesis

The exact root cause is unknown until a stack trace is available. The version boundary makes a v6.1.x startup regression plausible, especially in one of the new Android settings app initialization, database/migration/bootstrap, resource/theme, emoji/database, permission/notification, or target-SDK-related startup paths.

Because Samsung A71 / Android 13 is above the minimum SDK and below target SDK 36, this should be treated as a compatibility crash rather than an unsupported-device case unless evidence shows an external/system limitation.

## Proposed Investigation Plan

1. Ask the reporter for the crash details needed to identify the failing path:
   - whether the crash happens when opening the launcher/settings app, enabling/selecting the keyboard, or opening the keyboard inside another app;
   - whether this is a clean install or upgrade from an older LIME version;
   - if possible, a screenshot and Android crash/logcat stack trace around `FATAL EXCEPTION` for `net.toload.main.hd2026`.
2. Try to reproduce locally or on a Samsung/Android 13 emulator/device if available:
   - clean install v6.1.12;
   - upgrade from v6.0.2 or v6.0.0 to v6.1.12;
   - open `.ui.LIMESettings` and enable/select the IME.
3. Inspect initialization paths for unguarded assumptions introduced after v6.0.2, especially settings UI startup, database initialization/migrations, emoji database loading, backup/restore preference migration, and notification/permission setup.
4. Once a stack trace or reproduction is available, create a focused Android fix branch and run compile checks before opening a PR.

## Follow-up Questions For Reporter

Use a concise Traditional Chinese public reply asking for:

- Whether the crash happens while opening the LIME settings app, switching to the LIME keyboard, or both.
- Whether v6.1.12 was installed as a clean install or upgraded over an older version.
- If convenient, a screenshot plus Android crash/logcat details for `net.toload.main.hd2026` / `萊姆輸入法`.

## Verification Plan

A future fix should be verified by:

- Installing/opening the fixed build on Samsung A71 4G / Android 13 if available, or at least Android 13 emulator/device coverage.
- Testing both clean install and upgrade from v6.0.2/v6.0.0 to the fixed build.
- Opening the LIME settings app and activating/selecting the keyboard without repeated app-stop dialogs.
- Running feasible Android compile checks:
  - `cd LimeStudio && ./gradlew :app:compileDebugJavaWithJavac`
  - `cd LimeStudio && ./gradlew :app:compileDebugAndroidTestJavaWithJavac`

## Retest Condition

Do not ask the reporter to retest the existing v6.1.12 APK again. Request retest only after a newer APK/build includes a fix that is clearly tied to the identified startup crash path.
