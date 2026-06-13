# LIME IME Backlog

Public backlog for confirmed pending fixes, active retest watches, and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-13

## Active issue follow-up

- #111 Android/iOS `快倉` (`scj`) table data: current `Database/scj.db` contains `x -> 1991` and `z -> 1991`, matching the reporter's bad-candidate report. Fix scope is to audit/rebuild the legacy `scj` artifact so `x` / `z` no longer present `1991` as the leading candidate; broader `快倉` deprecation/replacement/catalog-order decisions are not in backlog yet.

## Unfiled release-QA follow-up

- Unify full database backup ZIP filenames across Android and iOS. Android currently defaults to `limeBackup.zip`, while iOS creates `lime_backup_<timestamp>.zip`; choose one user-facing naming convention for DB Manager backup/restore docs, QA, and support.

## Pending fixes

- #111 Android/iOS: correct or regenerate the shared `scj` / `快倉` downloadable table data so the one-letter `x` and `z` codes no longer surface `1991` as the default/leading candidate.

