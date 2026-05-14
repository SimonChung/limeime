# iOS User Records Backup / Restore — Porting Plan

**Feature:** When an IM table is deleted, back up user-learned records; when the same table is re-imported or re-downloaded, automatically restore those records.  
**Android reference:** `SetupImLoadDialog.java` (`chkSetupImBackupLearning`, `chkSetupImRestoreLearning`), `SetupImController.clearTable(tableName, backupUserRecords)`, `SetupImFragment.importZippedDb/importTxtTable/downloadAndImportZippedDb(…, restoreUserRecords)`, `SearchServer.backupUserRecords/restoreUserRecords`.

---

## 1. Current State

### Already implemented (no changes needed)

| Layer | File | Methods available |
|-------|------|-------------------|
| LimeDB | `Shared/Database/LimeDB.swift` | `backupUserRecords(_:)`, `restoreUserRecords(_:) -> Int`, `checkBackupTable(_:) -> Bool`, `getBackupTableRecords(_:)`, **`dropBackupTable(_:) -> Bool`** |
| SearchServer | `Shared/Search/SearchServer.swift` | `backupUserRecords(_:)`, `restoreUserRecords(_:) -> Int` (wrappers over LimeDB, already at line 1212–1218) |
| Unit tests | `LimeTests/DBServerTest.swift` | `testDBServerBackupUserRecordsViaLimeDB`, `testDBServerRestoreUserRecordsViaLimeDB`, pair test, invalid-table test (lines 901–975) |

### Gaps to fill

| Gap | Location | Description |
|-----|----------|-------------|
| DBServer bridge | `Shared/Database/DBServer.swift` | No `backupUserRecords` / `restoreUserRecords` pass-through. Upper layers reach SearchServer through `DBServer.makeSearchServer()` only in ManageImController. |
| LimeDBProtocol | `Shared/Database/LimeDBProtocol.swift` | `dropBackupTable(_:)` exists in `LimeDB.swift` but is not declared in the protocol. |
| SearchServer wrapper | `Shared/Search/SearchServer.swift` | No `dropBackupTable(_:)` wrapper method. |
| ManageImController | `LimeSettings/Controllers/ManageImController.swift` | `clearTable(tableNick:)` never calls `backupUserRecords` before clearing. |
| SetupImController | `LimeSettings/Controllers/SetupImController.swift` | `importDBFile(url:tableName:)` and `importTxtFile(url:tableName:)` never call `restoreUserRecords` after import. |
| IMDownloadManager | `LimeSettings/Controllers/IMStoreView.swift` | `importDownloaded(tempURL:variant:)` never calls `restoreUserRecords` after cloud download+import. |
| IMDetailView UI | `LimeSettings/Views/IMDetailView.swift` | Remove alert has no backup option toggle. |
| IMInstallView UI | `LimeSettings/Views/IMInstallView.swift` | File-import and cloud-download paths have no restore option. |
| Preferences | — | No persistent keys for backup/restore preference. |

---

## 2. Design Decisions (Android vs. iOS)

### Android behaviour
The two checkboxes (`chkSetupImBackupLearning`, `chkSetupImRestoreLearning`) live *inside* `SetupImLoadDialog` — a dialog that pops up just before a delete or import action. The user decides per-action whether to backup/restore.

### iOS approach
SwiftUI's `.alert` modifier does not support embedded arbitrary views (Toggles, etc.).  
**Decision:** Use *persistent preference toggles* that control the behaviour, exactly as the Android checkboxes would be if the user never changed them.  
- A `Toggle` in `IMDetailView`'s detail section controls "刪除時備份已學習記錄" (`backup_user_records_on_delete`).  
- A `Toggle` in `IMInstallView`'s settings section controls "匯入後還原已學習記錄" (`restore_user_records_on_import`).  
- Both default to `true` (matching Android checkbox default state: checked).  
- Keys are stored in `UserDefaults.standard` (LimeSettings-side only; the keyboard extension does not need them).

