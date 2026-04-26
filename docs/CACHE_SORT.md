# Cache, Prefetch & Sort Implementation

## Overview

This document describes how `SearchServer` (Android and iOS) manages the candidate
mapping cache, pre-warms it via prefetch, and keeps candidate order up to date after
a user selection.  It also lists the preference keys that control sort behaviour.

---

## 1. Cache Structure

### Android (`SearchServer.java`)

| Field | Type | Purpose |
|---|---|---|
| `cache` | `ConcurrentHashMap<String, List<Mapping>>` | Main mapping cache keyed by `cacheKey(code)` |
| `engcache` | `ConcurrentHashMap<String, List<Mapping>>` | English suggestions |
| `emojicache` | `ConcurrentHashMap<String, List<Mapping>>` | Emoji lookups |
| `keynamecache` | `ConcurrentHashMap<String, String>` | Key display name mapping |
| `coderemapcache` | `ConcurrentHashMap<String, List<String>>` | Remapped-code alias lists |

Cache key format (`cacheKey()`):
- Soft keyboard: `tableName + [phoneticKeyboardType] + code`
- Physical keyboard: `physicalKeyboardType + tableName + [phoneticKeyboardType] + code`

No size cap — grows unbounded until `initialCache()` or process restart.

### iOS (`SearchServer.swift`)

| Field | Type | Purpose |
|---|---|---|
| `mappingCache` | `[String: [Mapping]]` | Main mapping cache |
| `relatedCache` | `[String: [Mapping]]` | Related phrases |
| `englishCache` | `[String: [Mapping]]` | English suggestions |
| `emojiCache` | `[String: [Mapping]]` | Emoji lookups |
| `keynameCache` | `[String: String]` | Key display names |
| `coderemap` | `[String: [String]]` | Remapped-code alias lists |

Cache key format: `"\(tableName):\(lowercasedCode):\(limit)"` — two variants per code:
`limit=50` (default) and `limit=210` (getAllRecords).

Size cap: 1024 entries per map — full eviction when exceeded (`evictIfNeeded()`).

All reads and writes to `mappingCache`, `relatedCache`, and `blacklistCache` are
protected by `cacheLock` (NSLock), making iOS fully thread-safe.  Android uses
`ConcurrentHashMap` for map-level safety but the `List<Mapping>` values inside are
plain `ArrayList` — mutations during in-memory re-sort are not locked against
concurrent reads (see §4).

---

## 2. Cache Lifetime

The cache is designed as a **within-composition buffer**.  Its primary purpose is:

1. Serving backspace/re-type of the same prefix without a DB round-trip
2. Powering `makeRunTimeSuggestion` sub-queries (remaining-code lookups) cheaply
3. Serving prefetched single-char codes on the first keystroke of any word

### Android: also cross-composition for exact-match selections

Android additionally keeps exact-match cache entries **alive across selections** by
updating the in-memory list in place (see §4).  This means typing `im` after
previously selecting 二 may still be a cache hit, with the updated order already
applied.  This design originates from the era of slow eMMC flash; on modern hardware
the benefit is marginal.

### iOS: evict-on-selection only

iOS always evicts the cache entry after selection (see §4).  The next composition
for the same code fetches from DB, which returns correctly ordered results by SQL
`ORDER BY`.  One extra DB query per composition, negligible on modern hardware.

---

## 3. Prefetch

Both platforms warm the cache for single-character keys immediately after a table
switch, so the first keystroke of any word is served from cache.

### Android (`prefetchCache()`)

- Triggered by `setTableName()` **only when** `cache.get("a") == null` (no existing cache)
- Runs in a raw background `Thread`
- Keys: `a–z` (no `q`), optionally `0–9` and `,./;` based on IM capabilities
- No abort if table changes mid-run

### iOS (`triggerPrefetch()`)

- Triggered by `setTableName()` **always** — cancels any previous prefetch thread first
- Runs in a raw `Thread` with `.background` QoS
- Keys: same as Android (`a–z` no `q`, optionally `0–9`, `,./;`)
- Aborts mid-run if `currentTableName` changes — prevents stale cache population

---

## 4. Score Update & Sorting After Selection

