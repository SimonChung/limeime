# Issue #93: iOS .lime import without cname does not appear in installed IM list

## Problem statement

Maintainer-created tracking issue #93 reports that on iOS, importing a `.lime` text table without `@cname@` / `%cname` metadata can finish successfully, yet the imported table does not appear in the installed input-method list. The missing-cname condition is the observed report shape; code inspection suggests the registration failure is broader than cname fallback alone. The IM catalog can still show the same table as installed because it detects mapping data separately.

## Current classification

- Type: bug / usability
- Platform: iOS
- Reporter/source: maintainer-created (`limeimetw`)
- Live labels: `bug`, `Usability`
- Live assignee: `jrywu`
- Public acknowledgement: not needed; this is an internal maintainer tracking issue.

## Code paths inspected

- `LimeIME-iOS/Shared/Database/LimeDB.swift`
  - `importTxtFile(at:tableName:progress:)` parses `@version@`, `@cname@`, `%version`, and `%cname`; version/cname metadata cross-populates the display-name fallback, and `sourceName` is used when no usable version/name metadata is available.
  - After import it writes only key-value rows such as `source`, `version`, `name`, `amount`, `import`, `selkey`, `endkey`, `spacestyle`, `imkeys`, and `imkeynames` through `setImConfig(...)`.
  - `setImConfig(...)` inserts rows with `code`, `title`, and `desc` only; even if called with `field == "keyboard"`, it does not populate the `keyboard` column that `getAllImConfigs()` reads.
  - `getAllImConfigs()` groups `im` rows by `code`, looks for a non-key-value seed row, then requires a non-empty keyboard id from either a `title="keyboard"` row or the seed row's `keyboard` column before returning an `ImConfig`.
  - The key-value field allowlist excludes `source`, `amount`, and `import`, so those metadata rows can be treated as candidate seed rows, but they still lack a keyboard id.
- `LimeIME-iOS/LimeSettings/Views/IMInstallView.swift`
  - After text import, `seedCustomIM()` is called only for `tableName == "custom"`, but `seedCustomIM()` bails out when any `im` row already exists for `custom`. A text import has already written metadata rows, so the seed row is not synthesized. Text imports targeting non-`custom` tables do not get this seed attempt at all.
  - The catalog refresh uses `IMDownloadManager.refreshInstalledTables()` / `DBServer.tableHasData(...)`, so it can mark a table as installed based on mapping data even when `getAllImConfigs()` cannot surface it in the installed list.
- `LimeIME-iOS/LimeSettings/Controllers/SetupImController.swift`
  - Restore-specific `reregisterKnownIMs()` is separate and only handles known bundled IMs, not arbitrary `.lime` text imports.

## Likely root cause

The iOS text-import path writes mappings and metadata for the imported table without ensuring the `im` table also has a usable registration/seed row and keyboard configuration. The installed-list failure does not depend only on cname absence: metadata rows such as `source`, `amount`, and `import` can be treated as seed candidates because they are not in `getAllImConfigs()`'s key-value field allowlist, but those rows have no keyboard id. `title="name"` is a key-value field and cannot become the seed row. Because `seedCustomIM()` skips seeding once any metadata row exists, non-`custom` imports have no seed attempt, and `setImConfig(...)` does not populate the `keyboard` column, the installed-list query will return no `ImConfig` for metadata-only text-import registration even though `tableHasData(...)` makes the catalog treat the table as installed.

## Proposed fix / investigation plan

1. Add a failing iOS unit test that imports a `.lime` text file without `@cname@` / `%cname` and verifies:
   - mapping rows are imported;
   - `getAllImConfigs()` returns the imported table;
   - the label falls back to a safe display value such as `@version@`, file name, table name, or localized custom-table name;
   - the config has a non-empty keyboard id.
   Include at least one case with no cname/version metadata and one case with cname or version metadata present, because the registration failure appears broader than the no-cname symptom.
2. Adjust the text-import completion path so successful imports always ensure a usable IM registration for the target table:
   - preserve explicit `name`/`version` metadata when present;
   - choose a safe fallback label when cname/name is missing;
   - ensure a default keyboard id appropriate to the table (for `custom`, likely `lime_abc` unless a better table-specific mapping exists);
   - avoid overwriting richer cloud/known-IM metadata unnecessarily.
   A naive `setImConfig(tableName, "keyboard", ...)` call is not sufficient unless `getAllImConfigs()` is also changed to read `kbRow.desc`, because the current query uses the `keyboard` column. The fix should either insert/merge a row with the `keyboard` column populated, make `registerIM(...)` merge registration data into existing metadata-only rows, or update `getAllImConfigs()` fallback behavior deliberately.
3. Revisit `seedCustomIM()` / `registerIM(...)` early-return behavior so metadata-only rows do not prevent creation of the required seed/keyboard registration. Registration may need to run before metadata writes, use a narrower existing-row check, or merge the missing keyboard/seed data into existing rows.
4. Consider updating `getAllImConfigs()` so metadata keys such as `source`, `amount`, and `import` are not mistaken for seed rows, while still supporting legacy/imported rows.
5. After registration changes, rebuild/sync keyboard state as needed so the keyboard extension can see the imported IM.

## Verification plan

- Import a `.lime` file without `@cname@` / `%cname` on iOS.
- Confirm the import reports success and the mapping rows are queryable.
- Confirm the imported table appears in the installed IM list with a non-empty fallback display name.
- Confirm the pre-fix catalog/installed-list divergence is covered by a regression check, then confirm after the fix that the IM catalog installed marker and installed IM list agree.
- Confirm the imported IM can be enabled/disabled and selected/used by the keyboard.
- Regression-check `.lime` / `.cin` files that do include `@cname@`, `%cname`, `@version@`, or `%version` metadata.

## Follow-up / retest condition

No community retest request is needed because #93 is maintainer-created. Close this issue only after an iOS fix is implemented and verified locally or through the next iOS/TestFlight build path.
