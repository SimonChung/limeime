# Issue #76: extra next-code candidate still shown after #70 follow-up

## Problem statement

Community reporter `ejmoog` opened #76 after testing Android APK `LIMEHD2026-6.1.8.apk` and reported that the unwanted extra next-code / code-extension candidate remains visible. The report was split from #70, where the reporter asked to hide/configure the number of these extra candidates and later described the desired value as `0` for disabled.

Example from the report:

- Input code: `ha`.
- Desired candidate display: exact match `白` only, matching the reporter's gcin comparison screenshot.
- Actual candidate display in LIME: `白` plus an extra next-code / prefix-extension candidate `皔` (code `haa`).
- Comparison screenshots show gcin displaying only `白`, while LIME still displays the extra `皔` candidate.

The issue body and screenshots show the extra next-code candidate symptom after version 6.1.8; the specific display-count / disabled-setting connection is confirmed by maintainer comment `4517136291`, which says that when the suggested-candidate count is set to `0`, the current implementation still sends one `ha*` partial-match candidate, and that the intended follow-up is to make `0` truly mean zero partial/extension candidates.

## Reproduction notes from current evidence

1. Install Android APK `6.1.8` on Android 15, matching the reporter's follow-up comment.
2. Use the Android soft keyboard with a Cangjie-style table where `ha` maps to `白` and `haa` maps to `皔`.
3. Configure `建議字顯示數量` / `similiar_list` to `0` if reproducing the disabled-count path.
4. Type `ha`.
5. Observe whether the candidate bar still includes one next-code / prefix-extension candidate after the exact match.

The reporter's screenshots are visual evidence. The exact setting value used in the screenshot is still inferred from the #70/#76 discussion and the single-extra-candidate behavior, but maintainer comment `4517136291` confirms the product-level `建議字顯示數量 = 0` path currently still emits one `ha*` partial-match candidate.

Reporter follow-up comment `4519464729` adds an adjacent learned-word / association / ranking-control concern: the reporter showed LIME suggesting or learning `重要` when typing `重`, said they do not know when that learned word was created or how to delete it, and requested a way to disable self-learned words, association/related candidates, and automatic ranking changes. That comment broadens the product/usability discussion but does not invalidate the narrower confirmed implementation bug: `建議字顯示數量 = 0` should still suppress next-code / partial-match candidates while preserving exact matches.

Community comment `4519546693` suggested turning off `自動學習新詞`. Maintainer comment `4519607485` separately says the reporter can turn off `關聯字` and `學習段落` features in 6.1 preferences and use the table editor to delete table contents; the maintainer also stated that they do not consider this learned-word / association behavior itself to be a bug. The reporter then replied in comment `4519615053` that they had already disabled the relevant settings, insisted it is a bug, and attached a preferences screenshot; visual inspection of that screenshot shows unchecked boxes for `啟用關聯字庫`, `啟動自建關聯字`, `自動學習新詞`, and `啟動選取排序`. This latest evidence means the learned-word / suggestion complaint should not be dismissed as simply `自動學習新詞` still being enabled, but there is an unresolved reporter/maintainer disagreement about whether it should be treated as a bug versus product behavior/enhancement. It needs separate confirmation of whether existing learned/table entries, relation candidates, or another suggestion/ranking path can still surface `重要` after those toggles are off.

Reporter comment `4519684121` further says they are sure `自動學習新詞` was turned off immediately after installing LIME or was never enabled, and objects to framing the report as a misuse of LIME or physical-keyboard thinking. Treat this as reporter-friction/product-tone context and additional evidence that the learned-word/association/ranking path needs investigation without another public boilerplate reply.

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

## Implemented fix

Commit `7e1d57b` implements the planned exact-only behavior for disabled similar-code candidates on both Android and iOS, adds focused tests for the zero-cap path and cap boundary behavior, and updates async iOS test stabilization. APK metadata now points to `LIMEHD2026-6.1.9.apk`, which contains the fix for Android retesting.

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

## Fix / APK / follow-up status

Commit `7e1d57bdf6cc026d5d32e5fb670a7cebb6d316b9` fixed the confirmed `similiar_list = 0` / exact-match-only bug for Android and iOS database lookup paths by suppressing partial-match lookup when the configured cap is zero or lower, correcting partial-match cap handling, and adding Android/iOS tests. The repository then added Android release APK `LIMEHD2026-6.1.9.apk`, which contains this fix.

