# Issue #76: extra next-code candidate still shown after #70 follow-up

## Problem statement

Community reporter `ejmoog` opened #76 after testing Android APK `LIMEHD2026-6.1.8.apk` and reported that the unwanted extra next-code / code-extension candidate remains visible. The report was split from #70, where the reporter asked to hide/configure the number of these extra candidates and later described the desired value as `0` for disabled.

Example from the report:

- Input code: `ha`.
- Desired candidate display: exact match `白` only, matching the reporter's gcin comparison screenshot.
- Actual candidate display in LIME: `白` plus an extra next-code / prefix-extension candidate `皔` (code `haa`).
- Comparison screenshots show gcin displaying only `白`, while LIME still displays the extra `皔` candidate.

The report strongly suggests the related display-count setting did not produce the expected "disabled" behavior, but the exact current preference value in the #76 screenshot still needs confirmation if the issue cannot be reproduced locally.

## Reproduction notes from current evidence

1. Install Android APK `6.1.8` on Android 15, matching the reporter's follow-up comment.
2. Use the Android soft keyboard with a Cangjie-style table where `ha` maps to `白` and `haa` maps to `皔`.
3. Configure `建議字顯示數量` / `similiar_list` to `0` if reproducing the disabled-count path.
4. Type `ha`.
5. Observe whether the candidate bar still includes one next-code / prefix-extension candidate after the exact match.

The reporter's screenshots are visual evidence only; the precise preference value used in the screenshot should still be confirmed if needed.

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

This appears to make the limit inclusive-after-add instead of pre-add. If `similiar_list` is the setting intended to control this code-extension display, then `sLimit == 0` can still allow the first partial-match record to be added before the loop breaks, and positive values may also allow one more partial-match record than the configured number.

## Likely root cause

Likely off-by-one / post-add limit check in `LimeDB.buildQueryResult(...)` for partial-match candidates, combined with the UI exposing `0` as a valid `建議字顯示數量` value. The expected product behavior is that `0` disables these extra next-code / prefix-extension candidates, while exact matches remain visible.

This should be verified with an Android test or manual repro using `similiar_list=0`; also verify that `similiar_list` is indeed the setting that governs the candidate shown in the reporter's screenshot.

## Proposed solution / investigation plan

- Verify locally that `皔` appears through the `similiar_list` / partial-match path, not a separate runtime suggestion path.
- Update the limiting logic so no partial-match candidate is added when `getSimilarCodeCandidates()` returns `0`.
- Preserve exact-match candidates such as `白`.
- Verify that positive values allow the intended number of partial/next-code candidates without changing exact-match behavior.
- Consider adding a focused unit/instrumentation test for `buildQueryResult(...)` or a lower-level query helper if feasible.

## Follow-up questions

No public follow-up is required before investigation, but if behavior cannot be reproduced locally, ask the reporter to confirm:

- The exact `建議字顯示數量` value they used while taking the LIME screenshot.
- The active table/input method and whether any custom table is involved.

## Verification plan

- Set `建議字顯示數量` / `similiar_list` to `0`.
- Type `ha` with the same or equivalent table.
- Confirm the candidate bar shows the composing code and exact match `白` but no partial `皔`/`haa` candidate.
- Set the value back to a positive value such as `10` or `20` and confirm partial/next-code candidates appear as expected.
- After a fix lands in a newer Android APK, ask `ejmoog` to retest #76; do not close until reporter confirmation or maintainer instruction.
