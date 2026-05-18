# #54 — Brave URL bar candidates covered by browser toolbar after EN→ZH switch

Issue: https://github.com/lime-ime/limeime/issues/54

## Problem statement
In Brave Browser’s address bar, if the user types in **English first** and then switches to **Chinese**, the candidate UI becomes partially covered by Brave’s toolbar (see screenshots in the issue).

## Classification
Bug report (UI / window-insets / IME positioning interaction).

## Likely root cause (hypothesis)
This looks like an **IME window insets / layout** interaction with Brave’s custom address-bar UI.

Common failure modes that can produce “IME UI covered by app chrome”:
- The IME window (or its embedded candidate strip) does not correctly apply **WindowInsets** (system bars / gesture nav / IME insets), so the last rows/edges render under overlays.
- `InputMethodService.onComputeInsets()` is overridden in a way that prevents the host app from receiving correct insets for the IME window height.
- Switching EN→ZH changes LIME’s candidate visibility state (`hasCandidatesShown`, `mEnglishOnly`, prediction state), which may toggle candidate strip height without forcing a re-layout/inset pass.

LIME currently uses an embedded candidate view inside the input view container and overrides `onComputeInsets()` with a “no-op” comment. This may be fine for most apps, but Brave’s address bar can be a special case.

## What to inspect in code
Android:
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
  - `onCreateInputView()` inset padding logic (currently gated by API level)
  - `onComputeInsets()` override
  - transitions around URL fields (`EditorInfo.TYPE_TEXT_VARIATION_URI`) + switching language mode
  - candidate strip show/hide paths after mode switch

## Proposed solution directions
1. Make inset handling consistent across API levels (not only API 35+):
   - Apply `WindowInsetsCompat` padding to the candidate/input container for `systemBars()` and (where appropriate) `ime()`.
2. Re-evaluate `onComputeInsets()` override:
   - If Brave depends on proper IME insets, we may need to provide a correct inset computation rather than delegating to a no-op.
3. Add a device/app-specific mitigation if needed:
   - Detect `TYPE_TEXT_VARIATION_URI` and ensure candidate strip height changes trigger a re-layout.

## Follow-up questions for reporter
- Android version + device model.
- Brave version.
- Navigation mode: gesture vs 3-button.
- Is Brave configured with bottom address bar / bottom toolbar?
- Does the same happen in Chrome (or only Brave)?

## Verification plan
- On the reporter’s device (or emulator if reproducible):
  1. Open Brave address bar.
  2. Type some English.
  3. Switch to Chinese mode and type to bring up candidates.
  4. Confirm candidate strip is fully visible and not covered.
- Cross-check in Chrome to distinguish Brave-specific behavior.
