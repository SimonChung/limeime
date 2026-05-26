# Issue #94: Android backup file shown as 0 B — diagnostic follow-up

## Current confirmed facts

Reporter `ejmoog` says every Android backup produces an empty file and cannot be restored.

Known environment from the reporter's first follow-up comment:

- Device: Samsung A52
- Android: 15
- LIME: 6.1.15

Original issue evidence:

- Symptom: `limeBackup.zip` exists and is displayed as `0 B` in screenshots
- Reporter says, in hedged wording, that the problem appears to have existed for a long time

Live GitHub state checked during the 2026-05-26 comment follow-up:

- Issue: https://github.com/lime-ime/limeime/issues/94
- State: open
- Labels: `bug`, `Usability`
- Assignee: `jrywu`
- First developer/public acknowledgement by `limeimetw`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4544340087
- Diagnostic request by `limeimetw`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4545079892
- Reporter environment follow-up: https://github.com/lime-ime/limeime/issues/94#issuecomment-4544306916
- New reporter follow-up: https://github.com/lime-ime/limeime/issues/94#issuecomment-4545397998

The latest reporter follow-up answers part of the diagnostic request:

1. Phone storage is not close to full; screenshot says there is enough storage.
2. Reporter says saving to another local destination (`document/tmp`) still did not work, with a screenshot attached. The exact file details still need to be recorded from that screenshot/comment path before treating the destination test as fully characterized.

## Current interpretation

There is still **no fully confirmed root cause**. However, the latest reporter evidence makes these explanations less likely than before:

- phone storage full / no free space
- a problem limited only to the original Downloads folder, assuming the `document/tmp` screenshot indeed shows a newly-created 0 B backup file

The report now more strongly points toward one of these remaining classes, while still requiring logs or instrumentation:

- app-side backup ZIP generation or copy-to-output failure
- error propagation problem where backup failure is swallowed and UI still reports success
- device/storage-provider behavior that affects multiple selected local destinations
- stale/duplicate-file confusion if old `limeBackup*.zip` files were not deleted before the new attempt
- file-manager metadata/cache mismatch if another viewer would report a non-zero file size

Do not yet claim any single class as proven without logs or instrumentation.

## Why existing tests do not settle #94

Existing instrumentation tests are useful, but they do not answer the reporter’s exact device/destination path.

Relevant tests:

- `IntegrationTestBackupRestore.test_5_6_9_BackupRestoreDatabasePair`
- `IntegrationTestBackupRestore.test_5_6_10_BackupRestoreDatabasePairRestoresPreferenceCompatibilityManifest`
- `DBServerTest.testDBServerBackupDatabaseAndRestoreWithDataConsistency`

What they show:

- The backup/restore implementation can create a valid non-empty backup in tested paths.
- Full backup/restore can preserve database content and preference manifest in tested paths.

What they do **not** prove:

- They do not prove Samsung A52 / Android 15 works through the reporter’s selected storage provider(s).
- They do not prove `ACTION_CREATE_DOCUMENT` writes to the same file the reporter later inspected.
- They do not prove MediaStore Downloads fallback works on the reporter’s device.
- They do not rule out provider error, permission issue, stale 0 B file, duplicate-file confusion, or a low-level app exception hidden from UI.

Correct conclusion for now:

> The backup feature is known to work in existing test paths, and #88 also gives live counter-evidence that backup/restore can work on v6.1.15 for another reporter. #94 now has stronger reporter evidence that the symptom persists despite enough storage and an attempted second local destination. Next diagnostics should focus on logcat, file-size/path verification, a second file viewer if possible, and app-side byte-count/error propagation.

## Code paths to keep in mind

### UI backup flow

File: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`

- `backupLocalDrive()` starts backup flow.
- Primary path uses `Intent.ACTION_CREATE_DOCUMENT` with title `limeBackup.zip` and MIME type `application/zip`.
- If no document-create handler exists, fallback uses MediaStore Downloads.
- `performBackup(Uri)` shows success only if no exception reaches the fragment.

### Controller flow

File: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/SetupImController.java`

