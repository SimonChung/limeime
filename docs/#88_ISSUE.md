# Issue #88: LIME v6.1.12–v6.1.15 Samsung Android 13 settings and legacy restore crashes

## Problem statement

Community reporter `peter8777555` reports that LIME v6.1.12 cannot be used on a Samsung A71 4G running Android 13. After installing and opening the app, Android shows that 「萊姆輸入法」 repeatedly stops. The same reporter says older versions v5.2.4 and v6.0.0 worked, and they are currently using v6.0.2 as a workaround.

Live issue state checked 2026-05-26 after the v6.1.15 APK push: issue is open, labeled `bug`, assigned to `jrywu`, and has `limeimetw` follow-up comments documenting the v6.1.13 negative retest, log analysis, PR #89, v5.2.4-to-newer upgrade/backup guidance, the v6.1.14 scoped retest request, restore/import UI guidance, the concrete `emoji_fts already exists` restore/import crash, and the v6.1.15 scoped retest request. The reporter replied with `可以了`, then provided full screenshots showing the v6.1.14 app opens, bottom navigation is visible, the bottom `設定`, `輸入法`, `喜好設定`, and `資料庫管理` navigation is visible across the submitted screenshots, and the `資料庫管理` screenshot includes restore controls. The reporter then confirmed a concrete legacy restore/import failure after following the v6.x UI path: importing/restoring v5.2.4 settings errored, and afterward v6.1.14 settings could no longer open. The attached log shows a new LIME SQLite crash in `emoji_fts` creation. In a later follow-up, the reporter said they still have both v5.2.4 and v6.0.0 settings backups, and that v6.0.2 can import the v5.2.4 settings normally. Earlier reporter follow-up confirmed the crash happens when opening the 「萊姆輸入法」 settings app. The original reporter reproduced it after upgrading from LIME v6.0.0 to v6.1.12, while another reporter (`ejmoog`) added that uninstalling and reinstalling v6.1.12 also crashes, but installing v6.1.12 over an existing LIME 6 install can still work.

Local reproduction on 2026-05-26: clean install of `LimeStudio/app/release/LIMEHD2026-6.1.12.apk` on Samsung `SM-A325N`, Android 13 / API 33, reproduces the settings launch crash. Clean installs on a Google API 33 `sdk_gphone64_x86_64` emulator and an Android 16 `sdk_gphone64_x86_64` emulator did not reproduce it, so current evidence points to Samsung/One UI Android 13 behavior rather than an API 33-wide crash.

## Root cause

Confirmed app-level root cause: the LIME settings screen renders a `NestedScrollView` with platform scrollbars enabled on Samsung Android 13 / One UI. On this device family, Android's framework scrollbar draw path can hold a null `ScrollBarDrawable`; when the first settings page is drawn, framework code calls `ScrollBarDrawable.mutate()` and crashes before the UI can remain open. The same APK does not crash on a Google API 33 emulator, so this appears device/vendor-specific rather than Android 13/API 33 generic.

The crash is a rendering-time crash in the settings UI, not a first-run database creation, migration, bundled table, or emoji initialization crash. The fatal exception is:

```text
java.lang.NullPointerException: Attempt to invoke virtual method
'android.widget.ScrollBarDrawable android.widget.ScrollBarDrawable.mutate()'
on a null object reference
    at android.view.View.onDrawScrollBars(View.java:21718)
    at android.view.View.onDrawForeground(View.java:26440)
    at android.view.View.draw(View.java:24425)
    at androidx.core.widget.NestedScrollView.draw(NestedScrollView.java:2409)
```

The app package is `net.toload.main.hd2026`, versionName `6.1.12`, with launcher activity `.ui.LIMESettings`, separate declared `.ui.LIMEPreference` settings/preference activity, and input method service `.LIMEService`. On the Samsung `SM-A325N` API 33 reproduction, `monkey -p net.toload.main.hd2026 1` starts `.ui.LIMESettings`, then the process exits and foreground returns to Android Settings.

