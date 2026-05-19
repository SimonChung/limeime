# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-19T15:06:00+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context only, so scheduled runs can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.4.apk` (versionName 6.1.4), metadata modified 2026-05-18T17:42:43Z.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap. Reporter has a negative/still-reproduces result. `docs/#54_ISSUE.md` was rewritten for another debugging round in commit `8788beecb3381e60b159a543e1ea533ebf9948c0`. Keep open; gather targeted screenshot/video and Brave/device/navigation-mode data; do not retest-prompt until a new #54-relevant fix lands.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed with closing comment `4485128961`; remove from active watch unless reopened or referenced by new reports.
- #58: Was previously replied to asking reporter to test 6.1.1 and provide a small sample table if import still fails. Check current state/comments before any further action.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Triaged as Android voice-input compatibility bug, documented in `docs/#63_ISSUE.md`, labeled `bug`, and assigned to `jrywu`. Reporter tested 6.1.2 and said NOT fixed; 6.1.4 did not add a new #63-relevant fix. Keep open; ask for targeted screenshot/video, entry point, Android/HyperOS, Google Speech Services version, and exact duplicate-output behavior. Do not retest-prompt until a new #63-relevant fix lands.
- #64: Community-reported settings text/inset/scroll issue. Triaged as UI/accessibility bug and documented in `docs/#64_ISSUE.md`, labeled `bug`, and assigned to `jrywu`. Keep open until a real #64-relevant fix lands; then ask reporter to test only if the fix is newer than their last tested build.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.4`, #55 is closed after positive reporter confirmation, #65/#66 are closed as maintainer-created tracking issues, and #63 remains open after negative reporter testing.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, or run outcomes change.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.