Called from `LIMEService` / `KeyboardViewController` when user commits a candidate:
`learnRelatedPhraseAndUpdateScore(mapping)`.

### Android (`updateScoreCache()`)

Runs in a **background thread** (raw `Thread`).  Behaviour depends on record type:

| Case | Action |
|---|---|
| Related-list selection (`id == null` or `isPartialMatchToCodeRecord`) | `cache.remove(cacheKey)` — full eviction |
| Exact-match selection + sort pref **on** | Score +1 in-memory; bubble-shift item up to correct sorted position; call `updateSimilarCodeCache()` |
| Exact-match selection + sort pref **off** | Score +1 in-memory only; no reorder; call `updateSimilarCodeCache()` |
| Code not in cache | `removeRemappedCodeCachedMappings(code)` |

DB is always updated first via `dbadapter.addScore()` (updates all rows matching the word with `score+1`).

**Threading note**: The `List<Mapping>` inside `ConcurrentHashMap` is a plain
`ArrayList`.  The background thread mutates it (remove + add for re-sort) while the
UI thread may be reading it concurrently.  This is a known race condition inherited
from the original 2011 design.

### iOS (`learnRelatedPhraseAndUpdateScore()`)

Runs on `DispatchQueue.global(qos: .background)` — all cache operations guarded by
`cacheLock`.

| Case | Action |
|---|---|
| `candidate.id > 0` (exact match) | DB `updateScore()` → `removeRemappedCodeCachedMappings()` → `updateSimilarCodeCache()` |
| `candidate.id == 0` (related / runtime) | No cache change (nothing to evict) |

No in-memory re-sort — sorting is delegated entirely to SQLite `ORDER BY score DESC,
basescore DESC` on the next cache-miss query.

---

## 5. Cache Invalidation Rules

### `removeRemappedCodeCachedMappings(code)`

Removes all cache entries for `code` and any codes aliased to it via `coderemapcache`
/ `coderemap`.

- Android: removes the single cache key for `code` and each alias
- iOS: removes 3 key variants per code (`base`, `base:50`, `base:210`) to cover both
  limit flavours; all under `cacheLock`

### `updateSimilarCodeCache(code)`

Cascades invalidation up the prefix chain to keep shorter-code result lists coherent
after a score change.  For `code` of length N (capped at 5):

- Removes cached entries for `code[0..N-1]`, `code[0..N-2]`, … down to length 1
- Each prefix removal also calls `removeRemappedCodeCachedMappings` on that prefix

Example: selecting 二 under code `"im"` also busts the cache for `"i"`.

After eviction, iOS re-warms **all evicted entries** on the same background thread
(already running for the score update), guarded by a table-snapshot check:

- `candidate.code` itself (e.g., `"im"`) — always re-queried
- Every prefix code that was actually present in cache and removed by the loop
  (e.g., `"i"`) — re-queried only if it was in cache

`updateSimilarCodeCache()` now returns the list of actually-evicted prefix codes so
the caller can re-warm them without an extra dispatch hop.

This effectively mirrors Android's cross-composition cache survival, but with a
correctness advantage: the re-queried results reflect the **updated DB score order**
rather than Android's in-memory bubble-shift approximation.

---

## 6. `getMappingByCode` — Public API and Internal Design

`getMappingByCode` is the **only public method** for fetching candidates.  All
callers — keyboard controllers, prefetch threads, post-selection re-warm — go through
this single entry point.  **Caching is entirely an internal implementation detail**;
callers are not aware of whether a result came from cache or DB.

`getMappingByCodeFromCacheOrDB` is **private** — it exists solely to let
`makeRunTimeSuggestion` do remaining-code sub-queries without triggering the full
pipeline recursively.  It must never be called from outside `SearchServer`.

### Public callers of `getMappingByCode`

