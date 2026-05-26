# Issue #92 — iOS DB restore double spinner and spinner dialog theme colors

## Problem statement

The iOS database restore flow can show two loading spinners at the same time. Spinner/progress dialogs also appear to use incorrect font/theme colors, making the dialog styling inconsistent with the current app theme and potentially reducing readability.

GitHub issue: https://github.com/lime-ime/limeime/issues/92

## Current classification

- Type: bug
- Area: iOS UI / restore progress dialog styling
- Labels: `bug`, `Usability`
- Owner: `jrywu`
- Reporter/source: maintainer request from Jeremy

## Observed behavior

- iOS DB restore can display a duplicated spinner / double loading indicator.
- Spinner/progress dialogs have incorrect font or theme colors.
- The color problem may affect all spinner dialogs, not only the DB restore path.

## Expected behavior

- A single restore operation should show only one progress/loading indicator.
- Spinner/progress dialogs should use theme-aware, readable colors for title/body/action text and controls.
- Light mode and dark mode should both be readable and visually consistent with the app.

## Likely root cause / investigation notes

This likely needs inspection of the iOS restore flow and shared spinner/progress dialog presentation code. Possible causes:

1. The restore flow may present both a custom loading overlay and a system progress dialog/spinner.
2. A shared spinner/progress dialog component may hard-code text/control colors instead of using semantic iOS colors.
3. A UIKit/SwiftUI bridge or custom alert wrapper may not update color styling when the app theme changes.

Relevant areas to inspect:

- iOS database restore UI flow around restore start/completion/error handling.
- Shared spinner/progress dialog helpers or loading overlay components.
- Light/dark mode color definitions used by iOS settings/dialog UI.

## Proposed solution

1. Identify the restore path that shows progress while DB restore is running.
2. Ensure only one loading UI is presented for a single restore operation.
3. Centralize or fix spinner/progress dialog styling so it uses theme-aware semantic colors.
4. Audit other spinner dialog call sites to ensure the shared fix covers all affected dialogs.

## Follow-up questions

- Which iOS screen/action reliably reproduces the double spinner during DB restore?
- Does the wrong text color happen in light mode, dark mode, or both?
- Are action buttons also affected, or only dialog title/body text?

## Verification plan

- Run iOS database restore and confirm only one spinner/progress indicator appears.
- Verify spinner/progress dialogs in light mode and dark mode.
- Confirm dialog title/body/action text colors remain readable and consistent with the app theme.
- Check other spinner dialog call sites to ensure the theme fix applies generally.

## Current follow-up status

Open. Waiting for iOS implementation fix and verification. No community retest request is needed because this is maintainer-created/internal tracking.
