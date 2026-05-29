# LIME IME Backlog

Public backlog for confirmed pending fixes and new-feature/product work. Issue-specific investigation details stay in `docs/#NN_ISSUE.md`; mutable automation state stays outside the repo.

Last reviewed: 2026-05-29

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

- #93 — iOS — imported `.lime` tables without cname metadata should appear in the installed IM list
  - Status: Open maintainer-created bug, assigned to `jrywu`.
  - Current state: Import can succeed and catalog can mark the table installed, but the IM manager / installed IM list remains empty when cname metadata is missing.
  - Next action: Fix iOS text-import registration/fallback naming so successful imports create visible installed IM configs, then verify import and keyboard availability.

- #93 — Android — `.lime` import should correctly read `@cname@` and `@version@` metadata
  - Status: Open maintainer-created bug scope, assigned to `jrywu`.
  - Current state: Android import can succeed but cname/version metadata may not be read or saved correctly; Array10 `.lime` includes several `#` comment lines, so comment-line support must be verified.
  - Next action: Verify whether `.lime` supports `#`-prefixed comments like `.cin`, then fix metadata parsing/persistence and add regression coverage.

- #96 — Android — direct `,` / `.` table mappings should highlight the direct full-width punctuation match
  - Status: Open bug + enhancement/question/usability issue, assigned to `jrywu`.
  - Current state: If a table defines direct mappings such as `, = ，` and `. = 。`, the current Android candidate path can still keep the composing-code record as the effective first selection instead of the direct match.
  - Next action: Fix Android candidate selection so direct exact mappings are highlighted/selected before the composing-code fallback when appropriate, without globally forcing punctuation for tables that use `,`/`.` as roots; add regression coverage, then ship a newer APK and ask the reporter to retest.


## Confirmed feature / product work

- #90 — Android — keyboard theme should optionally follow system accent/dynamic colors
  - Status: Open enhancement/usability issue; product scope confirmed for backlog by maintainer direction.
  - Current state: The 6.1 `系統設定` keyboard theme follows the system light/dark mode only. Reporter tested on motorola razr60 / Android 16 and clarified that it does not apply the system theme/accent color.
  - Next action: Evaluate Android dynamic color / system accent color support for the keyboard theme, then design it so it remains optional and compatible with existing fixed light/dark/color themes.

- #96 — Android + iOS/table-format — support end-key punctuation behavior for table IMs
  - Status: Open enhancement/question/usability issue with related Android bug scope tracked above.
  - Current state: Reporter clarified that 行列30/大易 may use `,`/`.` as roots, while 行列10/嘸蝦米/倉頡 expect punctuation behavior; prior discussion identified `.cin` `%endkey ,.` and future `.lime` `@endkey@` as the likely compatible feature direction. Community follow-up noted official 行列10 currently lacks `,|，` / `.|。` rows and would need explicit opt-in metadata plus mappings if the table should support one-key punctuation.
  - Next action: Design configurable end-key support that preserves tables where `,`/`.` are defined roots, then implement `.cin %endkey` and `.lime @endkey@` parsing/runtime behavior; for opt-in official tables, coordinate table metadata/mapping additions separately from the engine feature.

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

## Not in backlog yet

- #90 — Android keyboard UI customization / old-style layout / button visibility / theme options
  - Reason: Only the system accent/dynamic color theme scope is confirmed above. Other #90 UI customization requests, such as hiding/repositioning 中英／123, Emoji, and voice buttons or making selected layouts retain active IM labels, remain product-evaluation scope until Jeremy or a maintainer confirms the exact feature direction.

- Closed/source-fixed items such as #92
  - Reason: Do not list as pending backlog unless Jeremy wants a separate iOS TestFlight/release-QA tracking item.

