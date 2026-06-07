# Issue #103: English candidate disappearance and dictionary coverage around `salt`

## Live issue state

- Issue: https://github.com/lime-ime/limeime/issues/103
- Status: reopened on 2026-06-07 for reporter confirmation after Android APK `LIMEHD2026-6.1.17.apk` shipped the #103 fixes.
- Current labels: `enhancement`, `Usability`
- Reporter: `SmithCCho`
- Initial maintainer acknowledgement: https://github.com/lime-ime/limeime/issues/103#issuecomment-4629503196

## Problem statement

Reporter `SmithCCho` raised an English candidate usability issue: while typing `salt`, the expected candidate disappears when the word becomes an exact match. The public report also notes that `salt` appears late while typing `sal`.

Detailed cross-platform design lives in [ENG_AUTO_COMPLETION.md](ENG_AUTO_COMPLETION.md).

## Confirmed evidence

The actual bundled seed used by both platforms is byte-identical between:

- `LimeStudio/app/src/main/res/raw/lime.db`
- `Database/lime.db`

The bundled `dictionary` table has only one `salt*` row:

```text
2965|salt
```

For comparison, `year*` has non-exact follow-up rows:

```text
235|year
6298|year's
7981|yearly
121|years
```

Android filters exact English dictionary matches:

```sql
WHERE word MATCH '<typed>*'
AND word <> '<typed>'
```

That filter leaves `salt` with zero suggestion rows, because the only DB match is the exact word.

Before the #103 fix, Android also sorted English dictionary suggestions alphabetically. For `sal`, previous ordering was:

```text
Salem, Salisbury, salaries, salary, sale, sales, sally, salmon, saloon, salt, ...
```

So the `salt` ordering complaint was caused by `ORDER BY word ASC`, not by user score or frequency ranking. The #103 short-term fix uses `ORDER BY rowid ASC` as the existing dictionary rank signal.

## Implemented #103 spec

1. Keep filtering exact dictionary matches.

   Android English composing already has the typed word as the composing/self candidate. Returning the exact DB row too would create duplicate candidates, for example `year` + `year`.

2. If the exact match is the only dictionary match, still show the composing/self candidate as the only candidate item.

   Expected Android behavior:

   ```text
   salt -> [salt]
   ```

   This item should be the composing/self candidate, not a dictionary suggestion. Do not remove the exact-match filter just to make `salt` appear.

3. English composing / auto-completion mode should never pre-highlight a candidate.

   This applies whether the list is `[salt]` or `[year, year's, yearly, years]`. English candidates should be visible and tappable, but no item should be selected by default.

4. English suggestions should move away from plain alphabetical sorting.

   Short-term implemented: prefer existing dictionary row/rank order.

   Long-term: use a richer dictionary schema with `basescore` and local user `score`, matching the Chinese table score model.

## iOS alignment

iOS English completion uses a different flow from Android. It uses `UITextChecker.completions(...)` and displays completions with no default highlight (`selectedIndex = -1`). Because iOS does not prepend the same Android-style composing/self candidate in this path, it does not have the same duplicate exact-match problem.

The Android fix should align the visible behavior with iOS: English completion candidates are shown without default highlight.

## Android code paths

- `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
  - Keep the exact-match filter in `getEnglishSuggestions(...)`.
  - Sort current dictionary suggestions by `rowid ASC` instead of `word ASC`.
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
  - In the English prediction path, when dictionary suggestions are empty, show the composing/self candidate instead of calling `clearSuggestions()`.
  - Use a no-highlight candidate display path for all English composing candidates.
- `LimeStudio/app/src/main/java/net/toload/main/hd/candidate/CandidateView.java`
  - Add an explicit way to set suggestions while leaving `mSelectedIndex = -1`, scoped to English prediction.
  - Do not change normal Chinese/table IM default highlight behavior.

## Future dictionary upgrade direction

Use a separate bundled `dictionary.db` payload, similar to emoji data, instead of relying forever on the old FTS-only `dictionary(word)` table inside `lime.db`.

Planned shape:

```sql
dictionary(
  word TEXT PRIMARY KEY,
  basescore INTEGER DEFAULT 0,
  score INTEGER DEFAULT 0
)
```

- `basescore`: bundled frequency/rank score, potentially derived from `wordfreq` or another open data source.
- `score`: per-user local learning score. This is private user data and should not be disclosed publicly.
- `LICENSE.md`: disclose any third-party bundled dictionary/frequency source and license.
- Upgrade path: schema-driven and idempotent, including restored legacy DBs whose actual schema may not match `PRAGMA user_version`.
- Prefer normal indexed prefix lookup over FTS for English completion to avoid repeating the #88 stale FTS virtual-table failure pattern.

## Verification plan

1. Type `salt`.
   - Candidate strip shows one item: `salt`.
   - No item is highlighted.
2. Type `year`.
   - Candidate strip does not show duplicate exact `year` entries.
   - No item is highlighted.
3. Type `sal`.
   - Existing suggestions still appear.
   - No item is highlighted.
4. Verify normal Chinese/table IM candidates still keep their existing default highlight and end-key behavior.
5. Verify tapping an English candidate still commits the tapped item.
6. Verify `sal` no longer puts `salt` behind capitalized proper nouns solely because of alphabetical order.

## Public follow-up status

Issue #103 was reopened after Android APK `LIMEHD2026-6.1.17.apk` shipped the #103 English composing/candidate-display fixes. Verified APK Contents metadata: blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes. Retest request posted: https://github.com/lime-ime/limeime/issues/103#issuecomment-4641196730.

Reporter confirmation requested for the original `salt` / `sal` scenarios. Keep the issue open until `SmithCCho` confirms the Android APK behavior or provides new evidence. Public wording should continue to frame this as an English composing/candidate-display usability fix, not that exact-match filtering itself was a bug.
