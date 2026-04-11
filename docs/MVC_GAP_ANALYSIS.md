# MVC Gap Analysis — LimeIME iOS Settings App

Generated: 2026-04-11  
Reference spec: `LIME_SETTINGS.md`  
Constraint: **No direct `LimeDB` calls anywhere in the app layer (Views or Controllers).**

---

## Executive Summary

The iOS Settings app has **two distinct problem categories**:

1. **MVC Architecture Violation** — Every view calls `openDB()` and invokes `LimeDB` methods directly. The controllers (`SetupImController`, `ManageImController`, `ManageRelatedController`, `ShareManager`) all exist but are **wired to nothing** — no view uses them.

2. **Controller Layer Violation** — Even the controllers themselves violate the rule: `BaseController` holds a `LimeDB` reference and passes it to subclasses, which call `LimeDB` methods directly instead of going through `DBServer` / `SearchServer`.

3. **Spec Feature Gaps** — `IntentHandler`, `MainActivityView`/`NavigationDrawerView` protocols, and `NavigationManager` cross-tab wiring are missing.

---

## Part 1 — MVC Architecture Violations

### 1.1 `openDB()` global function

**Location:** `LimeIME/LimeSettingsView.swift:15`

```swift
func openDB() -> LimeDB? {
    guard let containerURL = ...
    return try? LimeDB(path: dbURL.path)   // ← exposes LimeDB to all callers
}
```

This global function is the root cause. It creates a new `LimeDB` connection on every call and returns the raw SQL abstraction layer to whatever code asks for it. Every view, every controller, every sheet — all call `openDB()` and speak `LimeDB` directly.

`DBServer.shared` already owns a lazy `datasource: LimeDB?` that is properly scoped to the app group container. `openDB()` should be eliminated.

---

### 1.2 Views With Direct LimeDB Access (15 files)

The spec (§3.5) states: *"Moving any business logic (DB calls, file I/O, state coordination) directly into a SwiftUI View struct — all such logic must remain in the Controller / Manager layer"* is **not permitted**.

| File | Direct LimeDB calls |
|---|---|
| `LimeSettingsView.swift` | defines `openDB()`; `db.seedDefaultIMs()` in `initDatabase()` |
| `Views/SetupTabView.swift` | `openDB()`, `db.seedDefaultIMs()` |
| `Views/IMListView.swift` | `openDB()`, `db.getAllImConfigs()`, `db.updateIMEnabled()`, `db.updateIMSortOrder()` |
| `Views/IMDetailView.swift` | `openDB()`, `db.getAllImConfigs()` (in computed property `currentKeyboard`) |
| `Views/KeyboardPickerView.swift` | `openDB()`, `db.getKeyboardConfigList()`, `db.getAllImConfigs()`, `db.setImConfigKeyboard()` |
| `Views/IMInstallView.swift` | `openDB()`, `db.isValidTableName()`, `db.importFromAttachedDB()`, `db.importTxtFile()` |
| `Views/RecordListView.swift` | `openDB()`, `db.getRecordList()`, `db.countRecords()`, `db.deleteRecord()` |
| `Views/AddRecordView.swift` | `openDB()`, `db.addRecord()` |
| `Views/EditRecordView.swift` | `openDB()`, `db.updateRecord()`, `db.deleteRecord()` |
| `Views/RelatedListView.swift` | `openDB()`, `db.getRelated()`, `db.countRecords()`, `db.deleteRecord()` |
| `Views/AddRelatedView.swift` | `openDB()`, `db.addRecord("related", ...)` |
| `Views/EditRelatedView.swift` | `openDB()`, `db.updateRecord()`, `db.deleteRecord()` |
| `Views/PreferencesTabView.swift` | `openDB()`, `db.getKeyboardConfigList()`, `db.setImConfigKeyboard()` |
| `Views/DBManagerView.swift` | `openDB()`, `db.exportDB()`, `LimeDB(path:)` for integrity check |
| `IMStoreView.swift` | `openDB()` (legacy; `IMInstallView` should replace this) |

All 15 files must have their DB calls removed and routed through the appropriate controller.

---

### 1.3 Controllers Exist But Are Wired to Nothing

All controllers were written correctly in terms of structure but **no view instantiates or calls any of them**.

