# Issue #94: Android backup file shown as 0 B — unconfirmed root cause

## Current confirmed facts

Reporter `ejmoog` says every Android backup produces an empty file and cannot be restored.

Known environment from the issue:

- Device: Samsung A52
- Android: 15
- LIME: 6.1.15
- Symptom shown in screenshots: `limeBackup.zip` exists and is displayed as `0 B`
- Reporter says the problem has existed for a long time

Live GitHub state:

- Issue: https://github.com/lime-ime/limeime/issues/94
- State: open
- Labels: `bug`, `Usability`
- Assignee: `jrywu`
- Existing public acknowledgement: https://github.com/lime-ime/limeime/issues/94#issuecomment-4544340087

## Important correction

There is **no confirmed root cause yet**.

Do not claim any of these as the cause until tested:

- core backup implementation is broken
- SAF / document picker provider failed
- MediaStore / Downloads provider failed
- Android permission or storage policy issue
- phone storage is full
- stale/old `limeBackup.zip` is being inspected
- duplicate backup file was created elsewhere
- missing `lime.db-journal` caused ZIP creation failure

The current report is enough to investigate, but not enough to prove an app-side bug.

## Why existing tests do not settle #94

Existing instrumentation tests are still useful, but they do not answer the reporter’s exact case.

Relevant tests:

- `IntegrationTestBackupRestore.test_5_6_9_BackupRestoreDatabasePair`
- `IntegrationTestBackupRestore.test_5_6_10_BackupRestoreDatabasePairRestoresPreferenceCompatibilityManifest`
- `DBServerTest.testDBServerBackupDatabaseAndRestoreWithDataConsistency`

What they show:

- The backup/restore implementation can create a valid non-empty backup in tested paths.
- Full backup/restore can preserve database content and preference manifest in tested paths.

What they do **not** prove:

- They do not prove Samsung A52 / Android 15 Downloads provider works.
- They do not prove `ACTION_CREATE_DOCUMENT` selected by the user writes to the file the user later inspected.
- They do not prove MediaStore Downloads fallback works on the reporter’s device.
- They do not rule out device storage full, file provider error, permission issue, stale 0 B file, or duplicate-file confusion.

So the correct conclusion is:

> The backup feature is known to work in existing test paths, but #94 needs targeted diagnostics on the reporter-relevant destination path before assigning root cause.

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
- It currently catches broad exceptions, logs/shows notification, and does not rethrow from that catch block.
- This means a low-level failure can potentially be hidden from the UI, but this is only a possible app-side weakness, not the confirmed cause of #94.

## Diagnostic tests that can actually distinguish causes

### Test 1: Confirm whether phone storage is full

Ask reporter to check Android storage before another backup:

- Android Settings → Battery and device care / Storage, or Settings → Storage.
- Report free space.
- Also try deleting old `limeBackup*.zip` files and ensure at least 1 GB free.

Expected interpretation:

- If free space is low or zero: likely environment/storage issue.
- If plenty of space remains: continue.

### Test 2: Remove stale or duplicate backup confusion

Ask reporter to delete all previous backup files first:

- Delete all `limeBackup.zip`, `limeBackup (1).zip`, `limeBackup*.zip` in Downloads.
- Run backup once.
- Open file details and report:
  - exact filename
  - folder/path
  - modified time
  - file size

Expected interpretation:

- If a new non-zero file appears under another name/path: user inspected stale/wrong file.
- If exactly one new file appears and it is 0 B: real write/output issue remains.

### Test 3: Try two different destinations

Ask reporter to run backup twice after deleting old files:

1. Save to local Downloads.
2. Save to another provider/path, if available:
   - Samsung My Files different folder
   - Google Drive disabled/not used for this test unless explicitly selected
   - internal Documents folder

Expected interpretation:

- Downloads 0 B but another destination non-zero: destination/provider-specific issue.
- All destinations 0 B: app-side backup/copy failure or storage policy issue more likely.
- Another destination works: no broad backup-function bug.

### Test 4: Verify file size using a second viewer

Ask reporter to check size with both:

- Samsung My Files file details
- Android Files / another file manager, if installed

Expected interpretation:

- If one viewer says 0 B and another says non-zero: file manager metadata/cache issue.
- If all viewers say 0 B: actual empty file.

### Test 5: Collect logcat while reproducing

This is the most useful app-side diagnostic.

If reporter can use adb:

```bash
adb logcat -c
adb logcat -v time DBServer:D DbManagerFragment:D LIMEUtilities:D AndroidRuntime:E '*:S'
```

Then run backup once and paste logs around the backup attempt.

If filtered logs are too sparse, use:

```bash
adb logcat -d -v time | grep -iE 'DBServer|DbManagerFragment|LIMEUtilities|backup|zip|openOutputStream|MediaStore|Exception|error'
```

Expected interpretation:

- `Error backing up database`: app/IO path failed.
- `openOutputStream` / provider exception: destination provider or permission issue.
- `No space left on device`: storage full.
- Missing source file exception: source ZIP list robustness issue.
- No relevant errors but file is 0 B: need deeper instrumentation around copied byte count.

### Test 6: Developer-side force provider/write failure

This does not prove reporter’s root cause, but proves whether the app UI can falsely report success after a write failure.

Temporary local debug patch in `DBServer.backupDatabase(Uri)` after opening output stream:

```java
inputStream = new FileInputStream(tempZip);
outputStream = appContext.getContentResolver().openOutputStream(uri);

// TEMP #94 diagnostic: simulate output provider failure after destination exists.
throw new IOException("Forced #94 output failure after Uri opened");
```

Run backup.

Expected interpretation:

- If UI still shows success and a 0 B file exists, error propagation is a real app-side robustness bug.
- This still does not prove the reporter hit this path naturally; it only validates one possible failure class.

### Test 7: Developer-side add byte-count instrumentation

Create a debug APK that logs:

- temp ZIP path and `tempZip.length()` before copy
- selected output `Uri`
- total bytes copied to output stream
- whether output stream closed successfully

Expected interpretation:

- `tempZip.length() > 0`, copied bytes `0`: output provider/write problem.
- `tempZip.length() == 0`: backup ZIP generation problem.
- exception before temp ZIP: source/preparation problem.
- copied bytes > 0 but user sees 0 B: wrong file, stale file, provider metadata/cache issue, or file manager issue.

### Test 8: Developer-side missing journal test

Force/delete `lime.db-journal` before backup or add a unit/instrumentation test that excludes it.

Expected interpretation:

- If backup fails only when journal missing: optional journal robustness bug.
- If backup succeeds without journal: rule this out.

## Recommended next public reply

Do not tell the reporter we have identified a backup-generation bug yet. Ask for facts that distinguish storage/provider/user-path issues from app defects.

Suggested reply:

```text
謝謝補充。這個 0 B 檔案目前還需要先確認是手機儲存空間/目的地 provider/舊檔案，還是 LIME 寫出流程本身失敗。

可否麻煩您幫忙做幾個確認：

1. 手機目前剩餘儲存空間大約多少？是否接近滿了？
2. 請先刪除 Downloads 裡所有 limeBackup.zip / limeBackup (1).zip / limeBackup*.zip，再重新備份一次。
3. 備份時是否有跳出 Android 選擇儲存位置的畫面？還是直接存到 Downloads？
4. 重新備份後，請開啟該檔案的詳細資料，截圖包含檔名、資料夾位置、修改時間、大小。
5. 如果方便，也請試著另存到不同位置（例如 Documents 或其他資料夾），看是否仍然是 0 B。
6. 若您可以使用 adb，請在備份時抓 logcat，搜尋 DBServer / DbManagerFragment / LIMEUtilities / Error backing up database / openOutputStream / No space left on device 相關訊息。

這些資訊可以幫我們判斷是手機儲存空間或目的地權限問題，還是 LIME 需要修正備份寫出/錯誤回報。
```

## Fix policy before evidence

Before logs or reproducible steps, only safe app-side improvements are:

- improve backup logging
- report copied byte count
- fail visibly if copied byte count is zero
- rethrow backup exceptions so UI does not show success after internal failure
- optionally handle missing journal as non-fatal if verified safe

Do not commit to a broad backup rewrite until tests identify the failing layer.
