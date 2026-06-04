# #96 — Table IM Lime end-key behavior

## Live issue state

- Issue: https://github.com/lime-ime/limeime/issues/96
- Status: open
- Current labels: `bug`, `enhancement`, `question`, `Usability`
- Assignee: `jrywu`
- Reporter: `SmithCCho`
- Community context: #95 was consolidated into #96 for the `%endkey ,.` / punctuation-commit discussion.

## Problem statement

Implement generic, opt-in Lime end-key behavior for table IMs without changing candidate ordering or adding punctuation-specific handling.

- Android keeps conventional `.cin %endkey` / `.lime @endkey@` as compatibility metadata only.
- LimeIME runtime commit behavior uses Lime-specific metadata: `.cin %limeendkey ...` and `.lime @limeendkey@ |...`.
- Configured Lime end-key characters should finish the current composition and commit through the same candidate-confirm semantics as existing confirmation keys, even if the asynchronous candidate strip has not yet marked candidates as shown.
- Tables without Lime end-key metadata remain unchanged. Keys such as `,` and `.` may still be ordinary roots/composing codes.
- Search/candidate construction must not special-case Chinese punctuation for this feature.

## Android implementation status

Implemented and merged to `master` via PR #101 (`43aa6c887d9eebf162891549d0ef04fca9b6fe50`) with the current Android test APK file `LIMEHD2026-6.1.15.apk` in `LimeStudio/app/release/`.

Feature scope:

- Android imports and persists `.cin %endkey` / `.lime @endkey@` as conventional compatibility metadata.
- Android imports and persists `.cin %limeendkey` / `.lime @limeendkey@` as Lime runtime commit metadata.
- LIME Settings IM detail shows an editable `limeendkey` metadata row labeled `結束鍵`.
- Android runtime treats the active table's configured Lime end-key characters as opt-in commit triggers and resolves the current composing candidates when needed before committing.
- Tables without Lime end-key metadata remain unchanged; roots are not globally converted or reordered.

Official table-data scope:

- This branch implements engine/settings support only. Packaged Android table data is represented by database resources rather than editable `.cin`/`.lime` source tables in this branch, so official table metadata/mapping updates are deferred to separate table-data release coordination.
- iOS/table-format parity remains pending and should align with the Android implementation when addressed.

## Reporter and maintainer clarifications

- Original report asked whether Chinese keyboard punctuation order can prefer full-width `，` / `。`.
- `Limeroshenko` noted a workaround by manually adding table mappings such as `,= ，` and `.= 。`, then warned that some long-time users use `,` and `.` as custom roots or short-phrase codes.
- `Limeroshenko` later clarified that the current official 行列10 `.lime` table does not contain the punctuation mapping rows; adding `,|，` and `.|。` enables the existing comma-plus-Space path, and if `.lime @endkey@` support is implemented they suggested making official Array10 opt in with `@endkey@ |,.` plus those punctuation mappings.
- `SmithCCho` later clarified:
  - 行列30 and 大易 use `,` / `.` as roots, so they should not directly output punctuation.
  - 行列10, 嘸蝦米, and 倉頡 are closer to direct punctuation output expectations.
  - A practical distinction is whether `,` / `.` are defined as roots in the table.
- Android now separates conventional `%endkey` / `@endkey@` metadata from the Lime-specific `%limeendkey` / `@limeendkey@` runtime feature mechanism to avoid conflict with historical CIN semantics.

## Source evidence inspected

Android candidate construction in the inspected path creates a composing-code `Mapping` and adds it before database results:

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

## Proposed solution / investigation plan

1. Add metadata parsing/runtime support for explicit Lime end-key behavior:
   - `.cin`: `%limeendkey ...`
   - `.lime`: `@limeendkey@` equivalent.
2. Preserve conventional `%endkey` / `@endkey@` as imported/exported compatibility metadata.
3. Keep candidate-list ordering unchanged. The composing-code fallback remains item 0.
4. For tables with any potential end-key character as a root, do not put that character in Lime end-key metadata unless the table intentionally opts in.

## Verification plan

- Android table using `,` / `.` as roots:
  - Verify root input remains available and direct punctuation behavior is not forced.
- `%limeendkey ,.` / `@limeendkey@` feature:
  - Import a `.cin` with `%limeendkey ;/`.
  - Import a `.lime` equivalent with `@limeendkey@ |;/`.
  - Verify pressing configured end-key characters commits according to table metadata without requiring extra Space/Enter.
- Regression:
  - Confirm existing custom `,` / `.` root/short-phrase mappings still work when Lime endkey is not configured.
  - Confirm endkey resolves candidates for the exact current composing buffer and does not consume a stale prefix candidate from an older candidate strip update.

## Platform impact analysis

### Android

Confirmed relevant platform for #96. Android runtime/settings/import support is implemented for Lime-specific end-key metadata without SearchServer candidate-order changes.

### iOS / table format

The Lime-specific table-format feature request (`%limeendkey ...` and `.lime @limeendkey@`) can affect both Android and iOS if both platforms import and honor the same table metadata. iOS parity should be assessed separately and aligned with Android later.

## Follow-up status

- Public clarification posted: https://github.com/lime-ime/limeime/issues/96#issuecomment-4556916179
- Current classification: enhancement/product work for generic table IM end-key behavior.
- Android retest request posted: https://github.com/lime-ime/limeime/issues/96#issuecomment-4624478044
- Current next action: wait for Android feedback on the opt-in Lime end-key behavior in the current test APK; address iOS/table-data coordination later.
