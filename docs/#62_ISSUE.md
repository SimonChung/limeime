# #62 — Related phrase DB fails with Ext-B leading character

Issue: https://github.com/lime-ime/limeime/issues/62

## Problem statement
When adding/searching entries in the related-phrase database, operations fail if the **first character** of the phrase is a Unicode supplementary-plane character (e.g. CJK Ext-B like `𩼣魚`, `𨑨迌`, `𤆬人`). The UI error message shows tofu/unknown glyphs for that first character.

The reporter notes:
- If the Ext-B character is **not** the first character (placed in the middle/end), add/search succeeds.
- Ext-B characters can be added to IM tables and searched normally, so the failure appears specific to related-phrase handling.

## Platform status
- **Android:** affected. The related-phrase editor/search/runtime paths used UTF-16 index slicing in Java, which can split an Ext-B leading character.
- **iOS:** confirmed **not affected** by user verification. The iOS related-phrase editor uses separate `parentWord` / `childWord` fields, and the related search/runtime paths use Swift `String` character APIs such as `prefix(1)`, `dropFirst()`, `suffix(1)`, and `index(offsetBy:)`, which preserve the Ext-B character boundary.

## Likely root cause
Supplementary-plane characters are encoded as **UTF-16 surrogate pairs** in Java/Kotlin `String`. Any code that assumes "one character == length 1" or uses `substring(i, i+1)` / `charAt(i)` as a character iterator will split a surrogate pair and produce invalid/unpaired surrogate values.

This pattern already exists in `SearchServer.java` where phrases are split using UTF-16 indices, e.g.:
- `phrase.substring(...)` when checking related-phrase existence (risk: splitting a surrogate pair)
- loops that do `word.substring(j, j + 1)` (risk: splitting a surrogate pair)

Once a surrogate pair is split:
- lookups can fail (the “character” is not a valid code point),
- error messages show tofu (rendering replacement glyph),
- database queries/keys become inconsistent.

## Proposed solution
1. Audit related-phrase code paths to remove UTF-16-index “character” slicing:
   - anywhere we compute `pword` / `cword` by `substring(..., ...+1)`
   - any loops that iterate with `for (int i=0; i<s.length(); i++)` and use `substring(i,i+1)` or `charAt(i)`
2. Replace with code-point safe operations:
   - Use `offsetByCodePoints` to compute boundaries.
   - Or convert to an `int[] cps = s.codePoints().toArray()` and slice by code-point indices.
   - When extracting a single “character”, build with `new String(Character.toChars(cp))`.
3. Add regression tests (unit test or instrumentation) covering:
   - related phrase add/update/search when `pword` starts with an Ext-B code point
   - mixed BMP + supplementary cases (Ext-B in middle/end)

## Follow-up questions for reporter
- Which Android version and device model?
- Exact steps in UI (“管理關聯字庫”): add vs search vs both fail?
- Please attach the exact error text/logcat if available (it may point to the failing query).

## Verification plan
- On a device/emulator, add related phrase entries where `pword` begins with an Ext-B character (e.g. `𩼣魚` → `很好吃`).
- Verify:
  - insert succeeds
  - subsequent search by pword succeeds
  - list renders the character correctly (no tofu)
  - related phrase suggestions / runtime checks (if applicable) don’t crash or corrupt data
