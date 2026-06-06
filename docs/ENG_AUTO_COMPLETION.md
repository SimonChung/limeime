# English Auto-Completion

## Purpose

Track the current iOS English auto-completion implementation, the implemented Android #103 fix, and the planned Android-only scored dictionary.

Goals:

1. Keep exact-match filtering on Android to avoid duplicate candidate items.
2. Show the typed composing word as the only candidate when it is the only exact dictionary match.
3. Never pre-highlight candidates in English composing / auto-completion mode.
4. Move Android English suggestion ordering away from plain alphabetical order.
5. Prepare for replaceable dictionary data and user-learned English frequency (Android only).

### Scope decision: Android-only scored dictionary

The scored English `dictionary(word, basescore, score)` table is **Android-only**.
iOS keeps its current `UITextChecker` completion and does **not** build, query, or
import the `dictionary` table.

Rationale: Apple's `UITextChecker` lexicon is larger than a bundled word list and adds
typo correction that a plain prefix scan cannot. A bundled scored dictionary only adds
value where there is no good system completer — i.e. Android. Replacing `UITextChecker`
with a ~30–50k-word list would *reduce* iOS coverage, so the earlier "unify iOS and
Android on one dictionary table" goal is **withdrawn**.

### The dictionary is self-versioned — no `lime.db` version bump

The Android dictionary is **not** tied to `lime.db`'s `PRAGMA user_version`. It carries its
own `DICTIONARY_DATA_VERSION` in an `im`-table row (`code='dictionary', title='version'`),
exactly like emoji carries `EMOJI_DATA_VERSION` — see "Bundled-payload version principle"
below. `lime.db` **stays at version 104 on both platforms.**

Why this matters (the iOS-lag problem it solves): if the dictionary were gated on a
`lime.db` 104→105 bump, iOS (which keeps 104) would lag Android (105) by one version, and
a backup round-trip Android→iOS→Android could arrive on Android **stamped 105 but with a
stale/missing dictionary**, causing `onUpgrade` to be skipped and the dictionary never
rebuilt — the exact #88 "`user_version` lies after restore" failure. By giving the
dictionary its own version and probing actual schema state on every Android open, the main
DB version is irrelevant and there is **no version lag to manage.**

Cross-platform restore consequences:

- **Android backup restored on iOS:** iOS **ignores** the `dictionary` table (left inert,
  never queried, never dropped). No migration. `lime.db` is 104 on both sides, so there is
  no version mismatch at all.
- **iOS backup restored on Android:** Android's open-path dictionary check runs, sees the
  `dictionary` table missing or its `DICTIONARY_DATA_VERSION` stale, and rebuilds/imports
  from the bundled payload — same as a fresh install.

### Bundled-payload version principle (shared with emoji)

Emoji and the English dictionary are both **bundled data payloads**. They follow one rule:

> **Payload currency is decided by an `im`-table version row, checked on every database
> open — never by `lime.db`'s `user_version` (`onUpgrade`), and never once-only (`onCreate`).**

**Where the version is stored.** A row in the `im` table (`LIME.DB_TABLE_IM`), namespaced
by `code`:

| `code` | `title` | `desc` |
| --- | --- | --- |
| `emoji` | `version` | e.g. `17.0` (matches `EMOJI_DATA_VERSION`) |
| `dictionary` | `version` | the bundled `dictionary.db` payload version |

The `im` table is a core LIME table that travels with backup/restore, so this row survives
backups. A **missing** row (every legacy DB, since neither feature wrote one before) reads
as "stale" and triggers a one-time import — see `isEmojiDataCurrent()`
(`SELECT desc FROM im WHERE code='emoji' AND title='version'`; absent cursor → not current).

**Where the check runs.** In `ensureCurrentDatabase()` (LimeDB.java), which calls
`refreshEmojiDataIfNeeded()` and (planned) `refreshDictionaryDataIfNeeded()`. That method is
the single funnel for **every** lifecycle event:

| Trigger | Caller |
| --- | --- |
| Normal open (every keyboard/app start) | constructor → `openDBConnection()` → `ensureCurrentDatabase()` (LimeDB.java:424) |
| Backup restore | `DBServer.restore*` → `ensureCurrentDatabase()` (DBServer.java:578/597) |
| Factory reset | seed copy → `ensureCurrentDatabase()` (LimeDB.java:6657) |

Each `refreshXxxDataIfNeeded()` is idempotent and self-gating: it (re)creates the table
(`CREATE TABLE IF NOT EXISTS`), then returns immediately if the `im` version row matches
the build constant (fast path), otherwise imports from the bundled payload. A lazy guard
before the feature's query (emoji's `checkEmojiDB()`; the dictionary's equivalent before
`getEnglishSuggestions`) covers sessions that never hit settings.