---

## 3. Preference Keys

| Key | Type | Default | Scope | Purpose |
|-----|------|---------|-------|---------|
| `backup_on_delete_{tableNick}` | Bool | `true` | `UserDefaults.standard` | Back up learned records before clearing IM `{tableNick}` |
| `restore_on_import_{tableNick}` | Bool | `true` | `UserDefaults.standard` | Restore learned records after importing/downloading IM `{tableNick}` |

Keys are **per-IM**, suffixed with the IM's `tableNick` (e.g. `backup_on_delete_phonetic`, `restore_on_import_cj`). This means each IM retains its own independent toggle state. These are **not** placed in the App Group shared defaults — the keyboard extension does not read them.

---

## 4. Layer-by-Layer Changes

### 4.1 DBServer — add backup/restore bridge (optional convenience)

File: `Shared/Database/DBServer.swift`

The existing path is: `ManageImController → self.searchServer → ss.backupUserRecords()`.  
`ManageImController.searchServer` already returns `dbServer.makeSearchServer()`.  
No DBServer changes are strictly required; the SearchServer path is sufficient.  
**Skip DBServer changes.**

---

### 4.1.1 LimeDBProtocol — add `dropBackupTable` declaration

File: `Shared/Database/LimeDBProtocol.swift`

Add alongside the existing backup/restore declarations (lines 75–78):

```swift
@discardableResult func dropBackupTable(_ table: String) -> Bool
```

### 4.1.2 SearchServer — add `dropBackupTable` wrapper

File: `Shared/Search/SearchServer.swift`

Add alongside `backupUserRecords` / `restoreUserRecords` (after line ~1218):

```swift
@discardableResult
func dropBackupTable(_ table: String) -> Bool {
    return limeDB.dropBackupTable(table)
}
```

---

### 4.2 ManageImController — `clearTable` gains `backupLearning` parameter

File: `LimeSettings/Controllers/ManageImController.swift`

**Current signature:**
```swift
func clearTable(tableNick: String) async -> Result<Void, Error>
```

**New signature:**
```swift
func clearTable(tableNick: String, backupLearning: Bool = false) async -> Result<Void, Error>
```

**Logic change** (inside `Task.detached`):
```swift
if backupLearning {
    ss?.backupUserRecords(tableNick)
}
ss?.clearTable(tableNick)
```

`backupLearning` defaults to `false` so all existing callers (tests, other views) are unaffected unless they pass `true`.

---

### 4.3 SetupImController — import methods gain `restoreLearning` parameter

File: `LimeSettings/Controllers/SetupImController.swift`

#### 4.3.1 `importDBFile(url:tableName:)` async variant

**Current signature:**
```swift
func importDBFile(url: URL, tableName: String) async -> Result<String, Error>
```

**New signature:**
```swift
func importDBFile(url: URL, tableName: String, restoreLearning: Bool = false) async -> Result<String, Error>
```

**Logic change** — after successful `importFromAttachedDB`, before returning `.success`:
```swift
if restoreLearning {
    if let ss = server.makeSearchServer() {
        let restored = ss.restoreUserRecords(safeTable)
        if restored > 0 {
            ss.dropBackupTable(safeTable)   // backup consumed; clear to free space
        }
    }
    // restored count logged; not surfaced to caller
}
```

#### 4.3.2 `importTxtFile(url:tableName:)` async variant

**Current signature:**
```swift
func importTxtFile(url: URL, tableName: String) async -> Result<Int, Error>
```

**New signature:**
```swift
func importTxtFile(url: URL, tableName: String, restoreLearning: Bool = false) async -> Result<Int, Error>
```

**Logic change** — after successful import, before returning `.success(lastCount)`:
```swift
if restoreLearning {
    if let ss = server.makeSearchServer() {
        let restored = ss.restoreUserRecords(tableName)
        if restored > 0 {
            ss.dropBackupTable(tableName)   // backup consumed; clear to free space
        }
    }
}
```

