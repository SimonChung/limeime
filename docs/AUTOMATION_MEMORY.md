# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-20T09:22:43+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context only, so scheduled runs can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.5.apk` (versionName 6.1.5), metadata observed 2026-05-20T09:22:43+08:00; APK bump commit `2ca6f1637b643905bebe356bb8d9092431d65943` was committed 2026-05-19T18:38:30+08:00.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-20 scheduled run.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in commit `8393abf64230684331f71e20d41797d29f4c3bbd` and APK `LIMEHD2026-6.1.5.apk`. A 6.1.5 retest request was posted as comment `4493653161`. Keep open; wait for reporter confirmation. If fixed, react thumbs-up where possible, close as completed, and remove from active context. If still broken, perform second-round root-cause analysis and update `docs/#54_ISSUE.md`.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed with closing comment `4485128961`; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Previously replied asking reporter to test 6.1.1 and provide a small sample table if import still fails. No newer #58-specific fix was observed in 6.1.5; avoid duplicate test requests until reporter responds or a clearly relevant fix lands.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed 6.1.4 improved add/search, but runtime related-candidate suggestions remain blank after committing parent `𩼣`. `docs/#62_ISSUE.md` was updated in commit `b6c895d3985e51530481d2ba427bf09a7ba4a967`; issue labeled `bug` and assigned to `jrywu`. Keep open; investigate runtime related lookup/display path. Do not ask for 6.1.5 retest because no new #62-relevant fix landed after 6.1.4.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Triaged as Android voice-input compatibility bug, documented in `docs/#63_ISSUE.md`, labeled `bug`, and assigned to `jrywu`. Reporter tested 6.1.2 and said NOT fixed; 6.1.5 did not add a new #63-relevant fix. Keep open; wait for targeted screenshot/video, entry point, Android/HyperOS, Google Speech Services version, and exact duplicate-output behavior. Do not retest-prompt until a new #63-relevant fix lands.
- #64: Community-reported settings text/inset/scroll issue. Triaged as UI/accessibility bug and documented in `docs/#64_ISSUE.md`, labeled `bug`, and assigned to `jrywu`. Keep open until a real #64-relevant fix lands; then ask reporter to test only if the fix is newer than their last tested build.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #67: New community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Investigated as an Android candidate-row hit-area bug; `docs/#67_ISSUE.md` created in commit `4ebbd1adc6d684aff35ceb18dd1ae04c0975edff`; issue labeled `bug` and assigned to `jrywu`. Likely root cause is overlapping/broad expand handling in `CandidateInInputViewContainer.dispatchTouchEvent()` plus `CandidateView.isExpandEdgeTap()`. Keep open for fix; after a relevant build lands, ask reporter to retest.

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.5`, #55 is closed after positive reporter confirmation, #65/#66 are closed as maintainer-created tracking issues, #54 awaits 6.1.5 retest, #62 has a partial negative follow-up, #63 remains open after negative reporter testing, and #67 is newly tracked as a bug.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, or run outcomes change.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
