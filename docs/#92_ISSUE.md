# Issue #92: iOS DB restore double spinner and spinner dialog theme colors

## Problem statement

Maintainer-created iOS bug report. During iOS database restore, the settings app can show two loading indicators at the same time, and spinner/progress dialog text or controls can use colors that do not match the active light/dark theme.

Live issue state at triage:

- Issue: https://github.com/lime-ime/limeime/issues/92
- Author: `limeimetw`
- Labels: `bug`, `Usability`
- Assignee: `jrywu`
- State: open

No public acknowledgement or community retest request is needed because this is a maintainer-created tracking issue.

## Relevant code paths inspected

- `LimeIME-iOS/LimeSettings/Views/DBManagerView.swift`
  - Owns local restore/backup UI state through `@State private var isWorking`.
  - Renders a local `.overlay` whenever `isWorking` is true.
  - `performRestore(from:)` sets `isWorking = true` before calling `setupController.restoreDB(from:)`.
  - `restoreBundledDatabase()` also sets `isWorking = true` before calling `setupController.restoreBundledDatabase()`.
- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - `restoreDB(from:)` calls `progress.show(status: "還原中…")`, then `progress.dismiss()`.
  - `restoreBundledDatabase()` calls `progress.show(status: "還原預設資料庫…")`, then `progress.dismiss()`.
- `LimeIME-iOS/LimeSettings/LimeSettingsView.swift`
  - Renders a global progress overlay whenever `progressManager.isVisible` is true.
  - The overlay uses a circular `ProgressView`, white tint/text, and `.regularMaterial` background.
- `LimeIME-iOS/LimeSettings/Controllers/ProgressManager.swift`
  - Shared observable global progress state.

## Likely root cause

The database restore screen currently has two independent progress presentation systems:

1. `DBManagerView` sets `isWorking = true` and shows its local overlay.
2. `SetupImController.restoreDB(from:)` also calls `ProgressManager.show(...)`, causing `LimeSettingsView` to show the global overlay.

For restore and restore-bundled flows, those states overlap, so a user can see both the DB manager overlay and the global progress overlay for a single operation.

The color/theme mismatch is likely a shared overlay styling issue rather than only a restore-flow issue. `LimeSettingsView` hard-codes white spinner tint and text (`.tint(.white)`, `.foregroundColor(.white)`) on top of `.regularMaterial`; `DBManagerView` uses a different local dialog style with `Color(.systemBackground)` and default text/progress colors. Mixing these styles can produce inconsistent or low-contrast spinner dialogs across light/dark mode and different progress call sites.

## Proposed fix / investigation plan

1. Consolidate progress UI for DB restore operations so each restore operation presents only one spinner/dialog.
   - Prefer one shared loading-overlay component/style for the settings app.
   - Either remove the `DBManagerView` local overlay for restore flows that already use `ProgressManager`, or let restore/restore-bundled methods accept a caller-owned-progress option so only the local overlay is used.
   - Keep backup/share progress separate if it needs a determinate progress bar and share-sheet lifecycle handling.
2. Standardize spinner/progress dialog styling.
   - Avoid hard-coded white text/spinner colors unless the background is guaranteed to require white.
   - Use theme-aware colors such as `.primary`, `.secondary`, `.tint`, `Color(.label)`, `Color(.secondaryLabel)`, and system background/material combinations with verified contrast.
   - Ensure title/status text, spinner, determinate progress bar, and any action text remain readable in light and dark mode.
3. Audit other `ProgressManager.show(...)` call sites and local `isWorking` overlays for duplicate presentations or inconsistent styling.
4. Preserve UI behavior while changing presentation:
   - Restore button remains disabled during work.
   - Status message still updates after success/failure.
   - IM and related-list invalidation still happens after restore.
   - Backup/share progress still shows useful determinate feedback.

## Verification plan

- iOS settings app, DB management tab:
  - Start database restore from a backup and confirm only one spinner/progress dialog is visible.
  - Start bundled/default database restore and confirm only one spinner/progress dialog is visible.
  - Confirm buttons are disabled during work and re-enabled after completion/failure.
  - Confirm success and failure status messages still appear.
- Theme checks:
  - Verify restore progress dialog in light mode and dark mode.
  - Verify backup/share progress dialog in light mode and dark mode.
  - Verify other `ProgressManager` call sites such as import/seed flows still have readable spinner/status text.
- Regression checks:
  - Confirm restored IM list and related list refresh after restore.
  - Confirm the keyboard extension still receives the `lime_db_restored_at` reload signal.
  - Confirm backup share-sheet lifecycle still clears the overlay and temporary backup file.

## Follow-up condition

Keep issue #92 open until the iOS restore/progress UI is fixed and manually verified in light and dark mode. No Android APK retest is relevant for this iOS-only maintainer-created issue.
