# LIME IME Backlog

Public backlog for confirmed pending fixes and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-07

## Completed / release-ready source fixes

- #86 — iOS — keyboard extension should see restored IM tables immediately after successful DB restore
  - Status: Completed and verified (full-app build succeeds).
  - Current state: After a Settings-app DB restore, the keyboard extension now reopens its own `DBServer.shared` connection (`reopenDatabaseFromDisk()` / `prepareKeyboardRuntimeDatabase(forceReopen:)`) instead of reusing a GRDB queue bound to the pre-restore file inode, so restored IMs appear without removing/re-adding the system keyboard. Stale index-based `keyboard_state` is ignored on reopen and the activated list is rebuilt from the restored enabled IMs. Related iOS alignment: phonetic auto-seed and the bundled `phonetic.db` copy phase were removed, and the fabricated fallback IM list was dropped, so iOS now matches Android (restore-to-default → empty IM list, keyboard runs English-only until an IM is installed).
  - Follow-up: Ship in the next iOS build; on-device retest of restore-from-backup and restore-to-default per `docs/#86_ISSUE.md` verification steps.

- #91 — Android — `.cin` import should preserve duplicate-code candidate order from the source file
  - Status: Completed and reporter-confirmed fixed on Android APK `LIMEHD2026-6.1.16.apk`.
  - Current state: Android import/search ordering now preserves source insertion order for same-code candidates when selection sorting is disabled; reporter `ejmoog` confirmed the 哈哈倉頡 `vmi` order is correct in `6.1.16`.
  - Follow-up: Closed as completed; remove from active reporter watch unless reopened or new `.cin` ordering evidence appears.

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
  - Status: Completed in source and included in Android test APK `LIMEHD2026-6.1.17.apk`; issue is open / pending reporter confirmation.
  - Current state: Android English prediction keeps the composing/self candidate visible for exact-only words such as `salt`, uses a no-default-highlight candidate display path for English prediction, and now uses the bundled scored `dictionary.db` / frequency-ranking path with local learning instead of plain alphabetical or rowid ordering. The 6.1.17 APK was verified through Contents metadata (blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes), and the scoped retest request was posted at https://github.com/lime-ime/limeime/issues/103#issuecomment-4641196730.
  - Follow-up: Wait for reporter `SmithCCho` to verify `salt` exact-match visibility and `sal` → `salt` ranking on Android 6.1.17; do not close until reporter confirmation or maintainer instruction.

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

- #104 — Android + iOS — related/association candidates after commit should not be highlighted or consumed by Enter
  - Status: Source fix completed by maintainer in `1cb8daecdcb6dd5583542ec902fd3b1d0089b5b9`.
  - Current state: Android restores no-default-highlight behavior for related-only/post-commit candidate strips and separates `%limeendkey` commit resolution from normal candidate-strip selection. iOS parity was aligned with the same selection-policy split. The community issue is closed by the fix commit, but the fix is not included in the current Android APK `LIMEHD2026-6.1.16.apk` (blob SHA `eb99705bc3f6a2668889e89c05f7d9914c574639`, size 11983378 bytes).
  - Follow-up: Ask reporter `Limeroshenko` for a scoped Enter/Search/Return retest only after a newer APK contains `1cb8dae`; do not treat 6.1.16 as containing this fix.

## Pending fixes

No confirmed source fixes are pending at this time. Retest/release-QA follow-up remains for source-fixed items once newer Android/iOS builds are available.

## Confirmed feature / product work

No confirmed pending feature/product work remains after the Android next-release completion and iOS alignment work above.

## Not in backlog yet

- #90 — Android keyboard UI customization / old-style layout / button visibility / theme options
  - Reason: Only the system accent/dynamic color theme scope is confirmed above. Other #90 UI customization requests, such as hiding/repositioning 中英／123, Emoji, and voice buttons or making selected layouts retain active IM labels, remain product-evaluation scope until Jeremy or a maintainer confirms the exact feature direction.

- Closed/source-fixed items such as #92
  - Reason: Do not list as pending backlog unless Jeremy wants a separate iOS TestFlight/release-QA tracking item.
