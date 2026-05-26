# Issue #92: iOS DB restore double spinner and spinner dialog theme colors

## Problem statement

Maintainer-created iOS bug report. During iOS database restore, the settings app can present two loading indicators for the same restore operation. Progress/spinner UI also has inconsistent color handling: one overlay hard-codes white text/spinner color on material, while local overlays use system background/default colors.

GitHub issue: https://github.com/lime-ime/limeime/issues/92

Live issue state at rewrite:

- State: open
- Labels: `bug`, `Usability`
- Assignee: `jrywu`
- Reporter/source: maintainer-created tracking issue

No public acknowledgement or community retest request is needed because this is maintainer-created/internal tracking.

## Source evidence inspected

### Root settings view global progress overlay

File: `LimeIME-iOS/LimeSettings/LimeSettingsView.swift`

- `LimeSettingsView` creates one shared `ProgressManager` and injects it into `SetupImController`:
  - lines 18-31: `@StateObject private var progressManager`, then `SetupImController(progress: pm)`.
- It renders a root-level overlay when `progressManager.isVisible` is true:
  - lines 79-97: `.overlay { if progressManager.isVisible { ... } }`.
- That global overlay uses:
  - line 82: `Color.black.opacity(0.35)` full-screen scrim
  - line 84: circular `ProgressView()`
  - line 86: `.tint(.white)`
  - lines 88-90: status `Text(...).foregroundColor(.white)`
  - line 94: `.background(.regularMaterial, in: RoundedRectangle(...))`

This is a global, screen-covering progress UI independent of any child view's local loading state.

### Database manager local overlay

File: `LimeIME-iOS/LimeSettings/Views/DBManagerView.swift`

- `DBManagerView` owns a separate local loading state:
  - line 19: `@State private var isWorking = false`.
- It renders its own overlay when `isWorking` is true:
  - lines 121-142: `.overlay { if isWorking { ... } }`.
- That local overlay uses:
  - line 124: `Color.black.opacity(0.3)` scrim
  - line 133: `ProgressView("處理中…")` fallback spinner text
  - lines 137-139: rounded `Color(.systemBackground)` card with shadow
- Restore paths explicitly set this local state:
  - lines 237-251: `restoreBundledDatabase()` sets `isWorking = true`, awaits `setupController.restoreBundledDatabase()`, then sets `isWorking = false`.
  - lines 255-269: `performRestore(from:)` sets `isWorking = true`, awaits `setupController.restoreDB(from:)`, then sets `isWorking = false`.

So the database tab has a second progress UI that can be active at the same time as the root overlay.

### Restore controller also shows the global overlay

File: `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`

- `restoreBundledDatabase()`:
  - line 135: `progress.show(status: "還原預設資料庫…")`
  - line 145: `progress.dismiss()`
- Async `restoreDB(from:)`:
  - line 196: `progress.show(status: "還原中…")`
  - line 209: `progress.dismiss()`
- Legacy/callback `restoreDB(from:view:)` also uses the same global progress manager:
  - line 181: `progress.show(status: "還原中…")`
  - line 186: `self.progress.dismiss()`

Therefore both DB restore entry points that `DBManagerView` calls also activate the root `ProgressManager` overlay.

### Other spinner/progress styles in settings

Additional local overlays use a third style that is closer to `DBManagerView` than the global overlay:

- `LimeIME-iOS/LimeSettings/Views/IMInstallView.swift` lines 184-195:
  - local overlay with `ProgressView("匯入中…")`, `Color.black.opacity(0.3)`, `Color(.systemBackground)` card.
- `LimeIME-iOS/LimeSettings/Views/IMDetailView.swift` lines 304-315:
  - local export overlay with `ProgressView("匯出中…")`, `Color.black.opacity(0.3)`, `Color(.systemBackground)` card.
- `LimeIME-iOS/LimeSettings/Controllers/IMStoreView.swift` lines 340-351:
  - inline install/import progress states, not a full-screen overlay.

This confirms the theme/color problem is not only theoretical: the settings app currently mixes at least two full-screen overlay styles, and the global one hard-codes white foreground colors while local overlays use system colors.

## Root cause

Confirmed from code: DB restore uses two independent progress presentation mechanisms at the same time.

Call chain for backup-file restore:

1. `DBManagerView.performRestore(from:)` sets local `isWorking = true`.
2. `DBManagerView` local overlay appears (`ProgressView("處理中…")`).
3. `performRestore(from:)` awaits `setupController.restoreDB(from:)`.
4. `SetupImController.restoreDB(from:)` calls `progress.show(status: "還原中…")`.
5. `LimeSettingsView` root overlay appears because `progressManager.isVisible == true`.

