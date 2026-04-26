# Plan: Fix LD Learning Path (RP-triggered branch broken)

## Summary

`postFinishInput()` in [SearchServer.swift](LimeIME-iOS/Shared/Search/SearchServer.swift) snapshots `ldPhraseListArray` **before** dispatching the background task, then runs `learnRelatedPhrase()` inside that task. Because `learnRelatedPhrase()` calls `addLDPhrase()` for high-score RP pairs (score > 20), those additions land in `ldPhraseListArray` **after** the snapshot — they are never passed to `learnLDPhraseList()` and are silently dropped.

The continuous-typing LD path is unaffected (those phrases are buffered before `postFinishInput` is called). Only the RP-triggered LD learning path is broken.

## Root Cause

### iOS (broken)
```
postFinishInput():
  1. snapshot ldPhraseListArray → localLD  ← too early
  2. clear ldPhraseListArray
  3. background {
       learnRelatedPhrase()               ← writes to ldPhraseListArray
       learnLDPhraseList(localLD)         ← misses RP-triggered additions
     }
```

### Android (correct) — SearchServer.java lines 1248–1259
```
background thread:
  1. learnRelatedPhrase(snapshot)         ← writes to LDPhraseListArray
  2. snapshot LDPhraseListArray → local   ← captures RP additions
  3. clear LDPhraseListArray
  4. learnLDPhrase(local)                 ← processes everything
```

## Requirements

Two independent LD accumulation paths must both reach `learnLDPhraseList`:

- **Path 1 — Continuous-typing** (score-independent): `commitCandidate()` calls `addLDPhrase(ending:false)` for each intermediate pick and `addLDPhrase(ending:true)` on the final pick (based solely on whether composing code remains — `composingNotFinish`). These phrases are committed to `ldPhraseListArray` **before** `postFinishInput` is called and must still be processed.
- **Path 2 — RP-triggered** (score-gated): `learnRelatedPhrase()` calls `addLDPhrase` for high-score RP pairs (score > 20). These additions land in `ldPhraseListArray` **during** the background task — after the current iOS snapshot — and are silently dropped. This is the broken path.
- No new thread-safety issues introduced.

## Acceptance Criteria

1. After `postFinishInput()`, `learnLDPhraseList` receives **both** continuous-typing phrases AND RP-triggered phrases.
2. `ldPhraseListArray` is empty after `postFinishInput()` completes its background work.
3. Existing unit tests for `addLDPhrase` / `learnLDPhrase` / `postFinishInput` still pass.

## Implementation — Single File Change

**File**: [LimeIME-iOS/Shared/Search/SearchServer.swift](LimeIME-iOS/Shared/Search/SearchServer.swift)  
**Function**: `postFinishInput()` (lines 793–810)

**Change**: Snapshot `ldPhraseListArray` for continuous-typing LD phrases before the task (as now), but take a **second snapshot** inside the background task after `learnRelatedPhrase()` returns to capture RP-triggered additions. Merge both snapshots into a single `learnLDPhraseList` call.

```swift
func postFinishInput() {
    scorelistLock.lock()
    let snapshot = scorelist
    scorelist.removeAll()
    scorelistLock.unlock()

    // Snapshot continuous-typing LD phrases accumulated so far.
    learnLock.lock()
    let continuousLD = ldPhraseListArray
    ldPhraseListArray = []
    learnLock.unlock()

    DispatchQueue.global(qos: .background).async { [weak self] in
        guard let self = self else { return }
        // learnRelatedPhrase runs first — may call addLDPhrase for high-score RP pairs.
        // Mirrors Android postFinishInput ordering (lines 1250–1259).
        self.learnRelatedPhrase(snapshot)
        // Snapshot RP-triggered LD phrases added by learnRelatedPhrase.
        self.learnLock.lock()
        let rpLD = self.ldPhraseListArray
        self.ldPhraseListArray = []
        self.learnLock.unlock()
        self.learnLDPhraseList(continuousLD + rpLD)
    }
}
```

## Test Hook Required

`ldPhraseListArray` is private with no existing test hook. Add one to the test-hooks section of [SearchServer.swift](LimeIME-iOS/Shared/Search/SearchServer.swift) (after line 1231):

