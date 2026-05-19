# #54 — Brave URL bar candidates covered by browser toolbar after EN→ZH switch

Issue: https://github.com/lime-ime/limeime/issues/54

## Problem statement
In Brave Browser’s address bar, if the user types in **English first** and then switches to **Chinese**, the candidate UI becomes partially covered by Brave’s toolbar (see screenshots in the issue).

## Classification
Bug report (UI / window-insets / IME positioning interaction).

## Status (needs another debugging round)
Reporter has indicated the issue **still reproduces** after trying a newer build, so the earlier “maybe fixed on latest” hypothesis is not sufficient.

This issue is likely **app-specific (Brave address bar)** and/or a **LIME IME inset / computeInsets interaction** that only shows up in certain window modes.

## Likely root cause (updated hypotheses)
### A) Brave address bar uses non-standard overlay chrome
Brave’s address bar UI can be implemented as an overlay that does not follow the typical “content area + IME” layout contract. When LIME changes mode (EN→ZH), Brave may not re-run layout in a way that accounts for the IME candidate strip height.

### B) LIME insets contract is insufficient for this host
LIME overrides `InputMethodService.onComputeInsets()` with a “no-op” comment. This may work for most apps, but some host UIs depend on accurate insets updates (especially if the IME view height changes, or if the host uses overlays).

Potential failure modes:
- Candidate strip is inside the IME window, but the host’s overlay (toolbar/address bar) still visually covers it due to incorrect host/IME coordination.
- EN→ZH switch toggles candidate strip visibility/height or layout params without forcing an inset recomputation visible to the host.

### C) Navigation/toolbar mode influences overlap (gesture/bottom bar)
The overlap may depend on:
- gesture vs 3-button navigation
- Brave “bottom address bar / bottom toolbar” settings
- device display size / font size

## What we need from reporter (next data)
Ask for **one screenshot or short screen recording** that shows:
- Brave address bar + toolbar position (top/bottom)
- the moment of EN→ZH switch
- the candidate strip being covered

Also ask for:
- Android version + device model
- Brave version
- Navigation mode: gesture vs 3-button
- Whether Brave uses bottom address bar / bottom toolbar
- Whether it reproduces in Chrome (control test)

## Developer debugging plan
### Step 1 — confirm whether LIME is changing IME height on EN→ZH switch
Instrument logs (debug-only):
- in `onStartInputView()` / `onUpdateSelection()` / any mode-switch path:
  - current `EditorInfo.inputType`
  - candidate strip visibility + measured height
  - root input view measured height

### Step 2 — validate / adjust `onComputeInsets()` behavior
Experiment (debug build):
- Remove the no-op override, or implement a correct `Insets` computation so the system/host gets consistent insets when candidate strip is shown/hidden.
- Ensure inset recomputation happens on mode switch (EN→ZH) and on candidate strip show/hide.

### Step 3 — add IME-aware padding inside IME window (defensive)
Even if Brave is overlaying, ensure LIME’s own candidate strip and composing view apply appropriate padding/insets (IME + system bars) so content isn’t drawn under overlays.

## Code pointers
Android:
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`
  - URL field handling (`EditorInfo.TYPE_TEXT_VARIATION_URI`)
  - EN/CH mode switch logic and candidate strip show/hide
  - `onComputeInsets()` override
  - candidate view container measurement and layout

## Verification plan
- Repro in Brave using reporter steps.
- Toggle Brave bottom address bar / toolbar.
- Toggle navigation mode (gesture / 3-button).
- Cross-check in Chrome.
- Confirm candidate strip is never visually covered after fixes.