The most likely immediate trigger is the root `NestedScrollView` in `LimeStudio/app/src/main/res/layout/fragment_setup.xml` (`@+id/setup_scroll`), because it is the default settings landing page and the stack reaches `NestedScrollView.draw()`. Other settings screens also use `NestedScrollView` and should receive the same defensive treatment to avoid the same Samsung/Android 13 framework path:

- `fragment_setup.xml` / `@+id/setup_scroll`
- `fragment_db_manager.xml` / `@+id/db_manager_scroll`
- `fragment_im_detail.xml` / `@+id/im_detail_scroll`
- `sheet_manage_im_add.xml`
- `sheet_manage_im_edit.xml`
- `sheet_manage_related_add.xml`
- `sheet_manage_related_edit.xml`

Do not assume the renewed Samsung Settings entry-point failure was fixed by the v6.1.13 scrollbar APK. That second path needed its own targeted metadata change; PR #89 has now merged that source fix, and Android pre-release APK `LIMEHD2026-6.1.14.apk` / version `6.1.14` is expected to contain the PR #89 metadata fix based on commit `60f078f5744e` and `output-metadata.json`. Reporter partially validated v6.1.14 by entering the app; UI/import-path follow-up remains open.

## New failure mode: v5.2.4 restore/import emoji FTS crash

The reporter's `lime-crash-log.zip` from https://github.com/lime-ime/limeime/issues/88#issuecomment-4541068761 changes the current engineering follow-up. This is a LIME process crash, not an unrelated device log and not the old Samsung `MainActivity` metadata failure. Representative stack:

```text
Process: net.toload.main.hd2026
java.lang.RuntimeException: Unable to start activity ComponentInfo{net.toload.main.hd2026/net.toload.main.hd.ui.LIMESettings}:
android.database.sqlite.SQLiteException: table emoji_fts already exists ...
while compiling: CREATE VIRTUAL TABLE emoji_fts USING fts4(name_en, name_tw, tags_en, tags_tw, tokenize=unicode61 "remove_diacritics=1", content=emoji_data)
```

The same `emoji_fts already exists` error also appears when Android tries to create `net.toload.main.hd.LIMEService`. Log context shows `LimeDB OnUpgrade() db old version = 101, new version = 104`, an attempted FTS5 creation failing with `no such module: fts5`, and then the FTS4 fallback failing because `emoji_fts` already exists. Source inspection points to `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java` `createEmojiFtsTable()`: it tries `CREATE VIRTUAL TABLE emoji_fts USING fts5(...)`, catches `SQLiteException`, and immediately tries `CREATE VIRTUAL TABLE emoji_fts USING fts4(...)` for the same name. Local Pixel 6 API 33 instrumentation reproduced the same behavior: the failed FTS5 virtual-table creation leaves an unloadable `emoji_fts` schema artifact, and even a normal `DROP TABLE IF EXISTS emoji_fts` can fail with `no such module: fts5`.

