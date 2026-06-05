# LIME IME Backlog

Public backlog for confirmed pending fixes and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-05

## Completed / release-ready source fixes

- #86 — iOS — keyboard extension should see restored IM tables immediately after successful DB restore
  - Status: Completed and verified (full-app build succeeds).
  - Current state: After a Settings-app DB restore, the keyboard extension now reopens its own `DBServer.shared` connection (`reopenDatabaseFromDisk()` / `prepareKeyboardRuntimeDatabase(forceReopen:)`) instead of reusing a GRDB queue bound to the pre-restore file inode, so restored IMs appear without removing/re-adding the system keyboard. Stale index-based `keyboard_state` is ignored on reopen and the activated list is rebuilt from the restored enabled IMs. Related iOS alignment: phonetic auto-seed and the bundled `phonetic.db` copy phase were removed, and the fabricated fallback IM list was dropped, so iOS now matches Android (restore-to-default → empty IM list, keyboard runs English-only until an IM is installed).
  - Follow-up: Ship in the next iOS build; on-device retest of restore-from-backup and restore-to-default per `docs/#86_ISSUE.md` verification steps.

- #91 — Android — `.cin` import should preserve duplicate-code candidate order from the source file
  - Status: Completed and verified in the Android next-release work.
  - Current state: Android import/search ordering now preserves source insertion order for same-code candidates when selection sorting is disabled.
  - Follow-up: Android test APK `LIMEHD2026-6.1.16.apk` is available; reporter retest is pending in #91 with the scoped `vmi` / 哈哈倉頡 order check.

- #94 / PR #101 — Android — backup must not create a 0 B `limeBackup.zip` while reporting success
  - Status: Completed, shipped in Android test APK `LIMEHD2026-6.1.16.apk`, and reporter-confirmed fixed; PR #97 is superseded by the newer batched PR/work.
  - Current state: Backup no longer treats a missing transient SQLite rollback journal as fatal, backup success/failure is reported consistently, and reporter `ejmoog` confirmed `6.1.16` backup and restore are usable.
  - Follow-up: Closed/completed for the verified Android backup/restore scope; no active retest watch unless reopened or new evidence appears.

- #93 — Android + iOS — `.lime` metadata, fallback names, and installed IM visibility
  - Status: Completed and verified/aligned.
  - Current state: Android `.lime` import reads/persists metadata such as `@cname@` and `@version@`, including files with comment lines. iOS imported `.lime` tables without cname metadata now remain visible in the installed IM list by using the IM full-name fallback. iOS `.lime` export also includes IM table metadata.
  - Follow-up: Ship in the next Android/iOS builds and retest with no-cname `.lime` files.

- #96 — Android + iOS/table-format — direct punctuation matches and LIME end-key behavior for table IMs
  - Status: Completed and verified/aligned.
  - Current state: Direct `,` / `.` mappings highlight/select the direct full-width punctuation match before the composing-code fallback. LIME-specific end-key metadata uses `limeendkey` instead of conflicting with conventional `.cin` `%endkey`; the distinction is behavioral (`%endkey` ends composition/shows candidates without committing, while `%limeendkey` ends composition and commits the highlighted candidate). Android and iOS runtime behavior is aligned.
  - Follow-up: Table-data changes for official tables, if any, should be coordinated separately from the engine feature.

- #100 — iOS — contextual Enter/Send key should not become light-on-light in light theme
  - Status: Completed and verified.
  - Current state: iOS contextual return-key states such as Send/Search/Go/Next/Done restore the correct readable foreground/background pairing after touch release/cancel.
  - Follow-up: Keep `docs/keyboard-type-field-test.html` available for visual checks of contextual return-key fields.

- #103 — Android — English prediction should keep the typed word visible when no dictionary alternatives remain
  - Status: Source fix completed by maintainer in `794f741e6102cdf1c0db82f5cc6ea6280d2d5029`.
  - Current state: Android English prediction now keeps the composing/self candidate visible for exact-only words such as `salt`, uses a no-default-highlight candidate display path for English prediction, and orders dictionary suggestions by existing row/rank order instead of plain alphabetical order.
  - Follow-up: Not included in the current Android APK `LIMEHD2026-6.1.16.apk`; ask reporter `SmithCCho` for a scoped retest only after a newer APK contains this commit.

- #90 — Android — keyboard theme should optionally follow system accent/dynamic colors
  - Status: Completed and visually verified in the Android next-release work.
  - Current state: Android follow-system keyboard/settings UI now applies the system accent/dynamic color where appropriate while preserving fixed theme behavior.
  - Follow-up: Keep the broader #90 button/layout customization requests out of backlog until product direction is confirmed.

- #99 — Android + iOS — shifted keyboard layouts should hide non-alphabet IM root labels
  - Status: Completed and verified/aligned.
  - Current state: Shifted layouts remove misleading IM root labels from non-alphabet shifted symbol keys while preserving meaningful alphabet/root labels. Input handling, composing-code logic, candidate lookup, and Shift/caps-lock behavior remain unchanged.
  - Follow-up: Ship as layout-only behavior in the next Android/iOS builds.

- Unfiled — Android + iOS — simplify Shift key cycle and use double-click for Shift Lock
  - Status: Completed and regression-verified/aligned.
  - Current state: Single tap toggles between shifted and unshifted. Double tap enters Shift Lock. When Shift Lock is active, a single tap exits Shift Lock and returns to unshifted.
  - Follow-up: Ship with the next Android/iOS builds.

## Pending fixes

- #104 — Android — related/association candidates after commit should not be highlighted or consumed by Enter
  - Status: Root cause identified; source fix pending.
  - Current state: Android 6.1.16 can highlight the first related candidate after committing a word, so Enter selects that related candidate instead of reaching the target editor for newline/search. Causal commit: `35abf08da89ddec0b221fab5612a44cbd2ea03d4`, whose default-candidate-selection helper falls back to index `0` for related-only suggestion lists.
  - Follow-up: Restore no-default-highlight behavior for related-only/post-commit candidate strips, add Android regression coverage, then ship in a newer APK before asking reporter `Limeroshenko` to retest.

## Confirmed feature / product work

No confirmed pending feature/product work remains after the Android next-release completion and iOS alignment work above.

## Not in backlog yet

- #90 — Android keyboard UI customization / old-style layout / button visibility / theme options
  - Reason: Only the system accent/dynamic color theme scope is confirmed above. Other #90 UI customization requests, such as hiding/repositioning 中英／123, Emoji, and voice buttons or making selected layouts retain active IM labels, remain product-evaluation scope until Jeremy or a maintainer confirms the exact feature direction.

- Closed/source-fixed items such as #92
  - Reason: Do not list as pending backlog unless Jeremy wants a separate iOS TestFlight/release-QA tracking item.