| Caller | Platform | Notes |
|---|---|---|
| `LIMEService` (user typing) | Android | Normal composing path; `synchronized` |
| `KeyboardViewController` (user typing) | iOS | Normal composing path |
| `prefetchCache()` — background thread | Android | `prefetchCache=true` suppresses phrase suggestion state update |
| `triggerPrefetch()` — background thread | iOS | Called outside active composition; no flag needed |
| `updateSimilarCodeCache()` — post-eviction re-warm | Android | `prefetchCache=true` to avoid disturbing composition state |
| `learnRelatedPhraseAndUpdateScore()` — post-eviction re-warm | iOS | Re-warms evicted entries on same background thread after score update |

### Private use of `getMappingByCodeFromCacheOrDB`

Used only **inside** `SearchServer` for sub-queries that must not trigger side effects:

| Internal caller | Platform | Reason |
|---|---|---|
| `getMappingByCode` main body — initial raw fetch | Android only | Gets raw candidate list to pass to `makeRunTimeSuggestion`; iOS inlines this cache check directly |
| `makeRunTimeSuggestion` — remaining-code lookup | Both | Avoids re-entrant phrase suggestion logic and (on Android) `synchronized` contention |

---

## 7. Preference Keys

_See also §4 for how each platform reads and applies these prefs._

| Pref key | Android method | iOS property | Default | Effect |
|---|---|---|---|---|
| `learning_switch` | `getSortSuggestions()` | `learningSwitch` / `sortSuggestions` | `true` | **Soft keyboard**: enable score-based candidate ordering |
| `physical_keyboard_sort` | `getPhysicalKeyboardSortSuggestions()` | **Not implemented** | `true` | **Physical keyboard** (Android only): enable score-based ordering |

### UI Labels

| Pref key | Android title | Android summary | iOS label |
|---|---|---|---|
| `learning_switch` | 啟動選取排序 | 依選取次數排序選字清單 | 啟動選取排序 |
| `physical_keyboard_sort` | 啟動實體鍵盤選取排序 | 使用實體鍵鍵時依選取次數排序選字清單 | — |

### How each platform applies the pref

**Android**: checked inside `updateScoreCache()` at the re-sort step.
- `sort=true` → bubble-shift item in cached list
- `sort=false` → update score in-memory only, no reorder

**iOS**: applied by `applyPrefsToDatabase()` which sets `LimeDB.sortSuggestions`.
- `sortSuggestions=true` → SQL query includes `ORDER BY score DESC, basescore DESC`
- `sortSuggestions=false` → SQL query uses DB insertion order

`KeyboardViewController` reads `"learning_switch"` from shared defaults and pushes
it to `searchServer?.sortSuggestions` via `loadSettings()` on every keyboard activation.

### Gap: `physical_keyboard_sort` on iOS

iOS has no equivalent for `physical_keyboard_sort`.  It uses `learning_switch` /
`sortSuggestions` for all keyboard types.  This is acceptable because iOS physical
keyboard support is minimal compared to Android.

---

## 8. Summary: Android vs iOS Design Trade-offs

| | Android | iOS |
|---|---|---|
| Cache survives across compositions | ✓ Yes (exact-match entries kept alive) | ✓ Yes (evicted then re-warmed in background with updated DB order) |
| Thread safety of cache mutation | ✗ Race on `List<Mapping>` during re-sort | ✓ All mutations under `cacheLock` |
| Sorting mechanism | In-memory bubble-shift after selection | SQLite `ORDER BY` on next cache-miss |
| Sort pref effect | Gates the re-sort step | Gates the `ORDER BY` clause |
| Physical keyboard sort pref | Separate pref `physical_keyboard_sort` | Not implemented (uses same pref) |
| Prefetch robustness | No abort on table change | Aborts if table changes mid-prefetch |
| Cache size limit | Unbounded | 1024 entries per map |

The iOS design is simpler, thread-safe, and correct.  The one extra DB query per
composition after a selection is negligible on modern hardware.  The Android design
avoids that DB query at the cost of complexity and a threading race inherited from its
original 2011 implementation on slow eMMC devices.

---

## 9. TODO: Refactor Android to Match iOS Evict-and-Re-warm Pattern

Android's current post-selection cache update (in `updateScoreCache`) keeps the
exact-match cache entry alive by doing an in-memory bubble-sort of the `ArrayList`
on a background thread.  This causes a known race condition and produces an
approximated sort order.  The iOS approach — evict then re-query DB on the same
background thread — is simpler, thread-safe, and always reflects the true DB order.