Implemented local fix: when FTS5 creation fails, `createEmojiFtsTable()` now removes the partial FTS5 `emoji_fts` schema before creating the FTS4 fallback. It first attempts a normal `DROP TABLE IF EXISTS`; if Android SQLite rejects the drop because the saved virtual table references unavailable FTS5, it uses a narrow `PRAGMA writable_schema` cleanup for `emoji_fts` and its shadow-table names, then creates the FTS4 table. The restore failure status strings were also fixed from malformed `%1\` placeholders to `%1$s`, preventing the UI from throwing `UnknownFormatConversionException` while reporting restore errors.

Verification on Pixel 6 API 33 after the fix:

```text
./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=net.toload.main.hd.LimeDB103IntegrationTest
```

Result: 10 tests passed, including a new `restoreVersion101BackupRunsFullUpgradeAndEmojiRefresh` regression case that exercises the reporter's `old version = 101, new version = 104` path.

FTS5 compatibility note: there is no Android platform API level that should be treated as a guaranteed `android.database.sqlite` FTS5 boundary. FTS5 is controlled by SQLite compile-time options, not by the Android SDK level. Current AOSP SQLite platform build flags include FTS3/FTS4 support, but do not enable `SQLITE_ENABLE_FTS5`, and Pixel 6 API 33 testing confirms `CREATE VIRTUAL TABLE ... USING fts5` fails with `no such module: fts5`. Therefore LIME must keep runtime FTS5 detection and a robust FTS4 fallback for platform SQLite. Using FTS5 reliably would require a bundled SQLite implementation/dependency rather than an Android API-level check.

## Fix implemented

Fixed locally on 2026-05-26. The fix does not disable settings scrollbars globally, because that would regress issue #64, where the main settings tabs need a visible scroll affordance when content overflows and enough bottom padding so the last row is not hidden behind the bottom navigation.

The implemented approach keeps the #64 behavior in `ScrollableTabHelper`: bottom-navigation inset, `clipToPadding=false`, and conditional scrollbar visibility only when the container can actually scroll. It changes the scrollbar implementation so Samsung Android 13 never draws a null platform scrollbar drawable.

Changed files:

- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/ScrollableTabHelper.java`
- `LimeStudio/app/src/main/res/drawable/settings_scrollbar_thumb.xml`
- `LimeStudio/app/src/main/res/drawable/settings_scrollbar_track.xml`

Implementation details:

1. Added small non-null settings scrollbar thumb/track drawables.
2. Updated `ScrollableTabHelper.applyToNestedScrollView()` to install those drawables on API 29+ before the helper conditionally enables the scrollbar.
3. Kept `setVerticalScrollBarEnabled(false)` during setup, then continued to call `setScrollbarVisibleWhenScrollable(scrollView, canScroll)` after layout.
4. Preserved #64 behavior: visible scrollbars still appear only on overflowing settings pages; the bottom-navigation inset and `clipToPadding=false` behavior remain unchanged.
5. Avoided broad theme-level or app-wide scrollbar changes, so keyboard candidate popups, lists, and unrelated UI surfaces are not touched.

Samsung verification commands used:

```text
adb -s localhost:8167 uninstall net.toload.main.hd2026
adb -s localhost:8167 install <fixed-apk>
adb -s localhost:8167 logcat -c
adb -s localhost:8167 shell monkey -p net.toload.main.hd2026 1
adb -s localhost:8167 logcat -d -v time AndroidRuntime:E *:S
```

Result: `.ui.LIMESettings` remained foreground after launch, the process stayed alive, and no `AndroidRuntime` fatal exception was emitted.

Release APK verification on 2026-05-26 for v6.1.13 (launcher path only; this did not exercise the input-method settings entry point now implicated by the second reporter log; see the v6.1.14 Webhook update for current retest status):

- Tested `LimeStudio/app/release/LIMEHD2026-6.1.13.apk` on Samsung `SM-A325N`, Android 13 / API 33.
- Confirmed installed package reports `versionName=6.1.13`.
- Clean-installed the release APK, launched `net.toload.main.hd2026` with `monkey -p net.toload.main.hd2026 1`, and confirmed the LIME process stayed alive with no `AndroidRuntime` fatal exception.
- Ran a second force-stop plus explicit `.ui.LIMESettings` launch. The LIME process stayed alive and `AndroidRuntime:E` remained empty. Foreground moved to Android keyboard settings during the setup flow, but there was no app crash.

## Follow-up questions

Already answered / added publicly:

- `peter8777555` confirmed the crash happens when opening the 「萊姆輸入法」 settings app.
- `peter8777555` reproduced it after upgrading from LIME v6.0.0 to v6.1.12, and is currently using v6.0.2 normally.
- `ejmoog` reported the same issue after uninstalling and reinstalling v6.1.12; their in-place upgrade over an existing LIME 6 install can still work.
- A local v6.1.12 crash stack is available from Samsung `SM-A325N` API 33.
- `peter8777555` reported that v6.1.13 still crashes/cannot be opened on Samsung A71 4G / Android 13 after the install/update flow shown in screenshots. The screenshots show the v6.1.13 install/update flow followed by 「萊姆輸入法2026」屢次停止運作 and Android Settings displaying 「無法開啟『萊姆輸入法2026』的設定」.
- Reporter uploaded a first `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4539986307. It is a broad device log, not a filtered LIME-only crash dump: the only `FATAL EXCEPTION` is unrelated package `de.android.telnet`, not `net.toload.main.hd2026`, and there are no `ScrollBarDrawable` / `NestedScrollView` frames.
- Reporter then uploaded a second `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540030225. That second log contains no LIME `AndroidRuntime` / `FATAL EXCEPTION`, but it does show Samsung Settings failing to open the IME settings activity because it tries `net.toload.main.hd2026/net.toload.main.hd.ui.MainActivity`, which is not declared in the app manifest.
- After APK `LIMEHD2026-6.1.14.apk`, reporter `peter8777555` replied in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540709915 with `可以了` plus a legacy v5.2.4 restore/import concern. Automation replied in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540812173 explaining the v6.x bottom-tab locations and asking for full screenshots. The reporter then provided four screenshots in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540913107: bottom navigation is visible across the submitted `設定`, `輸入法`, `喜好設定`, and `資料庫管理` screenshots, and the `資料庫管理` page shows `備份資料庫`, `還原資料庫`, and `還原預設資料庫`. Automation posted follow-up guidance in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540979736 to use `資料庫管理` -> `還原資料庫` for a full v5.2.4 database backup, use `輸入法` for table/import files, and report exact button/file-format/error details if restore/import still fails.
- Reporter then reported in https://github.com/lime-ime/limeime/issues/88#issuecomment-4541068761 that importing/restoring v5.2.4 settings still errored and afterward v6.1.14 settings could no longer open. The attached `lime-crash-log.zip` contains repeated LIME `AndroidRuntime` crashes for `Process: net.toload.main.hd2026`; both `.ui.LIMESettings` startup and `LIMEService` creation fail with `android.database.sqlite.SQLiteException: table emoji_fts already exists`, while compiling `CREATE VIRTUAL TABLE emoji_fts USING fts4(...)`. Preceding lines show `LimeDB OnUpgrade() db old version = 101, new version = 104`, FTS5 unavailable, and then an FTS4 fallback. Automation acknowledged this as a new SQLite/emoji-index restore-import crash in https://github.com/lime-ime/limeime/issues/88#issuecomment-4541234220.
- Reporter added in https://github.com/lime-ime/limeime/issues/88#issuecomment-4541184653 and https://github.com/lime-ime/limeime/issues/88#issuecomment-4541246237 that they kept both v5.2.4 and v6.0.0 settings backups, and that v6.0.2 can import the v5.2.4 settings normally. This narrows the regression evidence toward the newer v6.1.x database/emoji-index migration path rather than the reporter's backup file being generally unusable.

Still useful:

1. Retest the reporter path on a release APK: restore/import legacy v5.2.4 data, then reopen settings and ensure `LIMEService` starts without `AndroidRuntime` crashes.
2. Confirm whether the IME keyboard itself also crashes when enabled/switched to after a clean install, or whether the observed failure is limited to Samsung Settings opening the IME settings activity.
3. Re-run #64 visual checks: on the four top-level phone tabs, overflowing content must still show a visible scrollbar and the last row must scroll fully above the bottom navigation.
4. Smoke-test a Google API 33 emulator with the fixed build to ensure settings pages still scroll correctly and the custom scrollbar behavior does not regress non-Samsung Android 13.

