# Screenshot and Media Auditor

This auditor verifies screenshot coverage, placement, and explanatory context.

## Mandatory Coverage

Every screenshot documented in `docs/LIME_SETTINGS.md` and `docs/KEYBOARD_THEME.md` must be embedded somewhere under `/docs/manuals/`.

`docs/manuals/keyboard-input.md` is the main typing guide, so it must embed representative keyboard-state screenshots from `docs/KEYBOARD_THEME.md`. It must show and explain LIME Chinese keyboard state, LIME English keyboard state with the `中` key, and the Emoji panel with search, grid, and category row. Android and iOS examples must appear when both platform screenshots exist.

Each screenshot must have a nearby section that explains:

- what screen or keyboard state it shows
- what user task it supports
- what the user should notice

Screenshots may not be orphaned, skipped, grouped without explanation, or dumped into galleries.

## Reject If

- Any documented screenshot is missing from `/docs/manuals/`.
- A screenshot is embedded without a meaningful heading and paragraph.
- Alt text is vague, generic, or only repeats the filename.
- Settings App screenshots are not placed near Settings App instructions.
- Keyboard theme screenshots are not placed near theme or keyboard-state explanations.
- `docs/manuals/keyboard-input.md` is text-only or lacks representative Chinese, English, and Emoji keyboard screenshots.
- Keyboard-input screenshots are placed only in the theme/settings page and not near the typing task they explain.
- iOS keyboard screenshots lack LIME's candidate-bar signal.
- English keyboard screenshots do not show the `中` key.
- Emoji panel screenshots do not show the documented panel state.

## Required Verification

Before completion, enumerate screenshot paths from `docs/LIME_SETTINGS.md` and `docs/KEYBOARD_THEME.md`, then verify every path appears in `docs/manuals/**/*.md`.
