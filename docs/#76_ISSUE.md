# Issue #76: extra next-code candidate still shown after #70 follow-up

## Problem statement

Community reporter `ejmoog` opened #76 after testing Android APK `LIMEHD2026-6.1.8.apk` and reported that the unwanted extra next-code / code-extension candidate remains visible. The report was split from #70, where the reporter asked to hide/configure the number of these extra candidates and later described the desired value as `0` for disabled.

Example from the report:

- Input code: `ha`.
- Desired candidate display: exact match `白` only, matching the reporter's gcin comparison screenshot.
- Actual candidate display in LIME: `白` plus an extra next-code / prefix-extension candidate `皔` (code `haa`).
- Comparison screenshots show gcin displaying only `白`, while LIME still displays the extra `皔` candidate.

The report strongly suggests the related display-count setting did not produce the expected "disabled" behavior. Maintainer comment `4517136291` confirms that when the suggested-candidate count is set to `0`, the current implementation still sends one `ha*` partial-match candidate, and that the intended follow-up is to make `0` truly mean zero partial/extension candidates.

## Reproduction notes from current evidence

1. Install Android APK `6.1.8` on Android 15, matching the reporter's follow-up comment.
2. Use the Android soft keyboard with a Cangjie-style table where `ha` maps to `白` and `haa` maps to `皔`.
3. Configure `建議字顯示數量` / `similiar_list` to `0` if reproducing the disabled-count path.
4. Type `ha`.
5. Observe whether the candidate bar still includes one next-code / prefix-extension candidate after the exact match.

The reporter's screenshots are visual evidence. The exact setting value used in the screenshot is still inferred from the #70/#76 discussion and the single-extra-candidate behavior, but maintainer comment `4517136291` confirms the product-level `建議字顯示數量 = 0` path currently still emits one `ha*` partial-match candidate.

## Code inspection

Relevant Android preference and query paths on `master`:

- `LimeStudio/app/src/main/res/values/strings_settings.xml`
  - `similiar_list` is titled `建議字顯示數量`.
  - `similiar_codes` includes `0`, `10`, `20`, `30`, `40`, `50`.
- `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEPreferenceManager.java`
  - `getSimilarCodeCandidates()` reads `similiar_list`, defaulting to `20`.