## New evidence: Samsung IME settings activity metadata

The reporter's `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540030225 changes the next likely fix area. It does **not** show a LIME process `FATAL EXCEPTION`; instead Samsung Settings logs repeated IME settings launch failures:

```text
D/SecInputMethodPreference: IME's Settings Activity Not Found
android.content.ActivityNotFoundException: Unable to find explicit activity class
{net.toload.main.hd2026/net.toload.main.hd.ui.MainActivity}
```

Pre-PR source inspection confirmed `LimeStudio/app/src/main/res/xml/method.xml` declared:

```xml
<input-method ... android:settingsActivity="net.toload.main.hd.ui.MainActivity"/>
```

But `LimeStudio/app/src/main/AndroidManifest.xml` declares exported launcher activity `.ui.LIMESettings` and settings/preference activity `.ui.LIMEPreference`, not `.ui.MainActivity`. The IME settings entry uses the standard `android:settingsActivity` hook; on the reporter's Samsung/One UI device this fails with `ActivityNotFoundException` because the target activity is not declared. This was a separate remaining #88 failure path after the v6.1.13 scrollbar fix. PR #89 (https://github.com/lime-ime/limeime/pull/89) merged the targeted Android source fix: it updates the IME metadata to point at declared `net.toload.main.hd.ui.LIMESettings`. APK `LIMEHD2026-6.1.14.apk` is expected to contain that PR by build provenance, and automation has already asked the reporter to verify the Android/Samsung input-method settings launch path plus direct app launch.

### MainActivity scan results and naming follow-up

A production-source scan of `LimeStudio/app/src/main` excluding Android/unit tests found only three remaining `MainActivity` references:

```text
LimeStudio/app/src/main/java/net/toload/main/hd/ui/LIMESettings.java:190
    setupImController.setMainActivityView(this);

LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java:58
    public void setMainActivityView(LIMESettingsView view) {

LimeStudio/app/src/main/res/xml/method.xml:31
    android:settingsActivity="net.toload.main.hd.ui.MainActivity"
```

Only the pre-PR `method.xml` reference was an Android runtime entry point and explains why Samsung Settings called `MainActivity` in the reporter's v6.1.13 log. The two Java references are internal method names left from the `MainActivity` -> `LIMESettings` rename; they do not launch an activity and are not the immediate crash cause.

Recommended cleanup after the functional metadata fix:

1. PR #89 fixed `method.xml` to point `android:settingsActivity` at the declared settings activity, `net.toload.main.hd.ui.LIMESettings`, and was merged to `master` as merge commit `ca2fde90883a` on 2026-05-26.
2. Rename the remaining internal `setMainActivityView(...)` naming to `setLIMESettingsView(...)` or a neutral name such as `setSettingsView(...)` to finish the class-rename cleanup and reduce future confusion.
3. Update/trim stale docs/tests that still describe `MainActivity` as the current Android settings activity, or explicitly mark them historical if they remain as architecture notes.

## Verification plan

