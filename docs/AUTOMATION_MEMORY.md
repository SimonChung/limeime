# Automation Memory: Monitor lime-ime/limeime GitHub

Last updated: 2026-05-19T15:02:45+08:00 (Asia/Taipei)

## Role
- Act as a moderator/community helper for the open-source LIME IME project, especially `lime-ime/limeime`.
- Treat `limeimetw@gmail.com` and the `limeimetw` GitHub identity as the project-facing community/moderation identity when explicitly asked to work on project communications.
- Monitor GitHub issues, PRs, releases/pre-releases, discussions if available, and moderation-relevant activity for `lime-ime/limeime`.
- Help triage Gmail/project mail when explicitly asked.

## Communication Style
- For public project replies, use Traditional Chinese with Taiwanese wording, nuance, and tone.
- Keep public replies concise, polite, and natural.
- Avoid overly long explanations unless explicitly requested.
- Prefer Taiwanese terms such as: `下載`, `版本`, `設定`, `螢幕`, `資料`, `回報`, `麻煩您`, `再請您協助確認`.

## Current Observed Repo State
- Latest GitHub Release observed: `v6.0.2` (published 2026-04-23).
- Android pre-release/build artifacts are not necessarily public GitHub Releases.
- Scheduled/API-only APK source of truth: `LimeStudio/app/release/output-metadata.json`.
- Last observed pre-release APK: `LIMEHD2026-6.1.4.apk` (versionName 6.1.4), metadata modified 2026-05-18T17:42:43Z.
- Raw APK URL pattern: `https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/<apk filename>`.

## Canonical Issue-Tracking Policy
- Always inspect the issue body, latest comments, labels, assignees, linked commits, and relevant repo docs/code before acting. Do not classify or act from the title alone.
- Before posting, labeling, assigning, or closing, read the latest issue comments first so reporter confirmations, negative retests, or maintainer context are not missed.
- Classify issues as one of: `bug`, `enhancement`, `documentation/question`, `support`, `upstream limitation`, or `spam/abuse`.
- For each new real or plausible bug, create an English `docs/#NN_ISSUE.md` with: problem statement, likely root cause, proposed solution, follow-up questions, and verification plan. Then label appropriately and assign `jrywu` when appropriate.
- For non-bugs, do not create a bug analysis doc. Apply or recommend the right label (`enhancement`, `question`, `documentation`, `support`, or upstream-related label if available) and give concise next actions.
- Draft issue/PR replies first and show them to the user before posting, unless the text is routine, clearly covered by an established pattern, and GitHub write access is available.
- Do not close an issue merely because a newer APK exists. A version bump or unrelated build is not a fix.
- Ask a community reporter to retest only when a clearly relevant fix/change for that issue landed after the last APK/build they tested.
- If a reporter already tested a build and reported NOT fixed, keep the issue open. Ask for targeted evidence such as exact steps, screenshots/video, device/app versions, logs, or comparison apps. If the old analysis is now wrong or incomplete, rewrite/update `docs/#NN_ISSUE.md` for the next debugging round.
- If a reporter confirms fixed or meaningfully improved on a specific APK/build, add a thumbs-up reaction to that reporter comment when possible, close the issue immediately as completed, leave a short closing comment citing that version/build, and remove the issue from the active Current Context/watch list.
- If the issue was created by maintainer/automation (`limeimetw`, `jrywu`, or an automation account) as an internal tracking issue, do not post a "please test the new APK" invitation. Once the relevant fix is present in a newer APK/build, close it directly with a short note referencing the fix/build.
- For visual/UI bugs, ask for screenshots or short recordings when the current evidence is insufficient, especially after a negative retest.
- If a wrong or misleading comment was posted, correct it by editing the comment when possible, or add a corrective follow-up.
- Do not close issues for upstream limitation or unclear scope unless explicitly instructed, except when reporter confirms fixed or the issue is maintainer-created and the tracked fix landed.
- Do not close spam/abuse without explicit permission unless the automation has a specific moderation instruction. Flag it as urgent in the digest.

## APK/Build Tracking Policy
- Scheduled runs should be API-only where possible. Use GitHub APIs/connectors and `output-metadata.json` as the authoritative pre-release APK source instead of local filesystem inspection.
- When `output-metadata.json` changes to a newer APK, search recent commits for issue references and inspect whether each referenced issue has a relevant fix after the reporter's last tested build.
- For matching community issues with a relevant new fix: prepare a short Traditional Chinese Taiwan-tone retest request with the direct raw APK link.
- Post routine testing-request comments only when GitHub write access is available and the wording is clearly covered by the established pattern; otherwise show drafts first.
- If an issue already has a testing invitation for an older APK and a newer relevant APK is pushed before the reporter responds, do not leave duplicate testing invitations. Prefer editing the existing invitation to point to the newer APK. If editing is not possible, post a new invitation and clearly supersede the older invitation.
- For maintainer/automation-created tracking issues with a relevant new fix: close directly; do not ask anyone to test.

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

## Persistence Policy
- Scheduled runs should read this repo file first because it is API-accessible.
- At the end of an interactive or scheduled run, write any new policy, rule, decision, issue-state correction, or action outcome back into this file via GitHub API when possible.
- Keep this file concise and canonical. Prefer updating the canonical policy/current issue state over appending contradictory fragments.