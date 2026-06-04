# Issue #91: CIN import changes same-code candidate order

## Problem statement

Community reporter `ejmoog` reports that importing a `.cin` table can change the order of duplicate-code candidates from the order in the source file, even when Android's candidate/selection sorting preference (`啟動選取排序`) is off or was never enabled.

Issue: https://github.com/lime-ime/limeime/issues/91

## Reported reproduction

1. Import the 哈哈倉頡 `.cin` file.
2. Enter code `vmi`.
3. In the source `.cin`, the same-code candidates are expected in this order: `狀`, `绒`, `戕`.
4. After import/use in LIME, the order is reported as: `狀`, `戕`, `绒`.

Evidence: the issue includes a screenshot showing the `vmi` duplicate-code candidate order after import.

## Current classification

Android bug in `.cin` import / candidate ordering.

This is distinct from a product request for learning-based sorting: the reporter explicitly says the selection sorting preference is disabled, so same-code candidates should remain stable in source-file order unless another enabled feature intentionally reorders them.

## Android implementation status

Implemented and merged to `master` via PR #101 (`43aa6c887d9eebf162891549d0ef04fca9b6fe50`) with the current Android test APK file `LIMEHD2026-6.1.16.apk` in `LimeStudio/app/release/`.

- Added regression coverage for duplicate-code `.cin` source order when selection sorting is disabled.
- Updated Android candidate query ordering so score/base-score priority applies only when sorting is enabled; sorting-disabled same-code exact matches fall back to `_id ASC` / source insertion order.
- GitHub auto-closed the community issue during the PR merge, but reporter confirmation is still needed. The issue was reopened and a scoped retest request was posted: https://github.com/lime-ime/limeime/issues/91#issuecomment-4624477607
- Current follow-up: wait for reporter retest with 哈哈倉頡 `vmi` using the current test APK: https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.16.apk

## Relevant code observed

Android import path:

- `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
  - `.cin` files are detected by file extension in `importTxtTable(...)`.
  - `%chardef begin/end` lines are parsed, `code` and `word` are inserted into the IM table, and rows are inserted with `db.insert(table, null, cv)`.
  - If no explicit score/base score is provided, `score` defaults to `0`, while `basescore` is populated from `getBaseScore(word)`.

Android candidate query path:

- `LimeDB.getMappingByCode(...)` builds an `ORDER BY` clause with `_id ASC` as the final tie-breaker.
- Even when the `sort` preference is false, several fixed ordering terms still run before `_id ASC`: exact-match priority, at-least-as-long code priority, a code-length tie-breaker, and this exact-match/single-character score condition:
  - `( exactmatch = 1 and ( score > 0 or basescore > 0) and length(word)=1) desc`
- For the reported `vmi` same-code / single-character candidates, most fixed terms should tie, so the exact-match/single-character score condition is the main observed clause that could differentiate candidates before `_id ASC`.
- When `sort` is true, `score DESC, basescore DESC` are also added before `_id ASC`.

## Suspected root cause / investigation notes

The import operation likely preserves source order at insertion time through SQLite row order / `_id ASC`, but candidate retrieval may still reorder some same-code candidates before `_id ASC` because imported rows receive a `basescore` value from `getBaseScore(word)` whose zero/non-zero result depends on the character, and the exact-match/single-character score-priority condition is always present, even when user-facing selection sorting is off.

If `绒` and `戕` differ in `basescore` presence/value or related query flags, the current query can make the displayed order diverge from the `.cin` file order despite the disabled sorting preference.

A second area to confirm is whether 哈哈倉頡 is being imported into `custom` or another table that already contains existing rows/user scores. Existing learned `score > 0` rows could also affect ordering, but the report says the issue occurs after importing the `.cin` file and with sorting disabled.

## Proposed solution / implementation plan

1. Add a focused regression test for same-code `.cin` import order:
   - import a small `.cin` fixture containing `vmi 狀`, `vmi 绒`, `vmi 戕` in that order;
   - query `getMappingByCode("vmi", true, true)` with selection sorting disabled;
   - assert that exact-match candidates preserve source-file order.
2. Inspect whether imported `.cin` rows without explicit score/base score should keep `basescore = 0` when sorting is disabled, or whether the `ORDER BY` clause should skip all score/base-score priority before `_id ASC` when the relevant sorting preference is disabled.
3. Keep learned/user score behavior intact when the user explicitly enables sorting or after a candidate is intentionally selected/learned.
4. Check iOS parity if the same `.cin` import/query logic exists there.

## Follow-up questions

Current report was sufficient for the Android source fix. If reporter retest still fails in a review APK, ask for:

- the exact 哈哈倉頡 `.cin` source file/version they imported;
- whether the table was imported into a clean custom IM or over an existing table with learned records;
- the Android APK version used for the screenshot.

## Verification plan

- Android unit/instrumentation test for `.cin` import source order with duplicate-code candidates and sorting disabled.
- Manual verification with the reporter's `vmi` / `狀 绒 戕` case.
- Confirm that enabling selection sorting still allows score/base-score/user-learning behavior where intended.
- Reporter retest requested for the current `LIMEHD2026-6.1.16.apk` after PR #101 merged the targeted ordering fix; verified APK blob SHA `eb99705bc3f6a2668889e89c05f7d9914c574639`, size 11983378 bytes.
