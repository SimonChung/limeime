# Issue #94: Android backup reports success but writes a 0-byte ZIP

## Problem Statement

Community reporter `ejmoog` reports that LIME Android backup consistently produces an empty `limeBackup.zip` file, so the backup cannot be restored. The report includes screenshots showing the database manager screen reporting `備份完成` and the resulting `Download/limeBackup.zip` file as `0 B`.

## Classification

- Issue: #94
- Type: bug
- Platform: Android
- Reporter environment: Samsung A52, Android 15, LIME 6.1.15
- Area: database backup/export, Android Storage Access Framework / Downloads output, backup error propagation
- Live state after assignment: open, labeled `bug` + `Usability`, assigned to `jrywu`
- Related context: #85 tracked restore failure propagation and invalid/zero-byte restore validation. #94 is the opposite direction: backup creation/output can fail while the UI still reports success, leaving a 0-byte file.

## Reproduction Notes From Report

1. Open LIME Android database manager.
2. Tap backup database.
3. The LIME UI shows backup success (`備份完成`).
4. Inspect the generated `limeBackup.zip` under Downloads.
5. Observed result: the file exists but its size is 0 bytes, and restore cannot use it.

## Evidence Summary

- Screenshot 1 shows the database manager backup/restore screen after backup with a visible success status.
- Screenshot 2 shows `limeBackup.zip` in `storage/emulated/0/Download` with size `0 B`.
- The reporter states this happens every time and has existed for a long time.

## Relevant Code Paths Inspected

- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`
  - `backupLocalDrive()` uses `Intent.ACTION_CREATE_DOCUMENT` for `application/zip`, or falls back to `saveBackupToDownloads()`.
  - `performBackup(Uri)` calls `setupImController.performBackup(uri)` and then shows `db_status_backup_ok` if no exception reaches the fragment.
- `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java`
  - `performBackup(Uri)` delegates to `dbServer.backupDatabase(uri)` and rethrows exceptions only if `DBServer` throws them.
- `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`
  - `backupDatabase(Uri)` prepares `LIME.SHARED_PREFS_BACKUP_NAME`, `PreferenceBackupAdapter.MANIFEST_PATH`, `lime.db`, and `lime.db-journal`, zips them to a temp file, then copies the temp ZIP to the selected output URI.
  - The `catch (Exception e)` block logs and shows a notification but does not rethrow, so callers can still report success after a failed backup.
  - The method does not currently verify that the temp ZIP exists and has non-zero length before copying, or that the selected output stream received any bytes.
- `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEUtilities.java`
  - `zip(...)` throws if one of the requested source files cannot be opened.
  - `addFileToZip(...)` does not skip missing optional files; if `lime.db-journal` is absent, the backup ZIP creation path can throw before the SAF/Downloads output receives data.

## Likely Root Cause

The backup flow can create the destination document before the actual ZIP copy succeeds. If `DBServer.backupDatabase(Uri)` fails while preparing the ZIP or copying it to the output URI, the exception is swallowed inside `DBServer`, so `DbManagerFragment.performBackup(Uri)` still shows backup success. Because Android document providers and MediaStore may already have created the destination entry, the user can be left with a visible `limeBackup.zip` of 0 bytes.

A likely concrete trigger is the backup file list including `lime.db-journal` even when SQLite has no journal file at that moment. `LIMEUtilities.addFileToZip(...)` attempts to open every listed item and throws on missing files. This would prevent writing a valid ZIP while still leaving the UI success path reachable because the exception is not propagated.

## Proposed Fix / Investigation Plan

1. Make Android backup return explicit success/failure:
   - Let `DBServer.backupDatabase(Uri)` throw an `IOException`/`RemoteException` or return a failure result when ZIP creation or output copy fails.
   - Keep `DbManagerFragment.performBackup(Uri)` success UI gated on a verified successful backup, similar to the #85 restore-failure propagation fix.
2. Validate backup artifacts:
   - Ensure the temp ZIP exists and is non-zero before copying.
   - Track copied byte count to the selected output URI and fail if zero bytes were written.
   - Flush and close the output stream before reporting success.
3. Treat `lime.db-journal` as optional:
   - Add it to the backup only if it exists, or make ZIP creation skip expected optional-missing files safely.
   - Keep `lime.db` required; fail if the main database is missing or zero-sized.
4. Clean up failed destination documents when possible:
   - For MediaStore fallback, delete the created row if backup fails before writing valid content.
   - For `ACTION_CREATE_DOCUMENT`, show a clear failure status so the user knows the created file is unusable.
5. Add regression coverage for successful backup and failure paths.

## Follow-up Questions

Current report already provides enough to classify this as a plausible Android backup bug. If implementation cannot reproduce immediately, useful follow-up evidence would be:

- Whether the user chose the file picker target or the app's Downloads fallback.
- Whether Android shows any permission/storage prompt.
- A short logcat around tapping backup, filtered for `DBServer`, `DbManagerFragment`, `LIMEUtilities`, or `Error backing up database`.

Do not ask for retest until a newer APK contains a targeted backup-generation fix.

## Verification Plan

- On Android 15, run backup to:
  - Downloads/MediaStore fallback when available.
  - A Storage Access Framework document provider target.
- Verify the resulting `limeBackup.zip` is non-zero and contains at least `lime.db` plus expected preference entries.
- Verify backup still succeeds when `lime.db-journal` is absent.
- Verify backup failure shows an error status and does not show `db_status_backup_ok`.
- Verify a 0-byte or invalid output is not treated as a successful backup.
- Restore the generated backup on the same build to confirm the archive is usable.

## Retest Condition

Ask the reporter to retest only after a newer Android APK contains a targeted backup-generation/error-propagation fix for #94.
