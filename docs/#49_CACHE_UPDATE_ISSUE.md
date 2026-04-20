# Cache, Prefetch & Sort Implementation

## TODO: Refactor Android to Match iOS Evict-and-Re-warm Pattern

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
