# Android Theming — LimeIME Architecture Notes

**Date:** 2026-04-19
**Status:** Implemented in v6.1

---

## 1. Keyboard Theme System

LimeIME supports 6 keyboard themes (indices 0–5) plus a 7th virtual theme (index 6) that follows the system.

### `KEYBOARD_THEMES[]` array (`LIMEService.java` ~line 4374)

| Index | Name           | Style resource              |
| ----- | -------------- | --------------------------- |
| 0     | Light          | `R.style.LIMETheme_Light`   |
| 1     | Dark           | `R.style.LIMETheme_Dark`    |
| 2     | Pink           | `R.style.LIMETheme_Pink`    |
| 3     | TechBlue       | `R.style.LIMETheme_TechBlue` |
| 4     | FashionPurple  | `R.style.LIMETheme_FashionPurple` |
| 5     | RelaxGreen     | `R.style.LIMETheme_RelaxGreen` |

Index 6 (`系統設定`) is a **virtual theme** — it is not in the array and has no dedicated style. At runtime it resolves to index 1 (dark) or index 0 (light) based on `Configuration.UI_MODE_NIGHT_MASK`.

### Theme application flow

1. User selects theme index in Settings → stored in `mKeyboardThemeIndex`.
2. `getKeyboardTheme()` maps index → `R.style.*` style ID.
3. A `ContextThemeWrapper` wraps the service context with the resolved style and is stored in `mThemeContext`.
4. `initialViewAndSwitcher(true)` rebuilds the keyboard view using `mThemeContext`.
5. Setting `mThemeContext = null` forces a full theme rebuild on the next call.

### Background color

`getKeyboardBackgroundColorForCurrentTheme()` switch-cases on `mKeyboardThemeIndex` (cases 0–6) to return a color resource for nav-bar tinting. Index 6 delegates to `isEffectiveDarkTheme()` to choose between `R.color.keyboard_background_dark` and `R.color.keyboard_background_light`.

---

## 2. Theme 6 — Follow System (Keyboard)

### Design

- `isEffectiveDarkTheme()` — single source of truth for "is dark currently active?"
  - Returns `true` for index 1 (explicit Dark) or index 6 when `UI_MODE_NIGHT_YES`.
  - Returns `false` for all other indices.
- `getKeyboardTheme()` — resolves index 6 → 1 or 0 before the bounds check.
- `onConfigurationChanged()` — watches `UI_MODE_NIGHT_MASK`; if changed while index 6 is active, sets `mThemeContext = null` to trigger rebuild.
- `createDialogBuilder()` — returns a dark or light `AlertDialog.Builder` based on `isEffectiveDarkTheme()`, replacing all bare `new AlertDialog.Builder(this)` calls in `showOptionsMenu()`, `showIMPicker()`, and `showHanConvertPicker()`.

### Key invariant

> Popup menus are dark **only** when the effective keyboard theme is dark (index 1, or index 6 in system-dark mode). All other themes use a light popup.

### Dark mode detection

```java
int uiMode = getResources().getConfiguration().uiMode
        & Configuration.UI_MODE_NIGHT_MASK;
boolean isDark = (uiMode == Configuration.UI_MODE_NIGHT_YES);
```

`onConfigurationChanged()` is called by Android when the system dark/light mode changes while the IME is active. The field `mLastUiNightMode` tracks the previous value so a change is detectable.

### Dialog styles

| Condition | Builder style |
| --------- | ------------- |
| Effective dark theme | `android.R.style.Theme_Material_Dialog_Alert` |
| All other themes | `android.R.style.Theme_Material_Light_Dialog_Alert` |

These are system styles available on API 21+ and require no custom resource definitions.

---

## 3. App UI — Follow System (MainActivity + Settings)

The main app UI (`MainActivity`) and the Settings screen (`LIMEPreference`) both follow the system day/night mode. This is independent of the keyboard's theme setting — the app chrome always tracks the OS, while the keyboard honors the user-chosen theme index.

### Mechanism

1. **`AppCompatDelegate.setDefaultNightMode(MODE_NIGHT_FOLLOW_SYSTEM)`** is called from a `static { … }` initializer in both `MainActivity` and `LIMEPreference`. The static block runs when the class is loaded — *before* `attachBaseContext()` wraps the base context — so AppCompat reads the right mode when it builds the context wrapper.
2. **Themes extend `Theme.AppCompat.DayNight`** which automatically resolves to `Theme.AppCompat.Light` in day mode and `Theme.AppCompat` in night mode, via the `values-night/` qualifier built into AppCompat itself.
3. **Explicit `android:windowBackground=?android:attr/colorBackground`** on both themes. Required on **API 35+ (targetSdk 36)** where edge-to-edge enforcement + transparent system bars cause the default `windowBackground` drawable to fall back to white in the absence of an explicit, theme-aware binding.

