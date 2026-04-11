# LIME Settings iOS App — Specification

## 1. Overview

This document specifies the design and behaviour of the **LimeIME container app** (the Settings app the user sees in the iOS Home Screen, not the keyboard extension). The goal is to replicate **every feature of the Android LIME Settings app** while applying iOS HIG conventions: `NavigationStack` / `NavigationView` for drill-down navigation, `Form + Section` for preference settings, `List` with swipe actions for record management, `Picker` for single-choice selections, and `Toggle` for boolean controls.

The app is organized around **four high-level feature areas**:

| Feature | Purpose |
|---|---|
| **IM Manager** | Install, download, import/export, and configure soft keyboard layouts |
| **IM Table Editor** | Browse and edit per-IM character mapping records and related phrases |
| **DB Manager** | Backup and restore the entire database |
| **IM Preferences** | Tune all keyboard behaviour and display settings |

A fifth area — **App Setup** — handles one-time activation and app-level information (version, about).

### Android → iOS Component Mapping

| Android component | iOS Feature Area | Tab |
|---|---|---|
| `SetupImFragment` (activation guide) | App Setup | 設定 |
| `SetupImFragment` (IM buttons) | IM Manager — enable/reorder | 輸入法 |
| `kbsetting.xml` (IM info + keyboard picker) | IM Manager — keyboard config | 輸入法 drill-down |
| `IMStoreView` / cloud download | IM Manager — download | 輸入法 |
| `SetupImFragment` (import file) | IM Manager — import | 輸入法 |
| `ManageImFragment` (record CRUD) | IM Table Editor — mapping records | 輸入法 drill-down |
| `ManageRelatedFragment` | IM Table Editor — related phrases | 關聯字 |
| `SetupImFragment` (backup/restore) | DB Manager | 資料 |
| `LIMEPreference` (`preference.xml`) | IM Preferences | 偏好設定 |

---

## 2. App Structure

The container app uses a `TabView` with **five tabs**. This collapses the Android navigation drawer + separate Preference activity into a flat tab bar per iOS HIG.

```
TabView
├── [1] 設定       systemImage: "gearshape"          (App Setup)
├── [2] 輸入法      systemImage: "list.bullet"         (IM Manager + IM Table Editor)
├── [3] 關聯字      systemImage: "textformat.alt"      (IM Table Editor — related phrases)
├── [4] 偏好設定    systemImage: "slider.horizontal.3" (IM Preferences)
└── [5] 資料        systemImage: "archivebox"          (DB Manager)
```

Each tab has its own `NavigationStack` (iOS 16+) or `NavigationView` (iOS 15) so drill-down navigation stays scoped to its tab.

---

## 3. MVC Architecture Mandate

The iOS LIME Settings app **strictly follows the same MVC pattern** defined in [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md). This is a hard architectural constraint, not a guideline.

### 3.1 Layer Compliance Rules

| Layer | Android | iOS | Porting Target |
|---|---|---|---|
| **Model** | `SearchServer`, `DBServer`, `LimeDB`, `LIMEPreferenceManager` | Same names, Swift | **100% — identical operations, logic, error handling, threading** |
| **Controller / Manager** | `SetupImController`, `ManageImController`, `NavigationManager`, `ShareManager`, `ProgressManager`, `IntentHandler` | Same names, Swift | **100% — identical orchestration, data flow, callback interfaces** |
| **View** | `MainActivity`, Fragments, Dialogs, `LIMEPreference` Activity | SwiftUI Views, Sheets, `TabView` | **Adapted to iOS HIG only — SwiftUI replaces XML/Fragment, everything else identical** |

### 3.2 Model Layer (100% Port)

The Model layer is ported to Swift with **no behavioural divergence** from the Android source. Every public method, return contract, null-safety rule, and threading assumption must be reproduced exactly.

| Android Class | iOS Swift Class | Purpose |
|---|---|---|
| `SearchServer` | `SearchServer.swift` | DB query operations, record search, keyboard config, related phrase queries |
| `DBServer` | `DBServer.swift` | File-level DB operations — import, export, backup, restore, table ops |
| `LimeDB` | `LimeDB.swift` | SQL abstraction — query execution, schema management, serialization |
| `LIMEPreferenceManager` | `LIMEPreferenceManager.swift` | Preferences persistence, query, defaults — reads/writes the shared App Group suite |

**Model layer rules** (mirroring `UI_ARCHITECTURE.md §Layer 3`):
- No UIKit / SwiftUI framework dependencies (except `FileManager` for file paths).
- No direct reference to any View type.
- Return safe defaults instead of `nil` (empty arrays, zero counts).
- All exceptions caught at this layer; callers receive `Result<T, Error>` or a safe default.

### 3.3 Controller / Handler / Manager Layer (100% Port)

Business logic and operation orchestration are ported to Swift **without changing the operation sequence or callback contract**. The data flow diagrams in `UI_ARCHITECTURE.md §Data Flow` define the exact call order that must be reproduced.

| Android Class | iOS Swift Class | Responsibilities |
|---|---|---|
| `BaseController` | `BaseController.swift` | `@MainActor` UI dispatch, error handling, progress callbacks — mirrors `mainHandler.post()` with Swift `DispatchQueue.main.async` / `await MainActor.run` |
| `SetupImController` | `SetupImController.swift` | Import workflow (txt / limedb / remote download), backup/restore, IM menu refresh, button state |
| `ManageImController` | `ManageImController.swift` | Async record CRUD, related phrase CRUD, search/filter, keyboard selection |
| `NavigationManager` | `NavigationManager.swift` | Tab/screen selection state, navigation callbacks |
| `ShareManager` | `ShareManager.swift` | Export IM / related as `.limedb` or `.lime` text, share-sheet invocation |
| `ProgressManager` | `ProgressManager.swift` | Progress overlay show/update/dismiss — wraps SwiftUI `@Published` state on `@MainActor` |
| `IntentHandler` | `IntentHandler.swift` | Incoming file handling (`.lime`, `.cin`, `.limedb`) from system share / Files |

**Controller layer rules** (mirroring `UI_ARCHITECTURE.md §Layer 2`):
- Controllers receive Model objects via constructor injection — no direct `UserDefaults` or `FileManager` calls except through `DBServer` / `LIMEPreferenceManager`.
- All heavy I/O dispatched on a background `Task` / `DispatchQueue.global`; all View callbacks dispatched on `MainActor`.
- Controllers and Managers hold no UIKit/SwiftUI types — they interact with Views only through **Swift protocols** (see §3.4).

### 3.4 View Protocols (100% Port of Java Interfaces, Swift Syntax)

All Android View interfaces are ported to Swift `protocol` with identical callback signatures.