**Why not `onUpgrade`.** `onUpgrade` is version-gated — it runs only when stored
`user_version` ≠ `DATABASE_VERSION`, then never again. That misses three cases a payload
must handle: (1) a restored DB that **lies** about its version (claims current, carries
stale schema) — the #88 "`user_version` lies" crash family; (2) a **data-only payload
refresh** (new `dictionary.db`/`emoji.db`) shipped without a schema bump; (3) **factory
reset**, which copies a current-version seed and never calls `onUpgrade`. The open-path
check is state-gated and catches all three.

**Why not `onCreate`.** This codebase has **no `onCreate`** — `lime.db` is a bundled seed
copied into place (`R.raw.lime`), not built by SQLite, so `onCreate` never fires. The
"initialize the data" role therefore lives in the every-open path (`onOpen`-like), which is
also what correctly re-checks after restore and reset.

**Emoji now follows this exactly.** Emoji's currency logic was already entirely in the
open-path `refreshEmojiDataIfNeeded()` / `isEmojiDataCurrent()` (im-row gated, no version
dependency). The vestigial `onUpgrade if (oldVersion < 103) createEmojiTables` line — a
leftover from before the #88 fixes moved emoji to per-open repair — has been **removed**,
so emoji and the dictionary share one scheme. The `LimeDB103IntegrationTest` #88 regression
suite (including the 102→103 upgrade, the 101 restore, the stale-FTS restore, and factory
reset) passes after removal.

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
- Tapping a completion commits only the untyped suffix plus a space. That
  auto-appended space is then swapped with the next punctuation (`word, ` not
  `word ,`) — see ENGLISH_KB.md §2a, implemented on both platforms.
- `showCandidates(mappings)` is called without a selected index, so the candidate bar shows no default highlight.
- iOS does not prepend an Android-style composing/self candidate in this path, so it does not have the same duplicate exact-match problem.

Important note:

- `selectedCandidate = mappings.first` is still assigned for commit/navigation logic, but the visual candidate bar receives `selectedIndex = -1`.

## iOS stays on `UITextChecker` (unification withdrawn)

iOS keeps `UITextChecker` and is **not** changed to use the Android scored dictionary.
The earlier "unify both platforms on one dictionary table" idea was evaluated and
withdrawn (see the Scope decision above).

Why it was withdrawn:

- A bundled word list (~30–50k words) is **smaller** than Apple's `UITextChecker` lexicon,
  so a pure-dictionary iOS path would *reduce* completion coverage and lose Apple's typo
  correction and locale behavior.
- The shared-table benefit (cross-platform learned `score`) does not outweigh that loss,
  and it would require a whole iOS query/learning/migration/backup/restore surface for no
  user-visible gain over the system completer.

If iOS unification is ever revisited, the least-disruptive option is "keep `UITextChecker`
for display but learn tapped/completed words into a `score` table" — but that is explicitly
**out of scope** here, and would not require any change to the Android-only design below.

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

Picking a suggestion commits `word + " "` (emoji and suffix paths). The trailing
space is swapped with the next punctuation (`word, ` not `word ,`), replicating
LatinIME — see ENGLISH_KB.md §2a.

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
2. Keep richer frequency/user-score ranking for the scored-dictionary design
   (see "Scored Dictionary (Android)" below).

Long-term target:

```text
ORDER BY (score + basescore) DESC, word ASC
```

where:

- `basescore` is bundled frequency/rank score.
- `score` is local user-learned frequency.

## Scored Dictionary (Android)

Android-only. Replaces the legacy FTS-only `dictionary(word)` table with a plain indexed,
scored dictionary delivered as an emoji-style payload. **No `lime.db` version bump** — the
dictionary is governed by its own `DICTIONARY_DATA_VERSION`, checked on every open like
emoji data (see "The dictionary is self-versioned" above).

### Schema

```sql
-- Replaces: CREATE VIRTUAL TABLE dictionary USING fts3(word)
CREATE TABLE dictionary (
    word      TEXT    PRIMARY KEY,
    basescore INTEGER NOT NULL DEFAULT 0,  -- bundled frequency/rank, from dictionary.db
    score     INTEGER NOT NULL DEFAULT 0   -- per-user local learning (private)
);

CREATE INDEX IF NOT EXISTS dictionary_word_idx ON dictionary(word);
CREATE INDEX IF NOT EXISTS dictionary_rank_idx ON dictionary(score + basescore);
```

### Prefix lookup — indexed range scan, no FTS