#### 4.3.3 Legacy view-callback variants (non-async)

The legacy `importDBFile(url:tableName:view:)` and `importTxtFile(url:tableName:view:)` are kept unchanged (no callers pass `restoreLearning`). They can be extended later if needed.

---

### 4.4 IMDownloadManager — cloud download gains `restoreLearning`

File: `LimeSettings/Controllers/IMStoreView.swift`

#### 4.4.1 `install(_:)` gains parameter

**Current:**
```swift
func install(_ variant: IMVariant)
```

**New:**
```swift
func install(_ variant: IMVariant, restoreLearning: Bool = false)
```

Store it temporarily (e.g. in a `[String: Bool]` dictionary keyed by `variant.id`) so the async completion closure can read it.

#### 4.4.2 `importDownloaded(tempURL:variant:restoreLearning:)` — restore after import

After the `server.importFromAttachedDB` / `server.importFromZip` call succeeds, add:
```swift
if restoreLearning {
    if let ss = server.makeSearchServer() {
        let restored = ss.restoreUserRecords(variant.tableName)
        if restored > 0 {
            ss.dropBackupTable(variant.tableName)   // backup consumed; clear to free space
        }
    }
}
```

---

### 4.5 IMDetailView — backup toggle + alert integration

File: `LimeSettings/Views/IMDetailView.swift`

#### 4.5.1 Per-IM `@AppStorage` property

The key is suffixed with the IM's `tableNick` so each IM has its own independent toggle state:

```swift
// Cannot use @AppStorage with a dynamic key — use a computed binding instead.
private var backupOnDelete: Bool {
    get { UserDefaults.standard.object(forKey: "backup_on_delete_\(im.tableNick)") as? Bool ?? true }
    nonmutating set { UserDefaults.standard.set(newValue, forKey: "backup_on_delete_\(im.tableNick)") }
}
```

Wrap it in a `Binding` for use in the Toggle:
```swift
private var backupOnDeleteBinding: Binding<Bool> {
    Binding(get: { backupOnDelete }, set: { backupOnDelete = $0 })
}
```

#### 4.5.2 New Toggle row in the detail `List`

Add a new `Section` (show only when `im.tableNick != "related"`):

```swift
Section(header: Text("選項")) {
    Toggle("刪除時備份已學習記錄", isOn: backupOnDeleteBinding)
}
```

Place this section just above the "移除輸入法" destructive button row.

#### 4.5.3 Pass preference to `clearTable`

Change the existing remove alert button action:
```swift
// Before:
_ = await manageImController.clearTable(tableNick: im.tableNick)

// After:
_ = await manageImController.clearTable(tableNick: im.tableNick, backupLearning: backupOnDelete)
```

#### 4.5.4 Alert message update

When `backupOnDelete == true`, append a note to the confirmation message:
```
"此操作將清除「\(im.label)」的所有對應資料。\n已學習記錄將先備份，可在重新匯入時還原。確定繼續？"
```
When `false`:
```
"此操作將清除「\(im.label)」的所有對應資料，無法還原。確定繼續？"
```

---

### 4.6 IMInstallView / FamilyInstallGroup — per-IM restore toggle

Files: `LimeSettings/Views/IMInstallView.swift`, `LimeSettings/Controllers/IMStoreView.swift`

The restore option belongs at the **per-IM row level** in `FamilyInstallGroup`, not at the top of the install list. It is only visible for a specific IM when *that IM's* backup table exists.

#### 4.6.1 Per-IM backup detection and toggle in `FamilyInstallGroup`

Add two properties to `FamilyInstallGroup`:

```swift
@State private var hasBackup: Bool = false
```

The per-IM toggle preference key is `restore_on_import_{family.id}` (defaults to `true` when first shown):

