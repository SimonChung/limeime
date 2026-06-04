# Issue #93: .lime import metadata and installed-list registration issues

## Problem statement

Maintainer-created tracking issue #93 originally reported that on iOS, importing a `.lime` text table without `@cname@` / `%cname` metadata could finish successfully while the imported table did not appear in the installed input-method list. The IM catalog could still mark the same table as installed because it detects mapping data separately.

Follow-up maintainer context added an Android scope: Android could import a `.lime` file containing `@version@` and `@cname@`, but cname/version metadata might not be read or saved correctly when the file included Array10-style `#` comment lines before metadata rows.

## Current classification

- Type: bug / usability
- Platform: iOS and Android
- Reporter/source: maintainer-created (`limeimetw`)
- Live labels: `bug`, `Usability`
- Live assignee: `jrywu`
- Public maintainer context: https://github.com/lime-ime/limeime/issues/93#issuecomment-4556745511 recorded the Android metadata parsing scope.
- Closure: #93 is closed as completed. Maintainer/automation closure comment: https://github.com/lime-ime/limeime/issues/93#issuecomment-4625074355.

## Implementation and closure status

Fixed on `master` by PR #101 merge commit `43aa6c887d9eebf162891549d0ef04fca9b6fe50` (`android ios fix #90 #91 #93 #94 #96 #99 #100: merge next release updates`).

- Android `.lime` delimiter detection now ignores blank/comment lines so leading Array10-style `#` comments do not skew parsing.
- Android `.lime` parsing skips `#` comment lines and persists `@cname@` / `@version@` metadata.
- Android regression coverage imports an Array10-style `.lime` fixture with comments and verifies metadata persistence.
- iOS imported `.lime` tables without cname metadata now remain visible in the installed IM list by using a safe IM full-name fallback.
- iOS `.lime` export now includes IM table metadata so re-imported tables can preserve display metadata.
- Because this is a maintainer-created internal tracking issue, no community retest request is needed.

## Code paths inspected

- `LimeIME-iOS/Shared/Database/LimeDB.swift`
  - `importTxtFile(at:tableName:progress:)` parses `@version@`, `@cname@`, `%version`, and `%cname`; version/cname metadata cross-populates the display-name fallback, and `sourceName` is used when no usable version/name metadata is available.
  - Before the fix, the text-import path could write mappings and metadata without ensuring the installed-list query had a usable display/registration fallback.
- `LimeIME-iOS/LimeSettings/Controllers/ManageImController.swift` / iOS installed-list code
  - The fix aligns imported-table visibility with the catalog/data state so successful text imports appear in the installed IM list.
- `LimeIME-iOS/LimeSettings/Views/IMInstallView.swift`
  - Text-import completion and catalog refresh needed to agree with installed-list visibility.
- Android `.lime` / `.cin` import path
  - The fix documents and tests `.lime` `#` lines as parser comments and preserves `@cname@` / `@version@` metadata after successful import.

## Root cause summary

### iOS installed-list registration

The iOS text-import path could persist table data/metadata without enough installed-list metadata for the imported table to surface in the installed IM list. This made the catalog and installed-list views disagree: the catalog saw imported mapping rows, but the installed-list path lacked a safe display/registration fallback. PR #101 fixes the visible installed-list path for no-cname `.lime` imports by using a full-name fallback and aligns metadata handling for exported/re-imported `.lime` tables.

### Android metadata parsing / persistence

The Android failure path was separate: successful `.lime` import could miss `@version@` / `@cname@` when `#`-prefixed lines affected parsing/delimiter detection. PR #101 makes `.lime` comment handling explicit and verifies metadata persistence with an Array10-style fixture.

## Verification plan / release QA

The source fix is complete and the issue is closed. Remaining checks are release QA, not an active public issue watch:

- Android: import an Array10-style `.lime` file with multiple `#` comment lines plus `@version@` and `@cname@`; confirm `#`-prefixed lines are skipped and cname/version metadata are read and saved.
- Android: verify the behavior in the current test APK line that contains PR #101 (`LIMEHD2026-6.1.16.apk` or newer).
- iOS: import a `.lime` file without `@cname@` / `%cname`; confirm the imported table appears in the installed IM list with a non-empty fallback display name.
- iOS: confirm the IM catalog installed marker and installed IM list agree after text import.
- iOS: confirm the imported IM can be enabled/disabled and selected/used by the keyboard in the next TestFlight/App Store QA pass.
- Regression-check `.lime` / `.cin` files that include `@cname@`, `%cname`, `@version@`, or `%version` metadata.

## Follow-up status

Closed/completed as a maintainer-created internal tracking issue after PR #101 merged to `master`. Do not reopen or post routine public retest requests unless new evidence appears or a maintainer asks for additional tracking. Android verification can use the current test APK line; iOS verification remains part of normal TestFlight/App Store release QA.
