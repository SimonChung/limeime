# Issue #79: Android dark-mode emoji search field stays bright

## Problem statement

Reporter SmithCCho reports that in Android dark mode, the emoji panel search box remains bright/white and is visually glaring at night. The screenshot shows the emoji panel itself in a dark keyboard context while the search field at the top keeps a light rounded background.

Issue URL: https://github.com/lime-ime/limeime/issues/79

Relevant comments:

- Reporter screenshot/request: https://github.com/lime-ime/limeime/issues/79
- Initial acknowledgement: https://github.com/lime-ime/limeime/issues/79#issuecomment-4523853744
- Android 6.1.12 retest request: https://github.com/lime-ime/limeime/issues/79#issuecomment-4529659072
- Reporter confirmation and adjacent emoji-search input question: https://github.com/lime-ime/limeime/issues/79#issuecomment-4531664505

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

## Implementation notes

Implemented on `master` in commit `a763ee80b199` / `a763ee80b199360140185066f94ef619f4f2f716`:

1. Android no longer uses the fixed `0xF2FFFFFF` search-field background for every theme; it selects `EmojiPanelColors.searchBackground` through `currentEmojiPanelColors()`.
2. Empty-state text and active query text use `EmojiPanelColors.searchHint` / `EmojiPanelColors.searchText` instead of fixed gray/black values. The Android control remains a `TextView` updated by LIME's custom emoji-search key handling, not a native editable `EditText`.
3. The compound search icon from `android.R.drawable.ic_menu_search` is wrapped/mutated and tinted with `EmojiPanelColors.searchIcon`.
4. The theme palette includes explicit light, dark, pink, tech-blue, fashion-purple, relax-green, and system-following branches.
5. Rounded shape, padding, and search-field height are preserved.

## Fix / APK follow-up status

Android APK `LIMEHD2026-6.1.12.apk` contains the scoped emoji search-field theme fix from the latest emoji search/theme polish push.

Retest request posted: https://github.com/lime-ime/limeime/issues/79#issuecomment-4529659072

Reporter SmithCCho confirmed in https://github.com/lime-ime/limeime/issues/79#issuecomment-4531664505 that, in the tested Android dark-mode case, the search-field background and icon are no longer too bright. Treat the original visual/theme bug as reporter-confirmed fixed for the Android APK 6.1.12 scope.

The same comment raised a separate product/behavior question: during emoji search, typing table codes such as `100` with 行列/倉頡 did not enter the emoji search field; the code appeared in the host app's text field instead. Current Android code explains the direct-key path:

- Entering emoji search calls `setEmojiSearchKeyboard(emojiSearchInitialEnglishOnly(mEmojiSourceWasEnglish))`, so the search keyboard initially follows whether the user came from English mode.
- `handleEmojiSearchKey()` appends printable keys directly to `mEmojiSearchQuery` only when `shouldEmojiSearchConsumePrintableKey(primaryCode, mEnglishOnly)` is true.
- `shouldEmojiSearchConsumePrintableKey()` currently returns true only for English mode printable ASCII (`englishOnly && primaryCode >= 32 && primaryCode < 127`).
- In non-English IM mode, key events can continue through the normal IM/composition path; a picked non-emoji, non-composing candidate can be appended to emoji search through `appendPickedCandidateToEmojiSearch()`.

Live discussion after the reporter's question:

- `Limeroshenko` replied from APK 6.1.12 / Pixel 9 / Android 16 that emoji search behavior was normal for them: https://github.com/lime-ime/limeime/issues/79#issuecomment-4531768150
- Reporter `SmithCCho` clarified their failing case was APK 6.1.12 on Samsung A16 / Android 16 / One UI 8.0: https://github.com/lime-ime/limeime/issues/79#issuecomment-4531782542
- Maintainer `jrywu` replied that 6.1.12 emoji supports Chinese, while 6.1.11 and earlier did not: https://github.com/lime-ime/limeime/issues/79#issuecomment-4531795839

Treat this as an adjacent emoji-search input-method compatibility discussion, not evidence that the Android dark-mode color fix failed. Because the maintainer has already answered in public, do not post another automation reply unless new reporter evidence appears.

The same commit also includes iOS emoji search/polish source work, but Android APK availability does not verify iOS delivery or TestFlight behavior.

## Follow-up questions

- If `SmithCCho` reports that Chinese emoji search still fails on APK 6.1.12 after the maintainer clarification, collect exact steps and whether they are entering raw table codes, selecting Chinese candidates into emoji search, or using a specific Samsung/One UI keyboard state.
- Close #79 once the maintainer/reporter considers the adjacent emoji-search behavior answered, or split the input-method compatibility question if it needs separate product/debug tracking. The original Android visual/theme bug is already reporter-confirmed fixed for APK 6.1.12.
- iOS manual/device verification remains useful even though commit `a763ee80b199` added iOS emoji-search/theme UI work and screenshot coverage; do not treat Android APK confirmation as iOS/TestFlight confirmation.

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
