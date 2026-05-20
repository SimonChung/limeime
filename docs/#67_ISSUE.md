# Issue #67: Candidate-list expand hit area captures last candidate taps

GitHub issue: https://github.com/lime-ime/limeime/issues/67

## Problem Statement

A community reporter says that after updating to the 6.1.x line, tapping the last visible candidate, or a candidate close to the right-side down-arrow button, often opens the full candidate list instead of committing the candidate. The reporter compares this with 6.0.x and the historical 5.2.4-530 build, where candidates overlapping or close to the down-arrow area could still be selected unless the user tapped the arrow explicitly.

This is high-impact for input methods such as 行列10 because users often select later candidates before entering a full code. If the candidate-list popup opens unexpectedly and the user continues typing, the next key sequence can be inserted as raw numeric/code characters.

## Initial Classification

Type: Android UI regression / candidate selection bug.

The report includes a video and a clear version regression range, so it should be treated as a plausible real bug rather than a usage question.

## Relevant Code Observations

- `CandidateInInputViewContainer.dispatchTouchEvent()` intercepts every `ACTION_UP` inside the rightmost `candidate_expand_button_width` of the whole candidate row when candidates are present, and directly toggles the candidate popup.
- `CandidateView.onTouchEvent()` also has an expand-edge path through `isExpandEdgeTap(x, getWidth(), mExpandButtonWidth, mTotalWidth)`.
- `CandidateInInputViewContainer.updateCandidateViewWidthConstraint()` subtracts visible action-button widths from the live `CandidateView` width, but the container-level interceptor still uses the full row width and a fixed right-edge action width.
- The layout also contains a real `candidate_right` `ImageButton` inside `candidate_right_parent`. This means there are overlapping/duplicated concepts of expand-button hit handling: the actual button, the container right-edge interceptor, and CandidateView's own expand-edge check.

## Likely Root Cause

The container-level right-edge tap interceptor is too broad for normal candidate selection. It likely treats taps near the right edge of the candidate row as expand-button taps even when the user intended to select the last visible candidate. This became more visible after the 6.1.x candidate-row/layout work because the row now reserves action-button width and uses explicit embedded candidate controls.

A secondary contributor may be `CandidateView.isExpandEdgeTap()`: it considers the rightmost `mExpandButtonWidth` of the `CandidateView` itself as an expand target when candidates overflow, which can collide with the last candidate's selectable visual area.

## Proposed Solution

1. Prefer the actual `candidate_right` / `candidate_right_parent` button click target for popup expansion.
2. Remove or narrow `CandidateInInputViewContainer.dispatchTouchEvent()` so it does not intercept candidate-row taps outside the actual action-button view bounds.
3. Re-evaluate `CandidateView.isExpandEdgeTap()` after the embedded right-side button exists. If the dedicated button is always visible when candidates overflow, CandidateView should not reserve a hidden right-edge expand zone.
4. Add regression coverage for `CandidateInInputViewContainer.isRightEdgeActionTap()` and/or the event-routing helper so a tap at the candidate view's last-candidate edge is not classified as an expand action unless it is inside the real button bounds.

## Follow-Up Questions

- Confirm the reporter's device model, Android version, navigation mode, keyboard theme, and candidate font-size setting.
- Ask whether the issue happens only when the candidate row overflows, or also when all candidates fit in one row.
- Ask whether it happens in all input methods or mainly 行列10.

## Verification Plan

- Reproduce on Android emulator/device with LIME 6.1.x, 行列10, and a candidate list long enough to overflow.
- Tap the last visible candidate repeatedly near the expand arrow boundary and verify it commits the candidate rather than opening the popup.
- Tap the actual down-arrow button and verify the full candidate list opens.
- Repeat with larger candidate font size and both gesture and three-button navigation.
- Run the focused Android unit tests for candidate view/container hit testing, plus a debug install smoke test if available.