```swift
private var restoreOnImport: Bool {
    get { UserDefaults.standard.object(forKey: "restore_on_import_\(family.id)") as? Bool ?? true }
    nonmutating set { UserDefaults.standard.set(newValue, forKey: "restore_on_import_\(family.id)") }
}
private var restoreOnImportBinding: Binding<Bool> {
    Binding(get: { restoreOnImport }, set: { restoreOnImport = $0 })
}
```

In the group's `.task` (or `.onAppear`), check only this IM's backup table:

```swift
.task {
    let tableName = family.id
    hasBackup = await Task.detached(priority: .background) {
        DBServer.shared.checkBackupTable(tableName)
    }.value
}
```

In the group's body, add a toggle row **inside the DisclosureGroup**, shown only when `hasBackup == true`:

```swift
if hasBackup {
    Toggle("還原已學習記錄", isOn: restoreOnImportBinding)
        .font(.subheadline)
        .foregroundColor(.secondary)
}
```

Place this row above the download variant rows so the user sees it before tapping "下載".

After a successful import or download (in `IMDownloadManager.importDownloaded` or `SetupImController.importDBFile/importTxtFile`), the backup table is deleted. **Update `hasBackup` to `false` after the operation completes** so the toggle row automatically disappears without requiring the user to leave and re-enter the view. Pass the `hasBackup` state down as a binding if necessary, or use a callback/notification pattern consistent with the existing `onRefresh` pattern.

#### 4.6.2 Pass per-IM preference to `IMDownloadManager.install`

When the user taps "下載" for a variant:

```swift
downloadManager.install(variant, restoreLearning: restoreOnImport)
```

`restoreOnImport` here reads the per-IM key for `family.id`, so each IM's toggle is independent.

#### 4.6.3 Pass per-IM preference to `handleFileImport`

`IMInstallView.handleFileImport` uses `pendingTableName` to identify which IM is being imported. Read that IM's preference at import time:

```swift
let restoreLearning: Bool = UserDefaults.standard.object(
    forKey: "restore_on_import_\(tableName)") as? Bool ?? true

// .limedb / .db
let r = await setupController.importDBFile(url: url, tableName: tableName,
                                            restoreLearning: restoreLearning)
// .lime / .cin / .txt
let r = await setupController.importTxtFile(url: url, tableName: tableName,
                                             restoreLearning: restoreLearning)
```

No value needs to be threaded from `IMInstallView` to `FamilyInstallGroup` — the preference is read directly from `UserDefaults` at call time using the known `tableName`.

---

## 5. Data Flow Summary

### Delete path

```
IMDetailView (Toggle: backupOnDelete)
  → .alert confirm
    → ManageImController.clearTable(tableNick:, backupLearning: true)
      → [Task.detached]
          → SearchServer.backupUserRecords(tableNick)   // copies score>0 rows to {table}_user
          → SearchServer.clearTable(tableNick)           // deletes all rows from {table}
```

### Re-import / re-download path

```
IMInstallView (Toggle: restoreOnImport)
  ├── File picker → handleFileImport
  │     → SetupImController.importDBFile(url:, tableName:, restoreLearning: true)
  │       → [Task.detached]
  │           → DBServer.importFromAttachedDB(...)              // bulk-insert mapping rows
  │           → SearchServer.restoreUserRecords(table)          // update score for backed-up rows
  │           → [if restored > 0] SearchServer.dropBackupTable(table)  // free space
  │           → [notify] hasBackup = false  (hides toggle in FamilyInstallGroup)
  │
  └── Cloud download → IMDownloadManager.install(variant, restoreLearning: true)
        → download(variant, restoreLearning: true)
          → importDownloaded(tempURL:, variant:, restoreLearning: true)
            → [Task.detached]
                → DBServer.importFromAttachedDB / importFromZip
                → SearchServer.restoreUserRecords(tableName)  // returns restored count
                → [if restored > 0] SearchServer.dropBackupTable(tableName)  // free space
                → [notify] hasBackup = false  (hides toggle in FamilyInstallGroup)
```

---