### What to change in `SearchServer.java`

**1. Replace in-memory re-sort with eviction in `updateScoreCache()`**

Remove the bubble-shift loop for exact-match entries.  Instead, call
`removeRemappedCodeCachedMappings(code)` to evict, then let
`updateSimilarCodeCache(code)` handle prefix eviction — same as the related-list
case already does today.

```java
// Current (remove):
if (sort) {
    // bubble-shift cachedList ...
} else {
    // score bump in-memory only ...
}

// Replacement:
cache.remove(cachekey);  // evict; DB has the updated score already
```

**2. Re-warm all evicted entries after eviction in `updateSimilarCodeCache()`**

Change `updateSimilarCodeCache` to return the list of actually-evicted prefix codes
(mirroring the iOS change), then re-query each one via
`getMappingByCode(code, ..., prefetchCache=true)` on the same background thread.
Always re-query `candidate.code` itself as well.

```java
// After the eviction loop and existing single-char re-prefetch:
getMappingByCode(code, !isPhysicalKeyboardPressed, false, true); // re-warm selected code
for (String prefix : evictedPrefixes) {
    getMappingByCode(prefix, !isPhysicalKeyboardPressed, false, true);
}
```

**3. Remove the threading race**

The above changes eliminate all `ArrayList` mutations on the background thread, so
no lock is needed.  The `ConcurrentHashMap` already handles concurrent `put`/`remove`
safely at the map level.

### Expected outcome after refactor

| | Android (current) | Android (after refactor) |
|---|---|---|
| Cache mutation on background thread | Mutates `ArrayList` (race) | Only `ConcurrentHashMap.remove` + `put` (safe) |
| Sort correctness | Approximate (in-memory bubble-shift) | Exact (DB `ORDER BY`) |
| Cross-composition cache | ✓ kept alive in-memory | ✓ evicted then re-warmed from DB |
| Code complexity | High | Same as iOS |

### Test impact

**Android `SearchServerTest.java`** — one test must be updated:

- `test_3_3_5_2_updateScoreCache_exact_match_reordering` (line 1866): currently asserts
  that after `updateScoreCache`, the cache list is still present and the selected item
  has been bubble-shifted to the correct position with score incremented to 6.  After
  refactor the cache entry is evicted entirely, so `cache.get("customab")` returns
  `null`.  The test should instead assert that the entry is absent from cache (evicted)
  and that `stub.addScoreCalled == true`.

The following tests remain valid unchanged:
- `test_3_3_4_1_updateSimilarCodeCache_drops_prefix_entries` — eviction still happens
- `test_3_3_4_2_updateSimilarCodeCache_prefetch_single_char` — single-char re-warm still triggered
- `test_3_3_4_3_updateSimilarCodeCache_remote_exception` — exception handling path unchanged
- `test_3_3_5_1_updateScoreCache_learning_invalidation` — only asserts `addScoreCalled`

**iOS `SearchServerTest.swift`** — `updateSimilarCodeCache`, `updateScoreCache`, and
`prefetchCache` tests are all marked `SKIPPED` (lines 282–285) since they are private
methods that were tested via Java reflection on Android and are not portable to Swift.
No iOS test changes required.

The 4 `learnRelatedPhraseAndUpdateScore` tests (lines 851–893) do call the method but
are **smoke tests only** — all assert `XCTAssertTrue(true)` with no cache-state
assertions.  The new re-warm logic in `learnRelatedPhraseAndUpdateScore` and
`updateSimilarCodeCache` is therefore untested at assertion level on iOS.

**Recommended new iOS tests to add:**

- After `learnRelatedPhraseAndUpdateScore(m)` with `m.id > 0`, assert that
  `getMappingByCode(m.code)` returns a non-empty list (cache was re-warmed, not just
  evicted)
- After selecting from code `"im"`, assert that `getMappingByCode("i")` returns a
  non-empty list (single-char prefix was re-warmed)
- Assert that `getMappingByCode(m.code)` called immediately after
  `learnRelatedPhraseAndUpdateScore` does not return stale order (score of selected
  word is highest)
