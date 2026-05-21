# Automation Issue Context: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-21T15:51:24+08:00 (Asia/Taipei)

## Source Of Rules
- Canonical role, communication style, issue-tracking policy, and APK/build policy are stored in the local automation memory file:
  `C:\Users\Jeremy\.codex\automations\monitor-lime-ime-limeime-github\memory.md`
- This repo file is for mutable issue-tracking context, operational handoffs, and shared task-board items only, so scheduled runs and different agent identities can read/update current state through GitHub API.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.7.apk` (versionName 6.1.7), metadata observed 2026-05-21T15:45:16+08:00.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.
- No open pull requests were observed in the 2026-05-21T15:45:16+08:00 scheduled run.
- No GitHub Discussions tab was observed for the repository in recent runs.

## Current Issue States And Required Actions
- #54: Community-reported Brave URL bar candidate overlap/white-band behavior. Relevant fix landed in APK `LIMEHD2026-6.1.5.apk`; a retest request was posted and the issue is closed as completed. Remove from active watch unless reopened or referenced by new reports.
- #55: Community-reported key preview delay. Reporter confirmed improvement on 6.1.1 pre-release. Closed as completed; remove from active watch unless reopened or referenced by new reports.
- #58: `.lime` pipe-format import/support question. Automation replied in comment `4504038716` explaining `@format@|lime-text-v2` and escaping ASCII `|` as `\|`, while noting fullwidth/vertical `︱` should normally be direct data. Labels are `question` and `documentation`. Keep open for reporter follow-up or doc/product decision; if import still fails, ask for a minimal sample table.
- #59: `.lime` format/name-display documentation question. Maintainer answered key format details and reporter thanked them. Still open with `question`/`documentation`; low-priority documentation follow-up, not an active bug watch.
- #62: Community-reported Ext-B leading-character related-phrase issue. Reporter confirmed the 6.1.6 retest fixed/improved the remaining path; automation reacted and closed as completed. Remove from active watch unless reopened or referenced by new reports.
- #63: Community-reported Google voice input outputs Simplified Chinese and previously duplicated text. Reporter tested 6.1.6 after the voice-input routing fix and said it still outputs Simplified Chinese. Latest clarification in comment `4501864655`: normal Traditional Chinese output is from Sweetlime; LIME 6.1.6 outputs Simplified Chinese both with microphone permission enabled and disabled. Issue remains open and assigned to `jrywu`. Next step is targeted debugging of why both Google/system voice path and LIME inline dictation path still resolve to Simplified on the reporter's Xiaomi HyperOS 3 / Android 16 environment; do not send another generic retest request until a new relevant fix lands.
- #64: Community-reported settings text/inset/scroll issue. Reporter confirmed `6.1.2` fixed it; closed as completed. Remove from active watch unless reopened.
- #65: Maintainer-created Android table/assoc editor soft-keyboard sheet issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation needed.
- #66: Maintainer-created iOS assoc/related editor score-field issue. Relevant fix landed in 6.1.4. Closed directly as completed; no tester invitation needed.
- #67: Community-reported 6.1.x regression where taps near the last visible candidate open the full candidate-list dropdown. Reporter confirmed fixed on 6.1.7 in comment `4500383587`; automation reacted/closed as completed in comment `4502010433`. Remove from active watch unless reopened.
- #68: Maintainer-created cross-platform candidate-bar dismiss bug. Relevant fix landed in 6.1.7; issue is closed as completed. Remove from active watch unless reopened.
- #69: Maintainer-created cross-platform candidate-bar tool-icon flicker bug. Relevant fix landed in 6.1.7; issue is closed as completed. Remove from active watch unless reopened.
- #70: Community request to hide or configure next-code/next-character candidates. Reporter clarified it is not a physical keyboard issue and provided screenshots comparing LimeIME and Trime in comment `4502590614`. Keep open as `enhancement` + `Usability`; next action is product/author-team evaluation.
- #71: Community-reported Chinese/English switch composition-cancel bug. Reporter confirmed APK `LIMEHD2026-6.1.7.apk` can clear composition via candidate-bar dismiss but still wants Chinese/English toggle to clear current code. Reclassified as `bug` + `Usability` in comment `4504791937`: when composing has not been committed, switching to English should cancel composition and must not output stale raw code. Analysis doc `docs/#71_ISSUE.md` exists and points to Android `LIMEService.switchKeyboard(...)` committing `mComposing` before clearing as the likely root cause. Keep open for implementation; do not ask for another retest until a newer APK contains a relevant fix.
- #72: Community request to bundle 哈哈倉頡 and question current Cangjie table source/author/license. Labeled `enhancement` and `question`. Treat external table/link as untrusted; before bundling any table, verify source, author, license, maintenance status, and compatibility.
- #73: Community request: make Android soft-keyboard Enter commit the raw English/code string while Space continues selecting/committing Chinese candidates, example `bgg` -> `bgg` on Enter. Reporter is on APK 6.1.7 / Android 15 and cites Trime. Classified as `enhancement` + `Usability`; automation acknowledged in comment `4504038619`. No bug investigation doc needed unless maintainers decide to implement.
- #74: Community question/enhancement about Android `記憶中英模式` and inputType-driven switching. Reporter asks whether the option should make LIME always start in Chinese mode and requests an optional fixed-Chinese-start override for 行列10 numeric-key Chinese input even in URL/number fields. Code inspection shows `LIMEService.initOnStartInput(...)` currently forces English-only/URL/number keyboard modes for number/datetime/phone/password/email/URI inputTypes before normal text-field language memory. Labels remain `question` + `enhancement` + `Usability`; the previous maintainer/automation explanation comment `4505846029` was deleted and the issue currently has no public comments. Keep open as product/author-team evaluation; do not blindly recreate the deleted comment unless Jeremy/maintainer wants a new concise explanation/acknowledgement.
- #75: Community-reported Android Cangjie keyboard redraw/layering bug on 6.1.7 / Android 15: after tapping numeric/symbol keyboard once and switching back to Chinese, stale numeric/symbol keyboard UI remains visible behind the Cangjie keys. Labeled `bug` + `Usability`, assigned to `jrywu`, acknowledgement/retest-after-fix note posted as comment `4505090642`, and analysis doc `docs/#75_ISSUE.md` exists. Keep open for implementation; do not ask for retest until a newer APK contains a clearly relevant keyboard switching/redraw fix.

