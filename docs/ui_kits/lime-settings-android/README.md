# LIME Settings — Android UI kit (Material 3 / Material You)

An interactive recreation of the LIME 萊姆輸入法 container app on **Android**, as a
counterpart to `ui_kits/lime-settings/` (iOS). Same four top-level tabs, re-laid-out
for **Material 3**:

| Tab | Title | Screen |
|---|---|---|
| 設定 | — | `AndroidSetupTab.jsx` — activation guide + About |
| 輸入法 | 管理輸入法 | `AndroidIMTab.jsx` — IM list, 關聯字庫, drill-down detail |
| 喜好設定 | 喜好設定 | `AndroidPrefsTab.jsx` — preference rows |
| 資料庫 | 資料庫管理 | `AndroidDBTab.jsx` — backup / restore |

## The one big difference vs iOS: the system colour scheme

On Android the settings-app accent is **inherited from the OS Material You palette** at
runtime — not hard-coded, and not "just `colors.xml`". The real path is three layers:

1. **Seed resolution — `SystemAccentColor.java`.** Reads the user's Material You choice
   from `Settings.Secure.getString(…, "theme_customization_overlay_packages")`, parsing the
   `system_palette` key (fallback `accent_color`) to a seed colour.
2. **Apply — `LIMESettings.onCreate()`.** First line, before `super.onCreate()`:
   `DynamicColors.applyToActivityIfAvailable(this, SystemAccentColor.dynamicColorOptions(this))`.
   The seed goes into `DynamicColorsOptions.Builder().setContentBasedSource(seed)`, so the
   **entire M3 tonal palette is generated from the system seed**.
3. **Day/night — `MODE_NIGHT_FOLLOW_SYSTEM`** (static initializer) follows system light/dark.

`themes.xml` (`Theme.MaterialComponents.DayNight`) only supplies **fallback** accents
(`material_blue` #2196F3 / `lime_green` #4CAF50) for when Dynamic Colors is unavailable
(pre-Android-12 / disabled), and points the action bar at the **surface** colour rather than
`colorPrimary`. The **6 keyboard themes** in `colors.xml` (淺色/深色/粉紅/科技藍/時尚紫/放鬆綠
via the `LIMETheme.*` styles) are a *separate* keyboard-surface preference — do not conflate
them with the app's Material You chrome.

Crucially, **this is a system setting, not an app setting** — the user chooses it in
Android Settings; LIME simply inherits it. So the kit models it **outside** the phone: an
OS-style "系統設定 · 佈景主題色" card sits in the letterbox next to the device. Switching its
chips re-seeds the device's M3 token set (`--md-primary`, `--md-secondary-container`,
surfaces, …) and every surface, button, switch, link and nav indicator retints — exactly
what `DynamicColors` does when the system theme changes. There is **no theme control inside
any app screen**. iOS, by contrast, uses a fixed LIME brand palette.

> Recreation caveat: the four chip seeds are curated M3 light/dark schemes, not a live
> wallpaper-extraction algorithm — they stand in for "whatever seed the OS supplies."

**Dark mode is implemented** (`MODE_NIGHT_FOLLOW_SYSTEM`): the OS card's 深淺色模式 segmented
control swaps the device between full M3 light and dark role sets, and it composes with the
accent seed — any of the four palettes works in either mode. Like the accent, this is a
*system* setting modelled outside the phone, not an in-app screen.

## Scope: Settings app vs. soft keyboard (what this kit touches)

The Android `res/values/colors.xml` and `themes.xml` are **shared** resource files that
hold BOTH the Settings-app chrome and the soft-keyboard styling. This kit models **only the
Settings-app subset**; it never references, redefines, or restyles the keyboard. The split:

| File | Settings-app (modelled here) | Soft keyboard (left untouched) |
|---|---|---|
| `themes.xml` | `LIMESettingsTheme` / `AppTheme` (`Theme.MaterialComponents.DayNight` + DynamicColors), `LIME.ActionBarStyle`, `LIME.ToolbarContentTheme` | The 6 `LIMETheme.{Light,Dark,Pink,TechBlue,FashionPurple,RelaxGreen}` styles — each maps `LIMEKeyboardStyle`, `LIMEKeyboardBaseView`, **`LIMEKeyboardLayout`**, **`LIMEPopupKeyboardLayout`**, `LIMECandidateView` (keyboard theming **and layout**) |
| `colors.xml` | `setup_status_*` (status card), `material_blue` (links/FAB/tabs), `lime_green` (switches) | `keyboard_background_*`, `second_background_*`, `composing_background_*`, `candidate_*`, `foreground_*`, `*_hl` for all 6 themes (keyboard/candidate-bar surfaces) |

**Brand greens are the design system's own.** The LIME brand greens in
`tokens/colors.css` are derived from the **lime-fruit app-icon gradient**
(`#B2D234`→`#00833E`), defined independently of the keyboard's 放鬆綠 / `relax_green`
palette (`keyboard_background_relax_green` etc.) — which stays the untouched original in the
keyboard's own domain. Where a Settings screen shows a keyboard preference (喜好設定 ▸
鍵盤樣式 ▸ 放鬆綠, or an IM's 軟鍵盤配置 ▸ 鍵盤佈局), that is a Settings **control row** — the
keyboard surface itself is never rendered or themed by this kit.

## Material 3 specifics modelled here
- **Bottom NavigationBar** with the pill-shaped `secondaryContainer` active indicator; the
  active icon fills and the label goes bold.
- **M3 Switch** — 52×32 track, 16→24px thumb, checkmark glyph when on.
- **Buttons** — filled / tonal / outlined / text + the destructive variant.
- **Extended FAB** (`primaryContainer`) for 新增 on the IM tab.
- **Top app bar** follows the **surface** colour (not `colorPrimary`), matching
  `LIME.ActionBarStyle`; each fragment owns its own `MaterialToolbar` (activity ActionBar
  hidden). The app is edge-to-edge with transparent system bars.
- **Responsive nav (in the real app):** phone = bottom `BottomNavigationView`; tablet =
  `NavigationRailView` + a two-pane `TwoPaneHostFragment` for the 輸入法 tab. **Both are
  implemented** — the 裝置類型 switch in the letterbox flips the device between a phone
  (bottom nav, full-screen IM drill-down) and a tablet (left navigation rail + master/detail
  IM list ⇄ detail pane).
- **Tonal surface elevation** — `surface` / `surfaceContainerLow` / `surfaceContainer` roles.

## Iconography
Uses the authentic **Material Symbols Rounded** webfont (Google Fonts, `display=block`)
rather than hand-drawn SVGs — these are the real Android system icons. Loaded by ligature
name (e.g. `settings`, `format_list_bulleted`, `tune`, `inventory_2`). They render as
glyphs in any browser; the project's DOM-diff screenshot tool can't substitute ligatures,
so captures may show the ligature text — open the file in a browser to see the glyphs.

## Files
- `index.html` — Pixel-style device frame, app shell, status bar, and the OS-level
  system-theme card (outside the phone) that drives `applyPalette()`.
- `m3.jsx` — Material 3 primitives (`Icon`, `Switch`, `Button`, `NavBar`)
  + the Material You palette table & `applyPalette()`. Exposed on `window.LimeM3`.
- `Android{Setup,IM,Prefs,DB}Tab.jsx` — the four screens.

## Source
Re-created from `docs/LIME_SETTINGS.md` (Android column), `SystemAccentColor.java`,
`LIMESettings.java`, and `res/values/{themes,colors}.xml` in
<https://github.com/lime-ime/limeime>.
