# #62 - Related phrase DB fails with Ext-B leading character

Issue: https://github.com/lime-ime/limeime/issues/62

## Problem statement
When adding/searching entries in the related-phrase database, operations fail if the **first character** of the phrase is a Unicode supplementary-plane character (e.g. CJK Ext-B like `𩼣魚`, `𨑨迌`, `𤆬人`). The UI error message shows tofu/unknown glyphs for that first character.

The reporter notes:
- If the Ext-B character is **not** the first character (placed in the middle/end), add/search succeeds.
- Ext-B characters can be added to IM tables and searched normally, so the failure appears specific to related-phrase handling.

## Current reporter status
- A 6.1.4 test APK was provided after commit `ec208105ce04f8536b85cdd0ee3eae641d309b54` (`fix(android): handle Ext-B related phrases`).
- Reporter confirmed add/search is now improved: Ext-B-leading related entries can be stored and retrieved.
- Reporter also found a remaining runtime issue: after typing/committing the Ext-B parent character `𩼣`, the related candidate `魚` does not appear; the related-candidate area is blank.

## Platform status
- **Android:** still affected in the runtime related-candidate suggestion path, even after the editor/search fix.
- **iOS:** previously confirmed **not affected** by user verification. The iOS related-phrase editor uses separate `parentWord` / `childWord` fields, and related search/runtime paths use Swift `String` character APIs such as `prefix(1)`, `dropFirst()`, `suffix(1)`, and `index(offsetBy:)`, which preserve Ext-B character boundaries.

## Initial root cause
Supplementary-plane characters are encoded as **UTF-16 surrogate pairs** in Java/Kotlin `String`. Any code that assumes "one character == length 1" or uses `substring(i, i+1)` / `charAt(i)` as a character iterator can split a surrogate pair and produce invalid/unpaired surrogate values.

This pattern existed in related-phrase code paths such as:
- phrase splitting when checking related-phrase existence
- loops that iterate by UTF-16 index and extract `word.substring(j, j + 1)`

Once a surrogate pair is split:
- lookups can fail,
- error messages show tofu,
- database query keys become inconsistent.

## Second-round root cause hypothesis
The 6.1.4 fix likely covered editor add/search paths but did not fully cover the runtime path that asks for related candidates after a parent word is committed.

The remaining failure is likely in one of these paths:
1. Runtime related lookup uses the last committed character by UTF-16 code unit rather than Unicode code point.
2. Related phrase lookup/query normalizes or stores parent/child words safely in the editor path, but runtime lookup still builds a different key for supplementary-plane parent words.
3. Candidate display receives a valid result but drops it because the related candidate type or parent/child split still assumes BMP characters.

## Proposed solution
1. Audit all runtime related-candidate lookup paths, not only the editor/import/search paths.
2. Replace any "last character" extraction with code-point safe logic:
   - `offsetByCodePoints(...)`
   - `codePointBefore(...)` / `codePointAt(...)`
   - `new String(Character.toChars(cp))`
3. Ensure DB query keys for related parent words match the exact Unicode scalar sequence stored by the editor.
4. Add regression coverage for both storage/search and runtime suggestion display:
   - `𩼣` as parent, `魚` as child
   - Ext-B parent followed by BMP child
   - Ext-B in middle/end as a control case

## Follow-up questions for reporter
- Confirm whether the blank related-candidate area happens immediately after selecting/committing `𩼣`, or only after typing a following key.
- Ask whether any BMP-parent related entries still display normally in the same table after 6.1.4.
- If possible, ask for a small exported related table sample containing the `𩼣 -> 魚` entry.

## Verification plan
- On Android 6.1.4 or a debug build after the next fix, add related phrase entry `𩼣 -> 魚`.
- Verify editor insert succeeds and search finds the row.
- Commit `𩼣` from the IM table and verify `魚` appears as a related candidate.
- Repeat with a BMP parent entry to confirm no regression.
- Run unit/instrumentation coverage around related phrase lookup and candidate rendering for supplementary-plane parent words.