```swift
internal var _testLdPhraseListArray: [[Mapping]] { ldPhraseListArray }
```

## New Tests — `SearchServerTest.swift`

### `test_3_2_6_5_postFinishInput_path1_drained`

Verifies path-1 phrases (pre-seeded before `postFinishInput`) are consumed.

```swift
func test_3_2_6_5_postFinishInput_path1_drained() throws {
    let ss = try makeSearchServer()
    ss.setTableName(LIME.DB_TABLE_DAYI, hasNumberMapping: false, hasSymbolMapping: false)
    let m1 = Mapping(id: 1, code: "a",  word: "蘋", score: 0, baseScore: 0,
                     recordType: .exactMatchToCode)
    let m2 = Mapping(id: 2, code: "go", word: "果", score: 0, baseScore: 0,
                     recordType: .exactMatchToCode)
    ss.addLDPhrase(m1, ending: false)
    ss.addLDPhrase(m2, ending: true)   // phrase committed to ldPhraseListArray
    XCTAssertEqual(ss._testLdPhraseListArray.count, 1, "one phrase pending before postFinishInput")
    ss.postFinishInput()
    // Wait for background task
    Thread.sleep(forTimeInterval: 0.3)
    XCTAssertTrue(ss._testLdPhraseListArray.isEmpty, "array must be empty after postFinishInput")
}
```

### `test_3_2_6_6_postFinishInput_path2_drained`

Verifies RP-triggered LD phrases added *inside* `learnRelatedPhrase` (path-2) are also consumed and not left in `ldPhraseListArray`.

```swift
func test_3_2_6_6_postFinishInput_path2_drained() throws {
    let ss = try makeSearchServer()
    ss.setTableName(LIME.DB_TABLE_DAYI, hasNumberMapping: false, hasSymbolMapping: false)
    // Seed scorelist with two mappings that have a pre-existing RP score > 20
    // so learnRelatedPhrase will call addLDPhrase internally.
    // Use learnRelatedPhraseAndUpdateScore twice to populate scorelist.
    let m1 = Mapping(id: 1, code: "a",  word: "蘋", score: 25, baseScore: 10,
                     recordType: .exactMatchToCode)
    let m2 = Mapping(id: 2, code: "go", word: "果", score: 25, baseScore: 10,
                     recordType: .exactMatchToCode)
    ss.learnRelatedPhraseAndUpdateScore(m1)
    ss.learnRelatedPhraseAndUpdateScore(m2)
    Thread.sleep(forTimeInterval: 0.1)  // let scorelist accumulate
    // No path-1 phrases — ldPhraseListArray starts empty
    XCTAssertTrue(ss._testLdPhraseListArray.isEmpty)
    ss.postFinishInput()
    Thread.sleep(forTimeInterval: 0.3)
    // Whether or not RP score threshold was met, array must be empty after task
    XCTAssertTrue(ss._testLdPhraseListArray.isEmpty,
                  "RP-triggered addLDPhrase additions must be drained by second snapshot")
}
```

> **Note**: `test_3_2_6_6` asserts the array is drained regardless of whether the score threshold was reached. To assert path-2 *produced* a phrase, seed the RP table with a score > 20 pair in the test DB fixture and check the LD table after the task.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| New content written to `ldPhraseListArray` between the pre-task snapshot and the in-task snapshot | Very low — `viewWillDisappear` has fired; keyboard is dismissed; no more user input | Lock used for both snapshots; even if it occurred, phrases would accumulate for the next session |
| Test suite uses `learnLDPhrase()` public stub that no longer matches real path | Low | `learnLDPhrase()` stub remains unchanged and still works; tests calling it directly are unaffected |

## Verification Steps

1. Build succeeds with no compiler errors.
2. Run `LimeTests` — all existing `test_3_7_*` and `test_3_2_6_*` tests pass.
3. Manual: type two characters with the same IM that share a high RP score, dismiss keyboard → re-open → the phrase should appear as a learned candidate.
4. Confirm no regression on continuous-typing LD (type a multi-char sequence without pausing; each commit buffers via `addLDPhrase(ending:false)`; final commit signals `ending:true` → should still be learned).
