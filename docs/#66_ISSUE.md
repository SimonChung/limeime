# #66 — iOS assoc/related add/edit dialogs missing score field

Issue: https://github.com/lime-ime/limeime/issues/66

## Type
Bug (missing functionality / parity regression).

## Problem statement
In the iOS assoc/related editor:
- **Add** dialog has no score input.
- **Edit** dialog has no score input.

Android supports a score value for assoc entries; iOS should allow setting/editing it for parity.

## Proposed fix
- Add a score input (numeric) to both add/edit dialogs.
- Ensure it persists to the related/assoc table (and is displayed consistently in the list).
- Decide default score behavior on add (e.g. 0) when not provided.

## Verification plan
- Add a new assoc entry with a non-zero score → verify stored + shown.
- Edit an existing entry’s score → verify updated + shown.
- Verify sorting/display logic (if any) is unchanged or updated intentionally.
