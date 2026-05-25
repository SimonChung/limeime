# Issue #85: DB restore can silently fail for cloud on-demand backup files

## Problem Statement

Maintainer-created Android and iOS bug tracking issue for database backup restore. When a user selects a full database backup ZIP from a cloud-backed document provider while the file is still an on-demand/offline placeholder, restore may fail without a clear visible error. The UI can still show restore success even though the database and preferences were not restored.

## Classification

- Issue: #85
- Type: bug
- Platform: Android and iOS
- Area: database backup/restore, Android Storage Access Framework, iOS File Provider / security-scoped URL handling
- Live state at creation: open, labeled `bug`, assigned to `jrywu`
- Current state after PR #87 merge: issue remains open because PR #87 covers the Android restore-failure path only; iOS restore/state-sync work remains separate.
- Reporter/source: maintainer account (`limeimetw`), so no routine public acknowledgement or community retest request is needed.

## Reproduction Notes

1. Store a valid `limeBackup.zip` in a cloud-backed provider such as Google Drive or OneDrive.
2. Ensure the file is not cached locally on the test device.
3. In LIME Android or LIME iOS, open database backup/restore and choose restore.
4. Select the cloud-only backup file from the picker and confirm.
5. Observe that restore may return without actually restoring data, and the UI may still indicate success.

## Relevant Code Paths Inspected

### Android

- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`
  - `restoreLocalDrive()` checks for a restore-capable picker and shows a confirmation dialog; `launchRestoreFilePicker()` uses `Intent.ACTION_GET_CONTENT`, `CATEGORY_OPENABLE`, and MIME type `application/zip`.
  - `performRestore(Uri)` calls `setupImController.performRestore(uri)` and then unconditionally sets `db_status_restore_ok` if no exception is thrown to the fragment.
- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java`
  - `performRestore(Uri)` calls `dbServer.restoreDatabase(uri)` inside a try/catch.
  - The catch path handles/logs the error but does not rethrow or return a failure result to the fragment.
- `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`
  - `restoreDatabase(Uri)` opens the selected URI via `ContentResolver.openInputStream(uri)`, copies it into a cache temp ZIP, and calls `restoreDatabase(String)`.
  - Exceptions are caught internally and converted to logs/notifications, not propagated to the UI caller.
  - `restoreDatabase(String)` also catches unzip failures internally and returns without signalling failure to the caller.


### iOS

- `LimeIME-iOS/LimeSettings/Views/DBManagerView.swift`
  - `.fileImporter` accepts a selected backup URL and calls `performRestore(from:)`.
  - `performRestore(from:)` sets success UI state when `setupController.restoreDB(from:)` returns `.success`.
- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - `restoreDB(from:)` calls `server.restoreDatabase(uri:)` in a detached task.
  - The method then re-registers known IMs, signals `lime_db_restored_at`, dismisses progress, and returns `.success(())` unconditionally.
- `LimeIME-iOS/Shared/Database/DBServer.swift`
  - `restoreDatabase(uri:)` starts security-scoped access and uses `NSFileCoordinator` around the selected URL, which is the right direction for File Provider/on-demand downloads.
  - Coordinator/copy errors are printed and return without throwing.
  - `restoreDatabase(srcFilePath:)` returns early for invalid/missing archives or missing `lime.db`, and catches extraction errors without propagating failure to callers.

## Likely Root Cause

Both platform restore paths do not consistently model restore as an explicit success/failure operation. Cloud-backed providers may delay, fail, or provide an unreadable/incomplete stream while a selected file is being fetched on demand. iOS already attempts File Provider coordination, but the failure result is still not propagated to the SwiftUI caller. Even when the lower-level restore fails, exceptions are swallowed in `DBServer`/`SetupImController`, so `DbManagerFragment.performRestore()` can show success after the method returns.

The issue may be triggered by cloud on-demand behavior, but the UI false-success problem is broader: any unreadable, zero-byte, incomplete, or invalid backup URI can be reported as successful if the error is handled internally and not propagated.

## Implementation Status

- Android: PR #87 (`fix(android): surface database restore failures`) was merged to `master` as `d22afcfddc82c0fc1260a5a09789590778199ec1` on 2026-05-25. It propagates restore failures from `DBServer` through `SetupImController` to `DbManagerFragment`, rejects zero-byte restore copies and invalid/wrong ZIP backups, and keeps the visible success path gated on a completed restore. The PR reports `./gradlew :app:compileDebugJavaWithJavac`, `./gradlew :app:compileDebugAndroidTestJavaWithJavac`, `git diff --check`, and a narrow Claude Code review as passing.
- iOS: still open/separate. The Swift/iOS restore path still needs explicit failure propagation from `DBServer` / `SetupImController.restoreDB(from:)` to `DBManagerView`, plus validation/error reporting for File Provider/cloud-backed restore failures.
- APK/build status: no newer Android APK containing PR #87 has been observed in this webhook event; do not request retest or close from the merge alone.

## Proposed Fix / Investigation Plan

1. Change restore APIs to return a boolean/result object or throw checked/runtime errors upward on both platforms:
   - Android `DBServer.restoreDatabase(Uri)` / `DBServer.restoreDatabase(String)` / `SetupImController.performRestore(Uri)`
   - iOS `DBServer.restoreDatabase(uri:)` / `DBServer.restoreDatabase(srcFilePath:)` / `SetupImController.restoreDB(from:)`
2. In Android `DbManagerFragment.performRestore(Uri)` and iOS `DBManagerView.performRestore(from:)`, show success only after an explicit successful restore result.
3. Validate the temp copy before applying it:
   - copied byte count > 0
   - valid ZIP
   - contains expected full-backup entries such as `lime.db` / `databases/lime.db` and optional preferences entries
4. Android: consider using `ACTION_OPEN_DOCUMENT` and persistable read permissions for restore, or otherwise document why `ACTION_GET_CONTENT` is sufficient.
5. iOS: keep `NSFileCoordinator` and security-scoped URL access, but surface coordinator/copy/archive/extract errors to the UI.
6. Run URI copy and restore work in a background task with progress/error reporting so slow cloud provider download does not look like an immediate silent success.
7. Ensure failure leaves the current database intact or clearly warns if restore partially progressed.

## Verification Plan

- Add tests/mocks for restore from:
  - valid local backup ZIP
  - zero-byte stream
  - invalid ZIP stream
  - `openInputStream()` throwing `FileNotFoundException` / `IOException`
  - stream that fails during read
- Confirm the UI reports failure for invalid/unreadable streams and does not show `db_status_restore_ok`.
- Manually verify on Android with a cloud-backed document provider where the backup file is not cached locally before selection.
- Manually verify on iOS with iCloud Drive / Files or another File Provider where the backup file is not downloaded locally before selection.
- Verify existing local-device restore still succeeds on both Android and iOS.

## Follow-up Condition

Android restore failure propagation and invalid/zero-byte ZIP validation have landed on `master` via PR #87 (`d22afcfddc82c0fc1260a5a09789590778199ec1`) but still need inclusion in a newer Android APK/build before Android delivery is complete. Keep #85 open until the remaining iOS restore failure propagation/validation work is implemented or explicitly split to #86/#another issue, and until maintainer build/testing status is clear. No public acknowledgement/retest request is needed because the issue is maintainer-created.
