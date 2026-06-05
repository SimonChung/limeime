# English Auto-Completion

## Purpose

Track the current iOS English auto-completion implementation, the implemented Android #103 fix, and the planned shared dictionary path.

Goals:

1. Keep exact-match filtering on Android to avoid duplicate candidate items.
2. Show the typed composing word as the only candidate when it is the only exact dictionary match.
3. Never pre-highlight candidates in English composing / auto-completion mode.
4. Move Android English suggestion ordering away from plain alphabetical order.
5. Prepare for replaceable dictionary data and user-learned English frequency.
6. Evaluate unifying iOS and Android English completion on the same dictionary table so learned scores can move across platforms through backup/restore.

## Current iOS Implementation

File: `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`

`updateEnglishPrediction()` uses the platform `UITextChecker` API:

```swift
textChecker.completions(
    forPartialWordRange: range,
    in: word,
    language: "en_US")
```

Current behavior:

- Completion source is iOS built-in English completion, not `lime.db`.
- Returned completions are mapped to `Mapping.RecordType.englishSuggestion`.
- Tapping a completion commits only the untyped suffix plus a space.
- `showCandidates(mappings)` is called without a selected index, so the candidate bar shows no default highlight.
- iOS does not prepend an Android-style composing/self candidate in this path, so it does not have the same duplicate exact-match problem.

Important note:

- `selectedCandidate = mappings.first` is still assigned for commit/navigation logic, but the visual candidate bar receives `selectedIndex = -1`.

## Future iOS Unification Option

After the scored dictionary table exists, iOS should consider using the same `dictionary(word, basescore, score)` source as Android instead of relying only on `UITextChecker`.

Major advantages:

- Same English word source and ranking behavior on iOS and Android.
- Same `basescore` model from the bundled dictionary payload.
- Same user-learned `score` model as Chinese table learning.
- Cross-platform backup/restore can preserve learned English frequency.
- Future dictionary source upgrades happen once for both platforms.

Tradeoffs:

- iOS loses some system-dictionary behavior that may include Apple-specific language model choices.
- `UITextChecker` may have richer language/locale behavior than a simple prefix dictionary.
- The shared dictionary path needs its own iOS query, learning, migration, backup, and restore tests.

Recommended future direction:

1. Keep current `UITextChecker` behavior for the #103 Android fix.
2. Build the DB 105 scored dictionary as a shared main-DB schema, not Android-only.
3. Once shared scoring is available, decide whether iOS should:
   - replace `UITextChecker` completely;
   - use shared dictionary first and `UITextChecker` as fallback;
   - keep `UITextChecker` for display but learn tapped/completed words into the shared `score` table.

## Current Android Implementation

Files:

- `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
- `LimeStudio/app/src/main/java/net/toload/main/hd/candidate/CandidateView.java`

Android uses the bundled `dictionary` table in `lime.db`:

```sql
CREATE VIRTUAL TABLE dictionary USING fts3(word)
```

Previous query:

```sql
SELECT word FROM dictionary
WHERE word MATCH '<typed>*'
AND word <> '<typed>'
ORDER BY word ASC
LIMIT ...
```

Implemented #103 query:

```sql
SELECT word FROM dictionary
WHERE word MATCH '<typed>*'
AND word <> '<typed>'
ORDER BY rowid ASC
LIMIT ...
```

Current list assembly:

```text
[typed composing/self candidate] + [dictionary suggestions]
```

Implemented #103 behavior:

- Exact-match filtering is correct for Android because the composing/self candidate already represents the typed word.
- If the exact word is the only dictionary match, Android now still displays the composing/self candidate alone.
- English composing candidates are displayed with no default visual highlight.
- Ordering now uses existing dictionary row order as the short-term rank signal instead of plain alphabetical order.

Previous alphabetical ordering made `sal*` return proper nouns and alphabetic neighbors before common expected words:

```text
Salem, Salisbury, salaries, salary, sale, sales, sally, salmon, saloon, salt, ...
```

## #103 Android Spec

### Candidate Display

Keep exact-match filtering in the DB query.

If no non-exact suggestions remain but the typed word is valid English composing text, display the composing/self candidate alone:

```text
salt -> [salt]
```

This item is not a dictionary suggestion. It is the typed composing word made tappable/visible.

### Highlight Policy

English composing / auto-completion should always display with no default highlight:

```text
selectedIndex = -1
```

This applies to:

- one-item composing-only lists, such as `[salt]`;
- multi-item English suggestion lists;
- English emoji-injected lists.

Do not change normal Chinese/table IM candidate highlighting or end-key selection behavior.

### Sorting Policy

Android English suggestions should not be sorted by `word ASC` only.

Implemented short-term behavior without new dictionary data:

1. Prefer existing `dictionary.rowid` order.
2. Keep richer frequency/user-score ranking for the DB 105 dictionary design.

Long-term target:

```text
ORDER BY (score + basescore) DESC, word ASC
```

where:

- `basescore` is bundled frequency/rank score.
- `score` is local user-learned frequency.

## Planned Shared Dictionary Architecture

Use an emoji-like payload model instead of baking all English dictionary data into the raw `lime.db` seed.

Planned components:

- bundled `dictionary.db` payload;
- main `lime.db` schema upgrade on Android and iOS;
- dictionary payload version metadata;
- local user-learned score preserved across dictionary refreshes.

Suggested main DB schema:

```sql
CREATE TABLE dictionary (
    word TEXT PRIMARY KEY,
    basescore INTEGER NOT NULL DEFAULT 0,
    score INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX dictionary_word_idx ON dictionary(word);
CREATE INDEX dictionary_score_idx ON dictionary(score + basescore);
```

Prefix lookup can avoid FTS entirely:

```sql
SELECT word
FROM dictionary
WHERE word >= :prefix
  AND word < :prefixUpperBound
  AND word <> :prefix
ORDER BY (score + basescore) DESC, word ASC
LIMIT :limit;
```

Reason to avoid FTS for English prefix completion:

- Android platform SQLite does not reliably support FTS5.
- FTS4 is widely available but still compile-option based.
- Prefix completion does not need full-text token search.
- A normal indexed `word` column avoids the stale virtual-table failure family seen in issue #88.
- The same indexed-prefix query can be shared by Android and iOS.

## Dictionary Source And License

If using `wordfreq` for `basescore`:

- keep the upstream source table and license metadata untouched;
- add the third-party data disclosure to `LICENSE.md`;
- keep the generated dictionary reproducible from a repo script;
- treat generated bundled dictionary frequency data as derived data under the source license terms.

`score` is per-user local learning data. It must not be disclosed publicly, uploaded, or treated as bundled third-party data. If backups include `score`, that is the user's private backup data.

## Upgrade And Restore Requirements

Dictionary upgrade must be schema-driven and idempotent, not only version-driven.

Required behavior:

```text
ensureCurrentDatabase()
  inspect actual dictionary schema

  if old FTS-only dictionary exists:
    preserve any local score if available
    remove old dictionary objects defensively

  create new dictionary table and indexes if missing
  import or refresh bundled dictionary.db basescore data
  restore preserved local score
  set dictionary payload version metadata
  set main DB user_version if schema changed
```

Restore requirements:

- A restored legacy DB may claim a newer `PRAGMA user_version` but still contain old or broken dictionary schema.
- A restored DB may contain old `dictionary` FTS virtual table artifacts.
- The repair path must run after normal open, restore, and factory reset.
- Migration must preserve user-learned English score whenever the old schema has such data.
- Migration must not destroy Chinese IM mapping scores or related phrase learning.
- iOS and Android should use the same schema contract so cross-platform backups do not need special dictionary conversion.

Lesson from #88:

- Do not assume virtual tables can always be dropped normally.
- Avoid FTS for the new English dictionary unless it is truly needed.
- If any virtual table remains in the migration, probe usability and repair by schema state, not by version alone.

## Verification Plan

### iOS

1. Type a partial English word.
2. Confirm iOS completions appear from `UITextChecker`.
3. Confirm no candidate is visually highlighted.
4. Tap a completion and confirm only the untyped suffix plus space is inserted.

### Android Current #103 Behavior

1. Type `salt`.
   - Candidate strip shows one item: `salt`.
   - No candidate is highlighted.
2. Type `year`.
   - No duplicate exact `year` dictionary suggestion appears.
   - No candidate is highlighted.
3. Type `sal`.
   - Suggestions still appear, with `salt` ranked before the previous alphabetical proper-noun results.
   - No candidate is highlighted.
4. Verify normal Chinese/table IM candidates keep their existing default highlight and end-key behavior.

### Shared Future Dictionary Upgrade

1. Fresh install creates/imports the new dictionary schema.
2. Upgrade from old FTS-only `dictionary(word)` creates the new schema.
3. Restore of a legacy DB repairs dictionary schema even if `PRAGMA user_version` is already current.
4. Dictionary payload refresh updates `basescore` and new words without resetting local `score`.
5. Backup/restore preserves local `score`.
6. Cross-platform restore preserves learned English `score` between Android and iOS.
