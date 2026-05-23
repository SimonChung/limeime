# Issue #79: Android dark-mode emoji search field stays bright

## Problem statement

Reporter SmithCCho reports that in Android dark mode, the emoji panel search box remains bright/white and is visually glaring at night. The screenshot shows the emoji panel itself in a dark keyboard context while the search field at the top keeps a light rounded background.

Issue URL: https://github.com/lime-ime/limeime/issues/79

Relevant comments:

- Reporter screenshot/request: https://github.com/lime-ime/limeime/issues/79
- Initial acknowledgement: https://github.com/lime-ime/limeime/issues/79#issuecomment-4523853744

## Classification

This should be tracked as a bug, not just an enhancement, because the dark keyboard/emoji panel theme is already active but one visible control does not follow it. The bug is visual/theme parity for the emoji search field in dark mode.

Current public labels should be `bug` + `Usability`.

## Reproduction steps

1. On Android, enable a dark LIME keyboard/theme or system dark-mode context that renders the emoji panel with a dark background.
2. Open the LIME emoji panel from the candidate bar / emoji key.
3. Observe the top search field.

Actual result: the emoji search control background is a bright/white rounded rectangle and can be uncomfortable in dark/night usage.

Expected result: the emoji search field background, hint text, typed text, and search icon should follow the active dark keyboard/emoji-panel theme with sufficient contrast.

## Android investigation

The Android emoji panel is built programmatically in `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`.

Relevant code:

```java
mEmojiSearchField = new TextView(mThemeContext);
...
mEmojiSearchField.setBackground(makeRoundRect(0xF2FFFFFF, dp(26)));
```

`updateEmojiSearchText()` also hard-codes the empty-state search text color and active search text color. This is a `TextView`, so the placeholder is implemented by manually setting the field text to `搜尋表情符號` rather than by using native `EditText` hint styling:

```java
mEmojiSearchField.setTextColor(0xFF8A8A8A);
...
mEmojiSearchField.setTextColor(ContextCompat.getColor(this, android.R.color.black));
```

The likely root cause is these hard-coded light-theme colors in the Android emoji search field. They do not branch on the selected keyboard/theme palette or dark-mode state.

## iOS impact check

The iOS emoji panel has a similar search control in `EmojiPanelView` inside `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift`:

```swift
private let searchField = UISearchTextField()
...
searchField.placeholder = "搜尋表情符號"
```

No matching hard-coded white background or black active-text override was found on the cited iOS `searchField` setup. The iOS code relies on `UISearchTextField` / dynamic system colors there, and other emoji panel controls use dynamic colors such as `.label`.

Preliminary assessment: the confirmed source-level issue is Android-specific so far. iOS is not obviously affected by the same hard-coded-color issue in the inspected search-field setup, but this remains pending manual dark-mode verification because the emoji panel is a custom keyboard extension view and can have theme/style overrides elsewhere.

## Proposed solution / investigation plan

Android:

1. Replace the hard-coded `0xF2FFFFFF` emoji search-field background with a theme-aware color.
2. Replace hard-coded empty-state gray and active black search text with theme-aware text colors. The Android control is a `TextView` updated by LIME's custom emoji-search key handling, not a native editable `EditText`.
3. Apply a theme-aware tint or replacement drawable for the compound search icon currently attached with `android.R.drawable.ic_menu_search`.
4. Ensure empty-state text, entered query text, and the search icon remain readable on both light and dark themes.
5. Keep rounded search-field shape and existing padding/height.

Possible implementation direction:

- Add a small helper that selects emoji search background / hint / text colors from the active keyboard theme or dark-mode state.
- Reapply those colors whenever the keyboard theme or emoji panel is rebuilt.

## Follow-up questions

- Which exact dark-theme search-field background should be used: near-black, gray, or the same surface color as other dark candidate/keyboard controls?
- Should non-default keyboard themes (`pink`, `tech_blue`, `relax_green`, `fashion_purple`) also get explicit themed search-field colors instead of only light/dark branching?
- After Android is fixed, should iOS receive an explicit theme styling pass for visual parity, or is the current system-adaptive `UISearchTextField` acceptable after manual verification?

## Verification plan

Android manual checks:

- Dark theme / system dark mode: emoji search field is not bright white.
- Light theme: search field still has clear contrast and looks intentional.
- Empty-state search text (`搜尋表情符號`) is readable.
- Typed search query text is readable.
- Search icon remains visible.
- Search mode still opens the English keyboard and filters emoji as before.
- Returning from emoji search to emoji panel still restores the panel layout.

Android regression checks:

- Candidate-bar emoji button still opens the emoji panel.
- Emoji category scrolling and category highlight still work.
- Committing emoji from the panel still records usage / recents as before.

iOS parity check:

- iOS dark mode: open the emoji panel and confirm whether `UISearchTextField` renders as an acceptable dark/adaptive control.
- If iOS shows a bright field too, extend the fix plan to explicitly style `searchField` using dynamic/theme-aware colors in `EmojiPanelView.setup()` inside `KeyboardViewController.swift`.
