# Issue #94: Android backup reported as 0 B on one device despite covered backup path

## Problem statement

Community reporter `ejmoog` reports that Android LIME 6.1.15 on Samsung A52 / Android 15 produces a visible `limeBackup.zip` with size `0 B`, and that the file cannot be restored. The screenshots show the database manager status after backup and Android file listing reporting `limeBackup.zip` as `0 B`.

This issue should **not** be analyzed as “Android backup is generally broken.” The current Android backup/restore implementation has source-backed instrumentation coverage for the internal/FileProvider-style backup path: tests create a full backup, verify ZIP contents, restore it, and validate data/preference recovery. That coverage does **not** fully exercise the exact public destination paths most relevant to the reporter (`ACTION_CREATE_DOCUMENT` SAF output and the Android Q+ MediaStore Downloads fallback). The report is still valid as a device/user-environment symptom, but the investigation should focus on why this reporter ends up seeing a 0 B Downloads file while the covered backup path succeeds.

## Classification

- Issue: #94
- Type: bug / support investigation
- Platform: Android
- Reporter environment: Samsung A52, Android 15, LIME 6.1.15
- Area: database backup export destination, Android file picker / provider / file listing behavior, backup result reporting
- Live state: open, labeled `bug` + `Usability`, assigned to `jrywu`
- Public acknowledgement already posted: https://github.com/lime-ime/limeime/issues/94#issuecomment-4544340087

## Reported reproduction

1. Open the Android database manager.
2. Run database backup.
3. UI shows backup completion (`備份完成`).
4. User inspects `Download/limeBackup.zip`.
5. Observed by reporter: file exists but is shown as `0 B`; restore cannot use it.

## Source evidence inspected

### UI backup entry points

File: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`

- `backupLocalDrive()` creates an `Intent.ACTION_CREATE_DOCUMENT` request with:
  - MIME type `application/zip`
  - default title `limeBackup.zip`
- If no document-create activity is available, it uses the Downloads fallback path.
- `launchBackupFilePicker()` starts the SAF picker.
- `saveBackupToDownloads()` creates a MediaStore Downloads row on Android Q+ and then calls `performBackup(finalUri)` on the UI thread.
- `performBackup(Uri)` calls `setupImController.performBackup(uri)` and shows `db_status_backup_ok` only when no exception reaches the fragment.

Relevant lines from current source:

- lines 119-160: file-picker availability and launch/fallback logic
- lines 163-209: Downloads/MediaStore fallback and `performBackup(finalUri)` handoff
- lines 212-220: `performBackup(Uri)` success/failure status handling

### Controller backup path

File: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java`

- `performBackup(Uri)` shows progress, calls `dbServer.backupDatabase(uri)`, hides progress on the normal path, and rethrows errors that reach it from `DBServer`.
- Therefore, if `DBServer.backupDatabase(uri)` throws, the fragment should use the failure path.

Relevant lines:

- lines 181-189: `performBackup(Uri)`

### Database backup implementation

File: `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`

- `backupDatabase(Uri)` builds the backup list from:
  - main database `lime.db`
  - `lime.db-journal`
  - legacy shared-preferences backup
  - cross-platform preference manifest
- It closes/holds the DB, zips those files into a temp `limeBackup.zip`, then copies that temp ZIP to the selected output `Uri`.
- Current code catches exceptions inside `backupDatabase(Uri)`, logs/shows an error notification, and does not rethrow from that catch block. That means UI success can still be misleading if a low-level ZIP/copy exception occurs.

Relevant lines:

- lines 397-425: backup file list
- lines 427-438: DB hold/close and temp ZIP creation
- lines 441-448: copy temp ZIP bytes to selected output `Uri`
- lines 450-453: catch/log/notification without rethrow
- lines 453-469: cleanup/reopen and backup-end notification

This is an error-reporting risk, but it is not proof that normal backup output is broken.

### ZIP utility behavior

File: `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEUtilities.java`

