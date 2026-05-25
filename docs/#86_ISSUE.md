# Issue #86: iOS keyboard shows zero IMs after successful DB restore

Live issue: https://github.com/lime-ime/limeime/issues/86

## Status

- State: open
- Label: `bug`
- Assignee: `jrywu`
- Source: maintainer-created bug report from Jeremy
- Platform: iOS
- Public reporter follow-up: none needed; this is maintainer-created.

## Symptom

After iOS database restore succeeds, LIME Settings shows the restored IM tables again, but the keyboard extension still behaves as if there are zero available IMs. Removing LIME from iOS system keyboard settings and adding it again makes the keyboard return to normal.

## Analysis

The restored data is likely present because LIME Settings can see the IM tables after restore. The workaround also points to stale keyboard-extension state or stale app-group preference state rather than a missing backup payload.

Likely path:

1. `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift` `restoreDB(from:)` restores the database, re-registers known IMs, then writes app-group key `lime_db_restored_at`.
2. `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` `viewWillAppear(_:)` checks `lime_db_restored_at` and calls `setupDatabase()` when it changes.
3. `setupDatabase()` updates `searchServer`, `activatedIMs`, `activeIM`, and layout state asynchronously.
4. `LimeIME-iOS/Shared/Database/DBServer.swift` `prepareKeyboardRuntimeDatabase()` reads `keyboard_state` and filters `getAllImConfigs()` by saved index strings before falling back to enabled IMs/fallback IMs.

Possible failure modes to verify:

- The extension retains stale `DBServer.shared`/`LimeDB`/`DatabaseQueue` state across restore.
- `keyboard_state` stores pre-restore IM indices that no longer match the restored `im` table ordering, producing zero/wrong active IMs.
- `keyboard_list` points to an IM not present/enabled after restore and is not reset.
- The timestamp reload path does not fully invalidate extension runtime state when iOS keeps the keyboard extension process alive.

## Follow-up direction

- On successful iOS restore, validate/regenerate app-group IM state (`keyboard_state`, `keyboard_list`) against the restored `im` table.
- Ensure the keyboard extension fully reopens/rebuilds runtime DB/search state after `lime_db_restored_at` changes.
- If saved state is invalid, fall back to restored enabled IMs rather than leaving `activatedIMs` empty.
- Add targeted logging for restore timestamp, all IM count, enabled IM count, saved `keyboard_state`, resolved active IM count, and active IM.

## Verification

- Restore an iOS backup with IM tables.
- Confirm LIME Settings shows the restored IM tables.
- Without removing/re-adding the system keyboard, open the LIME keyboard in another app.
- Confirm the keyboard sees/restores the IM list and can switch/input with restored IMs.
- Repeat with a backup whose IM order/enabled state differs from the current install.

## Relationship to #85

#85 tracks restore failure/success reporting and cloud/on-demand backup handling. This issue tracks a separate post-success iOS state sync problem where Settings has restored tables but the keyboard extension remains stale/empty.

---

## Original issue body snapshot

## Summary

After a successful database restore in iOS LIME Settings, the Settings app shows the restored IM tables again, but the keyboard extension still behaves as if there are zero available IMs. Removing the LIME keyboard from iOS system settings and adding it again makes the keyboard return to normal.

## User-visible symptom

1. In LIME Settings, restore a database backup.
2. LIME Settings reports the restore as successful.
3. In LIME Settings, IM tables are visible/restored.
4. Open the LIME keyboard in another app.
5. The keyboard still shows no available LIME IMs / behaves as zero IM.
6. Workaround: iOS Settings > Keyboard > Keyboards, remove LIME, then add LIME again. After re-adding, the keyboard sees the IM tables again.

## Expected behavior

After iOS restore succeeds, the keyboard extension should refresh its runtime database/IM state and show the restored enabled IMs without requiring the user to remove and re-add the system keyboard.

## Actual behavior

Settings-side restore and IM table display recover, but the already-installed keyboard extension remains stale until the system keyboard registration is removed and added again.

## Likely affected area

Manual source review points at the handoff between the Settings app restore path and the keyboard extension runtime bootstrap:

- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - `restoreDB(from:)` restores the DB, re-registers known IMs, then writes `lime_db_restored_at` to the app-group defaults.
- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`
  - `viewWillAppear(_:)` reads `lime_db_restored_at` and calls `setupDatabase()` when it sees a newer timestamp.
  - `setupDatabase()` asynchronously calls `DBServer.shared.prepareKeyboardRuntimeDatabase()` and updates `searchServer`, `activatedIMs`, and active IM state on the main thread.
- `LimeIME-iOS/Shared/Database/DBServer.swift`
  - `prepareKeyboardRuntimeDatabase()` reads `keyboard_state` from app-group defaults and filters `getAllImConfigs()` by saved index strings before falling back to enabled IMs / fallback IM list.

## Analysis / hypothesis

The symptom suggests the restored database is valid, because LIME Settings can see the restored IM tables and removing/re-adding the system keyboard fixes the extension. That points less to data loss and more to stale extension state or stale app-group preference state.

Possible causes to verify:

- The keyboard extension's existing `DBServer.shared` / `LimeDB` / `DatabaseQueue` remains bound to stale state after the restore, even though `lime_db_restored_at` is written.
- `keyboard_state` persisted before restore may contain indices that no longer match the restored `im` table ordering. `prepareKeyboardRuntimeDatabase()` first filters by those saved indices; if the saved state exists but points to disabled/nonexistent/different entries, the keyboard may resolve no active IMs or the wrong active IMs.
- `keyboard_list` may point to an IM name not present/enabled after restore and needs validation/reset after restore.
- The timestamp reload path only runs when the extension gets `viewWillAppear`; if the extension is already loaded or iOS keeps an extension process alive, not all runtime state may be fully invalidated.

## Proposed fix direction

- On successful iOS DB restore, force a clean keyboard runtime refresh contract:
  - invalidate/reopen keyboard DB/search runtime state after `lime_db_restored_at` changes;
  - reload `activatedIMs` from the restored DB;
  - validate `keyboard_state` and `keyboard_list` against the restored IM list;
  - if restored saved state is invalid, rebuild it from enabled IMs instead of leaving the keyboard with zero IMs.
- Consider clearing or regenerating app-group keys that are tied to old DB row ordering (`keyboard_state`, possibly active `keyboard_list`) after restore.
- Add logging around restore completion and keyboard bootstrap: restored timestamp seen, all IM count, enabled IM count, `keyboard_state`, resolved activated IM count, and chosen active IM.

## Regression test / verification

- Restore an iOS backup containing IM tables.
- Confirm LIME Settings shows the restored IM tables.
- Without removing/re-adding the iOS keyboard, open the LIME keyboard in another app.
- Confirm the internal IM picker and keyboard input see the restored IMs.
- Repeat with a backup where enabled IM order differs from the current install, to verify stale `keyboard_state` indices do not produce zero active IMs.

## Notes

This is separate from cloud/on-demand backup file restore reliability tracked in #85. This issue is about a restore that appears to succeed and restores tables in Settings, while the keyboard extension remains stale until the system keyboard is removed and re-added.