| Android Interface | Swift Protocol |
|---|---|
| `ViewUpdateListener` | `ViewUpdateListener` |
| `MainActivityView` | `MainActivityView` |
| `SetupImView` | `SetupImView` |
| `ManageImView` | `ManageImView` |
| `ManageRelatedView` | `ManageRelatedView` |
| `NavigationDrawerView` | `NavigationDrawerView` |

```swift
// Direct Swift translation of Android ViewUpdateListener
protocol ViewUpdateListener: AnyObject {
    func onError(_ message: String)
    func onProgress(_ percentage: Int, status: String)
}

protocol SetupImView: ViewUpdateListener {
    func updateButtonStates(_ states: [String: Bool])
    func refreshImList()
}

protocol ManageImView: ViewUpdateListener {
    func displayRecords(_ records: [Record])
    func updateRecordCount(_ count: Int)
    func refreshRecordList()
}

protocol ManageRelatedView: ViewUpdateListener {
    func displayRelatedPhrases(_ phrases: [Related])
    func refreshPhraseList()
}
```

### 3.5 View Layer (iOS-Adapted Only)

The View layer is the **only layer that deviates** from the Android source. Substitutions are one-to-one structural replacements — the same screens exist, only the platform primitives differ.

| Android View Component | iOS Equivalent | Notes |
|---|---|---|
| `MainActivity` (coordinator) | `LimeSettingsApp` + root `ContentView` | Owns and injects controller/manager instances |
| `NavigationDrawerFragment` | `TabView` (§2) | Same IM navigation items, different platform widget |
| `SetupImFragment` | `SetupTabView` + `IMListView` + `IMInstallView` | Setup guide + IM list + download flows |
| `ManageImFragment` | `RecordListView` + `AddRecordView` + `EditRecordView` | Per-IM record CRUD |
| `ManageRelatedFragment` | `RelatedListView` + `AddRelatedView` + `EditRelatedView` | Related phrase CRUD |
| `LIMEPreference` Activity + `PrefsFragment` | `PreferencesTabView` with `Form` sections | All 11 preference sections |
| `ImportDialog` / `SetupImLoadDialog` | SwiftUI `.sheet` + `.fileImporter` | File selection and import options |
| `ShareDialog` | SwiftUI `.sheet` + `ShareLink` | IM export format selection |
| `ManageImAddDialog` / `ManageImEditDialog` | SwiftUI `.sheet` (`AddRecordView` / `EditRecordView`) | Record add/edit forms |
| `ManageImKeyboardDialog` | `KeyboardPickerView` (Navigation drill-down) | Keyboard layout selection |
| `ProgressDialogManager` overlay | `ProgressManager` `.overlay(ProgressView(...))` | Progress feedback |

**Permitted iOS-View adaptations:**
- Use SwiftUI declarative layout instead of XML inflation.
- Use `NavigationStack` + `TabView` instead of navigation drawer.
- Use `.sheet`, `.alert`, `.confirmationDialog` instead of `AlertDialog` / `DialogFragment`.
- Use `.searchable()` instead of a manual search `EditText` + button.
- Use `@StateObject` / `@ObservedObject` for reactive state instead of `notifyDataSetChanged()`.
- Apply iOS HIG spacing, typography, and colour conventions.

**Not permitted in the View layer:**
- Moving any business logic (DB calls, file I/O, state coordination) directly into a SwiftUI `View` struct — all such logic must remain in the Controller / Manager layer.
- Skipping any screen, operation, or callback defined in the Android source.

### 3.6 Testing and Verification Requirements

The **Model and Controller layers must achieve the same testability goals** as the Android architecture (see `UI_ARCHITECTURE.md §Benefits — Testability`).

| Requirement | Rule |
|---|---|
| **Unit tests for all Controllers** | `SetupImControllerTests`, `ManageImControllerTests` — test every public method with mock Model objects |
| **Unit tests for all Model classes** | `SearchServerTests`, `DBServerTests`, `LimeDBTests`, `LIMEPreferenceManagerTests` |
| **No framework dependency in tests** | Controller and Model tests must compile and run without a simulator (XCTest only, no UIKit/SwiftUI) |
| **Mock View protocols** | Each test file provides a `Mock*View` struct implementing the corresponding protocol to capture callbacks |
| **Data flow verification** | Every data flow in `UI_ARCHITECTURE.md §Data Flow` (import, export, backup, restore) must have a corresponding integration test asserting the full call sequence |
| **Threading verification** | Tests assert that View callbacks are always delivered on the main thread |
| **100% operation coverage** | Every Android operation listed in §3.2 and §3.3 must have a corresponding Swift implementation and a passing test |

---

## 4. Feature: App Setup (設定 Tab) 

**Purpose**: One-time keyboard activation guide, database seeding, and app information. Corresponds to the non-IM-management parts of Android's `SetupImFragment`.

### 4.1 Layout

```
NavigationStack
└── List
    ├── Section "啟用狀態"
    │   └── Status banner (colour-coded: green / yellow / red)
    ├── Section "步驟 1 — 啟用鍵盤"
    │   ├── Text "前往「設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤」，選擇 LimeIME。"
    │   └── Button "前往系統設定"  → UIApplication.openSettingsURLString
    ├── Section "步驟 2 — 允許完整取用"
    │   ├── Text "在剛才的鍵盤設定頁面，開啟「允許完整取用」。"
    │   └── Note "完整取用是讀取偏好設定 App Group 所必需。"
    ├── Section "初始資料庫"
    │   ├── Button "預載預設輸入法"  → db.seedDefaultIMs() on background thread
    │   └── Text (inline status: progress / success / skip message)
    └── Section "關於"
        ├── LabeledContent "版本"   CFBundleShortVersionString + build number
        ├── LabeledContent "授權"   "GPL-3.0"
        └── Link "原始碼 (GitHub)"
```

### 4.2 Status Banner

- Re-checks on `.onAppear` and whenever `scenePhase` transitions to `.active`.
- Polls `UITextInputMode.activeInputModes` for the keyboard bundle ID; also checks for the App Group `UserDefaults` being accessible (proxy for Full Access).

| Condition | Colour | Message |
|---|---|---|
| Keyboard enabled + Full Access on | Green | "LimeIME 鍵盤已啟用 ✓" |
| Keyboard enabled, Full Access off | Yellow | "鍵盤已啟用，但尚未允許完整取用" |
| Keyboard not in active list | Red | "尚未啟用 LimeIME 鍵盤" |

### 4.3 初始資料庫 Button

