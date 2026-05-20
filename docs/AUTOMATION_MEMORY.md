# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-21T00:12:29+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context, operational handoffs, and shared task-board items only, so scheduled runs and different agent identities can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.7.apk` (versionName 6.1.7), metadata observed 2026-05-21T00:12:29+08:00; APK bump commit `6f1514a42d9919b4742f0f83547c079a3d9f5675` was committed 2026-05-21T00:08:44+08:00 and merged by `8ce2466ac640` at 2026-05-21T00:08:46+08:00.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-20T21:08:00+08:00 scheduled run.
- No GitHub Discussions tab was observed for the repository.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in commit `8393abf64230684331f71e20d41797d29f4c3bbd` and APK `LIMEHD2026-6.1.5.apk`; a 6.1.5 retest request was posted as comment `4493653161`. Issue is now closed as completed (closed 2026-05-19T10:38:36Z). Remove from active watch unless reopened or referenced by new reports.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed with closing comment `4485128961`; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Previously replied asking reporter to test 6.1.1 and provide a small sample table if import still fails. No newer #58-specific fix was observed in 6.1.5 or 6.1.6; avoid duplicate test requests until reporter responds or a clearly relevant fix lands.
- #59: `.lime` format/name-display documentation question. Maintainer answered key format details and reporter thanked them. Still open with `question`/`documentation`; low-priority documentation follow-up, not an active bug watch.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed the 6.1.6 retest fixed/improved the remaining `𩼣` -> `魚` related-candidate path in comment `4498310094`; automation added a `+1` reaction and closed the issue as completed on 2026-05-20. Remove from active watch unless reopened or referenced by new reports.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Reporter tested 6.1.2 and said NOT fixed, then provided Google Drive screen-recording/video evidence in comment `4493061495`: `https://drive.google.com/drive/folders/12XSn_FRBjEROuazexf_u4QCJnC2oNpsl`. A source-level fix landed in commit `342b6a3b12665a2267f2c2fa7e79a9ad298e3938` (`fix(android): resolve #63 voice input routing`) and is included in APK `LIMEHD2026-6.1.6.apk`. A 6.1.6 retest request was posted as comment `4498265930`, asking the reporter to test both the no-microphone-permission Google/system voice path and the LIME inline-dictation path after granting microphone permission. The reporter replied in comment `4498466036` that the current test still outputs Simplified Chinese and said they will upload another video to the same Google Drive folder. Automation acknowledged in comment `4498473042` and asked them to confirm the tested version (`6.1.6`) and whether LIME microphone permission was granted or not. Issue remains open; next step is to inspect the uploaded video/details, then continue debugging rather than sending another generic retest request.
- #64: Community-reported settings text/inset/scroll issue. Reporter confirmed `6.1.2` fixed the issue in comment `4493627919`; automation added a `+1` reaction. Issue is closed as completed (closed 2026-05-20T01:15:24Z). Remove from active watch unless reopened or referenced by new reports.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #67: Community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Relevant fix landed in commit `462d2b3cee1d` and APK `LIMEHD2026-6.1.7.apk`. The fixing commit auto-closed the issue, but it was reopened and a 6.1.7 retest request was posted in comment `4500347429`. Keep open pending reporter confirmation.
- #68: Maintainer-created cross-platform candidate-bar dismiss bug. Relevant fix landed in commit `ae42ae3e58e2` and APK `LIMEHD2026-6.1.7.apk`; issue is closed as completed with follow-up note comment `4500349694`. Remove from active watch unless reopened or referenced by new reports.
- #69: Maintainer-created cross-platform candidate-bar tool-icon flicker bug. Relevant fix landed in commit `3c6ce3c056d8` and APK `LIMEHD2026-6.1.7.apk`; issue is closed as completed with follow-up note comment `4500350136`. Remove from active watch unless reopened or referenced by new reports.

## Operational Handoff / Next Actions
- Time: 2026-05-21T00:12:29+08:00
- From: Hermes interactive moderation
- Summary: Detected new push/APK bump to `LIMEHD2026-6.1.7.apk`. Commits include fixes for #67, #68, and #69. #67 was auto-closed by the fixing commit, then reopened because it is community-reported and needs reporter confirmation; a 6.1.7 retest request was posted. #68 and #69 are maintainer-created tracking issues and remain closed with short notes referencing 6.1.7. #63 has no new 6.1.7-specific fix; continue waiting for/reviewing reporter evidence and do not send another generic retest request.
- Changed: Updated latest APK state from 6.1.6 to 6.1.7; updated #67/#68/#69 tracking state. GitHub writes: reopened #67 and posted retest comment `4500347429`; added #68 comment `4500349694`; added #69 comment `4500350136`.
- Needs: Watch #67 for reporter retest result on 6.1.7. Continue #63 follow-up only after reporter clarifies/replies or further evidence is inspected.
- Links: current APK raw URL `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.7.apk`; #67 retest comment `https://github.com/lime-ime/limeime/issues/67#issuecomment-4500347429`; #68 note `https://github.com/lime-ime/limeime/issues/68#issuecomment-4500349694`; #69 note `https://github.com/lime-ime/limeime/issues/69#issuecomment-4500350136`.

## Shared Task Board / Identity Exchange
- Purpose: This section is the repo-backed exchange area for Codex, Hermes, and future identities. Merge scheduled/background handoffs and task-board items here because local `.agents/shared/handoffs.md` and `.agents/shared/tasks.md` are not reliable for scheduled-session continuity.
- Format: `Status`, `Owner`, `Task`, `Context`, `Next`, `Updated`.
- Status: doing
  Owner: next LIME IME moderation/debugging identity
  Task: Continue #63 negative 6.1.6 retest follow-up.
  Context: Reporter says 6.1.6/current test still outputs Simplified Chinese and will upload another video to the same Google Drive folder. Acknowledgement comment `4498473042` asked them to confirm tested version and LIME microphone permission state.
  Next: Watch for the promised video/details, inspect the evidence, then debug targeted Google/system voice path versus LIME inline dictation path. Do not send another generic retest request.
  Updated: 2026-05-20T21:08:00+08:00
- Status: todo
  Owner: next implementation/debugging identity
  Task: Watch #67 candidate dropdown false-trigger retest.
  Context: Fix landed in 6.1.7 and retest request was posted after reopening the auto-closed community issue.
  Next: Wait for reporter confirmation or negative retest; do not close until reporter confirms fixed or maintainer explicitly instructs closure.
  Updated: 2026-05-21T00:12:29+08:00

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.7`; #55 is closed after positive reporter confirmation; #65/#66 are closed as maintainer-created tracking issues; #54 and #64 are closed as completed; #62 is closed after reporter confirmation on 6.1.6; #63 source-level fix is included in 6.1.6 and a retest request was posted after that APK landed, but the reporter says 6.1.6 still outputs Simplified Chinese; #67 has a 6.1.7 retest request pending after the fixing commit auto-closed it; #68 and #69 are maintainer-created tracking issues closed after their fixes landed in 6.1.7.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, run outcomes, cross-agent handoff/continuation notes, or shared task-board items change.
- Keep operational handoffs in `Operational Handoff / Next Actions` and shared task-board items in `Shared Task Board / Identity Exchange` so different identities can exchange state reliably.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
