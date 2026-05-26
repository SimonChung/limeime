# Issue #88: LIME v6.1.12 / v6.1.13 settings crash on Samsung Android 13

## Problem statement

Community reporter `peter8777555` reports that LIME v6.1.12 cannot be used on a Samsung A71 4G running Android 13. After installing and opening the app, Android shows that 「萊姆輸入法」 repeatedly stops. The same reporter says older versions v5.2.4 and v6.0.0 worked, and they are currently using v6.0.2 as a workaround.

Live issue state checked 2026-05-26: issue is open, labeled `bug`, assigned to `jrywu`, and has one `limeimetw` acknowledgement asking for crash-scope details and logcat/crash stack evidence. Reporter follow-up now confirms the crash happens when opening the 「萊姆輸入法」 settings app. The original reporter reproduced it after upgrading from LIME v6.0.0 to v6.1.12, while another reporter (`ejmoog`) added that uninstalling and reinstalling v6.1.12 also crashes, but installing v6.1.12 over an existing LIME 6 install can still work.

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

Do not assume the renewed Samsung Settings entry-point failure is fixed by the v6.1.13 scrollbar APK; that second path needs its own targeted metadata change, build, and reporter retest before closure.

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

Release APK verification on 2026-05-26 (launcher path only; this did not exercise the input-method settings entry point now implicated by the second reporter log):

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

Still useful:

1. Fix/verify the IME settings activity metadata: the reporter's uploaded v6.1.13 log shows Samsung Settings repeatedly tries to launch `net.toload.main.hd2026/net.toload.main.hd.ui.MainActivity`, while current `AndroidManifest.xml` declares `.ui.LIMESettings` and `res/xml/method.xml` still advertises the stale `android:settingsActivity="net.toload.main.hd.ui.MainActivity"`.
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

Source inspection confirms `LimeStudio/app/src/main/res/xml/method.xml` currently declares:

```xml
<input-method ... android:settingsActivity="net.toload.main.hd.ui.MainActivity"/>
```

But `LimeStudio/app/src/main/AndroidManifest.xml` declares exported launcher activity `.ui.LIMESettings` and settings/preference activity `.ui.LIMEPreference`, not `.ui.MainActivity`. The IME settings entry uses the standard `android:settingsActivity` hook; on the reporter's Samsung/One UI device this fails with `ActivityNotFoundException` because the target activity is not declared. This is likely a separate remaining #88 failure path after the v6.1.13 scrollbar fix. PR #89 (https://github.com/lime-ime/limeime/pull/89) is the current targeted Android fix: it updates the IME metadata to point at declared `net.toload.main.hd.ui.LIMESettings`. Verify launching LIME from Android/Samsung input-method settings, not only via launcher/monkey.

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

Only the `method.xml` reference is an Android runtime entry point and explains why Samsung Settings still calls `MainActivity`. The two Java references are internal method names left from the `MainActivity` -> `LIMESettings` rename; they do not launch an activity and are not the immediate crash cause.

Recommended cleanup after the functional metadata fix:

1. Fix `method.xml` to point `android:settingsActivity` at the declared settings activity, currently `net.toload.main.hd.ui.LIMESettings` in PR #89.
2. Rename the remaining internal `setMainActivityView(...)` naming to `setLIMESettingsView(...)` or a neutral name such as `setSettingsView(...)` to finish the class-rename cleanup and reduce future confusion.
3. Update/trim stale docs/tests that still describe `MainActivity` as the current Android settings activity, or explicitly mark them historical if they remain as architecture notes.

## Verification plan

- Reproduce on Android 13 if possible, preferably with a Samsung/One UI environment or a comparable Android 13 emulator/device.
- Historical context: `ejmoog` reported that clean reinstall of v6.1.12 reproduced the crash while in-place upgrade over an existing LIME 6 install could work; the original reporter later said both upgrade and reinstall paths still fail on v6.1.13.
- Do not ask for more generic v6.1.13 logs before a new targeted settings-entry APK exists; the current second log is actionable enough for PR #89 / equivalent metadata fix.
- Verify both app launch (`.ui.LIMESettings`) and IME activation/input (`.LIMEService`).
- For the newly captured Samsung Settings path, review/verify PR #89's `android:settingsActivity` change in `LimeStudio/app/src/main/res/xml/method.xml` so Samsung Settings no longer tries the undeclared `net.toload.main.hd.ui.MainActivity` class.
- Verify launching LIME from Samsung input-method settings after install/upgrade, because this path is different from launcher/`monkey -p net.toload.main.hd2026 1` launch.
- Also verify normal launcher `.ui.LIMESettings` launch still works and the v6.1.13 scrollbar fix remains intact.
- If a future log shows a real `net.toload.main.hd2026` `AndroidRuntime` crash after the settingsActivity fix, compare whether it is still `NestedScrollView.draw()` / `ScrollBarDrawable.mutate()` or another settings-launch path.
- After a newer targeted Android APK lands, ask the reporter(s) to retest with the direct APK link and confirm both launching from Android/Samsung input-method settings and opening the app directly.