## 6. Backup Table Semantics (reference)

The backup mechanism is already implemented in `LimeDB.swift`:

- **`backupUserRecords(_ table)`** — creates `{table}_user` (or clears it if it exists), then inserts all rows from `{table}` where `score > 0` (user-modified records). Only IM tables with valid names accepted (validated by `isValidTableName`).
- **`restoreUserRecords(_ table)`** — first checks whether `{table}_user` exists (`tableExists`). If no backup table is present (no prior backup was made), it returns `0` immediately without error — the import completes normally with no side-effects. If the backup table exists, reads all rows and calls `addOrUpdateMappingRecord` for each, returning the count of restored records. The backup table is **not** deleted by this method itself; deletion is the caller's responsibility.
- **`dropBackupTable(_ table)`** — drops `{table}_user` if it exists. Returns `true` on success. Validated by `isValidTableName`. Already implemented in `LimeDB.swift` but not yet declared in `LimeDBProtocol` or wrapped in `SearchServer`.
- **`checkBackupTable(_ table)`** — returns `true` if `{table}_user` exists and has at least one row.

The backup table persists across app sessions (it is a physical table in `lime.db`). A new backup overwrites the previous one. After a successful restore (`restoreUserRecords` returns > 0), the caller must drop the backup table via `dropBackupTable` — it has served its purpose and keeping it wastes space.

---

## 7. File-Change Summary

| File | Change |
|------|--------|
| `LimeSettings/Controllers/ManageImController.swift` | Add `backupLearning: Bool = false` to `clearTable`; call `ss?.backupUserRecords(tableNick)` when `true` |
| `Shared/Database/LimeDBProtocol.swift` | Declare `dropBackupTable(_:) -> Bool` (already implemented in `LimeDB.swift`) |
| `Shared/Search/SearchServer.swift` | Add `dropBackupTable(_:)` wrapper over `limeDB.dropBackupTable` |
| `LimeSettings/Controllers/SetupImController.swift` | Add `restoreLearning: Bool = false` to async `importDBFile` and `importTxtFile`; call `restoreUserRecords` then `dropBackupTable` on success |
| `LimeSettings/Controllers/IMStoreView.swift` | Add `restoreLearning: Bool = false` to `install(_:)` and `importDownloaded`; call `restoreUserRecords` then `dropBackupTable` on success |
| `LimeSettings/Views/IMDetailView.swift` | Add per-IM `backup_on_delete_{tableNick}` Toggle section; pass to `clearTable` |
| `LimeSettings/Views/IMInstallView.swift` | Read per-IM `restore_on_import_{tableName}` in `handleFileImport`; no global toggle |
| `LimeSettings/Controllers/IMStoreView.swift` (`FamilyInstallGroup`) | Add `hasBackup` check + per-IM `restore_on_import_{family.id}` Toggle row inside each group; pass to `install(_:restoreLearning:)` |

**No changes required to:** `LimeDB.swift`, `SearchServer.swift`, `DBServer.swift`, or any keyboard extension files.

---

## 8. Test Plan

### Unit tests (existing, in `LimeTests/DBServerTest.swift`)

The following tests already cover the DB layer and should remain green:

- `testDBServerBackupUserRecordsViaLimeDB` (line 901)
- `testDBServerRestoreUserRecordsViaLimeDB` (line 917)
- `testDBServerBackupUserRecordsWithInvalidTableName` (line 934)
- `testDBServerBackupUserRecordsAndRestoreUserRecordsPair` (line 941)

### New controller-layer unit tests (add to `LimeTests/`)

