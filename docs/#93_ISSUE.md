# Issue #93 — iOS .lime import without cname does not appear in installed IM list

## Problem statement

On iOS, importing a `.lime` table that does not include `@cname@` / `%cname` metadata can report success, but the IM manager / installed IM list shows no installed input method afterward. The IM catalog still marks the same IM/table as installed, creating contradictory state.

GitHub issue: https://github.com/lime-ime/limeime/issues/93

## Current classification

- Type: bug
- Area: iOS `.lime` text import / IM registration / installed-list state
- Labels: `bug`, `Usability`
- Owner: `jrywu`
- Reporter/source: maintainer request from Jeremy

## Observed behavior

- User imports a `.lime` file without cname metadata.
- Import completes successfully.
- The IM manager / installed IM list shows no installed IM.
- The IM catalog still shows the imported IM/table as installed.

## Expected behavior

After a successful `.lime` import, iOS should register and display the imported IM in the installed IM list even when cname metadata is missing. If cname is absent, the app should use a safe fallback display name such as version metadata, file name, table name, or a localized custom-table name.

The IM catalog installed state and the installed IM list should agree.

## Relevant source paths inspected

- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - `importTxtFile(url:tableName:view:)` and async `importTxtFile(url:tableName:restoreLearning:)` call `server.importTxtFile(...)` and report success, but do not appear to register an IM row or rebuild activated keyboard state afterward.
- `LimeIME-iOS/Shared/Database/LimeDB.swift`
  - `importTxtFile(at:tableName:progress:)` writes imported mappings and sets `im` config fields such as `source`, `version`, `name`, and `amount`; when `@cname@` / `%cname` is absent, `name` falls back to `sourceName`.
  - `registerIM(imName:tableName:label:keyboardId:)` exists but is used by catalog/download and some restore paths, not clearly by the text `.lime` import path.
- `LimeIME-iOS/LimeSettings/Controllers/ManageImController.swift`
  - `loadIMList()` reads installed-list data via `DBServer.getAllImConfigs()`.
- `LimeIME-iOS/LimeSettings/Controllers/IMStoreView.swift`
  - `refreshInstalledTables()` marks catalog installed state by `tableHasData(...)`, so catalog can say installed when mappings exist even if the `im` list/registration state is missing or incomplete.
- `LimeIME-iOS/Shared/Preferences/LIMEPreferenceManager.swift`
  - `syncIMActivatedState(dbServer:)` rebuilds `keyboard_state` from `im.enabled` rows; text import does not clearly call it after success.

## Likely root cause

The iOS text import path likely populates the mapping table but does not consistently create/update the corresponding `im` table row and activated keyboard state after a successful `.lime` import. The catalog uses `tableHasData(...)`, so it can mark the table installed based only on mapping rows, while the installed IM list depends on `getAllImConfigs()` and therefore appears empty or stale.

Missing cname metadata may expose this because the import flow relies on metadata-derived naming/registration instead of always using a safe fallback and registering the imported table.

## Proposed solution

1. After successful `.lime` / text import, ensure the imported table has a valid `im` row with:
   - stable code/table identity,
   - non-empty fallback display title/name,
   - enabled state appropriate for a newly imported custom IM,
   - keyboard id fallback if needed.
2. Rebuild `keyboard_state` through `LIMEPreferenceManager.syncIMActivatedState(dbServer:)` after registration.
3. Invalidate/reload the IM manager list and catalog installed state so both views agree.
4. Add regression coverage for `.lime` import without `@cname@` / `%cname`.

## Follow-up questions

- Which table name is selected by the iOS import UI for this `.lime` file (`custom` or another table)?
- Does the imported table contain `@version@` / `%version`, or no metadata at all?
- Is the issue limited to `.lime`, or does `.cin` without `%cname` show the same installed-list/catalog mismatch?

## Verification plan

- Import a `.lime` file without `@cname@` / `%cname` metadata.
- Confirm the imported table appears in the installed IM list with a fallback name.
- Confirm the IM catalog installed state and installed IM list agree.
- Confirm the imported IM can be enabled/disabled.
- Confirm the keyboard can select/use the imported IM after import.

## Current follow-up status

Open. Waiting for iOS implementation fix and verification. No community retest request is needed because this is maintainer-created/internal tracking.