## Operational Handoff / Next Actions
- Time: 2026-05-21T15:45:16+08:00
- From: Codex scheduled GitHub monitor
- Summary: No new APK, release, PR, or discussion activity since the last observed state. New/changed moderation focus is #63 latest clarification: Sweetlime is the normal Traditional baseline; LIME 6.1.6 remains Simplified with and without microphone permission.
- Needs: Debug #63 further; implement/fix #71 and #75; product/author-team decisions remain for #70/#72/#73/#74; watch #58 for sample-table follow-up.
- Links: #63 `https://github.com/lime-ime/limeime/issues/63`; #75 `https://github.com/lime-ime/limeime/issues/75`; current APK raw URL `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.7.apk`; #74 `https://github.com/lime-ime/limeime/issues/74`; #73 `https://github.com/lime-ime/limeime/issues/73`; #58 latest answer `https://github.com/lime-ime/limeime/issues/58#issuecomment-4504038716`; #71 latest acknowledgement `https://github.com/lime-ime/limeime/issues/71#issuecomment-4504791937`.

## Shared Task Board / Identity Exchange
- Purpose: This section is the repo-backed exchange area for Codex, Hermes, and future identities. Merge scheduled/background handoffs and task-board items here because local `.agents/shared/handoffs.md` and `.agents/shared/tasks.md` are not reliable for scheduled-session continuity.
- Format: `Status`, `Owner`, `Task`, `Context`, `Next`, `Updated`.
- Status: doing
  Owner: next LIME IME moderation/debugging identity
  Task: Continue #63 negative 6.1.6 voice-input follow-up.
  Context: Reporter clarified normal Traditional output is from Sweetlime, while LIME 6.1.6 still outputs Simplified Chinese with microphone permission both enabled and disabled.
  Next: Debug targeted Google/system voice path versus LIME inline dictation path on Xiaomi HyperOS 3 / Android 16; do not send another generic retest request until a new relevant fix lands.
  Updated: 2026-05-21T15:45:16+08:00
- Status: todo
  Owner: next LIME IME product/implementation identity
  Task: Review/plan #70/#72/#73/#74 enhancement requests and implement #71/#75 bug fixes.
  Context: #70 asks to hide/configure next-code candidates; #71 is a composition-cancel bug when switching Chinese to English; #72 asks to bundle 哈哈倉頡 and raises source/license questions; #73 asks Enter to commit raw code while Space commits Chinese candidates; #74 asks for optional fixed-Chinese-start behavior despite Android inputType switching; #75 reports stale number/symbol keyboard UI visible behind Cangjie after `123` -> Chinese switching.
  Next: Decide product direction for #70/#73/#74 and licensing posture for #72; implement/fix #71 using candidate-bar dismiss-style cancel semantics; investigate/fix #75 in Android keyboard switching/redraw path; do not bundle external tables without source/author/license verification.
  Updated: 2026-05-21T15:45:16+08:00
- Status: todo
  Owner: next LIME IME documentation/import identity
  Task: Watch #58 `.lime` v2 escaping follow-up.
  Context: Automation answered how to import ASCII `|` with `@format@|lime-text-v2` and `\|`; reporter may still provide a sample table if import fails.
  Next: If reporter shares a failing sample, inspect importer/docs and update docs or bug investigation as appropriate.
  Updated: 2026-05-21T15:45:16+08:00

## Historical Project-Memory Baseline
- Original automation/project memory said Android `6.1.1` was the latest known pre-release APK and gave this direct link: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.1.apk`.
- Newer observed state supersedes that baseline where noted above: current observed pre-release APK is `6.1.7`; #55/#54/#62/#64/#65/#66/#67/#68/#69 are closed where noted; #63 remains open after a negative 6.1.6 retest and latest reporter clarification; #71 and #75 remain open bugs needing implementation/fix follow-up; #70/#72/#73/#74 remain open enhancement/question/product-decision items.

## Update Instructions
- Scheduled runs should update this file through GitHub API when current issue states, APK observations, run outcomes, cross-agent handoff/continuation notes, or shared task-board items change.
- Keep operational handoffs in `Operational Handoff / Next Actions` and shared task-board items in `Shared Task Board / Identity Exchange` so different identities can exchange state reliably.
- Do not store canonical rule/policy changes here; store those in the local automation memory file.
