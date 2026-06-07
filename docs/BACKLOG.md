# LIME IME Backlog

Public backlog for confirmed pending fixes, active retest watches, and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-07

## Active issue follow-up

- #88 — Android — stale `emoji_fts` restore path from old backups should rebuild cleanly
  - Status: Delivered in Android test APK `LIMEHD2026-6.1.17.apk`; old-backup / old-Android restore retest pending.
  - Current state: The 6.1.17 APK contains the stale-FTS restore fixes from PR #102 / merge commit `289907b1318bb2c7dbe599ded6b7085e0d91148f` and later open-path emoji schema cleanup.
  - Follow-up: Retest request posted at https://github.com/lime-ime/limeime/issues/88#issuecomment-4641196837; keep #88 open until the narrow old-backup restore path is verified. Verified APK blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes.

- #103 — Android — English prediction should keep the typed word visible when no dictionary alternatives remain
  - Status: Completed in source and included in Android test APK `LIMEHD2026-6.1.17.apk`; issue is open / pending reporter confirmation.
  - Current state: Android English prediction keeps the composing/self candidate visible for exact-only words such as `salt`, uses a no-default-highlight candidate display path for English prediction, and now uses the bundled scored `dictionary.db` / frequency-ranking path with local learning instead of plain alphabetical or rowid ordering. The 6.1.17 APK was verified through Contents metadata (blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes), and the scoped retest request was posted at https://github.com/lime-ime/limeime/issues/103#issuecomment-4641196730.
  - Follow-up: Wait for reporter `SmithCCho` to verify `salt` exact-match visibility and `sal` → `salt` ranking on Android 6.1.17; do not close until reporter confirmation or maintainer instruction.

- #107 — Android — IME switch/startup latency should improve versus 6.1.16
  - Status: Android startup/switch optimization delivered in test APK `LIMEHD2026-6.1.17.apk`; reporter retest pending.
  - Current state: The Android startup/switch optimization is implemented by maintainer commit `537a66c4c21c` (`#107 Optimize LimeIME startup without changing init path`). The issue remains Android-only based on the Samsung A52 report; no iOS impact is inferred.
  - Follow-up: Retest request posted at https://github.com/lime-ime/limeime/issues/107#issuecomment-4641196799; if delay remains, ask for Android/One UI version, cold-vs-warm behavior, and logcat around the switch. Verified APK blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes.

## Unfiled release-QA follow-up

- `ENGLISH_KB.md` smart-space — Android + iOS — swap auto-inserted English suggestion space before punctuation
  - Status: Completed and compile/test verified; Android side is included in test APK `LIMEHD2026-6.1.17.apk` (blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes), while iOS ships through the normal TestFlight/App Store path.
  - Current state: After picking an English suggestion that auto-appends a space, typing punctuation now produces LatinIME-style `word,` instead of `word ,` on both Android and iOS, with focused Android and iOS coverage.
  - Follow-up: Ship with the next Android/iOS builds; collect user feedback before expanding into broader English keyboard behavior changes.

- Android — enabling the first IM on a fresh install should activate that IM immediately
  - Status: Completed and included in Android test APK `LIMEHD2026-6.1.17.apk` (blob SHA `4b0f42af2b9d97e9b9c1e87ec87bffa1271d1e2f`, size 13930960 bytes).
  - Current state: Enabling an IM now makes it active when the persisted active IM is missing or no longer enabled, avoiding the fresh-install fallback to the English layout.
  - Follow-up: Verify during normal fresh-install / table-enable release QA.

## Pending fixes

No confirmed source fixes are pending at this time. Reporter retest/release-QA follow-up remains only for the active items above.

## Cleared from backlog

Closed/source-fixed items are no longer tracked here once the relevant Android/iOS source fixes are committed and no separate active retest watch remains. Cleared examples: #86, #90, #91, #93, #94, #96, #99, #100, #104, and #92.