## Current follow-up status

Locally reproduced on Samsung `SM-A325N`, Android 13 / API 33. Not reproduced on Google API 33 or Android 16 emulators. Crash stack points to `NestedScrollView.draw()` / Samsung framework scrollbar rendering.

Fix implemented in remote commit `5a73ac1d2842` and released in Android pre-release APK `LIMEHD2026-6.1.13.apk` / version `6.1.13`. The fix was verified locally on Samsung `SM-A325N`, Android 13 / API 33: `:app:assembleDebug` succeeded, the fixed build launched `.ui.LIMESettings` twice without an `AndroidRuntime` fatal exception, and release `LIMEHD2026-6.1.13.apk` was clean-installed and launched without the settings crash.

Because GitHub auto-closed this community issue from the `Fix #88` commit before reporter confirmation, automation reopened the issue and posted the v6.1.13 retest request: https://github.com/lime-ime/limeime/issues/88#issuecomment-4539808310. Reporter negative retest on 2026-05-26: `peter8777555` reported that v6.1.13 still cannot be used on the original Samsung A71 4G / Android 13 device after the install/update flow shown in screenshots. See https://github.com/lime-ime/limeime/issues/88#issuecomment-4539874261. The attached screenshots show the v6.1.13 install/update flow followed by an Android crash dialog saying 「萊姆輸入法2026」屢次停止運作, plus Android Settings showing 「無法開啟『萊姆輸入法2026』的設定」. The uploaded second log corroborates the Samsung Settings entry-point failure, but does not include a LIME `AndroidRuntime` crash stack for the screenshot-only crash dialog.

This means the v6.1.13 scrollbar fix was not sufficient for the reporter's device/path, even though it passed local Samsung `SM-A325N` Android 13 verification. Keep the issue open and do not close from the fix commit or APK alone. Automation kept a single targeted logcat collection request at https://github.com/lime-ime/limeime/issues/88#issuecomment-4539952465 after duplicate concurrent follow-up comments were removed, then added a mobile-logcat alternative at https://github.com/lime-ime/limeime/issues/88#issuecomment-4539984855.

Reporter `peter8777555` uploaded a first `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4539986307. Inspection found one `FATAL EXCEPTION`, but it belongs to unrelated package `de.android.telnet` (`PendingIntent` mutability error), not `net.toload.main.hd2026`; there are no `ScrollBarDrawable` or `NestedScrollView` entries in that uploaded log. Automation asked for a fresh filtered LIME log in https://github.com/lime-ime/limeime/issues/88#issuecomment-4539991114. Reporter then uploaded a second `lime88_crash.zip` in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540030225. The second log contains no LIME `AndroidRuntime`/`FATAL EXCEPTION`, but it shows Samsung Settings trying to start `net.toload.main.hd2026/net.toload.main.hd.ui.MainActivity` and receiving `ActivityNotFoundException` multiple times. Source inspection confirms `method.xml` points `android:settingsActivity` to `net.toload.main.hd.ui.MainActivity`, while the manifest declares `.ui.LIMESettings` and `.ui.LIMEPreference` but not `.ui.MainActivity`. Automation acknowledged the useful second log in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540060560.

Reporter later noted in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540069317 that v5.2.4 still works on the same device but lacks microphone input, and then asked in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540095503 whether installing a newer version over v5.2.4 will automatically import all settings. Automation answered in https://github.com/lime-ime/limeime/issues/88#issuecomment-4540141863 that same-package direct upgrades usually preserve app data, but v5.2.4-to-newer compatibility is not guaranteed, so the reporter should back up/export first and avoid uninstalling before upgrade.

Current next debugging/fix area: PR #89 (https://github.com/lime-ime/limeime/pull/89) corrects the IME settings activity metadata. Verify the Android/Samsung input-method settings launch path before producing a newer targeted APK. Do not ask for another APK retest until a newer targeted fix/build exists.

Still useful before final closure: #64 visual regression checks for overflowing settings pages, but that regression check should not block the renewed crash investigation.