- `zip(...)` opens a `ZipOutputStream`, iterates the supplied file list, and writes each file.
- `addFileToZip(...)` currently does not skip missing files; the old missing-file skip guard is commented out.

Relevant lines:

- lines 136-160: ZIP creation loop
- lines 170-205: file entry creation and copy
- line 173: missing-file skip guard is commented out

This means missing optional files can still be a robustness concern, but existing tests show the normal backup flow succeeds in the current tested environment.

## Test evidence inspected

### Full Android backup/restore integration test

File: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/IntegrationTestBackupRestore.java`

- `test_5_6_9_BackupRestoreDatabasePair()` performs a full backup through `setupController.performBackup(backupUri)`, factory-resets the database, restores from the same URI, and verifies the IM list and record counts match before/after.
- `test_5_6_10_BackupRestoreDatabasePairRestoresPreferenceCompatibilityManifest()` performs a full backup through `setupController.performBackup(backupUri)`, verifies the ZIP contains:
  - `databases/lime.db`
  - `shared_prefs.bak`
  - `preferences/lime_prefs.json`
  then restores it and verifies preference values are recovered.

Relevant lines:

- lines 541-600: backup → reset → restore → IM/count validation
- lines 608-640: backup ZIP content validation and preference restore validation
- lines 849-855: helper verifies required ZIP entries are present

These tests are strong evidence that the core full-backup implementation can produce a valid non-empty ZIP and restore it when using the tested FileProvider/internal-storage destination pattern. They do not cover all public destination providers.

### DBServer-level backup/restore data consistency test

File: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/DBServerTest.java`

- `testDBServerBackupDatabaseAndRestoreWithDataConsistency()` adds custom and related records, calls `dbServer.backupDatabase(backupUri)`, asserts the backup file exists and is non-empty when the file is produced, clears data, restores from the backup, and verifies records/related phrase exist afterward.

Relevant lines:

- lines 2194-2236: seed data and count records before backup
- lines 2238-2274: create backup and assert `backupFile.length() > 0` if the test output file exists
- lines 2281-2316: clear data, restore, and verify records return

This supports the conclusion that the DBServer backup/restore path can work end-to-end, but it is not absolute proof against all 0 B output cases. The test explicitly returns early if the backup file is not created or if `RemoteException` occurs, and it uses a file/cache destination rather than SAF or MediaStore Downloads.

### Weaker API-presence / edge tests

