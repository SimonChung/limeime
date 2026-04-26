# Plan: Remove `seedDefaultIMs()` Dead Code

## TL;DR
`seedDefaultIMs()` is dead code — the bundled `lime.db` is copied directly from Android and has the `im` table fully pre-populated, so the guard `!exists` skips every IM on every call. Remove the function and all 7 call-chain layers across 6 files, plus the UI section that exposes it, plus the 2 unit tests that cover it.

## Files to Modify

- `LimeIME-iOS/Shared/Database/LimeDB.swift` — remove `seedDefaultIMs()` function (lines ~2350–2383)
- `LimeIME-iOS/Shared/Database/DBServer.swift` — remove `seedDefaultIMs()` forwarding wrapper (lines 784–787)
- `LimeIME-iOS/LimeIME/Controllers/SetupImController.swift` — remove both overloads of `seedDefaultIMs()` (lines ~115–155)
- `LimeIME-iOS/LimeIME/Views/SetupTabView.swift` — remove "初始資料庫" Section, `seedDefaultIMs()` private func, `isSeeding`, `seedStatus` state vars
- `LimeIME-iOS/LimeIME/LimeSettingsView.swift` — remove `seedDatabase()` private func + `.onAppear { seedDatabase() }` call; keep `.onAppear` if other logic lives there (it doesn't — confirm)
- `LimeIME-iOS/LimeIMEKeyboard/KeyboardViewController.swift` — remove `try? db.seedDefaultIMs()` call at line 532 (and the comment mentioning it at line 319)
- `LimeIME-iOS/LimeIMETests/SetupImControllerTest.swift` — remove `testSeedDefaultIMsCompletesWithoutError` and `testSeedDefaultIMsCallsRefreshImList` test methods, plus the `// MARK: - seedDefaultIMs` section header

## Steps

### Phase 1 — Core (no callers can exist after this)
1. **LimeDB.swift**: Delete the `seedDefaultIMs()` function body + its leading `// MARK:` comment if it's a dedicated section marker. (The `seedCustomIM` doc-comment references it — update that comment to remove "Unlike seedDefaultIMs" phrasing.)
2. **DBServer.swift**: Delete the `seedDefaultIMs()` forwarding method (lines 784–787).

### Phase 2 — Controller layer
3. **SetupImController.swift**: Delete both overloads:
   - `func seedDefaultIMs(view: (any SetupImView)?)` (UIKit async wrapper, lines ~115–135)
   - `func seedDefaultIMs() async -> Result<String, Error>` (SwiftUI async wrapper, lines ~138–155)
   - Delete the `// MARK: - Seed default IMs` section header(s) between them.

### Phase 3 — UI layer
4. **SetupTabView.swift**:
   - Delete `@State private var seedStatus: String = ""`
   - Delete `@State private var isSeeding = false`
   - Delete the entire `// MARK: Initial DB seeding` Section block (button + status text, lines ~52–67)
   - Delete the `private func seedDefaultIMs()` wrapper (lines ~112–125)
5. **LimeSettingsView.swift**:
   - Delete `private func seedDatabase()` (lines ~78–87)
   - Remove `.onAppear { seedDatabase() }` at line 56 (the `body`'s `.onAppear`; verify no other code is in that closure)

### Phase 4 — Keyboard extension
6. **KeyboardViewController.swift**:
   - Delete `try? db.seedDefaultIMs()` at line 532 (and tidy the adjacent comment if it now reads out of context)
   - Remove the inline comment at line ~319 that mentions seedDefaultIMs

### Phase 5 — Tests
7. **SetupImControllerTest.swift**:
   - Delete `// MARK: - seedDefaultIMs` section header
   - Delete `testSeedDefaultIMsCompletesWithoutError()` test method
   - Delete `testSeedDefaultIMsCallsRefreshImList()` test method

## Verification
1. Build with Xcode — confirm 0 errors (no unresolved `seedDefaultIMs` references)
2. Run remaining tests — confirm no test regressions
3. `grep -r seedDefaultIMs LimeIME-iOS/` → 0 results (excluding any changelog/docs)
4. Manual smoke test: launch app → "設定" tab → confirm "初始資料庫" section is gone; IM list still shows all IMs normally

## Scope / Decisions
- `seedCustomIM()` is **NOT** removed — it's legitimate (seeds on explicit user action even for empty tables)
- The `ManageImController` doc comment at line 27 references `seedDefaultIMs()` — update it to remove that reference
- `ManageImController.swift` line 165 comment ("im.keyboard may store an imkb-style id… set by seedDefaultIMs") — update or delete since seedDefaultIMs is gone, but the underlying resolution logic stays
