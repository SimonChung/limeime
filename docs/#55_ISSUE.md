# Issue #55 - Android Key Preview Popup Covers the Next Key

**Status:** Popup lifecycle fix implemented and visually verified  
**Date:** 2026-05-16  
**Reporter:** SmithCCho  
**GitHub:** https://github.com/lime-ime/limeime/issues/55  
**Scope:** Android soft-key preview popup

---

## Problem Statement

The bug is the magnified key-preview popup itself. During fast typing, the
preview bubble for the previous key hides too slowly and can visually cover or
interfere with the next key the user wants to tap. The reporter confirmed this
in the issue comments:

> 是指按按鍵跳出的 preview 延遲消失嗎?
>
> 是的，沒錯！

This is not primarily a keyboard bitmap redraw problem. The earlier
double-buffering change can reduce key-face redraw work, but it does not solve
the user-visible complaint because the `PopupWindow` preview lifecycle is mostly
unchanged.

## Second-Run Root Cause

### RC1 - Release schedules delayed hide instead of hiding now

On release, `PointerTracker.onUpEvent()` asks the UI proxy to clear preview:

- `PointerTracker.java:391` cancels key timers.
- `PointerTracker.java:393` calls `showKeyPreviewAndUpdateKey(NOT_A_KEY)`.
- `PointerTracker.java:481-493` forwards `NOT_A_KEY` to
  `LIMEKeyboardBaseView.showPreview(...)`.

But `LIMEKeyboardBaseView.showPreview(NOT_A_KEY, ...)` does not hide the popup
immediately:

- `LIMEKeyboardBaseView.java:1268-1269` calls
  `mHandler.dismissPreview(mDelayAfterPreview)`.
- `LIMEKeyboardBaseView.java:398-403` starts fade-out animation and posts
  `MSG_DISMISS_PREVIEW` after the delay.
- `config.xml:28` sets `config_delay_after_preview = 70`.
- `config.xml:30` sets `config_preview_fade_out_anim_time = 53`.

So after the finger releases, the preview remains visible for roughly the
configured delay plus a visible scale animation window. At normal typing speed,
that is long enough to overlap the user's next target.

### RC2 - The fade-out is not actually a fade

`key_preview_fadeout.xml` only scales the preview from `1.00` to `0.98`. It does
not animate alpha. Visually, the popup remains opaque and looks like it is still
present until `MSG_DISMISS_PREVIEW` finally sets it invisible and dismisses the
window.

This explains the user perception: the popup does not feel like it is fading
away; it feels like it is hanging over the keyboard.

### RC3 - Pending preview messages can outlive the touch they came from

The handler has separate message types for popup/update/show/dismiss:

- `MSG_POPUP_PREVIEW` -> `showKey(...)`
- `MSG_SHOW_PREVIEW` -> set preview text `VISIBLE`
- `MSG_DISMISS_PREVIEW` -> set preview text `INVISIBLE` and dismiss popup

`popupPreview(...)` removes pending `MSG_POPUP_PREVIEW`, but it does not cancel
pending `MSG_SHOW_PREVIEW` or `MSG_DISMISS_PREVIEW`. `dismissPreview(...)`
starts the dismiss animation and queues `MSG_DISMISS_PREVIEW`, but it also does
not cancel a pending `MSG_SHOW_PREVIEW`.

This means rapid key transitions can leave stale show/hide work in the handler
queue. Even if delays are short, the popup lifecycle can lag behind the active
finger.

### RC4 - `showKey(...)` does expensive live popup work on every key

Every preview update mutates and measures a live `TextView` inside a
`PopupWindow`:

- set text/drawables/typeface/padding (`LIMEKeyboardBaseView.java:1283-1303`)
- measure with unspecified specs (`LIMEKeyboardBaseView.java:1304-1307`)
- update or show the popup window (`LIMEKeyboardBaseView.java:1340+`)

This is secondary to the hide delay, but it adds more UI-thread work exactly
when the user is typing fastest.

## What The Previous Attempt Did

The previous implementation changed the keyboard surface drawing path:

- added front/back bitmaps;
- stopped `invalidateKey()` from calling `onBufferDraw()` synchronously;
- scheduled key-face redraws with `postInvalidateOnAnimation()`.

That can help key highlight redraw pressure, but it is not the fix for #55
because the complaint is the preview popup covering the next key. The popup
still delays hide and still runs its own `PopupWindow` update/hide path.

## Proposed Next Move

Fix the preview popup lifecycle first. Do not add a preference toggle as the
main answer, and do not spend more time on keyboard-surface buffering until the
popup hide behavior is corrected.

### Step 1 - Add immediate preview dismissal

Add a handler/helper path that hides the preview immediately:

```java
private void dismissPreviewNow() {
    removeMessages(MSG_POPUP_PREVIEW);
    removeMessages(MSG_SHOW_PREVIEW);
    removeMessages(MSG_DISMISS_PREVIEW);
    LIMEKeyboardBaseView view = mLIMEKeyboardBaseViewWeakReference.get();
    if (view == null) return;
    view.mPreviewText.clearAnimation();
    view.mPreviewText.setVisibility(INVISIBLE);
    if (view.mPreviewPopup.isShowing()) {
        view.mPreviewPopup.dismiss();
    }
}
```

Then use this path when `showPreview(NOT_A_KEY, ...)` is called from normal key
release/cancel. A released key should not leave an opaque popup over the next
target.

### Step 2 - Cancel stale show/dismiss messages on every state transition

Update handler methods so state transitions are exclusive:

- `popupPreview(...)`: cancel pending dismiss and show before showing/updating a
  new key.
- `showPreview(...)`: cancel pending dismiss for the same new key.
- immediate dismiss: cancel popup/show/dismiss.

This prevents old delayed messages from resurrecting or hiding the wrong preview
during fast typing.

### Step 3 - Remove or neutralize the scale-only fade for key preview

For normal key preview, either:

- remove fade-out completely and use immediate hide on release, or
- change fade-out to a very short alpha animation if a visual transition is
  still wanted.

The current scale-only animation should not remain as the normal key-release
path because it stays opaque and still covers keys.

### Step 4 - Keep long-press popup keyboard behavior separate

Do not break popup mini-keyboards (`popupKeyboard` / long-press alternates).
Those are a different feature from the magnified key preview. Verification must
confirm long-press popup keyboards still open and can select alternates.

### Step 5 - Optional optimization after correctness

After the hide behavior is fixed, reduce preview update cost:

- cache measured preview size by key width + label class where possible;
- avoid resetting typeface/text size when unchanged;
- avoid `PopupWindow.update(...)` when position/size/text are unchanged.

This is secondary. The correctness fix is immediate hide plus stale-message
cancellation.

## Expected Behavior After Fix

1. Tap a normal key: preview can appear while the finger is down.
2. Release the key: preview disappears immediately or near-immediately.
3. Rapidly tap the next key: no previous-key preview remains over the next key.
4. Long-press keys with alternates still open the mini keyboard.
5. Key input commits remain unchanged.

## Verification Plan

Use Android visual verification on the emulator:

1. Build/install debug APK.
2. Enable and select LIME with `adb shell ime enable ...` and `adb shell ime set ...`.
3. Open a normal text/search field and show the English keyboard.
4. Tap adjacent keys quickly with touch input only.
5. Confirm the previous preview does not remain over the next key after release.
6. Capture screenshots during and immediately after rapid taps.
7. Long-press a key with alternates, such as English `e`, and confirm the
   mini-keyboard still opens and commits an alternate.
8. Repeat a quick check on phone/number layouts to confirm no preview regression.

## Implementation Result

Implemented the popup-first fix in `LIMEKeyboardBaseView.java`:

- Added `UIHandler.dismissPreviewNow()` to cancel popup/show/dismiss messages,
  clear any running preview animation, hide the preview `TextView`, and dismiss
  the `PopupWindow` immediately.
- Changed `showPreview(NOT_A_KEY, ...)` to call immediate dismissal instead of
  delayed `dismissPreview(mDelayAfterPreview)`.
- Updated `popupPreview(...)`, `showPreview(...)`, and delayed
  `dismissPreview(...)` to cancel stale show/dismiss/popup messages so old
  handler work cannot outlive the current touch transition.

The scale-only fade-out resource remains in the project, but normal key release
no longer uses it. Long-press mini-keyboards remain separate and were verified.

Verification completed:

1. `./gradlew :app:assembleDebug` - pass.
2. `./gradlew :app:installDebug` - pass on Pixel 9 Pro API 36 emulator.
3. `adb shell ime enable ...` / `adb shell ime set ...` - LIME selected.
4. Android Studio Running Devices visual check:
   - English keyboard visible in Chrome search field.
   - Rapid adjacent-key taps entered text.
   - After rapid taps, no previous-key magnified preview remained over the
     keyboard.
   - Long-press English `e` opened the alternate mini-keyboard.
   - Selecting `è` from the mini-keyboard committed the accented character and
     dismissed the popup.
   - Number layout quick tap check showed no stuck preview.
5. `adb logcat -d -t 500` grep for crash/window/popup exceptions - no fatal
   exception or popup/window crash found. One synthetic-input warning appeared:
   `onUpEvent: corresponding down event not found for pointer 0`.
6. `./gradlew :app:testDebugUnitTest` - pass (`NO-SOURCE`, build successful).

Screenshots captured in `.Codex/txt/`:

- `android_issue55_popup_before.png`
- `android_issue55_popup_after_rapid_taps.png`
- `android_issue55_popup_longpress_e.png`
- `android_issue55_popup_after_alternate.png`
- `android_issue55_popup_number_layout.png`