GitHub auto-closed #76 through the fixing commit, but because #76 is community-reported and the reporter has not yet confirmed the APK result, Hermes reopened the issue and posted retest request `4519807270` with the direct 6.1.9 APK link. Current public follow-up state: open / pending reporter confirmation for the `建議字顯示數量 = 0` exact-match-only behavior.

The learned-word / association / ranking-control concern remains separate from the fixed `similiar_list = 0` candidate-count bug. Do not imply that APK 6.1.9 fixes the learned-word/delete/ranking-control complaint unless separately verified.

## Follow-up questions

Public follow-up for the confirmed candidate-count bug has now been posted after the fix reached APK 6.1.9. Maintainer `jrywu` had explained in comment `4517136291` that `0` previously still emitted one partial-match candidate and that a future change would make it truly `0`. He also advised that setting suggested candidates to `0` disables useful LIME learning/連打詞 workflows, but that product recommendation does not change the bug-fix requirement for the explicit setting value.

The learned-word / association / ranking-control complaint should be treated as related product/usability context rather than as evidence that the planned count-bug fix would also address learned-word, association, or ranking behavior. The reporter's latest settings screenshot shows the relevant learning/association/ranking toggles unchecked, so next investigation should distinguish:

- newly learned words being created despite disabled settings;
- old learned/table entries still being displayed because they already exist;
- relation/association candidates coming from another setting path;
- ranking/order changes caused by selection-history data despite `啟動選取排序` being off.

After the `similiar_list=0` bug is fixed, decide whether to keep learned-word delete/disable controls in #76 or split them into a separate enhancement/usability tracking item so the retest request can ask about the candidate-count bug without overclaiming a broader learning/ranking redesign.

If local reproduction unexpectedly fails, ask the reporter to confirm the active table/input method and whether any custom table is involved.

## Current follow-up status

APK `LIMEHD2026-6.1.9.apk` / version `6.1.9` now contains the targeted fix for the `建議字顯示數量 = 0` next-code / partial-match candidate bug. The issue was reopened and a retest request was posted in comment `4519807270`:

- https://github.com/lime-ime/limeime/issues/76#issuecomment-4519807270
- APK: https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.9.apk

Retest scope is intentionally narrow: ask the reporter to verify that with `建議字顯示數量 = 0`, typing `ha` preserves the exact candidate `白` and no longer shows the extension candidate `皔` / `haa`. The separate learned-word / association / ranking-control concern remains open for follow-up and should not be claimed fixed by the 6.1.9 APK unless independently verified. Do not close #76 until reporter confirmation or maintainer instruction.

## Verification plan

- Set `建議字顯示數量` / `similiar_list` to `0`.
- Type `ha` with the same or equivalent table.
- Confirm the candidate bar shows the composing code and exact match `白` but no partial `皔`/`haa` candidate.
- Set the value back to a positive value such as `10` or `20` and confirm partial/next-code candidates appear as expected.
- APK `LIMEHD2026-6.1.9.apk` / version `6.1.9` retest request is already posted in comment `4519807270`; wait for `ejmoog` to confirm whether `ha` now shows only exact candidate `白` and no partial `皔` / `haa`. Do not close until reporter confirmation or maintainer instruction.

## 6.1.9 APK follow-up

Android APK `LIMEHD2026-6.1.9.apk` includes commit `7e1d57b` (`Fix #76: suppress partial matches when similar_list is disabled`), which implements the exact-match-only behavior for `建議字顯示數量` / `similiar_list = 0` on Android and iOS and fixes the positive partial-match cap boundary.

Because #76 is community-reported and was closed/reopened around the fixing commit before reporter validation, the issue should remain open until `ejmoog` confirms the Android APK result or the maintainer explicitly decides otherwise. A scoped retest request was posted in comment `4519807270` with direct APK link `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.9.apk`. Live comment re-read shows the concurrent duplicate retest comment `4519808965` is absent, so no further duplicate cleanup is currently needed.

Retest scope for this APK is intentionally narrow: verify that with `建議字顯示數量 = 0`, typing `ha` shows the exact candidate such as `白` but no extension/partial candidate such as `haa` / `皔`. The adjacent learned-word / association / ranking-control concern is not claimed fixed by this APK and still needs separate product/bug classification if further action is needed.