- Reproduce on Android 13 if possible, preferably with a Samsung/One UI environment or a comparable Android 13 emulator/device.
- Historical context: `ejmoog` reported that clean reinstall of v6.1.12 reproduced the crash while in-place upgrade over an existing LIME 6 install could work; the original reporter later said both upgrade and reinstall paths still fail on v6.1.13.
- Do not ask for more generic v6.1.13 logs; the current second log was actionable enough for PR #89. An APK expected to contain PR #89 now exists as `LIMEHD2026-6.1.14.apk`; the reporter has responded positively for entering the app, and the current wait condition is clarification of bottom-nav/import visibility.
- Verify both app launch (`.ui.LIMESettings`) and IME activation/input (`.LIMEService`).
- For the newly captured Samsung Settings path, verify APK `LIMEHD2026-6.1.14.apk` so Samsung Settings no longer tries the undeclared `net.toload.main.hd.ui.MainActivity` class.
- Verify launching LIME from Samsung input-method settings after install/upgrade, because this path is different from launcher/`monkey -p net.toload.main.hd2026 1` launch.
- Also verify normal launcher `.ui.LIMESettings` launch still works and the v6.1.13 scrollbar fix remains intact.
- If a future log shows a real `net.toload.main.hd2026` `AndroidRuntime` crash after the settingsActivity fix, compare whether it is still `NestedScrollView.draw()` / `ScrollBarDrawable.mutate()` or another settings-launch path.
- Reporter validation was requested for APK `LIMEHD2026-6.1.15.apk`; wait for confirmation whether restoring/importing the preserved v5.2.4 or v6.0.0 backup now succeeds and whether `.ui.LIMESettings` / `.LIMEService` can reopen afterward without the `emoji_fts already exists` crash. Do not ask for duplicate v6.1.14 logs unless the failure mode changes.

## Current follow-up status

Locally reproduced on Samsung `SM-A325N`, Android 13 / API 33. Not reproduced on Google API 33 or Android 16 emulators. Crash stack points to `NestedScrollView.draw()` / Samsung framework scrollbar rendering.

Fix implemented in remote commit `5a73ac1d2842` and released in Android pre-release APK `LIMEHD2026-6.1.13.apk` / version `6.1.13`. The fix was verified locally on Samsung `SM-A325N`, Android 13 / API 33: `:app:assembleDebug` succeeded, the fixed build launched `.ui.LIMESettings` twice without an `AndroidRuntime` fatal exception, and release `LIMEHD2026-6.1.13.apk` was clean-installed and launched without the settings crash.

Because GitHub auto-closed this community issue from the `Fix #88` commit before reporter confirmation, automation reopened the issue and posted the v6.1.13 retest request: https://github.com/lime-ime/limeime/issues/88#issuecomment-4539808310. Reporter negative retest on 2026-05-26: `peter8777555` reported that v6.1.13 still cannot be used on the original Samsung A71 4G / Android 13 device after the install/update flow shown in screenshots. See https://github.com/lime-ime/limeime/issues/88#issuecomment-4539874261. The attached screenshots show the v6.1.13 install/update flow followed by an Android crash dialog saying 「萊姆輸入法2026」屢次停止運作, plus Android Settings showing 「無法開啟『萊姆輸入法2026』的設定」. The uploaded second log corroborates the Samsung Settings entry-point failure, but does not include a LIME `AndroidRuntime` crash stack for the screenshot-only crash dialog.

This means the v6.1.13 scrollbar fix was not sufficient for the reporter's device/path, even though it passed local Samsung `SM-A325N` Android 13 verification. PR #89 then fixed the stale IME `android:settingsActivity` metadata and `jrywu` merged it to `master` as `ca2fde90883a` on 2026-05-26, then closed #88 at 2026-05-26T05:10:54Z. A concurrent maintenance flow reopened #88 at 2026-05-26T05:12:09Z and posted https://github.com/lime-ime/limeime/issues/88#issuecomment-4540382676 to explain the then-current state: PR #89 had merged, but APK `LIMEHD2026-6.1.13.apk` still did not contain that fix. That state is now superseded by APK `LIMEHD2026-6.1.14.apk` and the reporter’s partial-positive follow-up; treat the issue as open/pending bottom-navigation/import-path clarification, and do not post another public retest request unless the reporter/maintainer asks. Automation kept a single targeted logcat collection request at https://github.com/lime-ime/limeime/issues/88#issuecomment-4539952465 after duplicate concurrent follow-up comments were removed, then added a mobile-logcat alternative at https://github.com/lime-ime/limeime/issues/88#issuecomment-4539984855.

