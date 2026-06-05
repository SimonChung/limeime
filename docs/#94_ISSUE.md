# Issue #94: Android backup file shown as 0 B — reporter-confirmed fixed in 6.1.16

## Current status

Resolved/closed. Reporter `ejmoog` confirmed in https://github.com/lime-ime/limeime/issues/94#issuecomment-4633066872 that APK `6.1.16` makes both backup and restore usable, then closed the issue on 2026-06-05. `limeimetw` posted closing acknowledgement https://github.com/lime-ime/limeime/issues/94#issuecomment-4633078498.

Verified scope: Android APK `LIMEHD2026-6.1.16.apk` on the reporter's Samsung A52 / Android 15 path; this confirms fresh non-zero backup creation and restore for the reported Android scenario. iOS backup/restore parity is outside this Android report.

## Current confirmed facts

Reporter `ejmoog` originally said every Android backup produced an empty file and could not be restored.

Known environment from the reporter's first follow-up comment:

- Device: Samsung A52
- Android: 15
- LIME: 6.1.15

Original issue evidence:

- Symptom: `limeBackup.zip` exists and is displayed as `0 B` in screenshots
- Reporter says, in hedged wording, that the problem appears to have existed for a long time

Live GitHub state checked after reporter validation on 2026-06-05:

- Issue: https://github.com/lime-ime/limeime/issues/94
- State: closed/completed
- Labels: `bug`, `Usability`
- Assignee: `jrywu`
- Initial public acknowledgement by `limeimetw`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4544340087
- Diagnostic clarification/request by `limeimetw`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4545079892
- Scoped follow-up asking for stale-file confirmation and logcat: https://github.com/lime-ime/limeime/issues/94#issuecomment-4545450059
- Reporter confirmed old backup files were deleted and attached logcat: https://github.com/lime-ime/limeime/issues/94#issuecomment-4549686546
- Scoped retest request for Android test APK `LIMEHD2026-6.1.16.apk`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4624477896
- Reporter confirmed `6.1.16` backup and restore are usable: https://github.com/lime-ime/limeime/issues/94#issuecomment-4633066872
- Closing acknowledgement by `limeimetw`: https://github.com/lime-ime/limeime/issues/94#issuecomment-4633078498

Reporter diagnostics answered the earlier questions:

1. Phone storage is not close to full; screenshot says there is enough storage.
2. Saving to another local destination (`document/tmp`) still produced a 0 B backup file.
3. Old `limeBackup*.zip` files were deleted before the latest attempt.
4. Logcat captured during backup contains an actionable LIME stack trace.

## Logcat result from 2026-05-27

The attached `lime_backup.txt` contains the relevant failure at `05-27 06:39:32.561`:

```text
E/DBServer: Error backing up database
E/DBServer: java.io.FileNotFoundException: /data/user/0/net.toload.main.hd2026/databases/lime.db-journal: open failed: ENOENT (No such file or directory)
E/DBServer:     at net.toload.main.hd.global.LIMEUtilities.addFileToZip(LIMEUtilities.java:185)
E/DBServer:     at net.toload.main.hd.global.LIMEUtilities.zip(LIMEUtilities.java:154)
E/DBServer:     at net.toload.main.hd.DBServer.backupDatabase(DBServer.java:438)
E/DBServer:     at net.toload.main.hd.ui.controller.SetupImController.performBackup(SetupImController.java:184)
E/DBServer:     at net.toload.main.hd.ui.view.DbManagerFragment.performBackup(DbManagerFragment.java:214)
```

This confirms a concrete app-side failure path for the reporter's 0 B backup:

- `DBServer.backupDatabase(Uri)` always adds `lime.db-journal` to the backup file list.
- On the reporter's device, `lime.db-journal` does not exist at backup time.
- `LIMEUtilities.addFileToZip(...)` throws `FileNotFoundException` instead of skipping the missing optional journal file.
- `DBServer.backupDatabase(Uri)` catches the exception and logs/shows an error notification, but it does not rethrow to `SetupImController` / `DbManagerFragment`.
- Because no exception reaches `DbManagerFragment.performBackup(...)`, the UI can still set the status to backup success even though ZIP creation failed, leaving the selected output file at 0 B.

The log also contains many unrelated Samsung/system/other-app messages. Do not treat those as LIME root cause; the actionable LIME stack is the `DBServer` / `lime.db-journal` failure above.

## Current interpretation

Root cause for this reproduced path is now sufficiently identified:

1. The backup ZIP generation treats `lime.db-journal` as required even though SQLite journal files can be absent depending on database state.
2. The backup failure is swallowed in `DBServer.backupDatabase(Uri)`, allowing UI success status after a failed backup.

This does **not** mean the entire backup implementation is generally broken. Existing tests and #88 still show backup/restore can work in other paths. #94 is specifically a missing-journal/error-propagation bug in the Android backup path.

## Android implementation status

Implemented and merged to `master` via PR #101 (`43aa6c887d9eebf162891549d0ef04fca9b6fe50`) with the current Android test APK file `LIMEHD2026-6.1.16.apk` in `LimeStudio/app/release/`.

- PR #101 supersedes/recreates the relevant PR #97 behavior instead of depending on a separate PR merge.
- `lime.db-journal` is included only when it exists, because it is a transient SQLite rollback journal.
- Backup failures propagate to callers instead of allowing UI success status after ZIP/copy failure.
- Regression coverage verifies backup succeeds without `lime.db-journal` and propagates output-write failure.
- Android test APK `LIMEHD2026-6.1.16.apk` contains the fix: https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.16.apk (verified APK blob SHA `eb99705bc3f6a2668889e89c05f7d9914c574639`, size 11983378 bytes)
- Reporter `ejmoog` confirmed on 2026-06-05 that `6.1.16` backup and restore are usable: https://github.com/lime-ime/limeime/issues/94#issuecomment-4633066872
- Issue #94 is closed/completed with acknowledgement: https://github.com/lime-ime/limeime/issues/94#issuecomment-4633078498

## Fixed code paths

### Backup implementation

File: `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java`

Relevant current code:

- `backupDatabase(Uri)` builds a backup list containing:
  - `lime.db`
  - `lime.db-journal`
  - shared prefs backup
  - preference manifest
- It calls `LIMEUtilities.zip(...)` at about line 438.
- It catches broad exceptions at about lines 450-452, logs `Error backing up database`, shows an error notification, and currently does not rethrow.

Implemented fix requirements:

- Treat `lime.db-journal` as optional, or make the ZIP helper skip explicitly optional missing files.
- Preserve required-file failures for `lime.db` and preference/manifest files unless separately determined safe.
- Ensure backup failures propagate to `DbManagerFragment.performBackup(...)` so the UI shows failure rather than `db_status_backup_ok`.
- Consider logging temp ZIP size and copied byte count, and fail visibly if copied bytes are zero.

### ZIP helper

File: `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEUtilities.java`

Relevant current code:

- `addFileToZip(...)` has an old commented-out missing-file skip:

```java
//if( item==null || !item.exists()) return; //skip if the file is not exist
```

Implemented fix requirements:

- Do not blindly skip every missing file if that would hide required backup corruption.
- Prefer an explicit optional-file handling path for `lime.db-journal`, or pass structured backup entries with required/optional metadata.

### UI flow

File: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/DbManagerFragment.java`

Relevant current code:

- `performBackup(Uri)` calls `setupImController.performBackup(uri)` and then sets `db_status_backup_ok` if no exception is thrown.

Implemented fix requirements:

- With DBServer rethrowing failures, this existing UI catch path can display `db_status_backup_fail`.
- Add/adjust tests so a backup failure does not report success.

## Verification status

Developer-side checks for the fix:

1. Add or update a backup test where `lime.db-journal` is absent and verify backup still creates a non-empty ZIP containing the required DB/preferences/manifest.
2. Add or update a failure-propagation test showing a genuine backup/ZIP/copy failure reaches the UI/controller instead of reporting success.
3. Run Android compile checks:
   - `cd LimeStudio && ./gradlew :app:compileDebugJavaWithJavac`
   - `cd LimeStudio && ./gradlew :app:compileDebugAndroidTestJavaWithJavac`
4. Reporter retested Android APK `LIMEHD2026-6.1.16.apk` and confirmed backup and restore are usable. The verified community scope is Android/Samsung A52/Android 15 backup creation plus restore using 6.1.16.

## Public follow-up status

A concise public reply was posted after the logcat attachment to confirm that the log identified the likely failure path and that no more logs are needed before a fix.

A scoped retest request was posted and then edited after the targeted #94 backup fix reached the current `LIMEHD2026-6.1.16.apk` test APK. Reporter `ejmoog` confirmed `6.1.16` makes backup and restore usable, `limeimetw` posted one closing acknowledgement, and the issue is closed/completed. No active retest watch remains unless the issue is reopened or new backup/restore evidence appears.
