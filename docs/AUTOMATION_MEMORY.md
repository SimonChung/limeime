# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-20T20:53:34+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context, operational handoffs, and shared task-board items only, so scheduled runs and different agent identities can read/update current state through GitHub API.

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
- #59: `.lime` format/name-display documentation question. Maintainer answered key format details and reporter thanked them. Still open with `question`/`documentation`; low-priority documentation follow-up, not an active bug watch.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed the 6.1.6 retest fixed/improved the remaining `𩼣` -> `魚` related-candidate path in comment `4498310094`; automation added a `+1` reaction and closed the issue as completed on 2026-05-20. Remove from active watch unless reopened or referenced by new reports.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Reporter tested 6.1.2 and said NOT fixed, then provided Google Drive screen-recording/video evidence in comment `4493061495`: `https://drive.google.com/drive/folders/12XSn_FRBjEROuazexf_u4QCJnC2oNpsl`. A source-level fix landed in commit `342b6a3b12665a2267f2c2fa7e79a9ad298e3938` (`fix(android): resolve #63 voice input routing`) and is included in APK `LIMEHD2026-6.1.6.apk`. A 6.1.6 retest request was posted as comment `4498265930`, asking the reporter to test both the no-microphone-permission Google/system voice path and the LIME inline-dictation path after granting microphone permission. The reporter replied in comment `4498466036` that the current test still outputs Simplified Chinese and said they will upload another video to the same Google Drive folder. Automation acknowledged in comment `4498473042` and asked them to confirm the tested version (`6.1.6`) and whether LIME microphone permission was granted or not. Issue remains open; next step is to inspect the uploaded video/details, then continue debugging rather than sending another generic retest request.
- #64: Community-reported settings text/inset/scroll issue. Reporter confirmed `6.1.2` fixed the issue in comment `4493627919`; automation added a `+1` reaction. Issue is closed as completed (closed 2026-05-20T01:15:24Z). Remove from active watch unless reopened or referenced by new reports.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #67: Community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Investigated as an Android candidate-row hit-area bug; `docs/#67_ISSUE.md` created in commit `4ebbd1adc6d684aff35ceb18dd1ae04c0975edff`; issue labeled `bug` and assigned to `jrywu`. Likely root cause is overlapping/broad expand handling in `CandidateInInputViewContainer.dispatchTouchEvent()` plus `CandidateView.isExpandEdgeTap()`. Keep open for fix; after a relevant build lands, ask reporter to retest.
- #68: Maintainer-created cross-platform candidate-bar dismiss bug. Tapping dismiss should fully cancel composition and remove composing text/state. iOS currently closes composition but leaves inline composing text; Android clears candidate composing UI but leaves Android composing state open. `docs/#68_ISSUE.md` was created in commit `e6e8194c92bb9dc93aeb6aaf2ba64625b023fded`; issue labeled `bug` and assigned to `jrywu`. Keep open for fix; because it is maintainer-created, close directly when a relevant fix lands instead of posting a tester invitation.
- #69: Maintainer-created cross-platform candidate-bar tool-icon flicker bug. Continuous input can briefly show idle/tool icons between composition candidates on Android and iOS. Issue is open, labeled `bug`, and assigned to `jrywu`; not yet represented by a dedicated investigation doc in this repo file. Needs code-path investigation and an English `docs/#69_ISSUE.md` if not already created by the implementing agent.