| Test | File | Description |
|------|------|-------------|
| `testManageImControllerClearTableWithBackup` | `ManageImControllerTest.swift` | After adding a record with `score > 0`, call `clearTable(backupLearning: true)`. Verify table is empty and `checkBackupTable` returns `true`. |
| `testManageImControllerClearTableWithoutBackup` | `ManageImControllerTest.swift` | Same but `backupLearning: false`. Verify `checkBackupTable` returns `false`. |
| `testSetupImControllerImportDBRestoresLearning` | `SetupImControllerTest.swift` (new) | Backup records, clear table, import a `.limedb` with `restoreLearning: true`, verify restored records have elevated score. |
| `testSetupImControllerImportTxtRestoresLearning` | `SetupImControllerTest.swift` (new) | Same flow with a `.lime` text file. |

### Manual UI walkthrough

1. Install 注音 and 倉頡 via cloud download.
2. Use the keyboard to learn some words in each IM (raise score for several entries).
3. Open **LimeSettings → IM 管理 → 注音**: confirm "刪除時備份已學習記錄" toggle (per-IM) is ON.
4. Tap "移除輸入法" and confirm. Verify 注音 table is cleared.
5. Open **IM 管理 → 倉頡**: confirm the same toggle is ON independently.
6. Navigate to **下載 / 匯入輸入法 → 注音** and expand the group: confirm "還原已學習記錄" toggle is visible (backup exists for 注音).
7. Expand the 倉頡 group: confirm "還原已學習記錄" is **not visible** (no backup was made for 倉頡).
8. Re-download 注音. Verify scores are restored in the Table Editor.
9. Repeat with the 注音 restore toggle turned OFF: verify scores are NOT restored.

---

## 9. Required Updates to LIME_SETTINGS.md

The following sections of [LIME_SETTINGS.md](LIME_SETTINGS.md) must be updated once this feature is implemented.

### 9.1 §5.2 IMDetailView — "移除輸入法" section

**Current spec** (§5.2, last `Section`):
```
└── Section (no header)  (hidden when im.tableNick == "related")
    └── Button "移除輸入法" role: .destructive
        → confirmAlert("此操作將清除「…」的所有對應資料，無法還原。確定繼續？")
        → manageImController.clearTable(tableNick:)
```

**Updated spec:**
```
└── Section "選項"  (hidden when im.tableNick == "related")
    └── Toggle "刪除時備份已學習記錄"
        pref key: backup_on_delete_{tableNick}  (UserDefaults.standard, per-IM)
        default: true

└── Section (no header)  (hidden when im.tableNick == "related")
    └── Button "移除輸入法" role: .destructive
        → confirmAlert(message varies by toggle — see §4.5.4 of IOS_USER_RECORDS.md)
        → manageImController.clearTable(tableNick:, backupLearning: backupOnDelete)
           ├── [if backupOnDelete] SearchServer.backupUserRecords(tableNick)
           ├── SearchServer.clearTable → LimeDB.clearTable (DELETE records + resetImConfig)
           ├── LIMEPreferenceManager.syncIMActivatedState
           ├── markKeyboardCacheDirty
           └── invalidate
        → dismiss IMDetailView; onRefresh()
```

### 9.2 §5.3 IMInstallView — per-IM restore toggle inside each DisclosureGroup

**Current spec** (§5.3, each DisclosureGroup): no restore toggle row.

**Updated spec** — add a conditional `Toggle` row at the **top of each DisclosureGroup body**, before the download/import buttons:

```
├── DisclosureGroup "注音 (phonetic)"
│   ├── [if checkBackupTable("phonetic")]
│   │   Toggle "還原已學習記錄"
│   │   pref key: restore_on_import_phonetic  (UserDefaults.standard)
│   │   default: true (when first shown)
│   ├── Button "☁ 標準版"  → downloadIM(…, restoreLearning: restoreOnImport)
│   ├── Button "☁ 完整版"  → downloadIM(…, restoreLearning: restoreOnImport)
│   …
│   ├── Button "匯入 .limedb"     → importFromAttachedDB(…, restoreLearning: restoreOnImport)
│   └── Button "匯入 .cin / .lime"  → importTxtTable(…, restoreLearning: restoreOnImport)
```

