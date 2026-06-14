# LIME IME Backlog

Public backlog for confirmed pending fixes, active retest watches, and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-14

## Active issue follow-up

- #115 Android: active initial keyboard/layout startup bug. On a fresh install, tested first mounted non-`注音` IMs (`倉頡`, `大易`, `行列`, `行列10`) can first open in a mismatched English-looking layout with the `EN` switch key (lead hypothesis: Chinese-mode generic-layout fallback, pending reproduction/logging); after adding a second IM, any active IM including `注音` can show the same wrong first keyboard. The reporter's attached manually imported Array10 `.lime` table can also intermittently default to `行列+數字列鍵盤` instead of `電話數字鍵盤`; audit iOS only if the fix changes shared `.lime` import semantics. Open / assigned to `jrywu`; wait for a targeted fix and newer APK before requesting reporter retest.
- #114 Android: reporter retest requested for APK `LIMEHD2026-6.1.19.apk` after commit `0a80a082eabf` guarded the English-fallback path from clearing runtime suggestion state during background prefetch. Watch for `SmithCCho` confirmation on the Duolingo English candidate-strip issue; do not close until reporter or maintainer confirmation.
- #111 was closed by `limeimetw` after acknowledgement; the confirmed `scj` table-data correction remains tracked under pending fixes until a rebuilt table/artifact decision is made.

## Unfiled release-QA follow-up

- Unify full database backup ZIP filenames across Android and iOS. Android currently defaults to `limeBackup.zip`, while iOS creates `lime_backup_<timestamp>.zip`; choose one user-facing naming convention for DB Manager backup/restore docs, QA, and support.

## Pending fixes

- #111 Android/iOS: correct or regenerate the shared `scj` / `快倉` downloadable table data so the one-letter `x` and `z` codes no longer surface `1991` as the default/leading candidate.

