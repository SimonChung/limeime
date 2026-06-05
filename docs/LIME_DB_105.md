# LimeIME DB 105 Upgrade — Scored English Dictionary Schema

## Purpose

Define the concrete DB-schema upgrade from version **104** to **105** that replaces the
legacy FTS-only `dictionary(word)` table with a scored, indexed prefix dictionary shared
by Android and iOS.

This is the schema/upgrade companion to [ENG_AUTO_COMPLETION.md](ENG_AUTO_COMPLETION.md)
and [#103_ISSUE.md](#103_ISSUE.md). Those docs cover the user-facing candidate behavior;
this doc covers only how the database is migrated to 105 and how the bundled dictionary
payload is delivered.

## Goals

1. Bump the main-DB schema version from 104 to 105 on both platforms.
2. Replace `CREATE VIRTUAL TABLE dictionary USING fts3(word)` with a plain indexed table
   `dictionary(word, basescore, score)`.
3. Deliver bundled `basescore` data via an emoji-style payload (`dictionary.db`) instead
   of baking all English words into the raw `lime.db` seed.
4. Preserve per-user learned `score` across dictionary-payload refreshes and across
   backup/restore (Android ↔ iOS).
5. Make the upgrade **schema-driven and idempotent**, so a restored legacy DB that already
   claims `PRAGMA user_version = 105` is still repaired if its actual schema is wrong
   (lesson from #88).

## Current state (version 104)

### Android

`LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`

- Version constant: `private final static int DATABASE_VERSION = 104;` (line 122).
- Helper wiring: `super(context, LIME.DATABASE_NAME, DATABASE_VERSION);` (line 411).
- Upgrade ladder lives in `onUpgrade(SQLiteDatabase dbin, int oldVersion, int newVersion)`
  (line 663) as a chain of `if (oldVersion < N) { ... }` blocks (102 → wb/hs keyboard
  rows, 103 → `createEmojiTables`, 104 → `ensureCj4Schema`).
- Defensive re-check runs in the open path: after `getWritableDatabase()` (line 871) the
  code calls `refreshEmojiDataIfNeeded()` (line 885) and bumps `db.setVersion(...)` when
  `db.getVersion() < DATABASE_VERSION` (lines 882–883).
- English query today (line 4909):

  ```sql
  SELECT word FROM dictionary
  WHERE word MATCH '<typed>*' AND word <> '<typed>'
  ORDER BY rowid ASC LIMIT <similarSize>;
  ```

### iOS

`LimeIME-iOS/Shared/Database/LimeDB.swift`

- Version constant: `private static let CURRENT_DB_VERSION = 104` (line 149).
- Upgrade ladder in `upgradeIfNeeded(_ db:)` (line 230) mirrors Android with
  `if version < N` blocks, then stamps `PRAGMA user_version = CURRENT_DB_VERSION`
  (line 290).
- Defensive re-check in `ensureCurrentDatabase()` (line 301) runs idempotent schema
  ensures (`createEmojiTables`, `ensureCj4Schema`) on every open, then `refreshEmojiDataIfNeeded()`.
- English query today (line 2206), guarded by `tableExists("dictionary")` (line 2204):

  ```sql
  SELECT word FROM dictionary WHERE word MATCH ? ORDER BY word ASC LIMIT 20
  ```

### Why follow the emoji model

The emoji feature (DB 103) already implements exactly the payload pattern DB 105 needs:

- Bundled `emoji.db` raw resource → copied to a temp file → `ATTACH DATABASE` →
  `INSERT … SELECT` into the main DB → `DETACH` (`importEmojiData`, line 5179).
- A version-metadata row drives "is the payload current?" (`isEmojiDataCurrent`, line 5152;
  checks `im` table `code='emoji' title='version'` against `EMOJI_DATA_VERSION`).
- `createEmojiTables(..., forceRecreate)` is idempotent (`CREATE TABLE IF NOT EXISTS`,
  usability probe + rebuild for the FTS table, line 5206).

DB 105 reuses this shape with a `dictionary.db` payload and a `DICTIONARY_DATA_VERSION`
metadata row. Unlike emoji, the new `dictionary` table is **not** FTS — it is a plain
indexed table, to avoid the stale virtual-table failure family seen in #88.

## Target schema (version 105)

```sql
-- Replaces: CREATE VIRTUAL TABLE dictionary USING fts3(word)
CREATE TABLE dictionary (
    word      TEXT    PRIMARY KEY,
    basescore INTEGER NOT NULL DEFAULT 0,  -- bundled frequency/rank, from dictionary.db
    score     INTEGER NOT NULL DEFAULT 0   -- per-user local learning (private)
);

CREATE INDEX IF NOT EXISTS dictionary_word_idx  ON dictionary(word);
CREATE INDEX IF NOT EXISTS dictionary_rank_idx  ON dictionary(score + basescore);
```

`word PRIMARY KEY` already creates the unique index used for prefix range scans; the
explicit `dictionary_word_idx` is harmless and kept only for parity with the
ENG_AUTO_COMPLETION spec. The `score + basescore` expression index supports the long-term
ranked query.

Prefix completion query (replaces the FTS `MATCH` form on both platforms):

```sql
SELECT word
FROM dictionary
WHERE word >= :prefix
  AND word <  :prefixUpperBound   -- :prefix with last code unit incremented
  AND word <> :prefix             -- keep #103 exact-match filter
ORDER BY (score + basescore) DESC, word ASC
LIMIT :limit;
```

`:prefixUpperBound` is `:prefix` with its final character bumped by one code point
(e.g. `"sal"` → `"sam"`), giving a half-open range that needs no FTS and no `LIKE`.

## Payload: `dictionary.db`

A bundled raw resource, generated reproducibly by a repo script, structured like `emoji.db`:

```sql
-- inside dictionary.db
CREATE TABLE dictionary_data (
    word      TEXT PRIMARY KEY,
    basescore INTEGER NOT NULL,
    version   TEXT NOT NULL
);
```

- `version` carries the payload version string (e.g. a `wordfreq` snapshot id), compared
  against a `DICTIONARY_DATA_VERSION` constant to decide whether a refresh is needed.
- `basescore` may be derived from `wordfreq` or another open data source. See
  "License" below.
- Placed at:
  - Android: `LimeStudio/app/src/main/res/raw/dictionary.db` → `R.raw.dictionary`.
  - iOS: `dictionary.db` added to the keyboard/app bundle, loaded with
    `Bundle.main.url(forResource: "dictionary", withExtension: "db")` (mirrors emoji
    loading at LimeDB.swift line 2376).

## Migration algorithm (schema-driven, idempotent)

Run the same logical steps on Android (`onUpgrade` + open-path re-check) and iOS
(`upgradeIfNeeded` + `ensureCurrentDatabase`). The migration must be safe to run when
`user_version` is already 105 but the on-disk schema is stale (restored legacy DB).

```text
ensureDictionarySchema(db):
  legacy = schema-probe: does object 'dictionary' exist AND is it an FTS virtual table?
           (sqlite_master.type='table' AND sql LIKE '%VIRTUAL TABLE%USING fts%')

  preservedScores = {}
  if a NON-fts 'dictionary' table exists AND it has a 'score' column:
      preservedScores = SELECT word, score FROM dictionary WHERE score <> 0

  if legacy:
      # Old FTS-only dictionary(word) — no score to preserve, drop defensively.
      DROP TABLE IF EXISTS dictionary           # may be a virtual table
      # If DROP fails (see #88), fall back to renaming the shadow tables / recreate file.

  if 'dictionary' table is missing OR not the 105 shape:
      DROP TABLE IF EXISTS dictionary
      CREATE TABLE dictionary (word TEXT PRIMARY KEY,
                               basescore INTEGER NOT NULL DEFAULT 0,
                               score     INTEGER NOT NULL DEFAULT 0)
      CREATE INDEX IF NOT EXISTS dictionary_word_idx ON dictionary(word)
      CREATE INDEX IF NOT EXISTS dictionary_rank_idx ON dictionary(score + basescore)

  refreshDictionaryDataIfNeeded(db)             # imports basescore from dictionary.db

  # Restore any preserved per-user score onto matching words.
  for (word, score) in preservedScores:
      UPDATE dictionary SET score = :score WHERE word = :word
```

```text
refreshDictionaryDataIfNeeded(db):
  ensureDictionarySchema-created table exists
  if dictionary has rows AND stored DICTIONARY_DATA_VERSION == current:
      return                                    # payload already current

  copy R.raw.dictionary (or bundle dictionary.db) to a temp file
  if temp file has no dictionary_data table:
      log and keep existing data; return        # never wipe on a bad payload

  ATTACH temp file AS dict_src
  begin transaction
    # Refresh basescore for all words WITHOUT touching user score.
    # Upsert keeps learned score for words that survive across payloads.
    INSERT INTO dictionary(word, basescore, score)
      SELECT word, basescore, 0 FROM dict_src.dictionary_data
      WHERE true
      ON CONFLICT(word) DO UPDATE SET basescore = excluded.basescore;
    # Optional: prune words removed from the payload that have no learned score.
    DELETE FROM dictionary
      WHERE score = 0
        AND word NOT IN (SELECT word FROM dict_src.dictionary_data);
    store DICTIONARY_DATA_VERSION (im-table metadata row or pragma)
  commit
  DETACH dict_src
  delete temp file
```

Key invariants:

- `score` (user learning) is **never** overwritten by the payload import; only `basescore`
  is refreshed. This is what lets a dictionary-data refresh keep learned frequency.
- The schema repair is gated on **actual schema state**, not on `user_version`, so a
  restored DB with `user_version = 105` but a legacy FTS `dictionary` is still fixed.
- Importing from a missing/corrupt payload must never empty the existing `dictionary`.

## Code changes by file

### Android — `LimeDB.java`

1. `DATABASE_VERSION` → `105` (line 122).
2. Add `DICTIONARY_DATA_VERSION` constant (mirrors `EMOJI_DATA_VERSION`).
3. In `onUpgrade` (line 663) add:

   ```java
   if (oldVersion < 105) {
       ensureDictionarySchema(dbin);   // drops legacy FTS dictionary, builds 105 table
   }
   ```

4. In the open path (near `refreshEmojiDataIfNeeded()` at line 885) add
   `refreshDictionaryDataIfNeeded();` so fresh installs and restored DBs get the payload
   and a schema repair even when no version bump fires.
5. Add `ensureDictionarySchema(db)`, `refreshDictionaryDataIfNeeded()`,
   `isDictionaryDataCurrent()`, and `importDictionaryData(File)` modeled on the emoji
   equivalents (`createEmojiTables` line 5206, `refreshEmojiDataIfNeeded` line 5122,
   `isEmojiDataCurrent` line 5152, `importEmojiData` line 5179).
6. Rewrite `getEnglishSuggestions` (line 4898) to use the indexed prefix range query
   above instead of `word MATCH '<typed>*'`. Keep the `word <> :prefix` exact-match
   filter (#103) and the `getSimilarCodeCandidates()` limit.

### iOS — `LimeDB.swift`

1. `CURRENT_DB_VERSION` → `105` (line 149).
2. In `upgradeIfNeeded` (line 230) add `if version < 105 { try LimeDB.ensureDictionarySchema(db) }`
   before the final `PRAGMA user_version` stamp (line 290).
3. In `ensureCurrentDatabase()` (line 301) add idempotent `ensureDictionarySchema(db)` and
   `refreshDictionaryDataIfNeeded()` calls alongside the existing emoji ensures, so the
   repair runs after every open/restore/factory-reset (the same defensiveness as emoji).
4. Add `static func ensureDictionarySchema`, `refreshDictionaryDataIfNeeded`,
   `dictionaryDataVersion`, and the bundle-load/ATTACH import, modeled on
   `createEmojiTables` (line 2459) and `refreshEmojiDataIfNeeded` (line 2362).
5. Rewrite `getEnglishSuggestions(_:)` (line 2200) to the indexed prefix range query.
   The existing `tableExists("dictionary")` guard (line 2204) stays valid.

## License / data provenance

If `basescore` is derived from `wordfreq` (or any third-party source):

- Keep the upstream source table and license metadata reproducible from a repo script.
- Add the third-party data disclosure to `LICENSE.md`.
- Treat generated `basescore` as derived data under the source license terms.
- `score` is per-user private learning data — never bundled, disclosed, or uploaded.
  If a backup contains `score`, that is the user's private backup data.

## Verification plan

### Fresh install (no prior DB)

1. First launch creates the 105 `dictionary` table and imports `basescore` from
   `dictionary.db`.
2. `PRAGMA user_version` reports `105` on both platforms.
3. Typing `sal` returns ranked suggestions (`salt` not buried behind proper nouns).

### Upgrade from 104 (legacy FTS `dictionary(word)`)

1. Upgrade drops the FTS virtual table and builds the 105 table + indexes.
2. `basescore` is imported; `score` starts at 0 (legacy table had none to preserve).
3. English completion still filters the exact word (#103) and shows `[salt]` alone.

### Restore of a legacy backup claiming `user_version = 105`

1. Open/restore path detects the legacy/wrong `dictionary` schema by **schema probe**,
   not version, and repairs it (lesson from #88).
2. After repair, `dictionary` is the 105 shape and the payload is imported.

### Payload refresh (new `dictionary.db`, same major version)

1. A bumped `DICTIONARY_DATA_VERSION` triggers `refreshDictionaryDataIfNeeded`.
2. `basescore` updates for existing words; new words are inserted.
3. Per-user `score` is preserved for surviving words (upsert does not reset `score`).

### Backup / restore preserves learning

1. Learn a word (tap/commit), confirm its `score` increments.
2. Back up, factory reset, restore — confirm the learned `score` survives.
3. Cross-platform: restore an Android backup on iOS (and vice versa) and confirm the
   same `dictionary` schema and learned `score` load without dictionary-specific
   conversion (shared schema contract).

### Regression guards

1. Chinese / table IM mapping scores and phrase learning are untouched by the migration.
2. Emoji tables and emoji data version handling are unaffected.
3. `getEnglishSuggestions` returns the same #103 behavior (exact filtered, no default
   highlight handled upstream in `LIMEService` / `CandidateView`).