## Operational Handoff / Next Actions
- Time: 2026-05-20T20:46:00+08:00
- From: Hermes
- Summary: Repo `docs/AUTOMATION_MEMORY.md` is now the canonical reliable handoff location for Codex/Hermes scheduled/background identities because local `.agents/shared/handoffs.md` cannot be trusted for scheduled Codex read/write continuity. The 6.1.6 APK push was processed; `output-metadata.json` points to versionName `6.1.6`, and source fixes for #62 (`1b615d6`) and #63 (`342b6a3`) are included after previous 6.1.5 APK. #54 reporter already confirmed 6.1.5 fixed and issue remains closed.
- Changed: #62 reporter confirmed 6.1.6 fixed/improved the remaining `𩼣` -> `魚` path; automation added `+1` and closed #62 as completed. #63 reporter replied that 6.1.6 still outputs Simplified Chinese and will upload another video; automation acknowledged and asked them to confirm tested version and LIME microphone permission state. GitHub webhook subscription loads local skill `limeime-github-moderation` and listens to `issues`, `issue_comment`, `pull_request`, `push`, `release` only.
- Needs: Watch #63 for the promised video/details, then continue debugging; do not send another generic retest request. Remove #62 and #54 from active watch unless reopened or referenced by new reports. For future meaningful work, merge operational handoff notes into this repo file, not local `.agents/shared/handoffs.md`.
- Links: #62 retest comment `4498265731`; #62 reporter confirmation `4498310094`; #63 retest comment `4498265930`; #63 negative retest `4498466036`; #63 acknowledgement `4498473042`; APK raw URL pattern `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.

## Shared Task Board / Identity Exchange
- Purpose: This section is the repo-backed exchange area for Codex, Hermes, and future identities. Merge scheduled/background handoffs and task-board items here because local `.agents/shared/handoffs.md` and `.agents/shared/tasks.md` are not reliable for scheduled-session continuity.
- Format: `Status`, `Owner`, `Task`, `Context`, `Next`, `Updated`.
- Status: doing
  Owner: next LIME IME moderation/debugging identity
  Task: Continue #63 negative 6.1.6 retest follow-up.
  Context: Reporter says 6.1.6/current test still outputs Simplified Chinese and will upload another video to the same Google Drive folder. Acknowledgement comment `4498473042` asked them to confirm tested version and LIME microphone permission state.
  Next: Watch for the promised video/details, inspect the evidence, then debug targeted Google/system voice path versus LIME inline dictation path. Do not send another generic retest request.
  Updated: 2026-05-20T20:53:34+08:00
- Status: todo
  Owner: next implementation/debugging identity
  Task: Investigate #67 candidate dropdown false trigger near the last visible candidate.
  Context: Existing investigation points to Android candidate-row hit-area / expand-edge handling.
  Next: Implement relevant fix, then ask community reporter to retest only after a build containing the fix is available.
  Updated: 2026-05-20T20:53:34+08:00
- Status: todo
  Owner: next implementation/debugging identity
  Task: Investigate #68 candidate-bar dismiss composition cleanup across Android and iOS.
  Context: Maintainer-created issue; close directly when relevant fix lands.
  Next: Fix platform behavior and close with a short note referencing the fix/build; do not post a tester invitation.
  Updated: 2026-05-20T20:53:34+08:00
- Status: todo
  Owner: next implementation/debugging identity
  Task: Investigate #69 candidate-bar tool-icon flicker during continuous input on Android and iOS.
  Context: Maintainer-created issue; idle/tool icons briefly appear between composition candidate updates.
  Next: Create/update `docs/#69_ISSUE.md` if missing, identify candidate-bar idle delay/state-transition fix, and close directly when relevant fix lands.
  Updated: 2026-05-20T20:53:34+08:00

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.6`; #55 is closed after positive reporter confirmation; #65/#66 are closed as maintainer-created tracking issues; #54 and #64 are closed as completed; #62 is closed after reporter confirmation on 6.1.6; #63 source-level fix is included in 6.1.6 and a retest request was posted after that APK landed; #67 is tracked as a bug; #68 is tracked as a maintainer-created cross-platform dismiss/composition bug; and #69 is tracked as a maintainer-created cross-platform candidate-bar flicker bug.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, run outcomes, cross-agent handoff/continuation notes, or shared task-board items change.
- Keep operational handoffs in `Operational Handoff / Next Actions` and shared task-board items in `Shared Task Board / Identity Exchange` so different identities can exchange state reliably.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