- `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
  - `getMappingByCode(...)` builds `selectClause = expandBetweenSearchClause(codeCol, code) + extraSelectClause;` before reading the cursor.
  - `expandBetweenSearchClause(...)` deliberately includes shorter-prefix exact records and longer next-code records. For input `ha`, the query shape is equivalent to `code = 'h' OR (code >= 'ha' AND code < 'hb')`, so records such as `haa` / `皔` are fetched before result limiting.
  - `exactMatchCondition` marks only rows whose code equals the typed code (`ha`) as exact. Longer codes such as `haa` are therefore marked partial.
  - `buildQueryResult(...)` reads `int sLimit = mLIMEPref.getSimilarCodeCandidates();`.
  - For non-exact / partial-match records, it currently adds the mapping to `result`, then increments `sCount`, then breaks if `sCount > sLimit`.

Relevant iOS preference and query paths on `master`:

- `LimeIME-iOS/Shared/Search/SearchServer.swift`
  - `similiarList` defaults to `20`.
  - `applyPrefsToDatabase()` maps `similiarEnable ? similiarList : 0` into `db.similarCodeCandidatesCap`.
- `LimeIME-iOS/Shared/Database/LimeDB.swift`
  - `similarCodeCandidatesCap` defaults to `20`.
  - `getMappingByCode(...)` mirrors Android and always builds `let selectClause = expandBetweenSearchClause(column: codeCol, code: queryCode) + extraSelectClause`.
  - `expandBetweenSearchClause(...)` mirrors Android's prefix/extension range query.
  - The result loop mirrors Android's post-add partial count: append mapping, increment `sCount`, then break when `sCount > sLimit`.

The code inspection maps the product setting `建議字顯示數量` to `similiar_list`; maintainer comment `4517136291` confirms the observed product behavior that setting the count to `0` still sends one `ha*` partial-match candidate today, and the fix direction is to make `0` truly suppress those partial/extension candidates.

There are two related issues to handle:

- For `similiar_list = 0`, the DB query should not include the partial/extension branch in the first place. Fetching `haa` and then relying on `buildQueryResult(...)` to discard it leaves the disabled setting implemented too late in the pipeline and can still interact with cache/runtime suggestion paths.
- For positive `similiar_list` values, the post-add limit check in `buildQueryResult(...)` appears to allow one more partial-match record than requested because it adds the mapping before checking `sCount > sLimit`.

## Likely root cause

Likely root cause is that Android `LimeDB.getMappingByCode(...)` and iOS `LimeDB.getMappingByCode(...)` always use `expandBetweenSearchClause(...)`, even when the similar-code candidate cap is `0`. That expanded clause intentionally fetches next-code / prefix-extension records such as `haa` for typed code `ha`; those rows are then marked partial by `exactMatchCondition`.

The later `buildQueryResult(...)` limit logic adds a second bug: partial-match records are added before the limit is checked, so `0` still allows one partial row and positive values may allow one too many.

This should be verified with an Android test or manual repro using `similiar_list=0`; the internal `similiar_list` / `buildQueryResult(...)` path remains a code-inspection inference, while the maintainer comment confirms the product-level `建議字顯示數量 = 0` behavior.

## Proposed solution / investigation plan

- Verify locally that `皔` appears through the `expandBetweenSearchClause(...)` partial/extension path, not a separate runtime suggestion path.
- Apply the fix on both Android and iOS.
- When Android `getSimilarCodeCandidates()` / iOS `similarCodeCandidatesCap` returns `0`, build an exact-only `selectClause` instead of calling `expandBetweenSearchClause(...)`, while preserving any exact-match remap conditions required by `extraExactMatchClause`.
- Update the positive-count limiting logic on both platforms so a partial-match candidate is counted and checked before it is added to `result`.
- Preserve exact-match candidates such as `白`.
- Verify that positive values allow the intended number of partial/next-code candidates without changing exact-match behavior or #49 partial-match score ordering.
- Consider adding focused Android instrumentation coverage for `getMappingByCode(...)` with `similiar_list=0` and a positive count, because the disabled behavior depends on both SQL clause construction and result limiting.

## Existing coverage and new tests needed

Android:

- Existing adjacent tests, not expected to fail from the fix:
  - `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`
    - Many `getMappingByCode(...)` smoke tests exist, but they do not currently set `similiar_list` or assert exact-vs-partial count behavior.
  - `LimeStudio/app/src/androidTest/java/net/toload/main/hd/SearchServerTest.java`
    - Partial-match cache/update tests exist for #49 behavior, especially `test_3_3_5_19_updateScoreCache_partial_match`, but they do not cover `similiar_list=0` query suppression.
- Add or update focused Android instrumentation tests:
  - Seed a test table with exact `ha -> 白` and extension `haa -> 皔`.
  - Set default shared preference `similiar_list` to `0`.
  - Assert `LimeDB.getMappingByCode("ha", true, false)` returns exact `白` and no partial `皔` / `haa`.
  - Set `similiar_list` to a positive value such as `1`.
  - Assert at most one partial/extension candidate is returned, preserving exact matches and #49 score ordering.

iOS:

- Existing adjacent tests, not expected to fail from the fix:
  - `LimeIME-iOS/LimeTests/SearchServerTest.swift`
    - `test_prefs_similiarEnable_false_zeroes_cap` verifies preference wiring to `similarCodeCandidatesCap = 0`.
    - `test_prefs_similiarList_propagates_when_enabled` verifies positive cap propagation.
    - These do not verify DB query suppression or partial-result limiting.
  - `LimeIME-iOS/LimeTests/LimeDBTest.swift`
    - Many `getMappingByCode(...)` smoke tests exist, but they do not currently assert `similarCodeCandidatesCap=0` exact-only behavior.
- Add focused iOS XCTest coverage:
  - Seed temporary DB table with exact `ha -> 白` and extension `haa -> 皔`.
  - Set `db.similarCodeCandidatesCap = 0`.
  - Assert `db.getMappingByCode("ha", softKeyboard: true, getAllRecords: false)` returns exact `白` and no partial `皔` / `haa`.
  - Set `db.similarCodeCandidatesCap = 1`.
  - Assert at most one partial/extension candidate is returned, preserving exact matches and #49 score ordering.

## Follow-up questions

No public follow-up is required before investigation. Maintainer `jrywu` has already explained in comment `4517136291` that `0` currently still emits one partial-match candidate and that a future change will make it truly `0`. He also advised that setting suggested candidates to `0` disables useful LIME learning/連打詞 workflows, but that product recommendation does not change the bug-fix requirement for the explicit setting value.

If local reproduction unexpectedly fails, ask the reporter to confirm the active table/input method and whether any custom table is involved.

## Verification plan

- Set `建議字顯示數量` / `similiar_list` to `0`.
- Type `ha` with the same or equivalent table.
- Confirm the candidate bar shows the composing code and exact match `白` but no partial `皔`/`haa` candidate.
- Set the value back to a positive value such as `10` or `20` and confirm partial/next-code candidates appear as expected.
- After a fix lands in a newer Android APK, ask `ejmoog` to retest #76; do not close until reporter confirmation or maintainer instruction.