- `performBackup(Uri)` delegates to `dbServer.backupDatabase(uri)`.
- If `DBServer` throws, controller rethrows to UI.

### Backup implementation

File: `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`

- `backupDatabase(Uri)` creates a temp ZIP, then copies bytes to the selected output `Uri`.
- It catches broad exceptions, logs/shows notification, and may not rethrow from the catch block.
- This means a low-level failure can potentially be hidden from the UI; with the new reporter evidence, this should be tested explicitly, but it is not yet proven as the natural cause.

## Diagnostic status and next tests

### Completed or partly completed by reporter

- Storage space check: reporter says storage is sufficient.
- Second local destination: reporter says saving to `document/tmp` still does not work; screenshot evidence should be used only as file/path evidence, not as a fully parsed log or root cause.

### Still needed from reporter, if feasible

1. Confirm whether old `limeBackup*.zip` files were deleted before the latest attempts.
2. Check the newly-created backup file in a second file viewer, if available, to rule out Samsung My Files metadata/cache display mismatch.
3. Provide file details for the newly-created 0 B file: exact path, modified time, and size.
4. If possible, capture logcat around one backup attempt.

Suggested adb commands:

```bash
adb logcat -c
adb logcat -v time DBServer:D DbManagerFragment:D LIMEUtilities:D AndroidRuntime:E '*:S'
```

Then run backup once and paste the relevant lines. If filtered logs are too sparse:

```bash
adb logcat -d -v time | grep -iE 'DBServer|DbManagerFragment|LIMEUtilities|backup|zip|openOutputStream|MediaStore|Exception|error|No space left'
```

Expected interpretation:

- `Error backing up database`: app/IO path failed.
- `openOutputStream` / provider exception: destination provider or permission issue.
- `No space left on device`: storage full despite UI report.
- Missing source file exception: source ZIP-list robustness issue.
- No relevant errors but file is 0 B: need deeper instrumentation around temp ZIP size and copied byte count.

## Developer-side diagnostic tests

### Test 1: Forced output failure

This does not prove the reporter’s natural root cause, but tests whether UI can falsely report success after a write failure.

Temporary local debug patch in `DBServer.backupDatabase(Uri)` after opening output stream:

```java
inputStream = new FileInputStream(tempZip);
outputStream = appContext.getContentResolver().openOutputStream(uri);

// TEMP #94 diagnostic: simulate output provider failure after destination exists.
throw new IOException("Forced #94 output failure after Uri opened");
```

Expected interpretation:

- If UI still shows success and a 0 B file exists, error propagation is a real app-side robustness bug.
- This still does not prove the reporter hit this path naturally; it validates one possible failure class.

### Test 2: Add byte-count instrumentation

Create a debug APK that logs:

- temp ZIP path and `tempZip.length()` before copy
- selected output `Uri`
- total bytes copied to output stream
- whether output stream closed successfully

Expected interpretation:

- `tempZip.length() > 0`, copied bytes `0`: output provider/write problem.
- `tempZip.length() == 0`: backup ZIP generation problem.
- exception before temp ZIP: source/preparation problem.
- copied bytes > 0 but user sees 0 B: wrong file, stale file, provider metadata/cache issue, or file-manager issue.

### Test 3: Missing journal coverage

Force/delete `lime.db-journal` before backup or add a unit/instrumentation test that excludes it.

Expected interpretation:

- If backup fails only when journal is absent: optional journal robustness bug.
- If backup succeeds without journal: rule this out.

## Safe fix policy before full root-cause proof

Given the latest reporter evidence, it is reasonable to implement defensive backup-path improvements while keeping root-cause language scoped:

- improve backup logging
- report temp ZIP size and copied byte count in debug logs
- fail visibly if temp ZIP length or copied byte count is zero
- rethrow backup exceptions so UI does not show success after internal failure
- optionally handle missing journal as non-fatal if verified safe

Avoid a broad backup rewrite until logs or instrumentation identify the failing layer.