Reporter `peter8777555` uploaded a first `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4539986307. Inspection found one `FATAL EXCEPTION`, but it belongs to unrelated package `de.android.telnet` (`PendingIntent` mutability error), not `net.toload.main.hd2026`; there are no `ScrollBarDrawable` or `NestedScrollView` entries in that uploaded log. Automation asked for a fresh filtered LIME log in https://github.com/lime-ime/limeime/issues/88#issuecomment-4539991114. Reporter then uploaded a second `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540030225. The second log contains no LIME `AndroidRuntime`/`FATAL EXCEPTION`, but it shows Samsung Settings trying to start `net.toload.main.hd2026/net.toload.main.hd.ui.MainActivity` and receiving `ActivityNotFoundException` multiple times. Source inspection confirms `method.xml` points `android:settingsActivity` to `net.toload.main.hd.ui.MainActivity`, while the manifest declares `.ui.LIMESettings` and `.ui.LIMEPreference` but not `.ui.MainActivity`. Automation acknowledged the useful second log in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540060560.

Reporter later noted in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540069317 that v5.2.4 still works on the same device but lacks microphone input, and then asked in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540095503 whether installing a newer version over v5.2.4 will automatically import all settings. Automation answered in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540141863 that same-package direct upgrades usually preserve app data, but v5.2.4-to-newer compatibility is not guaranteed, so the reporter should back up/export first and avoid uninstalling before upgrade.

Superseded follow-up state after PR #89 merge: the issue was initially kept open because APK `LIMEHD2026-6.1.13.apk` / version `6.1.13` did not contain the PR #89 metadata fix. That state was superseded when commit `60f078f5744e` built Android pre-release APK `LIMEHD2026-6.1.14.apk` / version `6.1.14` after the PR #89 fix and GitHub auto-closed #88 again. Automation then reopened this community issue and posted the scoped v6.1.14 retest request recorded below.

Remaining release-QA note: #64 visual regression checks for overflowing settings pages remain useful, but they are separate from #88's Samsung settings-entry retest watch and should not trigger public issue follow-up by themselves.

## Webhook update: v6.1.14 APK retest request

Commit `60f078f5744e` (`Fix #88 Samsung settings entry and release APK`) built Android pre-release APK `LIMEHD2026-6.1.14.apk` / version `6.1.14` after PR #89. Based on that commit's changed files and `output-metadata.json`, this APK is expected to contain the IME settings metadata fix that points Samsung/Android input-method settings at the declared `net.toload.main.hd.ui.LIMESettings` activity, plus the prior v6.1.13 Samsung/Android 13 settings scrollbar fix.

No local Samsung `SM-A325N` install/launch verification of v6.1.14 has been recorded yet. Also, the reporter's v6.1.13 screenshot crash dialog was not matched to a captured LIME `AndroidRuntime` stack; the actionable log evidence specifically identified the Samsung Settings `ActivityNotFoundException` path. Therefore v6.1.14 should be treated as a targeted settings-entry retest, not proof that every screenshot-only crash symptom is resolved.

At the time of this webhook update, GitHub had auto-closed #88 from the commit that built the PR-#89-containing APK, but this was a community-reported issue and the reporter had not yet confirmed the new APK on the original Samsung A71 / Android 13 device. Automation reopened the issue and posted a scoped v6.1.14 retest request: https://github.com/lime-ime/limeime/issues/88#issuecomment-4540597661.

Superseded current state from the retest request: #88 was reopened/pending reporter confirmation for APK `LIMEHD2026-6.1.14.apk` (https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.14.apk). The reporter has since responded with 「可以了」 plus a new import/settings UI concern; see the reporter-response section below for the live state. #64 visual regression checks and non-Samsung emulator smoke tests remain internal QA, not part of the reporter ask. Do not ask for more generic v6.1.13 logs; if a future v6.1.14 failure is reported, request the exact operation path, screenshots, and preferably a filtered `net.toload.main.hd2026` logcat captured during the failing launch path rather than another broad device-wide dump.

