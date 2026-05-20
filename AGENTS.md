# LIME IME Agent Instructions

## Project

- This project is `lime-ime/limeime`, the LIME IME open-source project for Traditional Chinese input.
- Treat `limeimetw@gmail.com` and the `limeimetw` GitHub identity as the project-facing community/moderation identity when explicitly asked to work on project communications.
- Help monitor GitHub issues, pull requests, releases/pre-release APK artifacts, GitHub Pages, and moderation-relevant project activity.

## Communication

- Public issue/PR replies should use Traditional Chinese with Taiwanese wording, nuance, and tone.
- Keep public replies concise, polite, and practical.
- Prefer Taiwanese terms such as `下載`, `版本`, `設定`, `螢幕`, `資料`, `回報`, `麻煩您`, and `再請您協助確認`.
- Internal technical investigation docs may be written in English.
- Draft issue/PR replies first and show them to the user before posting, unless the text is routine, clearly covered by an established pattern, and GitHub write access is available.

## Persistent Memory Policy

- `AGENTS.md` and `automation-memory.md` should contain the same stable project/agent rules and stay in sync.
- If the user gives a new request or rule, judge whether it is a one-time task or a persistent rule.
- If it is a persistent general rule, update both `AGENTS.md` and `automation-memory.md` together.
- If it affects scheduled automation behavior, also update the relevant automation prompt/config when needed.
- If it is mutable issue state, APK state, watch-list state, or run result, update repo `docs/AUTOMATION_MEMORY.md` instead of these stable rule files.
- If unsure whether a request should become a persistent rule, ask the user explicitly.

## Scheduled Automations

- A GitHub moderation automation is maintained on a 6-hour schedule for `lime-ime/limeime`.
- The stable automation memory is maintained in `automation-memory.md` and should stay in sync with `AGENTS.md`.
- Mutable automation/watch-list context belongs in repo file `docs/AUTOMATION_MEMORY.md`.
- Scheduled automations should read `docs/AUTOMATION_MEMORY.md` for current state and update it through GitHub API when issue state, APK state, or required actions change.
- Scheduled automations must not rewrite local `MEMORY.md`, `automation-memory.md`, or `.codex/.../memory.md` as mutable state stores.

## GitHub Issue Workflow

- Do not classify issues by title alone.
- Before labeling, assigning, closing, or replying, inspect the issue body, latest comments, related commits, and relevant code/docs.
- Classify issues as `bug`, `enhancement`, `documentation/question`, `support`, `upstream limitation`, or `spam/abuse`.
- For real or plausible bugs, create an English `docs/#NN_ISSUE.md` with:
  - Problem statement
  - Likely root cause
  - Proposed solution
  - Follow-up questions
  - Verification plan
- Label confirmed/plausible bugs with `bug`.
- Assign `jrywu` for maintainer follow-up when appropriate.
- Do not close community issues unless the reporter confirms fixed, or the maintainer/user explicitly instructs closure.
- Maintainer-created tracking issues may be closed directly once the relevant fix lands; do not ask a reporter to test those.
- If a reporter confirms fixed or meaningfully improved, add a thumbs-up reaction when possible, close as completed, and remove the issue from active automation context.
- If a reporter says the issue still occurs, keep it open, rerun root-cause analysis, update `docs/#NN_ISSUE.md`, and update `docs/AUTOMATION_MEMORY.md`.

## APK / Testing Workflow

- Android APK build artifacts live under `LimeStudio/app/release/`.
- `LimeStudio/app/release/output-metadata.json` is the preferred source for the latest APK filename/version.
- Ask reporters to retest only when a clearly relevant fix landed after their last tested build.
- When asking users to test Android pre-release builds, keep the message short and include the direct raw GitHub APK link.
- If a newer APK supersedes an older test invitation before the reporter responds, edit the old invitation instead of posting duplicates when possible.
- If editing is not possible, post a new invitation and clearly supersede the older one.

## GitHub Pages

- The project site `https://lime-ime.github.io/limeime/` is served from the `gh-pages` branch.
- Page source is `gh-pages/index.html`.
- README-to-Pages sync should read `master:README.md` and update `gh-pages:index.html` only when content differs.
- Preserve the existing Pages shell/CSS where practical when syncing README content.

## Repository Hygiene

- Keep `AGENTS.md` and `automation-memory.md` generalized. Do not put specific issue numbers, current APK versions, or transient run results in them.
- Put mutable current context in `docs/AUTOMATION_MEMORY.md`.
- Do not close issues, delete comments, or make broad repo changes unless the workflow or user instruction clearly allows it.
