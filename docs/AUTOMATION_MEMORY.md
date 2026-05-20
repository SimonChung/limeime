# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-20T20:39:04+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context only, so scheduled runs can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.6.apk` (versionName 6.1.6), metadata observed 2026-05-20T20:12:38+08:00; APK bump commit `4b7f2f252de0f8d2ccfdf27f3372cb875d96ec70` was committed 2026-05-20T18:52:50+08:00.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-20 scheduled run.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in commit `8393abf64230684331f71e20d41797d29f4c3bbd` and APK `LIMEHD2026-6.1.5.apk`; a 6.1.5 retest request was posted as comment `4493653161`. Issue is now closed as completed (closed 2026-05-19T10:38:36Z). Remove from active watch unless reopened or referenced by new reports.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed with closing comment `4485128961`; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Previously replied asking reporter to test 6.1.1 and provide a small sample table if import still fails. No newer #58-specific fix was observed in 6.1.5; avoid duplicate test requests until reporter responds or a clearly relevant fix lands.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed the 6.1.6 retest fixed/improved the remaining `𩼣` -> `魚` related-candidate path in comment `4498310094`; automation added a `+1` reaction and closed the issue as completed on 2026-05-20. Remove from active watch unless reopened or referenced by new reports.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Reporter tested 6.1.2 and said NOT fixed, then provided Google Drive screen-recording/video evidence in comment `4493061495`: `https://drive.google.com/drive/folders/12XSn_FRBjEROuazexf_u4QCJnC2oNpsl`. A source-level fix landed in commit `342b6a3b12665a2267f2c2fa7e79a9ad298e3938` (`fix(android): resolve #63 voice input routing`) and is included in APK `LIMEHD2026-6.1.6.apk`. A 6.1.6 retest request was posted as comment `4498265930`, asking the reporter to test both the no-microphone-permission Google/system voice path and the LIME inline-dictation path after granting microphone permission. The reporter replied in comment `4498466036` that the current test still outputs Simplified Chinese and said they will upload another video to the same Google Drive folder. Automation acknowledged in comment `4498473042` and asked them to confirm the tested version (`6.1.6`) and whether LIME microphone permission was granted or not. Issue remains open; next step is to inspect the uploaded video/details, then continue debugging rather than sending another generic retest request.
- #64: Community-reported settings text/inset/scroll issue. Reporter confirmed `6.1.2` fixed the issue in comment `4493627919`; automation added a `+1` reaction. Issue is closed as completed (closed 2026-05-20T01:15:24Z). Remove from active watch unless reopened or referenced by new reports.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #67: New community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Investigated as an Android candidate-row hit-area bug; `docs/#67_ISSUE.md` created in commit `4ebbd1adc6d684aff35ceb18dd1ae04c0975edff`; issue labeled `bug` and assigned to `jrywu`. Likely root cause is overlapping/broad expand handling in `CandidateInInputViewContainer.dispatchTouchEvent()` plus `CandidateView.isExpandEdgeTap()`. Keep open for fix; after a relevant build lands, ask reporter to retest.
- #68: Maintainer-created cross-platform candidate-bar dismiss bug. Tapping dismiss should fully cancel composition and remove composing text/state. iOS currently closes composition but leaves inline composing text; Android clears candidate composing UI but leaves Android composing state open. `docs/#68_ISSUE.md` was created in commit `e6e8194c92bb9dc93aeb6aaf2ba64625b023fded`; issue labeled `bug` and assigned to `jrywu`. Keep open for fix; because it is maintainer-created, close directly when a relevant fix lands instead of posting a tester invitation.

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.6`; #55 is closed after positive reporter confirmation; #65/#66 are closed as maintainer-created tracking issues; #54 and #64 are closed as completed; #62 is closed after reporter confirmation on 6.1.6; #63 source-level fix is included in 6.1.6 and a retest request was posted after that APK landed; #67 is tracked as a bug; and #68 is tracked as a maintainer-created cross-platform dismiss/composition bug.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, or run outcomes change.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