### Themes (`res/values/themes.xml`)

```xml
<!-- Base application theme — follows system day/night. -->
<style name="AppTheme" parent="Theme.AppCompat.DayNight">
    <item name="android:windowBackground">?android:attr/colorBackground</item>
</style>

<!-- Settings activity theme — same pattern. -->
<style name="LIMESettingsTheme" parent="Theme.AppCompat.DayNight">
    <item name="android:windowBackground">?android:attr/colorBackground</item>
</style>
```

> `?android:attr/colorBackground` (Android framework attribute) — **not** `?attr/colorBackground`, which resolves to the app's own attribute namespace and fails to link.

### Manifest

```xml
<application android:theme="@style/AppTheme" ...>
    <activity android:name=".ui.MainActivity" ... />
    <activity android:name=".ui.LIMEPreference"
              android:theme="@style/LIMESettingsTheme" ... />
</application>
```

### Dynamic status/nav bar icons

Both activities draw over transparent system bars (edge-to-edge). Icon brightness must flip based on the current theme so icons stay visible:

```java
int uiMode = getResources().getConfiguration().uiMode
        & Configuration.UI_MODE_NIGHT_MASK;
boolean isLight = (uiMode != Configuration.UI_MODE_NIGHT_YES);
WindowInsetsControllerCompat controller =
        new WindowInsetsControllerCompat(getWindow(), decorView);
controller.setAppearanceLightStatusBars(isLight);
controller.setAppearanceLightNavigationBars(isLight);
```

- `setAppearanceLightStatusBars(true)` = **dark** icons on a **light** bar (day mode).
- `setAppearanceLightStatusBars(false)` = **light** icons on a **dark** bar (night mode).

---

## 4. Gotchas Hit During Implementation

These are the pitfalls that cost multiple failed attempts on API 36 / AppCompat 1.7.1:

1. **`setDefaultNightMode()` placement matters.** Calling it in `onCreate()` before `super.onCreate()` is **too late** — `attachBaseContext()` has already wrapped the context with whatever mode was active at class load. Put it in a `static { … }` initializer so it fires before any instance method.

2. **Hardcoded `colorPrimary=#FFFFFF` in the app-level theme does NOT leak** into child activities that override with `android:theme="..."` in the manifest. This was a red herring. Activity-level themes fully override the application theme.

3. **Hardcoded drawable tints.** Icons in `res/menu/main.xml` reference vector drawables (`outline_share_24.xml`, `outline_settings_24.xml`) that had `android:tint="#000000"` baked in. Black icons become invisible against a dark ActionBar. Fix with `android:tint="?attr/colorControlNormal"` — a theme-aware AppCompat attribute that resolves to dark in light mode and light in dark mode.

4. **Hardcoded layout backgrounds.** `fragment_navigation_drawer.xml` had `android:background="#FAFAFA"` on the drawer ListView. Replace with `?android:attr/colorBackground`.

5. **Incremental install (`adb install -r`) doesn't always pick up resource-qualifier / theme changes reliably.** `adb uninstall` followed by a fresh `adb install` is the safe path when testing theme work.

---

## 5. Files Touched (app chrome dark mode)

| File | Change |
| ---- | ------ |
| `res/values/themes.xml` | `AppTheme` → `Theme.AppCompat.DayNight` + explicit `windowBackground`; added `LIMESettingsTheme` |
| `AndroidManifest.xml` | `LIMEPreference` uses `@style/LIMESettingsTheme` |
| `MainActivity.java` | `static { … }` initializer + dynamic system-bar icon handling via `WindowInsetsControllerCompat` |
| `LIMEPreference.java` | `static { … }` initializer + dynamic system-bar icon handling |
| `res/drawable/outline_share_24.xml` | `android:tint` → `?attr/colorControlNormal` |
| `res/drawable/outline_settings_24.xml` | `android:tint` → `?attr/colorControlNormal` |
| `res/layout/fragment_navigation_drawer.xml` | `android:background` → `?android:attr/colorBackground` |

---

## 6. Verification

Verified on Android 16 emulator (API 36, system in dark mode):

- MainActivity: dark ActionBar, light icons (share, settings, hamburger, overflow), dark window background, white text.
- NavigationDrawer: dark background, white item text.
- LIMEPreference: dark ActionBar, dark preference list, white text, dark dialogs (for ListPreference pickers).
- News/Help dialogs in MainActivity: dark background, white text.
- Keyboard with Theme 6 selected: follows system dark/light including popup menus.