| Controller | Should be used by | Actually used by |
|---|---|---|
| `SetupImController` | `SetupTabView`, `IMInstallView`, `LimeSettingsView` | **Nothing** |
| `ManageImController` | `IMListView`, `KeyboardPickerView`, `RecordListView`, `AddRecordView`, `EditRecordView` | **Nothing** |
| `ManageRelatedController` | `RelatedListView`, `AddRelatedView`, `EditRelatedView` | **Nothing** |
| `ShareManager` | `DBManagerView` | **Nothing** |
| `ProgressManager` | All DB-touching views | Only used internally by `SetupImController` |

---

### 1.4 Controllers Call LimeDB Directly (Spec §3.3 Violation)

Even when the wiring is fixed, the controllers themselves violate the rule. `BaseController` holds `let db: LimeDB` and passes it to subclasses which call `LimeDB` methods directly.

Per spec §3.3: *"Controllers receive Model objects via constructor injection — no direct `UserDefaults` or `FileManager` calls except through `DBServer` / `LIMEPreferenceManager`."*

**Current — wrong:**
```swift
// BaseController.swift:17
let db: LimeDB
init(db: LimeDB, prefs: LIMEPreferenceManager = .shared)

// ManageImController.swift:41
let records = localDB.getRecordList(table, ...)   // ← LimeDB direct call
```

**Required — correct:**
```swift
// BaseController should hold DBServer + SearchServer
let dbServer: DBServer
let searchServer: SearchServer
init(dbServer: DBServer = .shared, searchServer: SearchServer, prefs: LIMEPreferenceManager = .shared)
```

Controllers that currently call `localDB.*` methods need corresponding methods added to `DBServer` or `SearchServer`, then call those instead.

---

## Part 2 — Spec Feature Gaps

### 2.1 Missing `MainActivityView` and `NavigationDrawerView` Protocols (Spec §3.4)

The spec mandates these two protocols alongside the three that were implemented:

```swift
protocol MainActivityView: ViewUpdateListener {
    // coordinator protocol for the root view
}

protocol NavigationDrawerView: ViewUpdateListener {
    // IM navigation drawer / tab selection callbacks
}
```

`ViewProtocols.swift` defines `ViewUpdateListener`, `SetupImView`, `ManageImView`, `ManageRelatedView` — but `MainActivityView` and `NavigationDrawerView` are absent.

---

### 2.2 Missing `IntentHandler` (Spec §3.3)

The spec lists `IntentHandler.swift` as a required Controller/Manager:

> `IntentHandler` — Incoming file handling (`.lime`, `.cin`, `.limedb`) from system share / Files

No `IntentHandler.swift` file exists. The app cannot receive files shared from the Files app or other apps. The `LimeSettingsApp` / `AppDelegate` have no `onOpenURL` / document scene handler wired.

---

### 2.3 `NavigationManager` Not Wired for Cross-Tab Navigation (Spec §3.3)

`NavigationManager.swift` exists and is injected as `@EnvironmentObject`, but `selectedTab` is only set by the `TabView` — no controller or view reads it to programmatically switch tabs (e.g., after an import in `IMInstallView`, switch to the IM list tab). Android's `NavigationManager` was used by controllers to drive tab selection after operations.

---

### 2.4 `DBManagerView` Uses Inline Backup/Restore Instead of `SetupImController` (Spec §7)

`DBManagerView` performs backup and restore inline with direct `openDB()` and `LimeDB` calls. `SetupImController` already has `backupDB()` (returns `URL`) and `restoreDB(from:view:)` (uses `DBServer.restoreDatabase(uri:)`). The view must be refactored to use the controller.

---

### 2.5 `IMStoreView.swift` Is Dead Code

`IMInstallView.swift` supersedes `IMStoreView.swift` and is what `IMListView` actually links to. `IMStoreView.swift` still exists in the project, still calls `openDB()` at line 56 and 114, and creates confusion. It should be removed from the target.

---

## Part 3 — Implementation Plan

### Step 1 — Add Missing Methods to `DBServer` / `SearchServer`

Before touching views or controllers, ensure the server layer exposes all operations that views currently call directly on `LimeDB`:

| Currently called on LimeDB | Should be on |
|---|---|
| `getAllImConfigs()` | `DBServer` |
| `updateIMEnabled(imName:enabled:)` | `DBServer` |
| `updateIMSortOrder(id:sortOrder:)` | `DBServer` |
| `getKeyboardConfigList()` | `DBServer` |
| `setImConfigKeyboard(_:_:)` | `DBServer` |
| `getRecordList(_:_:searchByCode:_:_:)` | `DBServer` or `SearchServer` |
| `countRecords(_:_:_:)` | `DBServer` |
| `addRecord(_:_:)` | `DBServer` |
| `updateRecord(_:_:_:_:)` | `DBServer` |
| `deleteRecord(_:_:_:)` | `DBServer` |
| `getRelated(_:_:_:)` | `DBServer` |
| `isValidTableName(_:)` | `DBServer` |
| `importFromAttachedDB(sourcePath:tableName:)` | `DBServer` (already has `importTxtTable`) |
| `importTxtFile(at:tableName:progress:)` | `DBServer` |
| `seedDefaultIMs()` | `DBServer` |
| `exportDB(to:)` | `DBServer` (already has `backupDatabase(uri:)`) |

