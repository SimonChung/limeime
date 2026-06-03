# LIME IME Backlog

Public backlog for confirmed pending fixes and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-06-02

## Pending fixes

- #91 — Android — `.cin` import should preserve duplicate-code candidate order from the source file
  - Status: Open bug, assigned to `jrywu`.
  - Current state: Reporter showed `vmi` candidates from 哈哈倉頡 changing from source order `狀 绒 戕` to `狀 戕 绒` even with `啟動選取排序` disabled.
  - Next action: Fix Android `.cin` import/query ordering so same-code candidates can follow source-file order when selection sorting is disabled, then ship in a newer APK and ask reporter to retest.

- #94 / PR #97 — Android — backup must not create a 0 B `limeBackup.zip` while reporting success
  - Status: Open bug with open fix PR #97.
  - Current state: Logcat traced the failure to treating missing transient SQLite rollback journal `lime.db-journal` as fatal, while the UI could still report success and leave a 0 B backup file.
  - Next action: Review/merge PR #97, ship a newer APK, then ask reporter to confirm backup creates a non-empty ZIP and can restore normally.

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
  - Status: Open maintainer-created bug scope, assigned to `jrywu`.
  - Current state: Android import can succeed but cname/version metadata may not be read or saved correctly; Array10 `.lime` includes several `#` comment lines, so comment-line support must be verified.
  - Next action: Verify whether `.lime` supports `#`-prefixed comments like `.cin`, then fix metadata parsing/persistence and add regression coverage.

## Confirmed feature / product work

- #90 — Android — keyboard theme should optionally follow system accent/dynamic colors
  - Status: Open enhancement/usability issue; product scope confirmed for backlog by maintainer direction.
  - Current state: The 6.1 `系統設定` keyboard theme follows the system light/dark mode only. Reporter tested on motorola razr60 / Android 16 and clarified that it does not apply the system theme/accent color.
  - Next action: Evaluate Android dynamic color / system accent color support for the keyboard theme, then design it so it remains optional and compatible with existing fixed light/dark/color themes.

- #96 — Android + iOS/table-format — support end-key punctuation behavior for table IMs
  - Status: Android engine/settings support implemented on `android-next-release-all-fixes`; iOS and official table-data coordination remain pending.
  - Current state: Android parses and persists conventional `.cin %endkey` / `.lime @endkey@` metadata for compatibility, parses Lime-specific `.cin %limeendkey` / `.lime @limeendkey@` for runtime commit behavior, exposes editable per-IM `limeendkey` metadata in LIME Settings, and commits the highlighted candidate only when an active table opts into a Lime end key. Tables without Lime end-key metadata still keep `,`/`.` roots usable.
  - Next action: Include Android support in the review APK. iOS should be addressed later and aligned with the Android implementation. Official table metadata/mapping updates, such as adding opt-in 行列10 punctuation rows, are deferred to separate table-data release coordination.

- #99 — Android — shifted keyboard layouts should hide non-alphabet IM root labels
  - Status: Closed question/enhancement/usability issue; product scope confirmed for backlog by maintainer direction.
  - Current state: Shift / caps-lock behavior remains by design so users can enter uppercase letters and symbols in hybrid input. The improvement is only about what the shifted keyboard layout displays: non-alphabet keys such as number/symbol positions should not continue showing Chinese IM root labels when those shifted keys now input symbols.
  - Scope: Layout/label adjustment only. Do not change input handling, composing-code logic, candidate lookup, Shift/caps-lock behavior, or hybrid symbol input behavior.
  - Expected behavior: Alphabet keys may continue showing alphabet/root labels as appropriate, because `abc...` -> `ABC...` can still be meaningful for some IM roots. Only non-alphabet shifted keys should remove or adjust IM root labels to avoid suggesting they still input the original Chinese IM roots.
  - Next action: Update the Android shifted keyboard layout resources/labels for affected IM layouts so non-alphabet shifted keys no longer show misleading IM root labels; verify the visual layout and confirm no runtime code change is needed.

- #99 — iOS — shifted keyboard layouts should hide non-alphabet IM root labels
  - Status: Cross-platform feature parity backlog item from the #99 Android discussion.
  - Current state: The public report was Android-specific, but the same UI rule should apply to iOS if any shifted LIME keyboard layout shows IM root labels on non-alphabet keys while those keys input shifted symbols.
  - Scope: Layout/label adjustment only. Do not change input handling, composing-code logic, candidate lookup, Shift/caps-lock behavior, or hybrid symbol input behavior.
  - Expected behavior: Preserve alphabet/root labels where shifted alphabet keys remain meaningful; remove or adjust only non-alphabet shifted-key IM root labels that would mislead users into thinking Chinese roots are still entered normally.
  - Next action: Audit iOS shifted keyboard layout assets/resources and update labels where applicable; verify the visual layout and confirm no runtime code change is needed.

- Unfiled — Android + iOS — simplify Shift key cycle and use double-click for Shift Lock
  - Status: New cross-platform feature request from maintainer direction.
  - Current state: Shift currently cycles through three states by repeated single taps: first tap = shifted, second tap = Shift Lock, third tap = unshifted, then repeats.
  - Expected behavior: Single tap should only toggle between shifted and unshifted. Double tap should enter Shift Lock. When Shift Lock is active, a single tap should leave Shift Lock and return to unshifted.
  - Scope: Update Shift key state-machine/input handling on both Android and iOS. Preserve existing shifted keyboard layouts, caps/lock visual indicators, and normal key output semantics except for the tap gesture/state transition change.
  - Next action: Audit Android and iOS Shift key handling, add regression coverage or focused manual test cases for single-tap toggle, double-tap lock, and single-tap unlock, then update both platforms consistently.

## Not in backlog yet

- #90 — Android keyboard UI customization / old-style layout / button visibility / theme options
  - Reason: Only the system accent/dynamic color theme scope is confirmed above. Other #90 UI customization requests, such as hiding/repositioning 中英／123, Emoji, and voice buttons or making selected layouts retain active IM labels, remain product-evaluation scope until Jeremy or a maintainer confirms the exact feature direction.

- Closed/source-fixed items such as #92
  - Reason: Do not list as pending backlog unless Jeremy wants a separate iOS TestFlight/release-QA tracking item.
