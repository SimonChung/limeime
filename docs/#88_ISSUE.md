# Issue #88: LIME v6.1.12 crashes / cannot be used on Android 13

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

The app package is `net.toload.main.hd2026`, versionName `6.1.12`, with launcher settings activity `.ui.LIMESettings` and input method service `.LIMEService`. On the Samsung `SM-A325N` API 33 reproduction, `monkey -p net.toload.main.hd2026 1` starts `.ui.LIMESettings`, then the process exits and foreground returns to Android Settings.

The most likely immediate trigger is the root `NestedScrollView` in `LimeStudio/app/src/main/res/layout/fragment_setup.xml` (`@+id/setup_scroll`), because it is the default settings landing page and the stack reaches `NestedScrollView.draw()`. Other settings screens also use `NestedScrollView` and should receive the same defensive treatment to avoid the same Samsung/Android 13 framework path:

- `fragment_setup.xml` / `@+id/setup_scroll`
- `fragment_db_manager.xml` / `@+id/db_manager_scroll`
- `fragment_im_detail.xml` / `@+id/im_detail_scroll`
- `sheet_manage_im_add.xml`
- `sheet_manage_im_edit.xml`
- `sheet_manage_related_add.xml`
- `sheet_manage_related_edit.xml`

Do not assume this is fixed by a newer APK until a relevant crash stack/reproducer is available and a targeted change lands.

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

Release APK verification on 2026-05-26:

- Tested `LimeStudio/app/release/LIMEHD2026-6.1.13.apk` on Samsung `SM-A325N`, Android 13 / API 33.
- Confirmed installed package reports `versionName=6.1.13`.
- Clean-installed the release APK, launched `net.toload.main.hd2026` with `monkey -p net.toload.main.hd2026 1`, and confirmed the LIME process stayed alive with no `AndroidRuntime` fatal exception.
- Ran a second force-stop plus explicit `.ui.LIMESettings` launch. The LIME process stayed alive and `AndroidRuntime:E` remained empty. Foreground moved to Android keyboard settings during the setup flow, but there was no app crash.

## Follow-up questions

Already answered / added publicly:

- `peter8777555` confirmed the crash happens when opening the 「萊姆輸入法」 settings app.
- `peter8777555` reproduced it after upgrading from LIME v6.0.0 to v6.1.12, and is currently using v6.0.2 normally.
- `ejmoog` reported the same issue after uninstalling and reinstalling v6.1.12; their in-place upgrade over an existing LIME 6 install can still work.
- A local crash stack is now available from Samsung `SM-A325N` API 33.

Still useful:

1. Confirm whether the IME keyboard itself also crashes when enabled/switched to after a clean install, or whether the observed failure is limited to opening settings.
2. Re-run #64 visual checks: on the four top-level phone tabs, overflowing content must still show a visible scrollbar and the last row must scroll fully above the bottom navigation.
3. Smoke-test a Google API 33 emulator with the fixed build to ensure settings pages still scroll correctly and the custom scrollbar behavior does not regress non-Samsung Android 13.

## Verification plan

- Reproduce on Android 13 if possible, preferably with a Samsung/One UI environment or a comparable Android 13 emulator/device.
- Test clean reinstall of v6.1.12 early, because `ejmoog` reports uninstall/reinstall is sufficient to reproduce the crash.
- Test in-place upgrade from an existing LIME 6 install separately, because reporter evidence now differs between upgrade and reinstall paths.
- Verify both app launch (`.ui.LIMESettings`) and IME activation/input (`.LIMEService`).
- After a targeted fix lands in a new Android APK, ask the reporter(s) to retest with the direct APK link and confirm whether the settings launch crash is resolved for both clean install and upgrade paths.

## Current follow-up status

Locally reproduced on Samsung `SM-A325N`, Android 13 / API 33. Not reproduced on Google API 33 or Android 16 emulators. Crash stack points to `NestedScrollView.draw()` / Samsung framework scrollbar rendering.

Fix implemented and verified locally on Samsung `SM-A325N`, Android 13 / API 33: `:app:assembleDebug` succeeded, clean-installed the debug `LIMEHD2026-6.1.12.apk`, launched `.ui.LIMESettings` twice, process stayed alive, settings remained foreground, and `adb logcat -d -v time AndroidRuntime:E *:S` emitted no fatal exception.

Release `LIMEHD2026-6.1.13.apk` was also clean-installed and verified on the same Samsung Android 13 device with no `AndroidRuntime` crash. Still need #64 visual regression checks before public retest request.
