# Issue #85: Android DB restore can silently fail for cloud on-demand backup files

## Problem Statement

Maintainer-created Android bug tracking issue for database backup restore. When a user selects a full database backup ZIP from a cloud-backed document provider while the file is still an on-demand/offline placeholder, restore may fail without a clear visible error. The UI can still show restore success even though the database and preferences were not restored.

## Classification

- Issue: #85
- Type: bug
- Platform: Android
- Area: database backup/restore, Storage Access Framework / cloud-backed URI handling
- Live state at creation: open, labeled `bug`, assigned to `jrywu`
- Reporter/source: maintainer account (`limeimetw`), so no routine public acknowledgement or community retest request is needed.

## Reproduction Notes

1. Store a valid `limeBackup.zip` in a cloud-backed provider such as Google Drive or OneDrive.
2. Ensure the file is not cached locally on the Android device.
3. In LIME Android, open database backup/restore and choose restore.
4. Select the cloud-only backup file from the picker and confirm.
5. Observe that restore may return without actually restoring data, and the UI may still indicate success.

## Relevant Code Paths Inspected

- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`
  - `restoreLocalDrive()` and `launchRestoreFilePicker()` use `Intent.ACTION_GET_CONTENT`, `CATEGORY_OPENABLE`, and MIME type `application/zip`.
  - `performRestore(Uri)` calls `setupImController.performRestore(uri)` and then unconditionally sets `db_status_restore_ok` if no exception is thrown to the fragment.
- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java`
  - `performRestore(Uri)` calls `dbServer.restoreDatabase(uri)` inside a try/catch.
  - The catch path handles/logs the error but does not rethrow or return a failure result to the fragment.
- `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`
  - `restoreDatabase(Uri)` opens the selected URI via `ContentResolver.openInputStream(uri)`, copies it into a cache temp ZIP, and calls `restoreDatabase(String)`.
  - Exceptions are caught internally and converted to logs/notifications, not propagated to the UI caller.
  - `restoreDatabase(String)` also catches unzip failures internally and returns without signalling failure to the caller.

## Likely Root Cause

The restore path does not model restore as an explicit success/failure operation. Cloud-backed providers may delay, fail, or provide an unreadable/incomplete stream while a selected file is being fetched on demand. Even when the lower-level restore fails, exceptions are swallowed in `DBServer`/`SetupImController`, so `DbManagerFragment.performRestore()` can show success after the method returns.

The issue may be triggered by cloud on-demand behavior, but the UI false-success problem is broader: any unreadable, zero-byte, incomplete, or invalid backup URI can be reported as successful if the error is handled internally and not propagated.

## Proposed Fix / Investigation Plan

1. Change restore APIs to return a boolean/result object or throw checked/runtime errors upward:
   - `DBServer.restoreDatabase(Uri)`
   - `DBServer.restoreDatabase(String)`
   - `SetupImController.performRestore(Uri)`
2. In `DbManagerFragment.performRestore(Uri)`, set `db_status_restore_ok` only after an explicit successful restore result.
3. Validate the temp copy before applying it:
   - copied byte count > 0
   - valid ZIP
   - contains expected full-backup entries such as `lime.db` / `databases/lime.db` and optional preferences entries
4. Consider using `ACTION_OPEN_DOCUMENT` and persistable read permissions for restore, or otherwise document why `ACTION_GET_CONTENT` is sufficient.
5. Run URI copy and restore work in a background task with progress/error reporting so slow cloud provider download does not look like an immediate silent success.
6. Ensure failure leaves the current database intact or clearly warns if restore partially progressed.

## Verification Plan

- Add tests/mocks for restore from:
  - valid local backup ZIP
  - zero-byte stream
  - invalid ZIP stream
  - `openInputStream()` throwing `FileNotFoundException` / `IOException`
  - stream that fails during read
- Confirm the UI reports failure for invalid/unreadable streams and does not show `db_status_restore_ok`.
- Manually verify with a cloud-backed file provider where the backup file is not cached locally before selection.
- Verify existing local-device restore still succeeds.

## Follow-up Condition

Implement and verify Android restore result propagation plus validation for cloud-backed/unreadable URI streams. Close the maintainer-created tracking issue once the fix is present in a build or otherwise verified by maintainer testing. No public acknowledgement/retest request is needed because the issue is maintainer-created.