Call chain for bundled/default restore:

1. `DBManagerView.restoreBundledDatabase()` sets local `isWorking = true`.
2. `DBManagerView` local overlay appears.
3. It awaits `setupController.restoreBundledDatabase()`.
4. `SetupImController.restoreBundledDatabase()` calls `progress.show(status: "還原預設資料庫…")`.
5. `LimeSettingsView` root overlay appears.

The double spinner is therefore not caused by SwiftUI rendering duplication; it is caused by two intentional overlays being activated for one operation.

The theme/color mismatch is caused by divergent overlay implementations:

- Global overlay: dark scrim plus white spinner/text on a `.regularMaterial` card.
- Local DB/import/export overlays: default `ProgressView` / text colors inside `Color(.systemBackground)` cards.

The global overlay can be visually inconsistent with local overlays and may be low contrast depending on material blur, underlying content, and light/dark mode.

## Proposed fix

### Preferred fix: one shared settings progress overlay style

1. Extract a shared SwiftUI loading overlay component for full-screen blocking operations, for example `SettingsLoadingOverlay`.
2. Use semantic colors instead of hard-coded white:
   - spinner: default tint or `.tint`
   - primary status text: `.primary` / `Color(.label)`
   - secondary text if needed: `.secondary` / `Color(.secondaryLabel)`
   - card background: `Color(.systemBackground)` or a material/card pairing with verified contrast
3. Use that component for:
   - root `ProgressManager` overlay in `LimeSettingsView`
   - `DBManagerView` local overlay, if local overlay remains
   - local import/export overlays in `IMInstallView` / `IMDetailView` when touched

### Remove the double presentation for DB restore

Choose one owner for restore progress:

Option A — controller-owned global overlay:

- Keep `SetupImController.restoreDB(from:)` and `restoreBundledDatabase()` responsible for `progress.show/dismiss`.
- Remove the spinner portion of `DBManagerView`'s local overlay for restore paths.
- Keep a separate local boolean if needed only to disable buttons and prevent duplicate taps.
- Ensure backup/share still has determinate local progress because it tracks `backupProgress` and share-sheet preparation.

Option B — view-owned local overlay:

- Add a way for restore controller methods to skip `ProgressManager.show/dismiss` when called by `DBManagerView`, or split lower-level restore work from UI presentation.
- Let `DBManagerView` be the only overlay owner for restore.

Option A is simpler because `SetupImController` already owns progress presentation for import/restore/seed flows through `ProgressManager`.

## Code paths to audit while fixing

- `LimeIME-iOS/LimeSettings/LimeSettingsView.swift`
  - root `.overlay` for `progressManager.isVisible`
  - hard-coded `.tint(.white)` and `.foregroundColor(.white)`
- `LimeIME-iOS/LimeSettings/Views/DBManagerView.swift`
  - local `isWorking` overlay
  - `performRestore(from:)`
  - `restoreBundledDatabase()`
  - backup/share flow using `backupProgress` and `preparingShare`
- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - `restoreDB(from:)`
  - `restoreBundledDatabase()`
  - legacy `restoreDB(from:view:)`
  - import/seed methods that also use `ProgressManager`
- Local overlay call sites for style consistency:
  - `IMInstallView.swift`
  - `IMDetailView.swift`

## Verification plan

### Restore behavior

- In iOS settings > database tab, restore from a backup file.
  - Expected: only one progress/spinner overlay appears.
  - Expected: restore buttons are disabled or otherwise protected from double tap during work.
  - Expected: success/failure status message still appears.
  - Expected: IM list and related list invalidate/refresh after success.
  - Expected: `lime_db_restored_at` is still written so the keyboard extension reloads its DB connection.
- Restore bundled/default database.
  - Expected: only one progress/spinner overlay appears.
  - Expected: success/failure status message still appears.
  - Expected: IM list invalidates after success.

### Theme/color behavior

- Test light mode and dark mode.
- Verify the spinner, progress text, card background, and scrim have acceptable contrast.
- Verify root `ProgressManager` flows such as import and seed-related still show readable progress text.
- Verify local import/export overlays still look consistent if they are not refactored in the same change.

### Regression checks

- Backup flow still shows determinate progress (`backupProgress`) and does not lose the share-sheet preparation behavior.
- Dismissing the share sheet still clears local backup state and deletes the temporary backup file.
- No duplicate overlays appear in other paths where a view-local overlay and `ProgressManager` could overlap.

## Follow-up condition

Keep issue #92 open until the iOS restore/progress UI is fixed and manually verified in light and dark mode. No Android APK retest is relevant for this iOS-only maintainer-created issue.