The same pattern applies to every other DisclosureGroup (one `restore_on_import_{tableNick}` key per IM). The toggle row is **hidden** when `checkBackupTable(tableNick)` returns `false`.

The `關聯字庫` DisclosureGroup is **excluded** — user records backup/restore does not apply to the related table.

### 9.3 §9 Preference Key Reference — add per-IM keys

Add two rows to the table:

| Pref Key | Android Key | Type | Default | Notes |
|---|---|---|---|---|
| `backup_on_delete_{tableNick}` | *(new)* | Bool | `true` | Per-IM. Stored in `UserDefaults.standard` (not App Group). Controls whether learned records are backed up before `clearTable`. |
| `restore_on_import_{tableNick}` | *(new)* | Bool | `true` | Per-IM. Stored in `UserDefaults.standard` (not App Group). Controls whether backed-up records are restored after import/download. |

Also update the **§10.3 Shared UserDefaults** note to acknowledge these two keys intentionally use `UserDefaults.standard` (they are LimeSettings-side only; the keyboard extension does not need them).

---

## 10. Known Behaviour (Verified)

1. **`hasBackup` UI update after restore** — `FamilyInstallGroup.hasBackup` is a local `@State` set via `.task` at view appearance. After a successful restore drops the backup table, the toggle must disappear in-place without requiring the user to leave and re-enter the view. The correct mechanism is the `onRefresh` callback already used throughout `IMInstallView` — calling it after a successful import triggers a parent-level refresh which re-evaluates `hasBackup` for each group. No new notification or binding mechanism is needed. This is a confirmed design choice.

2. **`related` table exclusion** — Android explicitly hides both `chkSetupImBackupLearning` and `chkSetupImRestoreLearning` when the table equals `DB_TABLE_RELATED` (verified in `SetupImLoadDialog.java` lines 168–169). The iOS plan matches this. The reason: the related table stores user-added phrase pairs (`pword`/`cword`), and the pair mapping in a freshly imported table may not be identical to the original, making score restoration meaningless or harmful. Both toggles are therefore unconditionally hidden for the `related` table — this is an intentional, Android-verified behaviour, not an edge case.

3. **`makeSearchServer()` is safe in `Task.detached`** — `SetupImController` captures `self.dbServer` as a local `let server` before entering `Task.detached`, then calls `server.makeSearchServer()` from the background thread. `makeSearchServer()` only reads `server.datasource` (the `LimeDB` instance), which is set once at `DBServer` init and never mutated. This is the same pattern already used for `server.importFromAttachedDB` and `server.importTxtFile` inside the same detached tasks. `server.makeSearchServer()` is therefore the correct and consistent call site — direct `SearchServer(db:)` construction is unnecessary.

---

## 11. Android Backport Required

The current Android implementation in `SearchServer.java` and `SetupImController.java` does **not** delete `{table}_user` after a successful restore. This is the behaviour we diverged from deliberately when writing this iOS plan.

### Android files to update

| File | Change needed |
|------|---------------|
| `LimeStudio/app/src/main/java/…/SearchServer.java` | After `restoreUserRecords(tableName)` returns a positive count, call `dropBackupTable(tableName)` (add method if absent). |
| `LimeStudio/app/src/main/java/…/SetupImController.java` | In `importZippedDb`, `importTxtTable`, and `downloadAndImportZippedDb` — wherever `searchServer.restoreUserRecords()` is called, follow up with `searchServer.dropBackupTable()` when the return value > 0. |

### Android `dropBackupTable` (if not already present)

Add to `SearchServer.java`:

```java
public boolean dropBackupTable(String table) {
    if (!isValidTableName(table)) return false;
    String backupTable = table + "_user";
    try {
        db.execSQL("DROP TABLE IF EXISTS " + backupTable);
        return true;
    } catch (Exception e) {
        return false;
    }
}
```

### Checkbox UI (Android)

No Android UI change is required — the restore checkbox behaviour is unchanged. The cleanup happens silently after a successful restore, exactly as on iOS.
