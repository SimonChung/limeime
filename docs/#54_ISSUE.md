# #54 — Brave URL bar candidates covered by browser toolbar after EN→ZH switch

Issue: https://github.com/lime-ime/limeime/issues/54

## Problem statement
In Brave Browser’s address bar, if the user types in **English first** and then switches to **Chinese**, the candidate UI becomes partially covered by Brave’s toolbar (see screenshots in the issue).

## Classification
Bug report (UI / window-insets / IME positioning interaction).

## Likely root cause (hypotheses)
### A) IME window insets / layout interaction (general)
This can be an **IME window insets / layout** interaction with Brave’s custom address-bar UI.

Common failure modes that can produce “IME UI covered by app chrome”:
- The IME window (or its embedded candidate strip) does not correctly apply **WindowInsets** (system bars / gesture nav / IME insets), so the last rows/edges render under overlays.
- `InputMethodService.onComputeInsets()` is overridden in a way that prevents the host app from receiving correct insets for the IME window height.
- Switching EN→ZH changes LIME’s candidate visibility state (`hasCandidatesShown`, `mEnglishOnly`, prediction state), which may toggle candidate strip height without forcing a re-layout/inset pass.

LIME uses an embedded candidate view inside the input view container and overrides `onComputeInsets()` with a “no-op” comment. This may be fine for most apps, but Brave’s address bar can be a special case.

### B) Candidate bar height jump after mode switch (regression hypothesis)
A plausible regression path is:
- In older LIME, URL/Email contexts in English keyboard could hide the candidate bar.
- When switching to Chinese IM inside Brave’s URL bar, the IME view height increased (candidate bar became visible), but Brave may not have re-accounted for the new IME height, causing overlap.

If the current LIME build keeps the candidate bar **always visible** (e.g. to expose emoji/mic affordances even in URL/Email contexts), then the IME height does *not* “jump” on EN→ZH switch, and the issue may no longer reproduce.

## What to inspect in code
Android:
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
  - URL field handling (`EditorInfo.TYPE_TEXT_VARIATION_URI`) and whether candidate bar visibility changes across modes
  - `onCreateInputView()` / `onStartInputView()` inset padding logic
  - `onComputeInsets()` override
  - candidate strip show/hide paths after mode switch

## Suggested next step
Treat this as “needs confirmation on latest build” before doing any invasive inset refactor.

## Follow-up questions for reporter
- Android version + device model.
- Brave version.
- Navigation mode: gesture vs 3-button.
- Is Brave configured with bottom address bar / bottom toolbar?
- Does the same happen in Chrome (or only Brave)?

## Verification plan
- On the reporter’s device:
  1. Open Brave address bar.
  2. Type some English.
  3. Switch to Chinese mode and type to bring up candidates.
  4. Confirm candidate strip is fully visible and not covered.
- Cross-check in Chrome to distinguish Brave-specific behavior.