```sql
SELECT word
FROM dictionary
WHERE word >= :prefix
  AND word <  :prefixUpperBound   -- :prefix with final code point incremented ("sal" -> "sam")
  AND word <> :prefix             -- keep #103 exact-match filter
ORDER BY (score + basescore) DESC, word ASC
LIMIT :limit;
```

Why a plain indexed table, never FTS (lessons from #88):

- AOSP SQLite does **not** reliably support FTS5 (`no such module: fts5`); FTS5 is a
  compile-time option, not an API-level boundary. A plain indexed `word` column needs no
  FTS module and no `MATCH`/`LIKE`.
- A failed FTS create can leave an unloadable `sqlite_master` row that even
  `DROP TABLE IF EXISTS` cannot remove — the entire #88 crash family. Not creating a
  virtual table makes that class impossible.
- AOSP LatinIME itself stores its dictionary as a binary Patricia trie, **not** SQLite/FTS
  — a B-tree prefix range scan is the correct SQLite-native analogue (same
  O(log N)-to-first-match then sequential read) for exact left-anchored completion.

### Payload: `dictionary.db` (Android only)

A bundled raw resource at `LimeStudio/app/src/main/res/raw/dictionary.db`
(`R.raw.dictionary`), generated reproducibly by a repo script, structured like `emoji.db`:

```sql
CREATE TABLE dictionary_data (
    word      TEXT PRIMARY KEY,
    basescore INTEGER NOT NULL,
    version   TEXT NOT NULL   -- payload version; compared against DICTIONARY_DATA_VERSION
);
```

iOS does not bundle or load `dictionary.db`.

### The legacy `dictionary` table — what we are upgrading from

The shipped seed (`R.raw.lime` / `Database/lime.db`) today contains:

```sql
CREATE VIRTUAL TABLE dictionary USING fts3(word)   -- + dictionary_content/_segments/_segdir shadows
```

It has **one column, `word`** — no `basescore`, no `score`, and **no `im` dictionary
version row** (the version scheme is new). So every existing user DB, and the bundled seed
itself, is in this legacy state. The upgrade has nothing to preserve from it (there is no
user-learned score yet anywhere) — it is a straight **drop-and-rebuild**.

### How we detect which state a DB is in

On open, classify the `dictionary` object purely from `sqlite_master` (never from
`user_version`):

```sql
SELECT type, sql FROM sqlite_master WHERE name = 'dictionary';
```

| Detected state | `sqlite_master` signature | Action |
| --- | --- | --- |
| **Legacy FTS** | row exists, `sql LIKE '%VIRTUAL TABLE%USING fts%'` | drop (defensively) → create scored → import |
| **Scored, current** | `dictionary` has `basescore`+`score` cols AND `im` version row == constant | fast-path: nothing to do |
| **Scored, stale** | scored cols present but `im` version row absent/older | import/refresh `basescore` (keep `score`) |
| **Absent** | no row (e.g. iOS-origin DB restored on Android) | create scored → import |

"Scored shape" is confirmed by probing `PRAGMA table_info(dictionary)` for both `basescore`
and `score` columns. The `im` version row check (below) then decides data freshness.

### Idempotent open-path check (schema-probe, not version)

`refreshDictionaryDataIfNeeded()` runs on **every Android open** from
`ensureCurrentDatabase()`, right after `refreshEmojiDataIfNeeded()` (see "Bundled-payload
version principle" for the full funnel + version-row details). It is gated on actual schema
state and the `im` version row — never on `lime.db` `user_version`. This is what makes the
self-versioned design safe across restore and the iOS round-trip:

```text
refreshDictionaryDataIfNeeded():
  isLegacyFts   = `dictionary` exists AND sql LIKE '%VIRTUAL TABLE%USING fts%'
  isScoredShape = `dictionary` exists AND table_info has both 'basescore' and 'score'

  # 1. Drop the legacy FTS dictionary BEFORE creating the scored one.
  #    The legacy fts3(word) table has NO score column, so there is nothing to
  #    preserve — it is a clean drop-and-rebuild. (Score preservation only applies
  #    to a future re-shape of an already-scored table; not to this legacy upgrade.)
  if isLegacyFts:
      try: DROP TABLE IF EXISTS dictionary               # also clears fts3 shadow tables
      except module-unavailable (no such module: fts3/4/5):   # #88 rule 2
          PRAGMA writable_schema = ON
          DELETE FROM sqlite_master
            WHERE name='dictionary' OR name LIKE 'dictionary\_%' ESCAPE '\'   # + _content/_segments/_segdir
          PRAGMA writable_schema = OFF; bump schema_version
      isScoredShape = false

  # 2. Ensure the scored table exists.
  if NOT isScoredShape:
      CREATE TABLE dictionary(word TEXT PRIMARY KEY,
                              basescore INTEGER NOT NULL DEFAULT 0,
                              score     INTEGER NOT NULL DEFAULT 0)
      + indexes (see Schema above)

  # 3. Data freshness via the im version row (absent on every legacy DB -> import).
  installed = SELECT desc FROM im WHERE code='dictionary' AND title='version'   # null if absent
  if dictionary has rows AND installed == DICTIONARY_DATA_VERSION:
      return                                  # fast path: nothing to do

  # 4. Import basescore from the bundled payload; keep any existing score.
  copy R.raw.dictionary to a temp file
  if it has no dictionary_data table: log and keep existing data; return   # never wipe on bad payload
  ATTACH temp AS dict_src; begin transaction
    INSERT INTO dictionary(word, basescore, score)
      SELECT word, basescore, 0 FROM dict_src.dictionary_data
      ON CONFLICT(word) DO UPDATE SET basescore = excluded.basescore    # refresh basescore, keep score
    INSERT OR REPLACE INTO im(code, title, desc)
      VALUES('dictionary', 'version', DICTIONARY_DATA_VERSION)          # mirrors emoji version row
  commit; DETACH; delete temp
```

Note: the legacy→scored upgrade never carries score forward because the legacy
`fts3(word)` table has none. The `ON CONFLICT … keep score` clause and any
"restore preserved score" step matter only on a *later* payload refresh of an
already-scored table, where users have accumulated `score` — not on this first upgrade.

Key invariants:

- `score` (user learning) is **never** overwritten by a payload import; only `basescore`
  is refreshed. A dictionary-data refresh therefore keeps learned frequency.
- The repair is gated on **actual schema state**, so a DB that lies about its version
  (e.g. an Android→iOS→Android round-trip) is still fixed on the next Android open.
- A missing/corrupt payload must never empty an existing `dictionary`.

### Dictionary source and license

`basescore` is bundled and redistributed, so its source license matters. Do **not** use
AOSP LatinIME's dictionary *data*: the AOSP `NOTICE` marks it "Dictionaries © Lexiteria
LLC. Used by permission" — proprietary, licensed to Google only, not redistributable.
LatinIME validates the *design*, not the data.

Safe sources:

- **Recommended: Google Books Ngrams 1-grams (CC BY 3.0)** — attribution only, no copyleft,
  commercial-OK. Aggregate counts → normalize to `basescore`; pre-extract top ~100k words
  in a repo script.
- **wordfreq v3.1.1** — pre-normalized, but its *data* is **CC BY-SA 4.0 (copyleft)**, not
  Apache-compatible and not usable in a proprietary build. Use only if the project commits
  to a copyleft-compatible license, and credit every upstream source per its `NOTICE.md`.
- Avoid Norvig `count_1w.txt` (LDC-sourced, no redistribution license) and SUBTLEX
  (non-commercial-leaning).

Rules: generate `dictionary.db` reproducibly from a committed script (record the source
snapshot in the payload `version`); disclose the source + URL + license in `LICENSE.md`;
treat `basescore` as derived data under the source terms. `score` is per-user private
learning data — never bundled, disclosed, or uploaded; if a backup contains `score`, that
is the user's private backup data.

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

### Scored Dictionary (Android only)

1. Fresh install creates the scored `dictionary` table and imports `basescore` from the
   bundled `dictionary.db`. `lime.db` `user_version` stays 104.
2. Open with the old FTS-only `dictionary(word)` present → the open-path check drops the
   FTS table (defensively, before create) and builds the scored table. No `USING fts5` is
   ever executed; no `table dictionary already exists` / `no such module` crash.
3. A DB that lies about its version (round-trip Android→iOS→Android, or any restore) is
   repaired because the check is gated on **actual schema state**, not `user_version`.
4. Payload refresh (bumped `DICTIONARY_DATA_VERSION`) updates `basescore` and adds new
   words without resetting local `score`.
5. Android backup/restore preserves local `score`.

Cross-platform (dictionary is Android-only):

- **Android backup → iOS:** iOS opens normally, keeps `UITextChecker`, never queries or
  drops the inert `dictionary` table. `lime.db` is 104 on both sides — no version mismatch.
- **iOS backup → Android:** the iOS DB has no `dictionary` table; Android's open-path
  check rebuilds it from the bundled payload, exactly like a fresh install.

### Regression guards

- Chinese / table IM mapping scores and phrase learning are untouched.
- Emoji tables and `EMOJI_DATA_VERSION` handling are unaffected.
- `getEnglishSuggestions` keeps the #103 behavior (exact filtered, no default highlight).
