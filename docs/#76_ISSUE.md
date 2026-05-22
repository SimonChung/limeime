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

## Code inspection

Relevant Android preference and query paths on `master`:

- `LimeStudio/app/src/main/res/values/strings_settings.xml`
  - `similiar_list` is titled `建議字顯示數量`.
  - `similiar_codes` includes `0`, `10`, `20`, `30`, `40`, `50`.
- `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEPreferenceManager.java`
  - `getSimilarCodeCandidates()` reads `similiar_list`, defaulting to `20`.
- `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
  - `buildQueryResult(...)` reads `int sLimit = mLIMEPref.getSimilarCodeCandidates();`.
  - For non-exact / partial-match records, it currently adds the mapping to `result`, then increments `sCount`, then breaks if `sCount > sLimit`.

This appears to make the limit inclusive-after-add instead of pre-add. The code inspection maps the product setting `建議字顯示數量` to `similiar_list`; maintainer comment `4517136291` confirms the observed product behavior that setting the count to `0` still sends one `ha*` partial-match candidate today, and the fix direction is to make `0` truly suppress those partial/extension candidates. Positive values may also allow one more partial-match record than the configured number and should be checked.

## Likely root cause

Likely off-by-one / post-add limit check in `LimeDB.buildQueryResult(...)` for partial-match candidates, combined with the UI exposing `0` as a valid `建議字顯示數量` value. The expected product behavior is that `0` disables these extra next-code / prefix-extension candidates, while exact matches remain visible.

This should be verified with an Android test or manual repro using `similiar_list=0`; the internal `similiar_list` / `buildQueryResult(...)` path remains a code-inspection inference, while the maintainer comment confirms the product-level `建議字顯示數量 = 0` behavior.

## Proposed solution / investigation plan

- Verify locally that `皔` appears through the `similiar_list` / partial-match path, not a separate runtime suggestion path.
- Update the limiting logic so no partial-match candidate is added when `getSimilarCodeCandidates()` returns `0`.
- Preserve exact-match candidates such as `白`.
- Verify that positive values allow the intended number of partial/next-code candidates without changing exact-match behavior.
- Consider adding a focused unit/instrumentation test for `buildQueryResult(...)` or a lower-level query helper if feasible.

## Follow-up questions

No public follow-up is required before investigation. Maintainer `jrywu` has already explained in comment `4517136291` that `0` currently still emits one partial-match candidate and that a future change will make it truly `0`. He also advised that setting suggested candidates to `0` disables useful LIME learning/連打詞 workflows, but that product recommendation does not change the bug-fix requirement for the explicit setting value.

The learned-word / association / ranking-control complaint should be treated as related product/usability context rather than as evidence that the planned count-bug fix would also address learned-word, association, ranking, or deletion behavior. The reporter's latest settings screenshot shows the relevant learning/association/ranking toggles unchecked, while maintainer comment `4519607485` says the behavior is not considered a bug and points to existing disable/delete controls. Next investigation should distinguish:

- newly learned words being created despite disabled settings;
- old learned/table entries still being displayed because they already exist;
- relation/association candidates coming from another setting path;
- ranking/order changes caused by selection-history data despite `啟動選取排序` being off.

After the `similiar_list=0` bug is fixed, decide whether to keep learned-word delete/disable controls in #76 or split them into a separate enhancement/usability tracking item so the retest request can ask about the candidate-count bug without overclaiming a broader learning/ranking redesign.

If local reproduction unexpectedly fails, ask the reporter to confirm the active table/input method and whether any custom table is involved.

## Verification plan

- Set `建議字顯示數量` / `similiar_list` to `0`.
- Type `ha` with the same or equivalent table.
- Confirm the candidate bar shows the composing code and exact match `白` but no partial `皔`/`haa` candidate.
- Set the value back to a positive value such as `10` or `20` and confirm partial/next-code candidates appear as expected.
- After a fix lands in a newer Android APK, ask `ejmoog` to retest #76; do not close until reporter confirmation or maintainer instruction.
