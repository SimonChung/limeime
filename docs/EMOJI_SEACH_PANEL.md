# Emoji Search Panel

This document records the emoji search panel behavior implemented during the iOS emoji-panel debugging pass.

Note: the filename keeps the current requested spelling, `EMOJI_SEACH_PANEL.md`.

## Goal

Emoji search mode is not a second custom keyboard stack. It is the normal LimeIME keyboard stack with one fixed search header added above it.

The iOS stack is:

1. Fixed emoji search header.
2. Normal candidate bar.
3. Normal keyboard view.

The candidate bar and keyboard must behave exactly like normal Chinese/English keyboard mode. Search mode must not resize, replace, or special-case the candidate bar.

## Fixed Search Header

The search box is fixed-height:

- Top inset: `EmojiPanelView.searchFieldTopInset` = 10 pt.
- Search field height: `EmojiPanelView.searchFieldHeight` = 44 pt.
- Header height: `EmojiPanelView.searchHeaderHeight` = 54 pt.

The search box height must not change between:

- English search mode.
- Chinese search mode.
- Empty query.
- Active composing.
- Candidate results visible.

## iOS Implementation

The earlier implementation reused `EmojiPanelView` as the search-mode header. That was wrong because the full emoji panel still owned hidden layout space, which made the search UI and candidate bar feel like a special stack.

The current implementation separates the two roles:

- Normal emoji browsing still uses `EmojiPanelView`.
- Emoji search mode uses a dedicated `emojiSearchHeaderView` with its own fixed `UISearchTextField`.
- When search mode starts, the full `EmojiPanelView` is hidden.
- The normal `CandidateBarView` stays visible and is shifted down only by the fixed search header height.
- `KeyboardView` stays attached to `candidateBar.bottomAnchor`, same as normal keyboard mode.

Relevant controller state:

- `emojiSearchHeaderView`
- `emojiSearchField`
- `emojiSearchFieldHeightConstraint`
- `isEmojiSearchMode`
- `emojiSearchEnglishOnly`
- `emojiSearchSourceLayout`
- `emojiSearchCandidates`

## Candidate Bar Contract

The emoji search candidate bar is the same `CandidateBarView` used for ordinary composing.

Required behavior:

- The candidate bar height is always `activeCandidateBarHeight`.
- The composing strip remains part of the normal candidate bar.
- Candidate bar location does not jump between English and Chinese search mode.
- The dismiss button uses the normal candidate-bar dismiss style and location.
- The expand chevron and expanded candidate view remain the same behavior as ordinary composing.
- Empty search text shows the fallback deduped emoji list, matching Android behavior.

The composing strip showing above candidates is expected. It is not a gap.

## Search Input Behavior

Emoji search supports both English and Chinese input.

English search mode:

- Printable key presses go directly into the emoji search field.
- Delete edits the search field.
- Enter/Done exits emoji search mode and returns to the source keyboard.

Chinese search mode:

- Printable keys go through the normal Chinese IM composer.
- The candidate bar shows composing code and Chinese candidates normally.
- Picking a Chinese text candidate appends that word to the emoji search query.
- Emoji candidates commit emoji directly.
- Delete edits composing first; when no composing text exists, it edits the search field.
- Enter/Done exits emoji search mode and returns to the source keyboard.

Mode switching inside emoji search:

- `中` switches the search keyboard to Chinese IM and stays in emoji search mode.
- `abc` switches the search keyboard to English and stays in emoji search mode.
- Dismiss or Enter/Done exits emoji search mode and restores the keyboard mode the panel came from.

## Android Parity

Android behavior is the parity target for empty-query results and Chinese search:

- Empty emoji search shows the deduped fallback/recent list instead of an empty candidate bar.
- Chinese IM can be used inside emoji search.
- Switching `中` / `abc` stays inside emoji search.
- Dismiss and Done exit emoji search and clear the search text.

iOS was adjusted to match this behavior while preserving iOS layout rules.

## Android Implementation

Android keeps the same conceptual stack as iOS in search mode:

1. Emoji search box.
2. Normal input candidate strip.
3. Normal `LIMEKeyboardView`.

The search box lives in the emoji panel container, while the candidate strip and keyboard are the same views used by ordinary input.