- Calls `db.seedDefaultIMs()` on a background thread (replicates Android's `l3_initial_btn_load_preload_db`).
- Shows inline progress text while running; dismisses overlay when done.
- Result messages: "✅ 預設輸入法已初始化" or "⚠️ 輸入法已存在，略過".

---

## 5. Feature: IM Manager (輸入法 Tab)

**Purpose**: Install input methods (download from cloud or import local files), configure which IMs are active and in what order, and set each IM's soft keyboard layout. Corresponds to Android's `SetupImFragment` IM grid + `kbsetting.xml` + `IMStoreView`.

### 5.1 IM List Screen

Entry point for the **輸入法** tab.

```
NavigationStack
└── List (editable for drag-reorder)
    ├── Section "已安裝的輸入法"
    │   └── ForEach IMRow  (sorted by im.sortOrder)
    │       ├── HStack
    │       │   ├── VStack { Text(im.label).bold, Text(im.tableNick).secondary.caption }
    │       │   └── Toggle("", isOn: $row.enabled)
    │       │       .onChange → db.updateIMEnabled(id:enabled:)
    │       └── NavigationLink → IMDetailView(im: row)
    └── Section "輸入法庫"
        └── NavigationLink "下載 / 匯入輸入法" → IMInstallView
.toolbar { EditButton() }
.navigationTitle("管理輸入法")
```

- **Enable / disable**: writes `im.enabled` via `db.updateIMEnabled(id:enabled:)` and updates `keyboard_state` preference string.
- **Drag to reorder**: writes `im.sortOrder` via `db.updateIMSortOrder(id:sortOrder:)`.
- Enabled rows display at full opacity; disabled rows display at half opacity (matching Android's `HALF_ALPHA_VALUE` / italic style).

### 5.2 IM Detail Screen

Drill-down from any IM row. Shows metadata, allows changing the soft keyboard layout, and links to the Table Editor.

```
NavigationStack (continued)
└── IMDetailView(im: IMRow)
    └── List
        ├── Section "輸入法資訊"
        │   ├── LabeledContent "代碼"    im.tableNick
        │   ├── LabeledContent "版本"    UserDefaults[tableNick + "mapping_version"] ?? "—"
        │   ├── LabeledContent "字數"    UserDefaults[tableNick + "total_record"]    ?? "—"
        │   └── LabeledContent "狀態"    "已安裝" / "未安裝"
        ├── Section "軟鍵盤配置"
        │   └── NavigationLink "鍵盤佈局：\(currentKeyboard)" → KeyboardPickerView(im:)
        ├── Section "字根對應設定"  (shown only when im.tableNick == "custom")
        │   ├── Toggle "數字字根對應"  pref: accept_number_index  default: false
        │   └── Toggle "符號字根對應"  pref: accept_symbol_index  default: false
        └── Section "字根對應表"
            └── NavigationLink "瀏覽 / 編輯對應表" → RecordListView(table: im.tableNick)
```

> The "字根對應設定" section is exclusive to the custom IM (`im.tableNick == "custom"`). All built-in IMs hardcode their own `hasNumberMapping` / `hasSymbolMapping` values in `initializeIMKeyboard()` and ignore these prefs.

#### 5.2.1 KeyboardPickerView — Soft Keyboard Selection

Equivalent to Android's `ManageImKeyboardDialog`.

```
NavigationStack (continued)
└── KeyboardPickerView
    └── List
        └── ForEach keyboards (from db.getKeyboards() or static list)
            └── HStack { Text(kb.description), Spacer(),
                        Image(systemName: "checkmark").hidden(!isSelected) }
               .onTapGesture → db.setIMKeyboard(table:description:code:); dismiss
.navigationTitle("選擇鍵盤佈局")
```

- Selection is persisted via `db.setIMKeyboard(table:description:code:)`.
- For the **注音** IM specifically, changing the layout here must also update the `phonetic_keyboard_type` preference so the keyboard extension picks up the correct layout.

### 5.3 IM Install Screen — Download & Import

Entry point reachable from the "下載 / 匯入輸入法" NavigationLink in §5.1. Each IM is a top-level `DisclosureGroup`; cloud download options appear only for built-in IMs.

```
NavigationStack (continued)
└── IMInstallView
    └── List
        ├── DisclosureGroup "注音 (phonetic)"
        │   ├── Button "☁ 標準版"         → downloadIM(CLOUD_PHONETIC,          table: "phonetic")
        │   ├── Button "☁ 完整版"         → downloadIM(CLOUD_PHONETIC_COMPLETE,  table: "phonetic")
        │   ├── Button "☁ BIG5 字集"       → downloadIM(CLOUD_PHONETIC_BIG5,      table: "phonetic")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "phonetic")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "phonetic")
        ├── DisclosureGroup "倉頡 (cj)"
        │   ├── Button "☁ 標準"            → downloadIM(CLOUD_CJ,      table: "cj")
        │   ├── Button "☁ BIG5"             → downloadIM(CLOUD_CJ_BIG5, table: "cj")
        │   ├── Button "☁ 香港字"          → downloadIM(CLOUD_CJHK,    table: "cj")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "cj")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "cj")
        ├── DisclosureGroup "快倉 (scj)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_SCJ, table: "scj")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "scj")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "scj")
        ├── DisclosureGroup "倉頡五代 (cj5)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_CJ5, table: "cj5")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "cj5")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "cj5")
        ├── DisclosureGroup "速成 (ecj)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_ECJ, table: "ecj")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "ecj")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "ecj")
        ├── DisclosureGroup "大易 (dayi)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_DAYI, table: "dayi")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "dayi")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "dayi")
        ├── DisclosureGroup "輕鬆 (ez)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_EZ, table: "ez")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "ez")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "ez")
        ├── DisclosureGroup "行列 (array)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_ARRAY, src: "array.limedb")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "array")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "array")
        ├── DisclosureGroup "行列 10 (array10)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_ARRAY10, src: "array10.limedb")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "array10")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "array10")
        ├── DisclosureGroup "拼音 (pinyin)"
        │   ├── Button "☁ Unicode"          → downloadIM(CLOUD_PINYIN,     table: "pinyin")
        │   ├── Button "☁ BIG5"             → downloadIM(CLOUD_PINYIN_BIG5, table: "pinyin")
        │   ├── Button "☁ 簡體 GB"         → downloadIM(CLOUD_PINYIN_GB,   table: "pinyin")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "pinyin")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "pinyin")
        ├── DisclosureGroup "華象直覺 (hs)"
        │   ├── Button "☁ 完整版"         → downloadIM(CLOUD_HS,    table: "hs")
        │   ├── Button "☁ 一版"            → downloadIM(CLOUD_HS_V1, table: "hs")
        │   ├── Button "☁ 二版"            → downloadIM(CLOUD_HS_V2, table: "hs")
        │   ├── Button "☁ 三版"            → downloadIM(CLOUD_HS_V3, table: "hs")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "hs")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "hs")
        ├── DisclosureGroup "筆順五碼 (wb)"
        │   ├── Button "☁ 下載"            → downloadIM(CLOUD_WB, table: "wb")
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "wb")
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "wb")
        ├── DisclosureGroup "自建 (custom)"
        │   ├── Button "匯入 .limedb"     → fileImporter → importFromAttachedDB(table: "custom") → seedCustomIM()
        │   └── Button "匯入 .cin / .lime"  → fileImporter → importTxtTable(table: "custom") → seedCustomIM()
        └── Section "狀態"  (visible only when statusMessage is non-empty)
            └── Text(statusMessage).font(.footnote).foregroundColor(.secondary)
```

#### 5.3.1 Progress Overlay

When import or download is running, show a centred `ProgressView("匯入中…")` overlay with the current status message. Set `.interactiveDismissDisabled(true)` on any surrounding sheet.

#### 5.3.2 Download Behaviour

1. Download `.zip` or `.limedb` to `FileManager.default.temporaryDirectory`.
2. If `.zip`, extract with `ZipArchive` or the `Zip` SPM library.
3. Route by file extension:
   - `.cin` / `.lime` → `db.importTxtFile(at:tableName:progress:)`, streaming progress updates.
   - `.db` / `.limedb` → `db.importFromAttachedDB(sourcePath:tableName:)`.
4. After import, call `db.seedDefaultIMs()` (or an explicit `insertImConfig`) so the IM appears in the list.
5. Clean up the temp file.

#### 5.3.3 Local File Import

- **Named IM rows**: `tableName` is fixed to the IM code shown in the `DisclosureGroup` header.
- **自建 (custom) row**: same pipelines with `tableName = "custom"`. After import, call `db.seedCustomIM()` to upsert `(code: "custom", title: "自建", keyboard: "lime_cj")` into the `im` table.
- After any import, reload the IM list in §5.1.

---

## 6. Feature: IM Table Editor

**Purpose**: Browse, search, and perform CRUD on the character mapping records of each installed IM (`mapping` tables) and on the cross-IM related-phrase pairs (`related` table). Corresponds to Android's `ManageImFragment` and `ManageRelatedFragment`.

### 6.1 Mapping Record List — RecordListView

Reached via NavigationLink from §5.2 ("瀏覽 / 編輯對應表").

```
NavigationStack (continued)
└── RecordListView(table: String)
    ├── .searchable(text: $query, prompt: "搜尋")
    ├── Picker "" segmented: ["字根", "文字"]   // search-by selector
    ├── List
    │   └── ForEach records (page of 100)
    │       ├── HStack
    │       │   ├── Text(record.code).monospaced
    │       │   ├── Spacer()
    │       │   ├── Text(record.word)
    │       │   └── Text("\(record.score)").secondary.caption
    │       └── .swipeActions(edge: .trailing) {
    │           Button("刪除", role: .destructive) → confirmAlert → db.removeRecord
    │           Button("編輯")                     → sheet: EditRecordView
    │       }
    └── HStack "pagination bar" {
        Button("‹ 上頁")   .disabled(page == 0)
        Spacer()
        Text("第 \(page+1) 頁 / 共 \(totalRecords) 筆")
        Spacer()
        Button("下頁 ›")   .disabled(isLastPage)
    }
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(systemImage: "plus") → sheet: AddRecordView
    }
}
.navigationTitle(im.label)
```

**Pagination**: 100 records per page (Android `LIME.IM_MANAGE_DISPLAY_AMOUNT`). Changing page or query resets to page 0.

**Search modes**:
- **字根**: prefix match on `code` column.
- **文字**: contains match on `word` column.

#### 6.1.1 AddRecordView (sheet) — Equivalent to `ManageImAddDialog`

```
Form
├── Section "新增對應"
│   ├── TextField "字根 (code)"
│   ├── TextField "文字 (word)"
│   └── Stepper "分數: \(score)"   in: 0...9999, step: 1; default: 0
└── Section
    └── Button "確認新增" → guard !code.isEmpty && !word.isEmpty
                          → db.addRecord(table:code:word:score:)
                          → dismiss
```

#### 6.1.2 EditRecordView (sheet) — Equivalent to `ManageImEditDialog`

```
Form
├── Section "編輯對應"
│   ├── TextField "字根"  binding: code
│   ├── TextField "文字"  binding: word
│   └── HStack "分數" {
│       Button("−") → score = max(0, score - 1)
│       Text("\(score)").frame(minWidth: 40)
│       Button("+") → score += 1
│   }
├── Section
│   └── Button("儲存") → confirmAlert → db.updateRecord(id:code:score:word:) → dismiss
└── Section
    └── Button("刪除", role: .destructive) → confirmAlert → db.removeRecord(id:) → dismiss
```

Validation on Save: code and word must not be empty.

### 6.2 Related Phrase List — RelatedListView (關聯字 Tab)

The **關聯字** tab hosts the full-screen related-phrase editor. Equivalent to Android's `ManageRelatedFragment`.

```
NavigationStack
└── RelatedListView
    ├── .searchable(text: $query, prompt: "搜尋詞彙")
    ├── List
    │   └── ForEach relatedList (page of 100)
    │       ├── HStack { Text(r.word).bold, Spacer(), Text(r.related).secondary }
    │       └── .swipeActions(edge: .trailing) {
    │           Button("刪除", role: .destructive) → confirmAlert → db.removeRelated
    │           Button("編輯")                     → sheet: EditRelatedView
    │       }
    └── HStack "pagination bar"  (same pattern as §6.1)
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(systemImage: "plus") → sheet: AddRelatedView
    }
}
.navigationTitle("關聯字管理")
```

**Pagination**: 100 per page; search resets to page 0.

**Search**: prefix / contains match on `word` column.

#### 6.2.1 AddRelatedView (sheet) — Equivalent to `ManageRelatedAddDialog`

```
Form
├── Section "新增關聯字"
│   ├── TextField "詞彙 (word)"
│   └── TextField "關聯詞 (related)"
└── Section
    └── Button("新增") → guard both non-empty → db.addRelated(word:related:) → dismiss
```

#### 6.2.2 EditRelatedView (sheet) — Equivalent to `ManageRelatedEditDialog`

```
Form
├── Section "編輯關聯字"
│   ├── TextField "詞彙"    binding: word
│   └── TextField "關聯詞"  binding: related
├── Section
│   └── Button("儲存", role .none)        → confirmAlert → db.updateRelated → dismiss
└── Section
    └── Button("刪除", role: .destructive) → confirmAlert → db.removeRelated → dismiss
```

---

## 7. Feature: DB Manager (資料 Tab)

**Purpose**: Backup the entire `lime.db` file and restore from a previous backup. Corresponds to the backup/restore buttons in Android's `SetupImFragment`.

### 7.1 Layout

```
NavigationStack
└── List
    ├── Section "備份"
    │   ├── Button "備份資料庫"
    │   │   → db.exportDB(to: tempPath)
    │   │   → ShareLink / UIActivityViewController (Files, AirDrop, Mail…)
    │   └── Text "備份包含所有字根、關聯字及偏好設定。"
    │         .font(.footnote).foregroundColor(.secondary)
    ├── Section "還原"
    │   ├── Button "還原資料庫"
    │   │   → confirmAlert("還原後目前所有資料將被取代，確定繼續？")
    │   │   → fileImporter([.item])   // pick .db / .limedb
    │   │   → performRestore(url:)
    │   └── Text "還原後鍵盤將重新載入資料庫。"
    │         .font(.footnote).foregroundColor(.secondary)
    └── Section "狀態" (visible when statusMessage non-empty)
        └── Text(statusMessage).font(.footnote).foregroundColor(.secondary)
.navigationTitle("資料管理")
```

### 7.2 Backup Behaviour

1. Call `db.exportDB(to: tempPath)` to write a snapshot of `lime.db` to `FileManager.default.temporaryDirectory`.
2. Present via `ShareLink(item: URL(fileURLWithPath: tempPath))` (SwiftUI) or `UIActivityViewController` (UIKit bridge) so the user can save to Files, send via AirDrop, etc.
3. Clean up temp file after the share sheet is dismissed.

### 7.3 Restore Behaviour

1. Show a **confirmation alert** before proceeding: "還原後目前所有資料將被取代，確定繼續？".
2. On confirm, open a `.fileImporter` restricted to `.item` (to pick `.db` / `.limedb` files).
3. On file selection:
   a. Stop any in-flight DB access (notify keyboard extension via App Group flag if needed).
   b. Copy the picked file over `lime.db` in the App Group container.
   c. Re-open the DB connection and verify integrity.
   d. Reload the IM list in §5.1 and the related list in §6.2.
4. Show status: "✅ 資料庫還原完成" or "❌ 還原失敗：\(error)".

### 7.4 Progress Overlay

When backup export or restore copy is running, show a centred `ProgressView` overlay. The operation typically completes in < 1 s, so an overlay is preferable to a progress bar.

---

## 8. Feature: IM Preferences (偏好設定 Tab)

**Purpose**: Replicate all settings from Android's `LIMEPreference` (`preference.xml`). All values persist to `UserDefaults(suiteName: "group.net.toload.limeime")` so the keyboard extension can read them without IPC.

Use `@AppStorage(key, store: UserDefaults(suiteName: "group.net.toload.limeime"))` (aliased as `sharedDefaults` constant) for every value.

### 8.1 Section 鍵盤外觀 (Keyboard Appearance)

| UI Control | Pref Key | Type | Default | Values / Notes |
|---|---|---|---|---|
| `Picker` "鍵盤樣式" | `keyboard_theme` | Int | 0 | 0=淺色 1=深色 2=粉紅 3=科技藍 4=時尚紫 5=放鬆綠 6=系統設定 *(iOS only)* |
| `Toggle` "顯示 Emoji" | `enable_emoji` | Bool | true | |
| `Picker` "Emoji 顯示位置" | `enable_emoji_position` | Int | 3 | 2–10 (position after Nth candidate); disabled when `enable_emoji` = false |
| `Picker` "鍵盤大小" | `keyboard_size` | String | "1.1" | "1.2"=特大 "1.1"=大 "1"=一般 "0.9"=小 "0.8"=特小 |
| `Picker` "顯示方向鍵" | `show_arrow_key` | Int | 0 | 0=無 1=鍵盤上方 2=鍵盤下方 |
| `Toggle` "顯示數字鍵盤" | `display_number_keypads` | Bool | false | Show number row on all keyboards |
| `Picker` "分離鍵盤" | `split_keyboard_mode` | Int | 0 | 0=關閉 1=開啟 2=僅橫向; **iPad only** — hide on iPhone |

> The keyboard extension reads `keyboard_theme` at `viewDidLoad`.
> - Values **0–5**: fixed colour themes regardless of system appearance. 0=淺色, 1=深色, 2=粉紅, 3=科技藍, 4=時尚紫, 5=放鬆綠.
> - Value **6** *(iOS only)*: follows the system Light/Dark appearance (`UITraitCollection.current.userInterfaceStyle`). When the system switches between light and dark the keyboard re-renders accordingly. This value does not exist on Android.

### 8.2 Section 鍵盤回饋 (Keyboard Feedback)

| UI Control | Pref Key | Type | Default | Values / Notes |
|---|---|---|---|---|
| `Toggle` "打字震動" | `vibrate_on_keypress` | Bool | true | |
| `Picker` "震動強度" | `vibrate_level` | Int | 40 | 10=特弱 20=弱 40=中 60=強 80=特強; maps to `UIImpactFeedbackGenerator`: 10–20→`.light`, 40→`.medium`, 60–80→`.heavy` |
| `Toggle` "打字音效" | `sound_on_keypress` | Bool | false | |

> Unlike Android API 31+ (which hides `vibrate_level`), iOS must keep this Picker because `UIImpactFeedbackGenerator` intensity is caller-controlled.

### 8.3 Section 字型與顯示 (Font & Display)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Slider` or `Stepper` "候選字字型大小" | `font_size` | String | "1.1" | Scale string, same values as `keyboard_size`; also exposed as raw `candidateFontSize` Double (14–28 pt) |
| `Toggle` "數字列英文鍵盤" | `number_row_in_english` | Bool | true | Show number row on the English keyboard layout |

### 8.4 Section 輸入法行為 (IM Behaviour)

| UI Control | Pref Key | Type | Default | Values / Notes |
|---|---|---|---|---|
| `Toggle` "智慧組詞" | `smart_chinese_input` | Bool | false | |
| `Toggle` "自動中文標點" | `auto_chinese_symbol` | Bool | false | Show Chinese punctuation candidates when composing buffer is empty |
| `Picker` "選字鍵預選順序" | `selkey_option` | Int | 0 | 0=混打英文優先 1=第一中文優先 2=第二中文優先 |
| `Picker` "電話鍵盤自動上屏" | `auto_commit` | Int | 0 | 0=無 4/5/6/7/8/9/10=Nth stroke auto-commit |
| `Toggle` "滑動選取候選字" | `candidate_switch` | Bool | true | Swipe on candidate bar to commit |

### 8.5 Section 注音鍵盤 (Phonetic Keyboard)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Picker` "鍵盤類型" | `phonetic_keyboard_type` | String | `"standard"` | See options below |

**Phonetic keyboard type options**:

| Value | Display Label |
|---|---|
| `standard` | 標準 |
| `et_41` | 倚天 41 鍵 |
| `eten26` | 倚天 26 鍵 (英文鍵盤) |
| `eten26_symbol` | 倚天 26 鍵 (符號鍵盤) |
| `hsu` | 許氏 (英文鍵盤) |
| `hsu_symbol` | 許氏 (符號鍵盤) |

**Live update**: when this picker value changes, call `db.setIMKeyboard("phonetic", description:, code:)` to update the `im` table immediately (mirrors Android's `onSharedPreferenceChanged` in `LIMEPreference`). Use SwiftUI's `.onChange(of: phoneticKeyboardType)` modifier:

```swift
.onChange(of: phoneticKeyboardType) { newType in
    updatePhoneticKeyboard(type: newType)   // writes im table + refreshes SearchServer
}
```

### 8.6 Section 漢字轉換 (Han Conversion)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Picker` "簡繁轉換" (`.segmented`) | `han_convert_option` | Int | 0 | 0=不轉換 1=繁→簡 2=簡→繁 |
| `Toggle` "轉換提示" | `han_convert_notify` | Bool | true | Show reminder when active conversion mode has been idle > 60 s |

> On iOS, the keyboard extension must implement the 60 s idle reminder as an in-candidate-bar banner (not a system notification — keyboard extensions cannot post those).

### 8.7 Section 關聯字與學習 (Related Phrases & Learning)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Toggle` "啟用關聯字典" | `similiar_enable` | Bool | true | Master switch for related-word display |
| `Picker` "建議字顯示數量" | `similiar_list` | Int | 20 | Options: 0 / 10 / 20 / 30 / 40 / 50 |
| `Toggle` "自動學習關聯字" | `candidate_suggestion` | Bool | true | Gates `learnRelatedPhraseAndUpdateScore()` in `SearchServer` |
| `Toggle` "自動學習新詞" | `learn_phrase` | Bool | true | Gates `addLDPhrase()` / `learnLDPhrase()` |
| `Toggle` "依選取次數排序" | `learning_switch` | Bool | true | Sort candidates by accumulated score |

### 8.8 Section 英文字典 (English Dictionary)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Toggle` "啟用英文建議字" | `english_dictionary_enable` | Bool | true | |

### 8.9 Section 進階 (Advanced)

| UI Control | Pref Key | Type | Default | Notes |
|---|---|---|---|---|
| `Toggle` "字根反查提示" | `reverse_lookup_notify` | Bool | true | Show popup when reverse lookup result is used |
| `Toggle` "記憶中英模式" | `persistent_language_mode` | Bool | false | Keep Chinese/English mode across sessions |

> `accept_number_index` and `accept_symbol_index` are surfaced in §5.2 `IMDetailView` under the "字根對應設定" section, shown only when the custom IM is active (`im.tableNick == "custom"`). They are omitted from here because all built-in IMs hardcode their own number/symbol mapping behaviour.

### 8.10 Section 字根反查 (Reverse Lookup) — Sub-screen

A `NavigationLink` opens a dedicated sub-screen. Configures which IM provides the reverse-lookup annotation for each main IM when no candidate is found.

```
NavigationLink "字根反查設定" → ReverseLookupSettingsView
```

```
ReverseLookupSettingsView
└── Form
    ├── Section "說明"
    │   └── Text "輸入字根無候選字時，以其他輸入法字根標注說明。"
    └── Section "各輸入法反查來源"
        ├── Picker "自建"      pref: custom_im_reverselookup  style: .menu
        ├── Picker "倉頡"      pref: cj_im_reverselookup
        ├── Picker "快倉"      pref: scj_im_reverselookup
        ├── Picker "倉頡五代"  pref: cj5_im_reverselookup
        ├── Picker "速成"      pref: ecj_im_reverselookup
        ├── Picker "大易"      pref: dayi_im_reverselookup
        ├── Picker "注音"      pref: bpmf_im_reverselookup
        ├── Picker "輕鬆"      pref: ez_im_reverselookup
        ├── Picker "行列"      pref: array_im_reverselookup
        ├── Picker "行列 10"   pref: array10_im_reverselookup
        ├── Picker "筆順五碼"  pref: wb_im_reverselookup
        ├── Picker "華象直覺"  pref: hs_im_reverselookup
        └── Picker "拼音"      pref: pinyin_im_reverselookup
```

All pickers default to `"none"`. Available options (matching `im_reverse_lookup_codes`):

| Value | Label |
|---|---|
| `none` | 無 |
| `custom` | 自建 |
| `cj` | 倉頡 |
| `scj` | 快倉 |
| `cj5` | 倉頡五代 |
| `ecj` | 速成 |
| `dayi` | 大易 |
| `phonetic` | 注音 |
| `ez` | 輕鬆 |
| `array` | 行列 |
| `array10` | 行列 10 |
| `wb` | 筆順五碼 |
| `hs` | 華象直覺 |
| `pinyin` | 拼音 |

---

## 9. Preference Key Reference

All stored in `UserDefaults(suiteName: "group.net.toload.limeime")`.

| Pref Key | Android Key | Type | Default |
|---|---|---|---|
| `keyboard_theme` | `keyboard_theme` | Int | 0 |
| `enable_emoji` | `enable_emoji` | Bool | true |
| `enable_emoji_position` | `enable_emoji_position` | Int | 3 |
| `keyboard_size` | `keyboard_size` | String | "1.1" |
| `font_size` | `font_size` | String | "1.1" |
| `candidateFontSize` | *(derived)* | Double | 18 |
| `show_arrow_key` | `show_arrow_key` | Int | 0 |
| `display_number_keypads` | `display_number_keypads` | Bool | false |
| `split_keyboard_mode` | `split_keyboard_mode` | Int | 0 |
| `vibrate_on_keypress` | `vibrate_on_keypress` | Bool | true |
| `vibrate_level` | `vibrate_level` | Int | 40 |
| `sound_on_keypress` | `sound_on_keypress` | Bool | false |
| `number_row_in_english` | `number_row_in_english` | Bool | true |
| `smart_chinese_input` | `smart_chinese_input` | Bool | false |
| `auto_chinese_symbol` | `auto_chinese_symbol` | Bool | false |
| `auto_commit` | `auto_commit` | Int | 0 |
| `selkey_option` | `selkey_option` | Int | 0 |
| `phonetic_keyboard_type` | `phonetic_keyboard_type` | String | "standard" |
| `han_convert_option` | `han_convert_option` | Int | 0 |
| `han_convert_notify` | `han_convert_notify` | Bool | true |
| `reverse_lookup_notify` | `reverse_lookup_notify` | Bool | true |
| `custom_im_reverselookup` | `custom_im_reverselookup` | String | "none" |
| `cj_im_reverselookup` | `cj_im_reverselookup` | String | "none" |
| `scj_im_reverselookup` | `scj_im_reverselookup` | String | "none" |
| `cj5_im_reverselookup` | `cj5_im_reverselookup` | String | "none" |
| `ecj_im_reverselookup` | `ecj_im_reverselookup` | String | "none" |
| `dayi_im_reverselookup` | `dayi_im_reverselookup` | String | "none" |
| `bpmf_im_reverselookup` | `bpmf_im_reverselookup` | String | "none" |
| `ez_im_reverselookup` | `ez_im_reverselookup` | String | "none" |
| `array_im_reverselookup` | `array_im_reverselookup` | String | "none" |
| `array10_im_reverselookup` | `array10_im_reverselookup` | String | "none" |
| `wb_im_reverselookup` | `wb_im_reverselookup` | String | "none" |
| `hs_im_reverselookup` | `hs_im_reverselookup` | String | "none" |
| `pinyin_im_reverselookup` | `pinyin_im_reverselookup` | String | "none" |
| `similiar_list` | `similiar_list` | Int | 20 |
| `similiar_enable` | `similiar_enable` | Bool | true |
| `candidate_switch` | `candidate_switch` | Bool | true |
| `candidate_suggestion` | `candidate_suggestion` | Bool | true |
| `learn_phrase` | `learn_phrase` | Bool | true |
| `learning_switch` | `learning_switch` | Bool | true |
| `english_dictionary_enable` | `english_dictionary_enable` | Bool | true |
| `accept_number_index` | `accept_number_index` | Bool | false |
| `accept_symbol_index` | `accept_symbol_index` | Bool | false |
| `persistent_language_mode` | `persistent_language_mode` | Bool | false |
| `keyboard_state` | `keyboard_state` | String | "0;1;2;3;…;12" |
| `keyboard_list` (active IM) | `keyboard_list` | String | "phonetic" |

---

## 10. iOS Adaptation Notes

### 10.1 Features Not Applicable on iOS

| Android Feature | Reason | iOS Decision |
|---|---|---|
| Entire 外接鍵盤 (External Keyboard) section | iOS does not allow 3rd-party keyboard extensions to intercept physical/Bluetooth keyboard input | **Omit entire section** |
| Google Drive backup | Not available on iOS | **Omit**; use Files / iCloud Drive via `ShareLink` instead |
| `vibrate_level` hidden on Android API 31+ | iOS `UIImpactFeedbackGenerator` is caller-controlled | **Keep as Picker** with intensity mapping |
| System notification bar during DB load | Keyboard extensions cannot post system notifications | **Use in-app `ProgressView` overlay** |
| Android navigation drawer | Platform-specific pattern | **Use `TabView`** + `NavigationStack` |
| `BroadcastReceiver` for IME change | iOS has no equivalent broadcast | **Poll in `scenePhase` `.active` transition** |
| `auto_cap` (首字自動大寫) | iOS provides `textDocumentProxy.autocapitalizationType` per text field — no user toggle needed | **Omit**; keyboard extension reads `autocapitalizationType` directly |

### 10.2 iOS-Only Enhancements

| Feature | Notes |
|---|---|
| Three-state status banner | Real-time green / yellow / red detection on scene activation |
| Split keyboard (iPad-only) | `split_keyboard_mode` row hidden on `UIDevice.current.userInterfaceIdiom == .phone` |
| `ShareLink` backup | Native share sheet for `.db` output |
| `@AppStorage(store:)` | Shared suite ensures keyboard extension reads prefs without IPC |
| `UIImpactFeedbackGenerator` | Maps `vibrate_level` → `.light / .medium / .heavy` style |

### 10.3 Shared UserDefaults

- **Always** use `UserDefaults(suiteName: "group.net.toload.limeime")` — never `UserDefaults.standard`.
- **Never** use `@AppStorage` without the explicit `store:` parameter.
- Preferences are **not** synced via iCloud (`NSUbiquitousKeyValueStore`); that is a future opt-in.

### 10.4 `keyboard_state` Synchronisation

Android stores enabled IM indices as a semicolon-delimited string (`"0;1;2;…"`). On iOS the canonical state is `im.enabled` in the DB, but `keyboard_state` must still be written whenever the user toggles an IM so `KeyboardViewController` can read it the same way. Port `LIMEPreferenceManager.syncIMActivatedState()` to call from the IM list toggle handler.

### 10.5 Han Conversion Idle Notify

Android shows a system notification when the user has been idle > 60 s with an active conversion mode. On iOS, implement this as a subtle text banner inserted into the candidate bar by the keyboard extension (system notifications are not available to keyboard extensions).

---

## 11. Data Persistence and Threading

### 11.1 Database Access

- All DB reads and writes must run on a **background thread** (`DispatchQueue.global(qos: .userInitiated)` or `Task { await … }` with an actor).
- All UI state mutations must occur on the **main thread** (`DispatchQueue.main.async` or `@MainActor`).

### 11.2 DB Open Guard

Every database-touching function should guard on a successful open:

```swift
guard let db = openDB() else {
    errorMessage = "無法開啟資料庫"
    return
}
```

### 11.3 Pagination Constants

| Constant | Value | Used in |
|---|---|---|
| Records per page | 100 | RecordListView (§6.1), RelatedListView (§6.2) |
| `similiar_list` default | 20 | Related-word candidate count (§8.7) |
| `similiar_list` options | 0 / 10 / 20 / 30 / 40 / 50 | Picker in §8.7 |

---

## 12. Feature Parity Checklist

### App Setup (§4)
- [ ] Step-by-step keyboard activation guide
- [ ] Real-time keyboard-enabled status banner (green / yellow / red)
- [ ] Full Access detection
- [ ] "前往系統設定" deep-link button
- [ ] Bundled IM seeding button (`seedDefaultIMs`)
- [ ] App version, licence, GitHub link

### IM Manager — IM List (§5.1)
- [ ] List of installed IMs with enable/disable toggle
- [ ] Toggle persists to `im.enabled` and updates `keyboard_state` preference
- [ ] Drag-to-reorder persists to `im.sortOrder`
- [ ] Enabled / disabled visual distinction (full / half opacity)

### IM Manager — IM Detail & Soft Keyboard (§5.2)
- [ ] IM info: source, version, record count, status
- [ ] Keyboard layout picker (`KeyboardPickerView`)
- [ ] `phonetic_keyboard_type` live update on keyboard change
- [x] "字根對應設定" section with `accept_number_index` / `accept_symbol_index` toggles (shown only when `im.tableNick == "custom"`) — **§13.3 done**

### IM Manager — Download & Import (§5.3)
- [ ] Per-IM `DisclosureGroup` list: 注音, 倉頡, 快倉, 倉頡五代, 速成, 大易, 輕鬆, 行列, 行列 10, 拼音, 華象直覺, 筆順五碼, 自建
- [ ] Cloud download buttons (☁) for each built-in IM; none for 自建
- [ ] `Button "匯入 .limedb"` + `Button "匯入 .cin / .lime"` for every IM row; all named-IM rows use fixed `tableName`
- [x] Each DisclosureGroup contains cloud variant rows + `Button "匯入 .limedb"` + `Button "匯入 .cin / .lime"` with fixed `tableName = family.id` — **§13.3 done**
- [x] 自建 group (no cloud variants) appended to catalog; import calls `seedCustomIM()` after — **§13.3 done**
- [ ] Progress overlay during import / download
- [ ] Status message on completion

### IM Table Editor — Mapping Records (§6.1)
- [ ] Paginated record list (100/page) with pagination bar
- [ ] Search by code (prefix)
- [ ] Search by word (contains)
- [ ] Add record (code + word + score stepper)
- [ ] Edit record (code, word, +/- score)
- [ ] Delete record (swipe action + confirmation)

### IM Table Editor — Related Phrases (§6.2)
- [ ] Paginated related-phrase list (100/page)
- [ ] Search by word
- [ ] Add related phrase (word → related)
- [ ] Edit related phrase
- [ ] Delete related phrase (swipe + confirmation)

### DB Manager (§7)
- [ ] Backup database via share sheet (Files, AirDrop, …)
- [ ] Restore database from file picker (with confirmation alert)
- [ ] Progress overlay during backup / restore

### IM Preferences (§8)
- **Keyboard Appearance** (§8.1): `keyboard_theme` (values 0–5 + **6=系統設定** iOS-only — **§13.2 done**), `enable_emoji`, `enable_emoji_position`, `keyboard_size`, `show_arrow_key`, `display_number_keypads`, `split_keyboard_mode` (iPad)
- **Feedback** (§8.2): `vibrate_on_keypress`, `vibrate_level`, `sound_on_keypress`
- **Font & Display** (§8.3): `font_size`, `number_row_in_english`
- **IM Behaviour** (§8.4): `smart_chinese_input`, `auto_chinese_symbol`, `selkey_option`, `auto_commit`, `candidate_switch`
- **Phonetic Keyboard** (§8.5): `phonetic_keyboard_type` (6 options) with live IM table update
- **Han Conversion** (§8.6): `han_convert_option`, `han_convert_notify`
- **Learning** (§8.7): `similiar_enable`, `similiar_list`, `candidate_suggestion`, `learn_phrase`, `learning_switch`
- **English Dictionary** (§8.8): `english_dictionary_enable`
- ~~**External Keyboard** (§8.9): removed — iOS does not allow 3rd-party extensions to intercept physical keyboard input~~ — **§13.1 done**
- **Advanced** (§8.9): `reverse_lookup_notify`, `persistent_language_mode`
- **Reverse Lookup** (§8.10): Sub-screen with per-IM picker (13 IMs × 14 lookup source options)

---

## 13. TODO

### 13.1 Remove Physical Keyboard Dead Code

iOS does not allow 3rd-party keyboard extensions to intercept physical/Bluetooth keyboard input. The following must be removed:

- `PreferencesTabView.swift`: `@AppStorage` properties `englishDictPhysical`, `hideSwKbWithPhysical`, `physicalKbSort`, `switchEnglishMode`, `switchEnglishModeShift`, `disablePhysicalSelkey` (lines ~53–60) and the entire "外接鍵盤" `Section` block that renders them (lines ~206–216); also remove the `Toggle` "外接鍵盤英文建議字" from the English Dictionary section (line ~206).
- `LIMEPreferenceManager.swift`: properties `disablePhysicalSelkey`, `physicalKeyboardType`, `englishDictPhysicalKeyboard`, `hideSwKbTypingWithPhysical`, `physicalKeyboardSort`, `switchEnglishMode`, `switchEnglishModeShift` (and their getters/setters).
- `LIMEPreferenceManagerTest.swift`: tests `testDefaultSwitchEnglishMode`, `testDefaultSwitchEnglishModeShift`, `testDefaultDisablePhysicalSelkey`.
- `SearchServerTest.swift`: `test_3_3_5_12_updateScoreCache_physical_keyboard_sort_preference` (currently skipped, can be deleted).

### 13.2 Implement `keyboard_theme` Value 6 (系統設定)

Spec §8.1 adds value `6=系統設定` (iOS only). The following code changes are required:

- `PreferencesTabView.swift`: Add `6` to the `keyboard_theme` Picker with label "系統設定". Annotate with a comment that this option is iOS-only and must not be synced back to the Android pref store.
- `KeyboardViewController.swift` (or the theme-application helper): In the function that applies `keyboard_theme`, add a `case 6` branch that reads `UITraitCollection.current.userInterfaceStyle` and maps `.light` → theme 0 (淺色) and `.dark` → theme 1 (深色). Also override `traitCollectionDidChange(_:)` (or use `registerForTraitChanges` on iOS 17+) so the keyboard re-applies the theme automatically when the system appearance changes at runtime.
- `LIMEPreferenceManager.swift`: Update the `getKeyboardTheme()` getter's documentation comment to note that value `6` is valid on iOS only; callers in the keyboard extension must handle it.
- `LIMEPreferenceManagerTest.swift`: Add `testKeyboardThemeSystemValue()` asserting default is `0` and that setting `6` round-trips correctly.

### 13.3 Implement Custom IM (自建輸入法) Support

Android has a "匯入自建輸入法" button in `SetupImFragment` (`btnSetupCustom` / `btnImportCustom` in `ImportDialog`). This flow is missing from the iOS port. The following code changes are required:

- `IMInstallView.swift` (§5.3): Implement the per-IM `DisclosureGroup` list (13 groups: 注音, 倉頡, 快倉, 倉頡五代, 速成, 大易, 輕鬆, 行列, 行列 10, 拼音, 華象直覺, 筆順五碼, 自建). Each built-in IM group has cloud download button(s) + `Button "匯入 .limedb"` + `Button "匯入 .cin / .lime"`, all with fixed `tableName` from the group's IM code. The 自建 group has only the two local import buttons (no cloud); on file selection call the respective import function with `tableName = "custom"`, then call `db.seedCustomIM()`. No separate screen needed.
- `IMDetailView.swift` (§5.2): Add a "字根對應設定" `Section` rendered only when `im.tableNick == "custom"`, containing `Toggle "數字字根對應"` (`accept_number_index`) and `Toggle "符號字根對應"` (`accept_symbol_index`). All built-in IMs skip this section.
- `LimeDB.swift`: Add `seedCustomIM()` that inserts the custom IM `im` row if absent (separate from `seedDefaultIMs` since custom IM requires explicit user action).
- `LIMEPreferenceManager.swift`: No change needed — `getAllowNumberMapping()` and `getAllowSymbolMapping()` already read `accept_number_index` / `accept_symbol_index` from the shared suite.
