# iOS Theme Literal Centralization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize iOS hardcoded UI colors and repeated layout metrics called out by `docs/MAGIC_NUMBER.md`, then verify by tests, guard script, and iOS simulator visual checks.

**Architecture:** Add Settings-specific theme and metrics sources, keep keyboard-specific values in `LayoutMetrics.swift`, and migrate direct one-off literals to named roles. Use source-level regression tests to prevent the same direct literals from returning.

**Tech Stack:** SwiftUI, UIKit, XCTest source audits, `scripts/check_ui_theme_literals.py`, iOS simulator/Xcode build.

---

### Task 1: Add Regression Coverage

**Files:**
- Modify: `LimeIME-iOS/LimeTests/KeyboardViewControllerTest.swift`

- [ ] Add a source-audit test that requires:
  - `SettingsTheme.swift` exists.
  - `SettingsMetrics.swift` exists.
  - Settings views use `SettingsTheme`/`SettingsMetrics` for destructive/status/scrim/modal/floating-action roles.
  - Keyboard popup/controller shadows use `LayoutMetrics.Shadow.color`.

- [ ] Run the new test and confirm it fails before implementation.

### Task 2: Add Settings Theme And Metrics

**Files:**
- Create: `LimeIME-iOS/LimeSettings/SettingsTheme.swift`
- Create: `LimeIME-iOS/LimeSettings/SettingsMetrics.swift`
- Modify: `LimeIME-iOS/LimeIME.xcodeproj/project.pbxproj`

- [ ] Add semantic Settings color roles:
  - destructive
  - success
  - warning
  - floating action foreground/background
  - overlay scrim
  - overlay card background
  - switch track/thumb/shadow

- [ ] Add Settings metric roles:
  - content max width
  - section/modal padding
  - card radius
  - row/icon/button sizes
  - progress bar width
  - title section height

### Task 3: Migrate iOS Settings Surfaces

**Files:**
- Modify Settings SwiftUI files under `LimeIME-iOS/LimeSettings`

- [ ] Replace direct destructive/status colors with `SettingsTheme`.
- [ ] Replace direct overlay scrims/card padding/radius with `SettingsTheme` and `SettingsMetrics`.
- [ ] Replace repeated content width, icon size, button width, row padding, and card radius with `SettingsMetrics`.
- [ ] Keep platform semantic colors such as `.primary`, `.secondary`, `.accentColor`, and `Color(.systemBackground)` where already theme-aware.

### Task 4: Centralize Keyboard Shadow Literals

**Files:**
- Modify: `LimeIME-iOS/LimeKeyboard/LayoutMetrics.swift`
- Modify: `LimeIME-iOS/LimeKeyboard/PopupKeyboardView.swift`
- Modify: `LimeIME-iOS/LimeKeyboard/KeyboardView.swift`
- Modify: `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`

- [ ] Add `LayoutMetrics.Shadow.color`.
- [ ] Replace direct `UIColor.black.cgColor` keyboard shadow assignments with `LayoutMetrics.Shadow.color`.

### Task 5: Run Code Verification

- [ ] Run the focused source-audit test.
- [ ] Run `python3 scripts/check_ui_theme_literals.py --limit 0`.
- [ ] Run a relevant iOS build/test command for the changed files.
- [ ] Update `docs/MAGIC_NUMBER.md` with the reduced iOS debt status if the scanner counts change.

### Task 6: iOS Visual Verification

- [ ] Use the already booted iOS simulator.
- [ ] Build/run LimeIME iOS.
- [ ] Check light and dark mode high-risk surfaces:
  - Settings setup tab status banner.
  - IM list floating add button.
  - DB backup/restore progress overlay.
  - IM detail export overlay.
  - Keyboard candidate bar collapsed/expanded.
  - Emoji search panel in English/Chinese mode.

### Task 7: Final Review

- [ ] Review `git diff`.
- [ ] Ensure no Android source changed.
- [ ] Commit only after verification succeeds, without any Codex co-author trailer.
