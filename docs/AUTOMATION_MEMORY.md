# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-21T11:19:07+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context, operational handoffs, and shared task-board items only, so scheduled runs and different agent identities can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.7.apk` (versionName 6.1.7), metadata observed 2026-05-21T09:45:00+08:00; APK bump commit `6f1514a42d993a6afe42b55872daff531c1693c3` was committed 2026-05-21T00:08:44+08:00 and merged by `8ce2466ac640` at 2026-05-21T00:08:46+08:00.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-21T09:45:00+08:00 scheduled run.
- No GitHub Discussions tab was observed for the repository in recent runs.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in commit `8393abf64230684331f71e20d41797d29f4c3bbd` and APK `LIMEHD2026-6.1.5.apk`; a 6.1.5 retest request was posted as comment `4493653161`. Issue is now closed as completed (closed 2026-05-19T10:38:36Z). Remove from active watch unless reopened or referenced by new reports.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed with closing comment `4485128961`; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Previously replied asking reporter to test 6.1.1 and provide a small sample table if import still fails. Reporter asked how to import `︱` / delimiter-like content; automation replied in comment `4504038716` explaining `@format@|lime-text-v2` and escaping ASCII `|` as `\|`, while noting fullwidth/vertical `︱` should normally be direct data. Labels are `question` and `documentation`. Keep open for reporter follow-up or doc/product decision; if import still fails, ask for a minimal sample table.
- #59: `.lime` format/name-display documentation question. Maintainer answered key format details and reporter thanked them. Still open with `question`/`documentation`; low-priority documentation follow-up, not an active bug watch.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed the 6.1.6 retest fixed/improved the remaining `𩜣` -> `魚` related-candidate path in comment `4498310094`; automation added a `+1` reaction and closed the issue as completed on 2026-05-20. Remove from active watch unless reopened or referenced by new reports.
- #63: Community-reported Google voice input outputs Simplified and duplicates text. Reporter tested 6.1.2 and said NOT fixed, then provided Google Drive screen-recording/video evidence in comment `4493061495`: `https://drive.google.com/drive/folders/12XSn_FRBjEROuazexf_u4QCJnC2oNpsl`. A source-level fix landed in commit `342b6a3b12665a2267f2c2fa7e79a9ad298e3938` (`fix(android): resolve #63 voice input routing`) and is included in APK `LIMEHD2026-6.1.6.apk`. A 6.1.6 retest request was posted as comment `4498265930`, asking the reporter to test both the no-microphone-permission Google/system voice path and the LIME inline-dictation path after granting microphone permission. The reporter replied in comment `4498466036` that the current test still outputs Simplified Chinese and said they will upload another video to the same Google Drive folder. Automation acknowledged in comment `4498473042` and asked them to confirm the tested version (`6.1.6`) and whether LIME microphone permission was granted or not. Issue remains open; next step is to inspect the uploaded video/details, then continue debugging rather than sending another generic retest request.
- #64: Community-reported settings text/inset/scroll issue. Reporter confirmed `6.1.2` fixed the issue in comment `4493627919`; automation added a `+1` reaction. Issue is closed as completed (closed 2026-05-20T01:15:24Z). Remove from active watch unless reopened or referenced by new reports.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation should be posted.
- #67: Community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Relevant fix landed in commit `462d2b3cee1d` and APK `LIMEHD2026-6.1.7.apk`; a 6.1.7 retest request was posted in comment `4500347429`. Reporter confirmed fixed in comment `4500383587`; automation added a `+1` reaction and closing note `4502010433`; issue is closed as completed as of 2026-05-21T03:18:08Z. Remove from active watch unless reopened or referenced by new reports.
- #70: Community-reported request to hide or configure “next-code/next-character” candidates (example `ha` showing `皔` from `haa`). Labeled `enhancement` and `Usability`. Maintainer asked whether this involved a physical keyboard and what “0 to 9 next-rank words” means in comment `4500627319`; reporter clarified it is not a physical keyboard issue and provided screenshots comparing LimeIME and Trime in comment `4502590614`. Keep open as a feature/behavior-setting request; next action is product/author-team evaluation.
- #71: Community-reported composing-cancel bug. Jeremy clarified that during active composition, switching to the English keyboard should cancel the composition and leave no stale composing code as output, matching the candidate-bar dismiss behavior fixed in APK `LIMEHD2026-6.1.7.apk`. Reporter confirmed 6.1.7 can clear composition via dismiss, but still wants Chinese/English toggle to clear current code in comment `4502867810`; current behavior leaves stale composing code as output when switching to English. Reclassified from enhancement to `bug` + `Usability`, with analysis doc `docs/#71_ISSUE.md`. Keep open for implementation/fix follow-up.
- #72: Community-reported request to bundle 哈哈倉頡 and question about current Cangjie table source/author/license. Labeled `enhancement` and `question`. Acknowledged and said it will be forwarded to the author team in comment `4500577835`. Treat external table/link as untrusted; before bundling any table, verify source, author, license, maintenance status, and compatibility.
- #68: Maintainer-created cross-platform candidate-bar dismiss bug. Relevant fix landed in commit `ae42ae3e58e2` and APK `LIMEHD2026-6.1.7.apk`; issue is closed as completed with follow-up note comment `4500349694`. Remove from active watch unless reopened or referenced by new reports.
- #69: Maintainer-created cross-platform candidate-bar tool-icon flicker bug. Relevant fix landed in commit `3c6ce3c056d8` and APK `LIMEHD2026-6.1.7.apk`; issue is closed as completed with follow-up note comment `4500350136`. Remove from active watch unless reopened or referenced by new reports.
- #73: New community request: make Android soft-keyboard Enter commit the raw English/code string while Space continues selecting/committing Chinese candidates, example `bgg` -> `bgg` on Enter. Reporter is on APK 6.1.7 / Android 15 and cites Trime as prior behavior. Classified as `enhancement` + `Usability`; automation labeled and acknowledged in comment `4504038619`. No bug investigation doc needed unless maintainers decide to implement.