## Reporter response after v6.1.14 retest request

Reporter `peter8777555` responded in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540709915 after the v6.1.14 retest request. The response says `可以了`, but also says `設定頁 出不來` and `我 無法 匯入 LIME v5.2.4 設定`.

Screenshot evidence from the edited comment:

- The v6.1.14 screenshot shows the current setup/status screen open, including `v6.1.14 - 2026`, enabled keyboard and voice-input status cards, and no visible Android crash dialog. This is positive evidence that the reporter can now enter the v6.1.14 app/settings UI, but it does not by itself verify every requested path.
- The v5.2.4 comparison screenshot shows the older single-page setup UI with visible `備份/還原資料庫`, `本地備份`, `本地還原`, `GOOGLE 備份`, `GOOGLE 還原`, `DROPBOX 備份`, `DROPBOX 還原`, plus input-method import buttons. The reporter appears blocked on finding or using the equivalent restore/import path in v6.1.14.

Automation replied in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540812173 with scoped user guidance: in the newer v6.x UI, backup/restore is expected under the bottom `資料庫` / `資料庫管理` tab and input-method/table import under the bottom `輸入法` tab; if the reporter's Samsung A71 did not show the bottom tabs (`設定／輸入法／喜好設定／資料庫`), they should provide a full screenshot including the bottom edge so the project could check whether the settings page was clipped or the bottom navigation was not rendering. The reporter's later screenshots answered that narrow UI question: bottom navigation is visible and the database-management restore controls are present.

Current interpretation: v6.1.14 appears to have improved the Samsung crash/settings-entry path enough for the reporter to enter the app, and the screenshots do not show a missing bottom-navigation/layout-rendering bug. The reporter has now provided a concrete legacy restore/import failure with a useful LIME crash log. #88 should remain open for an engineering fix to the `emoji_fts already exists` database initialization path. This is distinct from the original `ActivityNotFoundException` path and from the v6.1.13 scrollbar crash. Because v6.0.2 can still import the v5.2.4 backup normally on the reporter's device, the next engineering comparison should focus on schema/emoji FTS migration differences introduced after v6.0.2. Do not ask for duplicate logs unless a later build changes the failure mode.

## Webhook update: v6.1.15 APK restore/import retest request

Commit `d0eb4c047aac799b28dde6f9a8643790aa0103f6` (`Fix #88 restore legacy DB emoji FTS fallback`) updated `LimeStudio/app/release/output-metadata.json` from version `6.1.14` to `6.1.15` and added Android pre-release APK `LIMEHD2026-6.1.15.apk`. The APK link is https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.15.apk.

This APK is expected to contain the targeted legacy database restore/import fix for the reporter's latest crash path: after restoring/importing old v5.2.4 / v6.0-era settings, LIME v6.1.14 could no longer open because `LimeDB` failed while creating `emoji_fts` during the DB 101 -> 104 upgrade path. The fix makes the FTS5-unavailable fallback robust by cleaning the stale/unloadable `emoji_fts` schema before creating the FTS4 table, and includes a regression test for the full restore/upgrade path.

GitHub auto-closed #88 from the fixing commit at 2026-05-26T07:40:21Z, but this is a community-reported issue and the reporter has not confirmed v6.1.15 on the original Samsung A71 / Android 13 device with their preserved backups. Automation reopened #88 and posted the scoped v6.1.15 retest request: https://github.com/lime-ime/limeime/issues/88#issuecomment-4541715912.

Current state: #88 is open/pending reporter confirmation for APK `LIMEHD2026-6.1.15.apk`. The retest scope is narrow: restore/import the preserved v5.2.4 or v6.0.0 backup, then confirm whether settings and IME startup still crash with `emoji_fts already exists`. The earlier Samsung scrollbar and stale `settingsActivity` paths appear improved by v6.1.13/v6.1.14, but reporter confirmation for this new database restore path is still pending.

