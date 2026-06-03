# LIME IME Backlog

Public backlog for confirmed pending fixes and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-03

## Pending fixes

- #91 — Android — `.cin` import should preserve duplicate-code candidate order from the source file
  - Status: Implemented in Android source on `android-next-release-all-fixes`; awaiting review APK and reporter retest.
  - Current state: Android now keeps same-code `.cin` exact matches in source insertion order when selection sorting is disabled, with regression coverage for the `vmi` / `狀 绒 戕` case shape.
  - Next action: Include in the next Android review APK, then ask reporter to retest 哈哈倉頡 `vmi`.

- #94 / PR #97 — Android — backup must not create a 0 B `limeBackup.zip` while reporting success
  - Status: Implemented in Android source on `android-next-release-all-fixes`; PR #97 behavior is superseded/recreated in this branch pending APK retest.
  - Current state: Backup no longer requires a missing transient `lime.db-journal`, failure propagates instead of reporting success, and regression coverage verifies non-empty backup output plus output-write failure propagation.
  - Next action: Include in the next Android review APK, then ask reporter to confirm backup creates a non-empty ZIP and restores normally.

- #86 — iOS — keyboard extension should see restored IM tables immediately after successful DB restore
  - Status: Open maintainer-created bug, assigned to `jrywu`.
  - Current state: LIME Settings sees restored IM tables, but the iOS keyboard extension can still behave as if there are zero IMs until the user removes and re-adds the keyboard in iOS Settings.
  - Next action: Fix restore-to-keyboard handoff / app-group runtime database state sync, then verify in iOS app + keyboard extension.

- #100 — iOS — contextual Enter/Send key should not become light-on-light in light theme
  - Status: Open maintainer-created bug, assigned to `jrywu`.
  - Current state: Programmatic return-key overrides such as Send/Search/Go use white foreground on the correct blue highlighted/accent background, but after the user hits Enter, touch release/cancel can restore the unhighlighted gray modifier background without updating the foreground.
  - Next action: Centralize contextual Enter-key background restoration so initial render, release, and cancel keep a readable foreground/background pair; verify Send/Search/Go/Next/Done in light and dark themes.

- #93 — iOS — imported `.lime` tables without cname metadata should appear in the installed IM list
  - Status: Open maintainer-created bug, assigned to `jrywu`.
  - Current state: Import can succeed and catalog can mark the table installed, but the IM manager / installed IM list remains empty when cname metadata is missing.
  - Next action: Fix iOS text-import registration/fallback naming so successful imports create visible installed IM configs, then verify import and keyboard availability.

- #93 — Android — `.lime` import should correctly read `@cname@` and `@version@` metadata
  - Status: Implemented in Android source on `android-next-release-all-fixes`; maintainer-created issue still needs final Android APK verification and separate iOS work.
  - Current state: Android `.lime` import now skips `#` comment lines during delimiter detection/parsing and persists `@cname@` / `@version@`, with Array10-style regression coverage.
  - Next action: Include in the Android review APK. iOS #93 remains pending separately and should stay aligned with Android metadata semantics where applicable.

## Confirmed feature / product work

- #90 — Android — keyboard theme should optionally follow system accent/dynamic colors
  - Status: Implemented in Android source on `android-next-release-all-fixes`; awaiting APK review.
  - Current state: Existing `6 = 系統設定` remains the only follow-system theme option. Android now applies Material dynamic color to LIME Settings where available and uses resolved system accent for follow-system keyboard/emoji highlights while fixed themes `0-5` remain fixed.
  - Next action: Include in the next Android review APK and visually verify dynamic/accent behavior on supported Android versions. Button/layout customization remains outside the backlog until confirmed.