---

### Step 2 — Fix `BaseController` to Use `DBServer` / `SearchServer`

```swift
// Before
class BaseController {
    let db: LimeDB
    init(db: LimeDB, prefs: LIMEPreferenceManager = .shared)
}

// After
class BaseController {
    let dbServer: DBServer
    let searchServer: SearchServer
    let prefs: LIMEPreferenceManager
    init(dbServer: DBServer = .shared,
         searchServer: SearchServer,
         prefs: LIMEPreferenceManager = .shared)
}
```

Update `ManageImController`, `ManageRelatedController`, `SetupImController` to call `dbServer.*` / `searchServer.*` instead of `localDB.*`.

---

### Step 3 — Remove `openDB()` Global; Wire Controllers into Views

**`LimeSettingsView.swift`**
- Delete `openDB()` and `copyBundledDBIfNeeded(to:)`.
- Instantiate `SetupImController`, `ManageImController`, `ManageRelatedController` as `@StateObject` at root or inject via `@EnvironmentObject`.
- Replace `initDatabase()` direct call with `setupImController.seedDefaultIMs(view: nil)`.

**`SetupTabView.swift`**
- Receive `SetupImController` via `@EnvironmentObject`.
- Replace `seedDefaultIMs()` private function body with `controller.seedDefaultIMs(view: self)`.
- Adopt `SetupImView` protocol on the view or a local `@StateObject` proxy.

**`IMListView.swift`**
- Receive `ManageImController` via `@EnvironmentObject`.
- Replace `loadIMs()` with `controller.loadIMList(view: self)` (add this method to controller).
- Replace `toggleIM()` with `controller.toggleIMEnabled(imName:enabled:view:)`.
- Replace `moveIMs()` with `controller.updateIMSortOrder(id:sortOrder:)`.
- Adopt `ManageImView` to receive `refreshRecordList()` → reload IM list.

**`IMDetailView.swift`**
- Replace `currentKeyboard` computed property's inline `openDB()` with a controller call or pass `keyboardId` in `IMRow` directly (it already has `tableNick`; `IMListView.loadIMs()` should include `keyboardId` in `IMRow`).

**`KeyboardPickerView.swift`**
- Receive `ManageImController` via `@EnvironmentObject`.
- Replace `loadKeyboards()` and `selectKeyboard(_:)` with controller calls.

**`IMInstallView.swift`**
- Receive `SetupImController` via `@EnvironmentObject`.
- Replace `handleFileImport()` inline body with `controller.importDBFile()` / `controller.importTxtFile()`.

**`RecordListView.swift` / `AddRecordView.swift` / `EditRecordView.swift`**
- Receive `ManageImController` via constructor or `@EnvironmentObject`.
- Replace all inline `openDB()` bodies with `controller.loadRecords()`, `controller.addRecord()`, `controller.updateRecord()`, `controller.deleteRecord()`.
- Adopt `ManageImView` to receive `displayRecords(_:)`, `updateRecordCount(_:)`, `refreshRecordList()`.

**`RelatedListView.swift` / `AddRelatedView.swift` / `EditRelatedView.swift`**
- Receive `ManageRelatedController` via `@EnvironmentObject`.
- Replace inline `openDB()` bodies with `controller.loadRelated()`, `controller.addRelated()`, `controller.updateRelated()`, `controller.deleteRelated()`.
- Adopt `ManageRelatedView` to receive `displayRelatedPhrases(_:)`, `refreshPhraseList()`.

**`PreferencesTabView.swift`**
- Replace `updatePhoneticKeyboard(type:)` inline `openDB()` body with `dbServer.setImConfigKeyboard("phonetic", kb)` (accessible via injected `DBServer.shared` directly, since this is a pure preference sync — no controller needed).
- Or create a lightweight `PreferencesController` if the spec requires controller mediation here.

