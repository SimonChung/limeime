# #96 — Chinese keyboard comma/period punctuation and end-key behavior

## Live issue state

- Issue: https://github.com/lime-ime/limeime/issues/96
- Status: open
- Current labels: `bug`, `enhancement`, `question`, `Usability`
- Reporter: `SmithCCho`
- Community context: #95 was consolidated into #96 for the `%endkey ,.` / punctuation-commit discussion.

## Problem statement

The discussion has two related but separate scopes:

1. **Bug scope — direct punctuation mappings should be selectable correctly.**
   When an IM table defines direct mappings such as `, = ，` and `. = 。`, LIME should highlight/select the first direct match (`，` / `。`) instead of leaving the composing-code record (`，` candidate path represented by the typed code) as the effective first selection. Simply swapping `,` with `，` in the candidate order is not the right model because the first row is generally a composing-code record, not an ordinary candidate.

2. **Feature scope — `%endkey ,.` / `@endkey@` support.**
   Some table IMs expect `,` and `.` to finish composition directly when the table also maps them to `，` and `。`. This requires explicit end-key metadata, for example `.cin` `%endkey ,.` and a future `.lime` `@endkey@` equivalent. Tables that use `,` / `.` as roots, such as 行列30 or 大易, must not opt into those end keys because direct punctuation output would break root/short-phrase compatibility.

## Reporter and maintainer clarifications

- Original report asked whether Chinese keyboard punctuation order can prefer full-width `，` / `。`.
- `Limeroshenko` noted a workaround by manually adding table mappings such as `,= ，` and `.= 。`, then warned that some long-time users use `,` and `.` as custom roots or short-phrase codes.
- `SmithCCho` later clarified:
  - 行列30 and 大易 use `,` / `.` as roots, so they should not directly output punctuation.
  - 行列10, 嘸蝦米, and 倉頡 are closer to direct punctuation output expectations.
  - A practical distinction is whether `,` / `.` are defined as roots in the table.
- Maintainer clarification posted in https://github.com/lime-ime/limeime/issues/96#issuecomment-4556916179 records that direct-match highlighting is a bug, while `%endkey ,.` / `@endkey@` is the compatible feature mechanism.

## Source evidence inspected

Android candidate construction currently always creates a composing-code `Mapping` and adds it before database results:

- `LimeStudio/app/src/main/java/net/toload/main/hd/SearchServer.java`
  - `getMappingByCode(...)` creates `self`, sets `word = code`, `code = code`, and marks it with `setComposingCodeRecord()`.
  - The method then normally `result.add(self)` before `result.addAll(resultlist)`.
  - This means exact direct mappings from the table can be present but still appear after the composing-code record.

Relevant code area on current `master`:

- `SearchServer.java` lines 1018–1022: creates the composing-code `self` record.
- `SearchServer.java` lines 1058–1073: adds `self` before a runtime/English suggestion or as the first result.
- `SearchServer.java` lines 1076–1078: appends database mapping results after `self`.
- `SearchServer.java` lines 1124–1139: cache/DB lookup returns the actual table mappings for the typed code.

Commit behavior confirms why the highlighted/selected candidate matters:

- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
  - `commitTyped(...)` commits `selectedCandidate.getWord()`.

Relevant code area on current `master`:

- `LIMEService.java` lines 1664–1678: `commitTyped(...)` requires a selected candidate and commits its `word`.

## Likely root cause

The direct-match bug is likely caused by candidate list construction placing the composing-code record before exact table mappings for all one-key inputs, including punctuation keys. For codes such as `,` or `.`, if the DB returns exact mappings to `，` or `。`, the selection/highlight logic still sees the composing-code record first.

This should not be fixed by globally swapping punctuation candidates. The fix should distinguish ordinary composing-code fallback from exact direct mappings that should be selected first for that table.

## Proposed solution / investigation plan

1. Add or adjust candidate-order logic so exact direct matches for `,` / `.` can be highlighted/selected ahead of the composing-code fallback when the active table defines those mappings.
2. Preserve compatibility for tables where `,` / `.` are roots or short-phrase codes. Do not globally force punctuation output.
3. Add metadata parsing/runtime support for explicit end-key behavior:
   - `.cin`: `%endkey ,.`
   - `.lime`: `@endkey@` equivalent
4. For tables with `,` / `.` as roots, do not put those keys in endkey metadata. Direct `，` / `。` output should remain unavailable unless the table explicitly opts in.

## Verification plan

- Android table with direct mappings only:
  - Add/import mappings `, = ，` and `. = 。`.
  - Type `,` and `.`.
  - Verify the first direct match `，` / `。` is highlighted/selected instead of the composing-code record.
- Android table using `,` / `.` as roots:
  - Verify root input remains available and direct punctuation behavior is not forced.
- `%endkey ,.` / `@endkey@` feature:
  - Import a `.cin` with `%endkey ,.` plus punctuation mappings.
  - Import a `.lime` equivalent once supported.
  - Verify pressing `,` / `.` commits according to the table metadata without requiring extra Space/Enter.
- Regression:
  - Confirm existing custom `,` / `.` root/short-phrase mappings still work when endkey is not configured.

## Platform impact analysis

### Android

Confirmed relevant platform for #96. The inspected Android search/candidate path shows a plausible mechanism for the direct-match bug: composing-code `self` is inserted ahead of exact table mappings.

### iOS / table format

No concrete iOS runtime evidence has been inspected for the same highlight behavior yet. The table-format feature request (`%endkey ,.` and `.lime @endkey@`) can affect both Android and iOS if both platforms import and honor the same table metadata. iOS parity should be assessed separately before claiming the Android candidate-order bug exists there.

## Follow-up status

- Public clarification posted: https://github.com/lime-ime/limeime/issues/96#issuecomment-4556916179
- Current classification: mixed bug + enhancement/product work.
- Next action: implement/fix Android direct-match candidate selection first, then design `%endkey ,.` / `.lime @endkey@` support without breaking tables that use `,` / `.` as roots.