- #96 — Android + iOS/table-format — support end-key punctuation behavior for table IMs
  - Status: Android engine/settings support implemented on `android-next-release-all-fixes`; iOS and official table-data coordination remain pending.
  - Current state: Android parses and persists conventional `.cin %endkey` / `.lime @endkey@` metadata for compatibility, parses Lime-specific `.cin %limeendkey` / `.lime @limeendkey@` for runtime commit behavior, exposes editable per-IM `limeendkey` metadata in LIME Settings, and commits the highlighted candidate only when an active table opts into a Lime end key. Tables without Lime end-key metadata still keep `,`/`.` roots usable.
  - Next action: Include Android support in the review APK. iOS should be addressed later and aligned with the Android implementation. Official table metadata/mapping updates, such as adding opt-in 行列10 punctuation rows, are deferred to separate table-data release coordination.

- #99 — Android — shifted keyboard layouts should hide non-alphabet IM root labels
  - Status: Implemented in Android source on `android-next-release-all-fixes`; awaiting APK visual verification.
  - Current state: Shifted Android phonetic/EZ/ET41/Dayi symbol layouts remove root sub-labels from non-alphabet shifted symbol keys while preserving shifted alphabet-key root labels. Shift/caps-lock runtime behavior is handled by the separate unfiled Shift item.
  - Scope: Layout/label adjustment only. Do not change input handling, composing-code logic, candidate lookup, Shift/caps-lock behavior, or hybrid symbol input behavior.
  - Expected behavior: Alphabet keys may continue showing alphabet/root labels as appropriate, because `abc...` -> `ABC...` can still be meaningful for some IM roots. Only non-alphabet shifted keys should remove or adjust IM root labels to avoid suggesting they still input the original Chinese IM roots.
  - Next action: Include in the next Android review APK and visually verify at least one edited shifted layout.

- #99 — iOS — shifted keyboard layouts should hide non-alphabet IM root labels
  - Status: Cross-platform feature parity backlog item from the #99 Android discussion.
  - Current state: The public report was Android-specific, but the same UI rule should apply to iOS if any shifted LIME keyboard layout shows IM root labels on non-alphabet keys while those keys input shifted symbols.
  - Scope: Layout/label adjustment only. Do not change input handling, composing-code logic, candidate lookup, Shift/caps-lock behavior, or hybrid symbol input behavior.
  - Expected behavior: Preserve alphabet/root labels where shifted alphabet keys remain meaningful; remove or adjust only non-alphabet shifted-key IM root labels that would mislead users into thinking Chinese roots are still entered normally.
  - Next action: Audit iOS shifted keyboard layout assets/resources and update labels where applicable; verify the visual layout and confirm no runtime code change is needed.

- Unfiled — Android + iOS — simplify Shift key cycle and use double-click for Shift Lock
  - Status: Android implemented on `android-next-release-all-fixes`; iOS remains pending.
  - Current state: Android single Shift taps now toggle shifted/unshifted only, double-tap enters Shift Lock, and a single Shift tap exits Shift Lock. Regression coverage locks the Android state machine. iOS still needs the matching implementation later.
  - Expected behavior: Single tap should only toggle between shifted and unshifted. Double tap should enter Shift Lock. When Shift Lock is active, a single tap should leave Shift Lock and return to unshifted.
  - Scope: Update Shift key state-machine/input handling on both Android and iOS. Preserve existing shifted keyboard layouts, caps/lock visual indicators, and normal key output semantics except for the tap gesture/state transition change.
  - Next action: Include Android in the review APK and visually verify the Shift states. Address iOS later and keep its behavior aligned with the Android implementation.

## Not in backlog yet

- #90 — Android keyboard UI customization / old-style layout / button visibility / theme options
  - Reason: Only the system accent/dynamic color theme scope is confirmed above. Other #90 UI customization requests, such as hiding/repositioning 中英／123, Emoji, and voice buttons or making selected layouts retain active IM labels, remain product-evaluation scope until Jeremy or a maintainer confirms the exact feature direction.

- Closed/source-fixed items such as #92
  - Reason: Do not list as pending backlog unless Jeremy wants a separate iOS TestFlight/release-QA tracking item.