**`DBManagerView.swift`**
- Receive `SetupImController` via `@EnvironmentObject`.
- Replace `performBackup()` with `controller.backupDB()` (already returns `URL`).
- Replace `performRestore(from:)` with `controller.restoreDB(from:view: self)`.
- Remove the `LimeDB(path:)` integrity check — `SetupImController.restoreDB` already delegates to `DBServer.restoreDatabase(uri:)` which handles integrity.
- Use `ShareManager` for the share sheet instead of the inline `ShareSheet` struct.

---

### Step 4 — Add Missing Protocols and `IntentHandler`

**`ViewProtocols.swift`** — add:
```swift
protocol MainActivityView: ViewUpdateListener {
    func onIMListChanged()
    func onTabSelected(_ tab: Int)
}

protocol NavigationDrawerView: ViewUpdateListener {
    func updateIMMenu(_ imList: [ImConfig])
}
```

**`IntentHandler.swift`** — create in `Controllers/`:
```swift
final class IntentHandler {
    static let shared = IntentHandler()
    private let setupController: SetupImController

    func handle(url: URL, view: (any SetupImView)?) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "limedb", "db":
            setupController.importDBFile(url: url, tableName: url.deletingPathExtension().lastPathComponent, view: view)
        case "lime", "cin":
            setupController.importTxtFile(url: url, tableName: url.deletingPathExtension().lastPathComponent, view: view)
        default:
            view?.onError("不支援的檔案格式：.\(ext)")
        }
    }
}
```

Wire in `AppDelegate.swift` or `LimeSettingsApp.onOpenURL`.

---

### Step 5 — Wire `NavigationManager` for Post-Operation Tab Switching

After import completes in `SetupImController` / `IMInstallView`, call:
```swift
await MainActor.run {
    navigationManager.selectedTab = 1   // switch to IM list tab
}
```

Inject `NavigationManager` into controllers that need cross-tab navigation.

---

### Step 6 — Remove `IMStoreView.swift`

Remove `IMStoreView.swift` from the LimeIME target in `project.yml` / `project.pbxproj`. Verify `IMInstallView` handles all the same download and import flows.

---

## Part 4 — Checklist

### MVC Architecture Fixes
- [ ] Add all missing methods to `DBServer` (see §3.1 table)
- [ ] Fix `BaseController` to hold `DBServer` + `SearchServer` instead of `LimeDB`
- [ ] Update `ManageImController` to call `dbServer.*` instead of `localDB.*`
- [ ] Update `ManageRelatedController` to call `dbServer.*` instead of `localDB.*`
- [ ] Update `SetupImController` to call `dbServer.*` instead of `localDB.*`
- [ ] Delete `openDB()` global from `LimeSettingsView.swift`
- [ ] Wire `SetupImController` into `SetupTabView`
- [ ] Wire `SetupImController` into `IMInstallView`
- [ ] Wire `SetupImController` into `DBManagerView` (backup + restore)
- [ ] Wire `ManageImController` into `IMListView`
- [ ] Wire `ManageImController` into `KeyboardPickerView`
- [ ] Wire `ManageImController` into `RecordListView` / `AddRecordView` / `EditRecordView`
- [ ] Wire `ManageRelatedController` into `RelatedListView` / `AddRelatedView` / `EditRelatedView`
- [ ] Wire `ShareManager` into `DBManagerView` (replace inline `ShareSheet`)
- [ ] Remove inline DB calls from `PreferencesTabView.updatePhoneticKeyboard()`
- [ ] Remove inline DB call from `IMDetailView.currentKeyboard`
- [ ] Remove inline DB call from `LimeSettingsView.initDatabase()`

### Spec Feature Gaps
- [ ] Add `MainActivityView` protocol to `ViewProtocols.swift`
- [ ] Add `NavigationDrawerView` protocol to `ViewProtocols.swift`
- [ ] Create `IntentHandler.swift` in `Controllers/`
- [ ] Wire `IntentHandler` in `AppDelegate` / `LimeSettingsApp.onOpenURL`
- [ ] Wire `NavigationManager.selectedTab` for post-import tab switching
- [ ] Remove `IMStoreView.swift` from project target

### Verification
- [ ] `grep -r "openDB()" LimeIME-iOS/LimeIME/` returns zero results
- [ ] `grep -r "LimeDB" LimeIME-iOS/LimeIME/` returns zero results (only allowed in `Shared/Database/`)
- [ ] All `ManageImView`, `ManageRelatedView`, `SetupImView` callbacks exercised in tests
- [ ] `SetupImControllerTests`, `ManageImControllerTests`, `ManageRelatedControllerTest` all pass