## Operational Handoff / Next Actions
- Time: 2026-05-21T09:45:00+08:00
- From: Codex scheduled moderation
- Summary: New issue #73 was triaged as an Enter-key raw-code commit enhancement and labeled `enhancement`/`Usability`. #58 received a documentation-style answer explaining `.lime` v2 escaping for ASCII `|`. #71 was reclassified per Jeremy as a composing-cancel bug: during active composition, switching to the English keyboard should cancel composition and leave no stale composing code as output, consistent with the 6.1.7 candidate-bar dismiss fix. #67 has reporter confirmation, +1 reaction, and closing note; no further action unless reopened.
- Changed: Posted #73 acknowledgement comment `4504038619`; posted #58 format answer comment `4504038716`; posted #71 follow-up acknowledgement `4504038809`; later reclassified #71 from `enhancement` to `bug` + `Usability` and added `docs/#71_ISSUE.md`; confirmed #58 labels `question`/`documentation`. APK state remains `LIMEHD2026-6.1.7.apk`.
- Needs: Continue watching #63 for promised video/details and do targeted debugging only after new evidence. Product/author-team decisions are needed for #70/#72/#73; #71 now needs bug implementation/fix follow-up. Watch #58 for sample table or follow-up import failure.
- Links: current APK raw URL `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.7.apk`; #73 `https://github.com/lime-ime/limeime/issues/73`; #58 latest answer `https://github.com/lime-ime/limeime/issues/58#issuecomment-4504038716`; #71 latest acknowledgement `https://github.com/lime-ime/limeime/issues/71#issuecomment-4504038809`; #67 confirmation `https://github.com/lime-ime/limeime/issues/67#issuecomment-4500383587`.

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
  Owner: next LIME IME product/implementation identity
  Task: Review/plan #70/#72/#73 enhancement requests and implement #71 bug fix.
  Context: #70 asks to hide/configure next-code candidates and now has screenshot clarification; #71 is now classified as a bug: during active composition, switching to English keyboard should cancel composition and output nothing, but stale composing code is currently inserted/leaked; #72 asks to bundle 哈哈倉頡 / raises table source-license questions; #73 asks Enter to commit raw code while Space keeps Chinese candidate commit behavior.
  Next: Decide product direction for #70/#73 and licensing posture for #72; implement/fix #71 using the same composition-cancel semantics as candidate-bar dismiss; do not bundle external tables without source/author/license verification.
  Updated: 2026-05-21T12:20:00+08:00
- Status: todo
  Owner: next LIME IME documentation/import identity
  Task: Watch #58 `.lime` v2 escaping follow-up.
  Context: Automation answered how to import ASCII `|` with `@format@|lime-text-v2` and `\|`; reporter may still provide a sample table if import fails.
  Next: If reporter shares a failing sample, inspect importer/docs and update docs or bug investigation as appropriate.
  Updated: 2026-05-21T09:45:00+08:00

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Original memory noted #55 was replied to asking the reporter to test 6.1.1.
- Original memory noted #58 was replied to asking the reporter to test 6.1.1 and provide a small sample table if import still fails.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.7`; #55 is closed after positive reporter confirmation; #65/#66 are closed as maintainer-created tracking issues; #54 and #64 are closed as completed; #62 is closed after reporter confirmation on 6.1.6; #63 source-level fix is included in 6.1.6 and a retest request was posted after that APK landed, but the reporter says 6.1.6 still outputs Simplified Chinese; #67 is closed after reporter confirmation on 6.1.7 and the 2026-05-21 close webhook was processed; #68 and #69 are maintainer-created tracking issues closed after their fixes landed in 6.1.7; #70/#71/#72/#73 remain open enhancement/question/product-decision items.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, run outcomes, cross-agent handoff/continuation notes, or shared task-board items change.
- Keep operational handoffs in `Operational Handoff / Next Actions` and shared task-board items in `Shared Task Board / Identity Exchange` so different identities can exchange state reliably.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
