# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-24T01:54:50+08:00 (CST)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context, operational handoffs, and shared task-board items only, so scheduled runs and different agent identities can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.11.apk` (versionName 6.1.11), metadata observed 2026-05-24T00:47+08:00 after recovering the Cloudflare tunnel outage; direct raw APK link `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.11.apk`. This APK includes the Android #74 URL/search-field remembered Chinese/English mode change, Android #81 English-keyboard autocap behavior, Android #83 legacy settings UI removal, cross-platform preference backup/restore work, and iOS #82 legacy iPhone globe-key support. Android APK availability does not make iOS-only #82 changes tester-available on Android.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-22T04:18:00+08:00 scheduled run.
- No GitHub Discussions tab was observed for the repository in recent runs.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in APK `LIMEHD2026-6.1.5.apk`; a retest request was posted and the issue is closed as completed. Remove from active watch unless reopened or referenced by new reports.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Reporter `ejmoog` confirmed in comment `4526128600` (`https://github.com/lime-ime/limeime/issues/58#issuecomment-4526128600`) that `lime-text-v2` on version 6.1.9 can import escaped `\`, `|`, `@`, and `%`, then closed the issue on 2026-05-23. Hermes added a `+1` reaction and closing acknowledgement `4526130502` (`https://github.com/lime-ime/limeime/issues/58#issuecomment-4526130502`). Treat as resolved/closed documentation question; remove from active watch unless reopened or new import-failure evidence appears.
