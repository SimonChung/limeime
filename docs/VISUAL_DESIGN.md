# LIME 萊姆輸入法 — Design System

A design system for **LIME 萊姆輸入法** (LimeIME) — a free, open-source (GPLv3)
Traditional-Chinese **input method / soft keyboard** for Android and iOS. LIME
ships a dozen+ Chinese input methods (注音 Bopomofo, 倉頡 Cangjie, 速成, 大易,
行列, 拼音, 華象, …) plus the **container "Settings" app** that installs codetables,
edits character-mapping records, manages backups, and tunes keyboard behaviour.

This system captures LIME's brand (the lime-fruit wordmark, the green gradient)
and the **iOS-HIG settings vocabulary** the apps are built from, so agents can
produce on-brand LIME screens, mocks, and assets.

> **Scope.** This design system covers **only the LIMESettings container app** —
> its colour theming and screen layout (設定 · 輸入法 · 喜好設定 · 資料庫), on both
> iOS and Android. It deliberately does **not** model the **soft keyboard**: the six
> keyboard themes (淺色 / 深色 / 粉紅 / 科技藍 / 時尚紫 / 放鬆綠) and the on-screen
> keyboard layouts are a separate concern, owned by the keyboard extension, and are
> out of scope here. Where a Settings screen shows a keyboard preference (e.g.
> 喜好設定 ▸ 鍵盤樣式 ▸ 放鬆綠, or an IM's 軟鍵盤配置 ▸ 鍵盤佈局), that is a Settings
> *control row* — the keyboard surface itself is never restyled or laid out by this system.

#### Settings app vs. soft keyboard — the resource split
The Android `res/values/colors.xml` and `themes.xml` are **shared** files holding BOTH the
Settings-app chrome and the soft-keyboard styling. This system models **only the
Settings-app subset** and never references, redefines, or restyles the keyboard:

| File | Settings app (modelled) | Soft keyboard (untouched) |
|---|---|---|
| `themes.xml` | `LIMESettingsTheme` / `AppTheme` (`Theme.MaterialComponents.DayNight` + DynamicColors), `LIME.ActionBarStyle`, `LIME.ToolbarContentTheme` | The 6 `LIMETheme.{Light,Dark,Pink,TechBlue,FashionPurple,RelaxGreen}` styles → `LIMEKeyboardStyle`, `LIMEKeyboardBaseView`, **`LIMEKeyboardLayout`**, **`LIMEPopupKeyboardLayout`**, `LIMECandidateView` (keyboard theming **and layout**) |
| `colors.xml` | `setup_status_*` (status card), `material_blue` (links/FAB/tabs), `lime_green` (switches) | `keyboard_background_*`, `second_background_*`, `composing_background_*`, `candidate_*`, `foreground_*`, `*_hl` for all 6 themes |

**Brand greens are the design system's own.** The LIME brand greens in `tokens/colors.css`
are derived from the **lime-fruit app-icon gradient** (`#B2D234`→`#00833E`), defined
independently of the keyboard's 放鬆綠 / `relax_green` palette
(`keyboard_background_relax_green` etc.) — that keyboard palette is the untouched original in
the keyboard's own domain.

### Repository layout
This project is structured for merging into `lime-ime/limeime`. All design content
lives under `docs/`. The repo **root** keeps only the files the design-system
tooling needs there — `readme.md` (orientation/manifest), a one-line `styles.css`
that re-exports `docs/styles.css`, and the generated `_ds_*` artifacts — plus the
two source mirrors `LimeIME-iOS/` and `LimeStudio/`. Everything design-related —
`styles.css`, `tokens/`, `assets/`, `components/`, `foundations/`, `ui_kits/`, this
`VISUAL_DESIGN.md`, `LIME_SETTINGS.md`, and `SKILL.md` — lives **under `docs/`**.

## Sources used to build this system
Everything here was reverse-engineered from the official repository — explore it
for deeper fidelity:

- **GitHub:** <https://github.com/lime-ime/limeime> (branch `master`)
  - `docs/LIME_SETTINGS.md` — the canonical 4-tab Settings-app spec (iOS + Android)
  - `LimeIME-iOS/LimeSettings/` — SwiftUI source for the container app
    (`SetupTabView`, `IMListView`, `IMDetailView`, `PreferencesTabView`,
    `DBManagerView`, `SettingsTheme.swift`, `SettingsMetrics.swift`)
  - `LimeStudio/app/src/main/java/.../ui/view/` — the real Android settings fragments
    (`SetupFragment`, `ManageImFragment`, `ImListFragment`, `ImDetailFragment`,
    `DbManagerFragment`, `LimePreferenceFragment`, `ManageRelatedFragment`,
    `TwoPaneHostFragment`) + adapters; `.../ui/controller/` (`SetupImController`,
    `ManageImController`); `.../ui/{LIMESettings,NavigationManager,LIMEPreference}.java`
  - `LimeStudio/app/src/main/java/.../global/SystemAccentColor.java` — resolves the
    user's Material You seed from `Settings.Secure`
  - `LimeStudio/app/src/main/res/layout/*.xml` — the real fragment layouts
    (`fragment_setup`, `fragment_db_manager`, `fragment_im_list`, `item_im_row`,
    `fragment_im_detail`, `fragment_two_pane_im_host`, …)
  - `LimeStudio/app/src/main/res/values/{themes,colors}.xml` — Material 3 DayNight
    themes (fallback accents) + the 6 keyboard-theme palettes
  - `LimeIME-iOS/LimeSettings/Assets.xcassets/AppIcon.appiconset/` — the app icon
- **Latest release:** v6.1.15 · package `net.toload.main.hd2026` · minSDK 21 / targetSDK 36
- **Team:** Jeremy Wu, Julian Chen, Art Hung

> The original Swift/Android source files imported during construction live under
> `LimeIME-iOS/` and `LimeStudio/` in this project for reference. They are **not**
> part of the shipped system (only `styles.css` + its imports, components, cards,
> and assets are).

---

## CONTENT FUNDAMENTALS

LIME's product copy is **Traditional Chinese (zh-Hant), Taiwan idiom**, with
short technical English where it's a proper noun (`.limedb`, GitHub, Emoji).

- **Voice — plain, instructional, reassuring.** Copy explains *what a control
  does* and *what will happen*, never marketing fluff. Toggle subtitles read like
  documentation: 「部份輸入法可能會影響中英混打功能」,「無候選字詞時顯示中文標點選項」.
- **Person — mostly impersonal imperative.** Buttons are bare verbs/verb-phrases:
  「前往設定」「備份資料庫」「移除輸入法」「確認新增」. Guidance addresses the user politely
  with 「請」: 「請按下一步後，在系統鍵盤輸入法頁面啟用萊姆輸入法」. First person is never used.
- **Privacy is a recurring promise**, stated flatly: 「萊姆輸入法不會收集或傳送任何
  個人資料。」 LIME leans on its 5-permissions-only, no-account stance.
- **Status is concrete and symbol-tagged.** Setup states append a glyph to the
  text: 「萊姆內建語音輸入已啟用 ✓」「…尚未啟用 ✕」「需至系統設定開啟麥克風權限 ⚠」.
- **Section headers are 2–5-char nouns**: 鍵盤外觀 · 鍵盤回饋 · 輸入法行為 · 簡繁轉換 ·
  關聯字與學習 · 英文鍵盤 · 備份 · 還原. Footers are one explanatory sentence ending in 。
- **Punctuation** is full-width CJK (，。「」), and numbers/units stay half-width
  with a thin gap: 「34,838 筆」「2.4 MB」「第 1 頁 / 共 95,029 筆」.
- **No emoji in chrome.** Emoji appear only as a *feature* (the Emoji candidate
  row), never as decoration. No exclamation marks, no hype.

**Casing (English):** Title-style for proper nouns (GitHub, BIG5, Unicode);
file extensions lowercase with leading dot (`.cin` `.lime` `.limedb`).

---

## VISUAL FOUNDATIONS

**The brand mark.** A stylized **lime fruit** (rounded leaf-lemon silhouette)
carrying the wordmark **"LimE"** knocked out in white, filled with a diagonal
green gradient — bright yellow-lime at top-left (`#B2D234`) flowing to deep green
at bottom-right (`#00833E`). This gradient (`--brand-gradient`) is the single
strongest brand asset; use it for the app icon, hero logo tiles, and splash.

**Color.** The product *chrome* is pure **iOS HIG light appearance** — white
pages (`--bg #FFF`), `#F2F2F7` grouped backgrounds, hairline separators, and the
system label hierarchy (black / 60%-black / 30%-black). LIME's identity enters
through **green**: the brand green `#009444` is the action/accent color (filled
buttons, links, FABs), and **lime green `#4CAF50`** is the ON
state of every toggle. The native apps actually use iOS systemBlue for the FAB
and links; this system keeps that blue available as `--accent-blue` but promotes
**brand green to the primary accent** for a more LIME-forward re-layout. Status
uses iOS semantics: green success, orange warning, red destructive — color is
carried by icon + text over a *subtle tint*, not a saturated fill.

**Type.** The native face is **SF Pro** (iOS system) + **PingFang TC** for Chinese,
sized to **iOS Dynamic Type (Large)**: 34/700 large title → 17/400 body →
13/400 footnote → 12 caption. There are no custom/brand fonts — LIME deliberately
rides the platform. Web specimens fall back to **Noto Sans TC** for CJK. Weights
are limited to regular / semibold / bold. Screen titles are **34px bold,
left-aligned**, sitting statically above the scroll (not collapsing nav titles).

**Layout.** Single-column, **560px reading-width cap** (`--content-max-width`)
that centers on iPad and never engages on iPhone. Page padding 24px, grouped
sections 16px inset. The unit of composition is the **grouped form section**: an
uppercase footnote header, a 10px-radius card of hairline-separated 44px rows, and
a footnote footer. Everything in Settings is built from this.

**Shape & elevation.** Corner radii are gentle: **10px** cards, **12px** buttons
/ modals, **14px** global overlays, **18px** the app-icon tile, pills for toggles
/ segmented controls. Grouped cards are **flat** (no shadow) — depth is reserved
for things that float: the **FAB** (`0 2px 4px rgba(0,0,0,.3)`), modal overlays
(`0 4px 8px`), the switch thumb (`0 1px 1px`), and the lime hero glow
(`0 6px 20px rgba(0,131,62,.28)`).

**Motion.** Restrained and iOS-native. Toggles slide their thumb on a
`220ms cubic-bezier(.4,0,.2,1)`; detail screens **push in from the right** (300ms
ease); buttons dim ~8% on press (`brightness(.92)`); the progress overlay is a
plain circular spinner. No bounces, no decorative loops, no parallax.

**States.** Hover/press = slight brightness drop (filled) or 12% tint fill
(bordered). Disabled = 40% opacity. **Disabled/inactive IMs render at ~50%
opacity** (mirroring Android's `HALF_ALPHA_VALUE`). Destructive actions are red
text, confirmed with an alert before they run.

**IM identity badges.** Each installed input method is shown as a **grey circle
containing its representative character** — ㄅ for 注音 (the bopomofo symbol),
otherwise the first character of the name (倉 速 易 行 拼). Identical on iOS and
Android; this replaced the earlier per-IM coloured icon tiles. Rows are **name
only** (catalog descriptions / counts live in the IM catalogue, not the list).

**Imagery.** There is essentially none — LIME is a utility. The only "image" is
the lime logo. No photography, no illustration, no gradients-as-background beyond
the brand mark itself. Keep surfaces clean and content-dense.

---

## ICONOGRAPHY

- **Native system:** the apps use **Apple SF Symbols** on iOS
  (`gearshape`, `list.bullet`, `slider.horizontal.3`, `archivebox`, `keyboard`,
  `checkmark.circle.fill`, `exclamationmark.triangle.fill`, `xmark.circle.fill`,
  `square.and.arrow.up`, `arrow.down.circle`, `text.bubble`, `magnifyingglass`,
  `plus`, `chevron.left/right`) and **Material Symbols** on Android. Icons are
  monochrome, tinted by context (brand green tiles, status colors, secondary grey).
- **No icon font is bundled in this system.** SF Symbols and Apple's system glyphs
  **cannot be redistributed**, so the UI kit substitutes **Lucide-style stroke
  SVGs** (`ui_kits/lime-settings/icons.jsx`) matched 1:1 to the SF Symbols above,
  plus a few hand-built filled status glyphs inside `StatusBanner`. ⚠️ **This is a
  substitution** — if you have an SF Symbols / Material Symbols license, swap them
  back for pixel-exact fidelity. For new web work, **Lucide via CDN** is the
  recommended match (clean, rounded, consistent 1.9px stroke).
- **IM badges:** input-method rows use a **grey circle with the IM's representative
  character** (ㄅ 倉 速 易 行 拼), not a coloured tile — identical on both platforms.
  Other list-row leading icons are monochrome, tinted by context (grey / status).
- **Android** uses the authentic **Material Symbols Rounded** webfont (real system
  glyphs), loaded by ligature name; iOS uses the Lucide-style SVG substitutes above.
- **Status glyphs are filled circles** (✓ in a green disc, ⚠ in a triangle, ✕ in
  a red disc) — these are intentionally filled, not stroked, matching SF Symbols'
  `.fill` variants.
- **Emoji** are a keyboard *feature* (the Emoji candidate row), never UI chrome.
- **Brand assets** live in `assets/`: `lime-logo.png` (1024² iOS icon),
  `lime-icon-180.png`, `lime-logo-android.png`.

---

## INDEX / MANIFEST

**Foundations**
- `styles.css` — entry point (consumers link this); `@import`s the four token files
- `tokens/colors.css` · `tokens/typography.css` · `tokens/spacing.css` · `tokens/fonts.css`

**Components** (`window.LIMEDesignSystem_6ca3c0.*`)
- `components/controls/` — **Button**, **Switch**, **SegmentedControl**, **Stepper**
- `components/layout/` — **ListGroup**, **ListRow**
- `components/feedback/` — **StatusBanner**
- `components/navigation/` — **TabBar**

**Foundation specimen cards** — `foundations/*.card.html` (Colors, Type, Spacing, Brand)

**UI Kits** (the two platforms are kept **visually aligned** — same structure,
platform-native styling)
- `ui_kits/lime-settings/` — the re-laid-out 4-tab **iOS** Settings app
  (`index.html` + `SetupTab/IMTab/PrefsTab/DBTab.jsx` + `icons.jsx`); see its `README.md`
- `ui_kits/lime-settings-android/` — the same 4 tabs in **Material 3 / Material You**
  (`index.html` + `m3.jsx` + `Android*Tab.jsx`). Implements: system-inherited Material
  You accent + **light/dark** (both modelled by an OS control outside the phone), and a
  **phone bottom-nav ⇄ tablet navigation-rail + two-pane** form-factor switch; see its `README.md`

**Spec** — `LIME_SETTINGS.md` (alongside this `VISUAL_DESIGN.md`) — the canonical 4-tab
Settings-app spec with the re-layout revision header (iOS + Android).

**Assets** — `assets/lime-logo.png`, `lime-icon-180.png`, `lime-logo-android.png`

**Other** — `SKILL.md` (Agent-Skill manifest); `LimeIME-iOS/` + `LimeStudio/` at the
repo root hold the imported reference source.

---

## Notes & substitutions
- **Fonts:** SF Pro / PingFang TC are system-only and not bundled; web specimens
  use Noto Sans TC (CJK) + the system stack. Provide the real faces if you need
  exact metrics.
- **Icons:** iOS kit substitutes SF Symbols with Lucide-style SVGs (see ICONOGRAPHY);
  the Android kit uses the authentic **Material Symbols Rounded** webfont.
- **Android Material You — a *system* setting, three layers:** (1) `SystemAccentColor.java`
  reads the user's seed from `Settings.Secure` (`theme_customization_overlay_packages` →
  `system_palette`); (2) `LIMESettings.onCreate()` calls
  `DynamicColors.applyToActivityIfAvailable(this, …setContentBasedSource(seed))`, generating
  the whole M3 tonal palette at runtime; (3) `MODE_NIGHT_FOLLOW_SYSTEM` follows system
  light/dark. `themes.xml` `colorPrimary`/`colorSecondary` (material_blue / lime_green) are
  only **fallbacks** when Dynamic Colors is unavailable. The **6 keyboard themes**
  (淺色/深色/粉紅/科技藍/時尚紫/放鬆綠 in `colors.xml`) are a *separate* keyboard-surface preference,
  not the settings-app chrome. The kit simulates the system seed with a control **outside**
  the phone — there is no in-app theme picker.
- The recreation models **both light and dark appearance** and **both phone
  (bottom-nav) and tablet (navigation-rail + two-pane) form factors** — toggled by the
  OS-level controls in the Android kit's letterbox. The 6 keyboard themes
  (淺色/深色/粉紅/科技藍/時尚紫/放鬆綠) are the keyboard-surface preference, distinct from the
  settings-app Material You chrome.