Relevant implementation in `LIMEService.java`:

- `enterEmojiSearchMode()` starts search mode, clears `mEmojiSearchQuery`, chooses the initial search keyboard from `mEmojiSourceWasEnglish`, and refreshes the candidate/input container.
- `renderEmojiContent(query)` switches the emoji panel between normal browsing and search mode.
- `emojiSearchPanelHeight()` keeps the emoji panel container collapsed to the search-box area while the real keyboard is visible below it.
- `setInputCandidateStripVisibility(emojiSearchInputCandidateStripVisibility(...))` makes the ordinary candidate strip visible only during emoji search.
- `enforceEmojiKeyboardVisibility()` hides the keyboard in normal emoji browsing, but shows the real keyboard while the search field is focused.
- `showEmojiSearchCandidatesInInputStrip(...)` sends emoji search results to the normal `CandidateView` through `setSuggestions(...)`.
- `clearEmojiSearchCandidates()` clears the same candidate view when leaving search.

Search input is owned by:

- `mEmojiSearchQuery`
- `mEmojiSearchField`
- `handleEmojiSearchKey(int primaryCode)`
- `appendPickedCandidateToEmojiSearch(Mapping candidate)`
- `handleEmojiBackspace()`
- `updateEmojiSearchText()`

Keyboard routing is owned by:

- `setEmojiSearchKeyboard(boolean englishOnly)`
- `emojiSearchInitialEnglishOnly(boolean sourceWasEnglish)`
- `isEmojiSearchKeyboardModeKey(int primaryCode)`
- `resolveEmojiSearchEnglishOnlyForModeKey(int primaryCode, boolean currentEnglishOnly)`
- `shouldEmojiSearchConsumePrintableKey(int primaryCode, boolean englishOnly)`
- `emojiSearchImeOptions(int imeOptions)`

The Android Done key is forced with:

```java
static int emojiSearchImeOptions(int imeOptions) {
    return (imeOptions & ~EditorInfo.IME_MASK_ACTION) | EditorInfo.IME_ACTION_DONE;
}
```

Exit behavior:

- `KEYCODE_DONE`, enter, and the emoji-panel key exit emoji search through `exitEmojiSearchToKeyboard()`.
- Exit clears `mEmojiSearchQuery`.
- Exit clears the visible search field text.
- Exit hides the emoji keyboard and restores the source keyboard path.

Chinese search behavior:

- English mode consumes printable ASCII directly into `mEmojiSearchQuery`.
- Chinese mode does not consume printable keys directly; keys go through the normal IM composer.
- Picking a non-emoji, non-composing-code candidate appends the candidate word to `mEmojiSearchQuery`.
- Picking an emoji candidate commits the emoji.
- Backspace edits the search query when it has text; otherwise it falls back to normal backspace behavior.

Result behavior:

- Non-empty search queries call `SearchServer.searchEmoji(query, EN/TW, 80)`, dedupe by emoji string, then fall back to keyword matching on `FALLBACK_EMOJI_CATEGORIES` if DB search returns nothing.
- Empty search mode renders the deduped fallback/recent list in the normal candidate strip, not an empty bar.
- Search results are converted to `Mapping` objects marked as emoji records before being sent to `CandidateView`.

The Android candidate bar and expanded candidate behavior are therefore not separate emoji widgets. They are the ordinary candidate infrastructure reused for emoji search results.

## Verification Notes

Verified in code/build:

- The dedicated iOS search header compiles.
- `xcodebuild -project LimeIME-iOS/LimeIME.xcodeproj -scheme LimeIME -destination 'generic/platform=iOS Simulator' build` succeeded.

Visual verification still belongs on device/simulator because the critical requirement is layout behavior:

- Search box remains fixed at 44 pt.
- Candidate bar is directly below the fixed header.
- Candidate bar does not move between English and Chinese search mode.
- Chinese composing strip appears as part of the normal candidate bar.
- No hidden `EmojiPanelView` space appears between the search box and candidate bar.

## Related Docs

- [EMOJI_KEYBOARD.md](EMOJI_KEYBOARD.md)
- [EMOJI_BAR.md](EMOJI_BAR.md)
- [CANDI_LAYOUT.md](CANDI_LAYOUT.md)
