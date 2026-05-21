# Issue #75: Cangjie keyboard shows number/symbol keyboard remnants behind keys

## Problem statement

Community reporter `ejmoog` reports that on Android 15 with LIME IME 6.1.7, the Cangjie soft keyboard can show the number/symbol keyboard behind the Cangjie layout after switching modes.

Primary reported reproduction:

1. Start from the normal Cangjie Chinese keyboard.
2. Tap the numeric keyboard (`123` / number keyboard) once.
3. Switch back to Chinese.
4. The Chinese/Cangjie keys are visible, but a previous number/symbol keyboard layer remains visible underneath/behind the current keyboard.

The screenshot shows Cangjie keys in the foreground while another keyboard layer or toolbar controls remain visible through/around the keys, suggesting a stale keyboard view/invalidation or mode-state problem rather than an input conversion issue.

Additional reporter follow-up on the same issue: in English mode, long-pressing some European/accented letter popup keys can leave the popup visible indefinitely if the user does not select one; switching back to Chinese does not dismiss it. The reporter also suggests an option to disable accented/European letter popup display because many Traditional Chinese users may not need it.

## Likely root cause

Likely area: Android keyboard switching and redraw state in:

- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEKeyboardSwitcher.java`
- keyboard XML layouts for Cangjie and number/symbol modes under `LimeStudio/app/src/main/res/xml/`

Relevant observations from source inspection:

- `LIMEService.switchKeyboard(...)` routes symbol/number and Chinese/English transitions through `LIMEKeyboardSwitcher`.
- `KEYCODE_SWITCH_TO_SYMBOL_MODE` calls `mKeyboardSwitcher.toggleSymbols()`.
- `KEYCODE_SWITCH_TO_IM_MODE` sets `mEnglishOnly = false` and calls `initialIMKeyboard()`.
- `LIMEKeyboardSwitcher.setKeyboardMode(...)` sets a new `LIMEKeyboard` on the existing `LIMEKeyboardView`, then calls `mInputView.setKeyboard(mInputView.getKeyboard())` as an invalidation path.
- Symbol mode handling can leave internal `mIsSymbols` / `mIsChinese` state transitions non-obvious. Returning to Chinese through `initialIMKeyboard()` should set `isSymbol=false`, but stale drawing can still appear if the old keyboard surface is not fully invalidated or if transparent key backgrounds expose prior content.

Most plausible technical causes to check:

1. `LIMEKeyboardView` does not fully clear its canvas/background before drawing the new keyboard after a number/symbol -> Cangjie transition.
2. `LIMEKeyboardSwitcher` leaves symbol/number mode state inconsistent when returning to Chinese, causing the wrong keyboard/background to be cached or redrawn.
3. A Cangjie keyboard theme/key background is partially transparent, making stale pixels from the previous keyboard visible after layout switching.
4. `LIMEKeyboardBaseView` mini-keyboard popup lifecycle may not be cancelled when the main keyboard mode changes. Source inspection shows `onLongPress(...)` opens `mMiniKeyboardPopup`, and dismissal currently happens through mini-key selection/cancel, `closing()`, or `handleBack()`; keyboard switching paths should verify they call a popup dismissal/closing path so a long-press accented-letter popup cannot survive English -> Chinese switching.

## Proposed solution

Investigate and fix the keyboard switch path rather than changing input-method mapping logic:

1. Reproduce on Android 15 / 6.1.7 with Cangjie:
   - Cangjie keyboard -> `123` numeric/symbol keyboard -> switch back to Chinese.
   - Test with default and any custom keyboard themes if possible.
2. Reproduce the long-press popup path:
   - English keyboard -> long-press a key with accented/European popup choices -> do not select an alternative -> switch to Chinese.
   - Confirm whether the mini-keyboard popup remains visible and whether Back/outside tap dismisses it.
3. Add temporary logging around `LIMEService.switchKeyboard(...)`, `initialIMKeyboard()`, and `LIMEKeyboardSwitcher.setKeyboardMode(...)` for:
   - `primaryCode`
   - `mIsChinese`
   - `mIsSymbols`
   - selected keyboard XML id/name
   - active IM code
4. Verify that returning to Cangjie uses `isSymbol=false`, `isIm=true`, and `R.xml.lime_cj` / Cangjie layout.
5. Force a clean redraw when keyboard mode changes from symbol/number to Chinese:
   - clear symbol state when explicitly returning to IM mode if needed;
   - dismiss any active key preview / mini keyboard popup before or during keyboard mode changes;
   - invalidate the whole `LIMEKeyboardView` / parent input view;
   - ensure the keyboard view/background is opaque or clears the canvas before drawing keys.
6. Consider a separate product setting for showing accented/European letter popup alternatives. This is not required to fix the stuck-popup bug, but the reporter explicitly requested configurability.
7. Avoid broad cache resets unless needed; prefer a targeted mode-state, popup-dismissal, or redraw fix.

## Follow-up questions

The current report includes reproduction steps, screenshots, app version, and Android version. Ask only if needed after attempted reproduction:

- Device model and whether a custom keyboard theme/keyboard size/split-keyboard option is enabled.
- Whether the Cangjie number/symbol layering happens every time after `123` -> Chinese, or only after rotating/changing apps.
- Whether the same layering issue appears in non-Cangjie keyboards.
- Which English keys leave the accented/European popup stuck, and whether tapping Back or another non-key area dismisses it.

## Verification plan

- On Android 15, install the fixed build and confirm:
  - Cangjie -> numeric/symbol keyboard -> back to Chinese does not leave number/symbol remnants behind.
  - Repeated switches do not accumulate stale keyboard layers.
  - English long-press accented/European popup does not remain stuck after switching to Chinese or changing keyboard mode.
  - Arrow keys, candidate strip, emoji key, microphone key, and `123` key still render correctly.
  - Other layouts (English, Array, Dayi, phonetic) still switch normally.
- If a new APK includes the fix, ask the reporter to retest with the direct APK link and specifically confirm both the `123` -> Chinese Cangjie switching path and the English long-press popup dismissal path.