File: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/DBServerTest.java`

- `testDBServerBackupDatabaseWithUri()` only checks that calling `backupDatabase(Uri)` completes or throws acceptably; it does not validate output content.

Relevant lines:

- lines 998-1032

This test is weaker and should not be the basis for confidence; the stronger integration/data-consistency tests above are the relevant evidence.

## Corrected assessment

Do not assume the core backup function is broken. The code and tests support this more conservative assessment:

1. The tested core backup path can create a valid ZIP and restore from it; this is covered by Android instrumentation tests using FileProvider/file-style destinations.
2. The reporter’s 0 B file is still a real observed symptom on Samsung A52 / Android 15 / LIME 6.1.15.
3. The likely failure is in a destination path not covered by the strongest tests: SAF `ACTION_CREATE_DOCUMENT`, MediaStore Downloads fallback, provider-specific behavior, or a mismatch between where LIME writes the selected backup and which file the user inspects afterward.
4. The only source-backed weakness found in the implementation is error/result validation: `DBServer.backupDatabase(Uri)` can catch ZIP/copy exceptions without rethrowing, and the UI can therefore show success if an exceptional provider/write path fails internally.
5. Missing `lime.db-journal` should be treated as a robustness hypothesis, not the primary root cause. Existing e2e tests passing means it is not a universal trigger.

## Plausible investigation directions

### 1. Wrong/stale file inspected after SAF backup

The primary backup path uses `ACTION_CREATE_DOCUMENT`. On Android, this lets the user choose a destination and file name. If there is already a stale `Download/limeBackup.zip` from an earlier failed attempt, and the new successful backup was saved elsewhere or with a provider-modified name, the file manager screenshot could still show the stale 0 B file.

Check:

- Did the reporter pick `Download/limeBackup.zip` in the document picker, or did LIME use the automatic Downloads fallback?
- Are there duplicate files such as `limeBackup (1).zip`, provider-specific copies, or a recently modified non-zero file?
- What is the timestamp of the 0 B file relative to the latest backup attempt?

### 2. Provider/output-URI write failure on that device/path

If the selected `Uri` points to a provider path that opens a document but fails or truncates during write, `DBServer.backupDatabase(Uri)` may log an error internally and still return to the UI without throwing.

Check:

- Logcat around the backup attempt for `DBServer`, `DbManagerFragment`, `LIMEUtilities`, `Error backing up database`, and provider/write exceptions.
- Whether choosing a different destination provider/path produces a valid non-zero ZIP.

### 3. Downloads fallback inserted a row but write failed

If the device enters `saveBackupToDownloads()` fallback, the MediaStore row is inserted before backup writes bytes to it. If writing later fails and the exception is swallowed by `DBServer`, Android may show a 0 B row.

Check:

- Whether the backup flow opened the Android document picker or immediately saved to Downloads.
- Whether logcat shows MediaStore or `openOutputStream` errors.

### 4. Optional journal robustness

`lime.db-journal` is included in the backup list. In some SQLite states it may be absent. Current `LIMEUtilities.addFileToZip(...)` does not skip missing files. This remains worth hardening, but because full backup/restore tests pass, it should be presented as an optional-file robustness improvement rather than the confirmed cause of #94.

## Recommended next action

Do **not** start with a broad backup-function rewrite. Start with targeted diagnostics and a small robustness patch only if logs confirm provider/write errors.

Recommended order:

1. Ask the reporter for:
   - exact backup destination flow: document picker vs automatic Downloads fallback
   - screenshot of the file details including modified time
   - whether any duplicate `limeBackup*.zip` files exist
   - logcat around backup filtered for `DBServer`, `DbManagerFragment`, `LIMEUtilities`, and `Error backing up database`
2. In code, improve failure visibility without changing the successful path:
   - make `DBServer.backupDatabase(Uri)` rethrow after logging backup ZIP/copy failures, or return an explicit failure result
   - count bytes copied to the selected `Uri` and fail if zero bytes were written
   - optionally skip missing `lime.db-journal` while keeping `lime.db` required
3. Add/adjust tests only for the uncovered cases:
   - output stream opens but write fails
   - output stream writes zero bytes
   - optional journal file missing
   - SAF/MediaStore failure should not produce `db_status_backup_ok`

## Verification plan

Existing verified coverage to preserve:

- `IntegrationTestBackupRestore.test_5_6_9_BackupRestoreDatabasePair`
- `IntegrationTestBackupRestore.test_5_6_10_BackupRestoreDatabasePairRestoresPreferenceCompatibilityManifest`
- `DBServerTest.testDBServerBackupDatabaseAndRestoreWithDataConsistency`

Additional #94-focused verification:

- On Android 15, run backup through the document picker and confirm the selected file is non-zero and contains `databases/lime.db`, `shared_prefs.bak`, and `preferences/lime_prefs.json`.
- Run backup through Downloads/MediaStore fallback if that path can be forced.
- Confirm the file the user inspects has the same modified time/location as the destination selected by the backup flow.
- Simulate provider/write failure and confirm UI shows failure, not `備份完成`.
- Verify a missing `lime.db-journal` does not break backup, if that robustness patch is applied.
- Restore the produced ZIP on the same build and confirm it is usable.

## Retest / reporter follow-up condition

Because the core backup path is already covered by e2e tests, the next reporter interaction should request diagnostics rather than wait for a broad backup-generation fix. Ask for destination-flow details and logcat first. Only ask for a retest after either:

- logs identify a specific provider/write/journal failure and a targeted APK fix is available, or
- the reporter can reproduce with a clearly selected destination and no duplicate/stale `limeBackup*.zip` confusion.
