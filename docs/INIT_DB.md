# Plan: Replace seedDefaultIMs with restoreBundledDatabase

## TL;DR
seedDefaultIMs() is dead code. The "初始資料庫" button should instead restore the bundled lime.db from Bundle.main, WAL-safely replacing the App Group container copy. This clears all user IMs. New DBServer.restoreBundledDatabase() mirrors the existing restoreDatabase(srcFilePath:) pattern exactly. The main app bundles lime.db via a "Copy lime.db to bundle" build phase (confirmed in project.pbxproj).

## Files to Modify
- LimeIME-iOS/Shared/Database/LimeDB.swift — remove seedDefaultIMs() function
- LimeIME-iOS/Shared/Database/DBServer.swift — remove seedDefaultIMs() forwarder; add restoreBundledDatabase() throws
- LimeIME-iOS/LimeIME/Controllers/SetupImController.swift — remove both seedDefaultIMs() overloads; add restoreBundledDatabase() async
- LimeIME-iOS/LimeIME/Views/SetupTabView.swift — rewire button; inject manageImController
- LimeIME-iOS/LimeIME/LimeSettingsView.swift — remove seedDatabase(); inline seedRelatedIfNeeded on appear
- LimeIME-iOS/LimeIMEKeyboard/KeyboardViewController.swift — remove dead seedDefaultIMs() call + comment
- LimeIME-iOS/LimeIMETests/SetupImControllerTest.swift — delete 2 dead test methods

## Steps

### Phase 1 — New DBServer API
1. DBServer.swift: Add restoreBundledDatabase() throws after restoreDatabase(srcFilePath:):
   - guard Bundle.main.url(forResource: "lime", withExtension: "db") else throw
   - guard datasource else throw
   - ds.holdDBConnection() + closeDatabase()
   - copy bundled to lime.db.restore_tmp (throw on failure); set restoreSucceeded = true
   - defer: unHoldDBConnection -> datasource = nil (WAL checkpoint) -> remove old lime.db/-wal/-shm -> moveItem(tmp to dbURL) -> datasource = try? LimeDB(path:) -> checkAndUpdateRelatedTable()
2. DBServer.swift: Remove seedDefaultIMs() forwarding method (lines 784-787)

### Phase 2 — Remove dead LimeDB method
3. LimeDB.swift: Delete seedDefaultIMs() function (~lines 2350-2383) + MARK comment. Update seedCustomIM() doc-comment to drop "Unlike seedDefaultIMs" phrasing.

### Phase 3 — Controller layer
4. SetupImController.swift: Delete both seedDefaultIMs() overloads (lines ~115-155) + MARK headers.
5. SetupImController.swift: Add restoreBundledDatabase() async -> Result<String, Error>:
   - Same structure as restoreDB(from:) async (~line 200)
   - progress.show("還原預設資料庫...") -> Task.detached { try server.restoreBundledDatabase() } -> progress.dismiss
   - Return .success("已還原預設資料庫") or .failure(error)

### Phase 4 — UI layer
6. SetupTabView.swift:
   - Add @EnvironmentObject private var manageImController: ManageImController
   - Rename private seedDefaultIMs() -> restoreBundledDatabase()
   - Change body to call await setupController.restoreBundledDatabase() + manageImController.invalidate()
   - Update success msg: "已還原預設資料庫", failure: "還原失敗"
   - Keep isSeeding / seedStatus state vars
7. LimeSettingsView.swift:
   - Remove private func seedDatabase()
   - Replace .onAppear { seedDatabase() } with inline Task: await setupController.seedRelatedIfNeeded() + manageRelatedController.invalidate()

### Phase 5 — Keyboard extension cleanup
8. KeyboardViewController.swift: Remove try? db.seedDefaultIMs() at line 532; remove stale comment at ~319.

### Phase 6 — Tests
9. SetupImControllerTest.swift: Delete MARK - seedDefaultIMs header + testSeedDefaultIMsCompletesWithoutError + testSeedDefaultIMsCallsRefreshImList.

### Phase 7 — Comment cleanup
10. ManageImController.swift line 27: update doc comment removing seedDefaultIMs() reference.
11. ManageImController.swift line 165: update inline comment removing seedDefaultIMs reference.

## Verification
1. Build — 0 errors
2. Run tests — no regressions
3. grep -r seedDefaultIMs LimeIME-iOS/ -> 0 results
4. Smoke test: tap "初始資料庫" button -> progress HUD shows -> IM list resets to bundled defaults -> user-added IMs gone

## Decisions
- seedCustomIM() NOT touched
- LimeDB.restoredToDefault() NOT used (only resets scores, doesn't clear im rows)
- restoreBundledDatabase() replaces the whole DB file (im table included) -> all user-added IMs gone
- No new unit tests added
