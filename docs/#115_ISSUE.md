# Issue #115: Android initial keyboard layout is wrong after loading Array / Array10 tables

## Problem statement

Community reporter `gontera` reports two initial-keyboard problems on Android LIME 6.1.18 and 6.1.19. Both problems are reported on Android only; problem 2 also touches `.lime` import metadata/default-keyboard assignment, so iOS impact is unconfirmed and should be audited only if shared `.lime` interpretation changes.

1. After loading/enabling `行列` or `行列10` and switching to another app, the first Chinese keyboard shown is consistently wrong for those tables. The reporter says it visually resembles the English keyboard but still shows the `EN` key; that likely means LIME is in Chinese IM mode with the wrong soft-keyboard layout. The reporter can recover by tapping `EN` to switch to the real English keyboard, then tapping `中`, or by closing and reopening the target app.
2. After manually loading the attached `行列10` `.lime` table, LIME sometimes defaults the table's keyboard layout to `行列+數字列鍵盤`; the reporter expects the default to be `電話數字鍵盤`, as with `老刀行列10字根`.

The report includes a screenshot of the wrong initial keyboard state and an attached table archive:

- `array10a-v2023-1.0-20260614.zip`
- Attachment downloaded from the GitHub issue during triage on 2026-06-14; ZIP SHA-256 `2a558b3b3687ed73adea1e11ab87df53e22ebe2f1e84f826a34bcd5e46f4943e`
- Contained file: `array10a-v2023-1.0-20260614.lime`, SHA-256 `2d42d63952d46153237c42aee8e5654c78893eb0112e0b8674d5bc6652fec2be`
- Relevant metadata: `@format@|lime-text-v2`, `@cname@|行列10`, `@limeendkey@|,.`, `@spacestyle@|2`, `@imkeys@|1234567890`, `@imkeynames@|1\|2\|3\|4\|5\|6\|7\|8\|9\|0`

## Reproduction details from the report

### Problem 1: first keyboard after loading a new IM

1. Load/enable `行列` or `行列10` in LIME.
2. Switch to another app and focus a text field.
3. On first display, LIME shows a Chinese-mode keyboard whose physical layout resembles an English keyboard and whose mode key says `EN`.
4. Expected: the active Chinese IM should show its configured layout immediately; if the user is on the real English keyboard, the mode key should be `中`.
5. Workarounds reported:
   - Tap `EN`, then tap `中`.
   - Close and reopen the target app.

The reporter says `行列` and `行列10` reproduce consistently. `注音` is intermittent.

### Problem 2: manual `.lime` Array10 table default layout

1. Manually load the attached `行列10` `.lime` table.
2. LIME sometimes assigns `行列+數字列鍵盤` as the default keyboard layout.
3. Expected: default to `電話數字鍵盤`, matching `老刀行列10字根`.

## Evidence and code areas inspected

### Android startup keyboard selection

Code inspected on `master` at commit `472397e` after the triage doc was added. `LIMEService.initOnStartInput(EditorInfo attribute)` refreshes startup keyboard configuration, applies it to `LIMEKeyboardSwitcher`, loads preferences, then chooses Chinese/English/special-field keyboard mode.

Important code paths:

- `LIMEService.java` lines 895-999 read `activeIM`, call `refreshStartupConfigSnapshotIfNeeded()`, apply the snapshot to `LIMEKeyboardSwitcher`, load preferences, and then either choose an English/special-field keyboard or call `initialIMKeyboard()`.
- `LIMEService.java` lines 1041-1093 gate the startup snapshot on `isStartupConfigSnapshotDirty()`, read `SearchSrv.getKeyboardConfigList()` / `SearchSrv.getAllImKeyboardConfigList()`, and pass those lists into `mKeyboardSwitcher.setKeyboardConfigList(...)` / `setImConfigKeyboardList(...)`.
- `LIMEKeyboardSwitcher.java` line 433 defines `setKeyboardMode(String imCode, int mode, int imeOptions, boolean isIm, boolean isSymbol, boolean isShift)`. Lines 501-514 use `isIm=true` for Chinese IM keyboard XML (`kConfig.getImkb()` / `getImshiftkb()`) and `isIm=false` for the English layout resolver.
- `LIMEKeyboardSwitcher.java` lines 448-461 resolve the active IM through `imConfigMap`; when that mapping is missing, empty, or `custom`, lines 457-459 replace it with `lime`. This is a plausible route to a generic QWERTY-like Chinese keyboard with an `EN` mode key if the IM-keyboard map is stale or incomplete.

This fallback shape matches the reporter's textual description: a keyboard that looks English-like but is actually Chinese mode (`EN` key).

Related prior fixes are important context but do not by themselves close this issue:

- Commit `537a66c4` (`#107 Optimize LimeIME startup without changing init path`) added startup config snapshot/version tracking so `LIMEService` avoids repeated config reloads while still reloading when startup preferences change.
- Commit `680d34e5` (`Fix: activate the enabled IM on fresh install instead of falling back to English`) fixed a closely related first-enabled-IM path: if the persisted active IM is not enabled, enabling an IM now makes the just-enabled IM active instead of leaving `activeIM` pointing at a default IM whose keyboard config is not loaded, which had caused fallback to an English-looking layout.
- The reporter says the current symptom still occurs on 6.1.18 and 6.1.19, so this should be treated as the same bug family rather than proof that the old fix already solved the report. The remaining path is likely an import/activation/config-snapshot invalidation case that those earlier fixes did not cover, or a later startup/layout change interacting with the same fallback behavior.

### Imported table default keyboard assignment

`LimeDB.importTxtTable(...)` stores metadata and then presets keyboard assignment by table name. In the inspected `LimeDB.java` branch around the import preset logic (lines 4186-4242), `arraynum` is the stored keyboard config for `array`, while `phonenum` is the stored keyboard config for `array10`. The reporter describes `phonenum` as the expected `電話數字鍵盤` behavior, but this still needs on-device/UI verification against current master.

- `array` -> `arraynum` (`LimeDB.java` lines 4227-4228)
- `array10` -> `phonenum` (`LimeDB.java` lines 4229-4230)
- otherwise, if no table-specific `Keyboard` exists, the surrounding import preset branch can fall back based on `number_row_in_english` (`LimeDB.java` lines 4235-4240):
  - `limenum` when enabled
  - `lime` when disabled

The attached table's `@cname@` is `行列10`, but the issue needs live reproduction or code tracing to confirm which internal table code LIME uses during manual import. If the table is not imported under the exact `array10` code path, the fallback can plausibly choose `limenum`, which would explain the intermittent `行列+數字列鍵盤` default.

## Likely root cause / hypotheses

### Problem 1 hypothesis: stale or incomplete IM keyboard configuration snapshot after import/activation

The wrong first keyboard may be caused by the service using a stale or incomplete `imConfigMap` on the first `onStartInput` after a table is loaded/activated. When `LIMEKeyboardSwitcher` cannot find the active IM's assigned keyboard, the inspected code falls back to the generic `lime` layout. Toggling `EN` / `中` or reopening the app may force a later path to use refreshed configuration, so the correct layout appears; this needs reproduction before treating it as root cause.

Specific suspect areas:

- IM keyboard assignment changes in `LimeDB.setIMConfigKeyboard(...)` (`LimeDB.java` line 4242, implementation starts around line 4879) may not bump the startup-config version used by `LIMEService.isStartupConfigSnapshotDirty()` (`LIMEService.java` lines 1041-1045), or a different import/activation path may update the mapping without making the running service refresh before first focus.
- Import/activation may update the `im` table and active IM preference, but the running `LIMEService` may keep an older `mStartupImKeyboardConfigList` until a later focus/session refresh.
- Earlier fixes already covered some nearby cases (`537a66c4` for startup config snapshots and `680d34e5` for first-enabled-IM active selection). Because #115 is reported on builds that should include those commits, the investigation should first check whether the `行列` / `行列10` load path bypasses those preference-version bumps or active-IM repairs rather than duplicating the exact old fresh-install fix.
- The reporter's note that `注音` is intermittent while `行列` / `行列10` are consistent is useful reproduction context, but it should not be treated as proof of the cache hypothesis without logs or an instrumentation test.
- The fallback in `LIMEKeyboardSwitcher.setKeyboardMode(...)` can mask missing IM keyboard config by showing `lime`, making the bug appear as a wrong but usable keyboard rather than a hard failure.

### Problem 2 hypothesis: custom/manual Array10 imports can miss the `array10` preset-keyboard branch

The attached `.lime` file contains metadata for `行列10`, but the preset keyboard logic inspected in `LimeDB.importTxtTable(...)` is keyed on the internal destination table name (`array10`). If manual import stores the table under `custom` or another table code, the code path may skip the `array10 -> phonenum` assignment and fall back to `limenum` / `lime` based on `number_row_in_english`. This should be confirmed by tracing the import entry point and stored IM config for the reporter's exact manual-import path.

This should be treated as a hypothesis until reproduced on-device or with an import integration test.

## Proposed investigation / solution

1. Reproduce on Android 6.1.19 with a clean-ish app state:
   - load built-in `行列`
   - load built-in `行列10`
   - import the attached `array10a-v2023-1.0-20260614.lime`
   - after each load/activation, focus a normal text field in another app and inspect the first keyboard shown.
2. Add focused logging or tests around startup keyboard config invalidation:
   - after `setIMConfigKeyboard(...)`
   - after import completion
   - after active IM list / active IM preference changes
   - before `applyStartupConfigSnapshotToKeyboardSwitcher()` and `setKeyboardMode(...)`
3. Fix config invalidation so IM keyboard assignment changes make the next `onStartInput` refresh `getAllImKeyboardConfigList()` before resolving the layout.
4. Consider making `LIMEKeyboardSwitcher` fail softer but more visibly in debug logs when an active IM has no keyboard assignment, instead of silently falling back to `lime` with no trace.
5. For manual `.lime` imports, verify whether `@cname@|行列10` should select the `array10` keyboard preset or whether the import UI should store an explicit default keyboard assignment based on detected key metadata (`@imkeys@|1234567890`) / selected import target.

## Existing coverage / fragility assessment

Relevant tests exist for several nearby paths on inspected `master`:

- `LIMEServiceTest` covers restricted field keyboard policy such as `TYPE_CLASS_NUMBER -> MODE_PHONE`.
- `LIMEKeyboardSwitcherPolicyTest` covers English layout resolution with and without number row.
- Some `LIMEServiceTest` reflection tests exercise `initialIMKeyboard()` and startup preference version behavior.
- `KeyboardLayoutResourceTest` checks keyboard XML resource availability.

Coverage gap: there does not appear to be a focused regression test for the sequence "import/activate an IM -> immediately start input in another app -> keyboard switcher resolves the just-updated IM keyboard assignment." The current code is fragile because the live keyboard choice depends on consistency between SharedPreferences startup-version invalidation, SearchServer DB reads, cached startup snapshots, and `LIMEKeyboardSwitcher` fallback behavior.

## Follow-up questions for reporter

Only ask if needed after initial code/device reproduction attempts:

1. Does problem 1 happen with `記憶中英模式` (remember Chinese/English mode across fields/apps) enabled, disabled, or both?
2. For problem 1, does the wrong first keyboard appear immediately after importing/loading the table only, or also after later app launches without changing IM settings?
3. For problem 2, in the manage-IM list, what is the internal table/import target shown for the attached `.lime` file when the default keyboard becomes `行列+數字列鍵盤`?

## Verification plan

### Android

- Reproduce both reported paths on 6.1.19 or current `master`.
- Add a regression test or instrumentation coverage proving that after `setIMConfigKeyboard(array10, ..., phonenum)` / active IM switch, `initOnStartInput()` uses the updated `phonenum` / Array layout on the first input session; also include normal text fields with `EditorInfo` flags that could force English-like layouts so the test does not confuse intended input-type behavior with this bug.
- Import the attached `.lime` file through each relevant Android UI path and verify the assigned keyboard is deterministic and matches the intended Array10 default for the `行列10` path.
- Verify `行列`, `行列10`, and `注音` still show their intended layouts after toggling `EN` / `中`, reopening apps, orientation changes, and normal text vs restricted field types.
- Request reporter retest only after a newer Android APK contains a relevant fix.

### iOS

- Confirmed reporter platform is Android; the report references Android APK versions and Android soft-keyboard behavior.
- The first-keyboard-display symptom is probably Android-only because it depends on Android `LIMEService`, `LIMEKeyboardSwitcher`, and `EditorInfo` startup paths.
- If the chosen fix changes shared `.lime` metadata interpretation or import-target semantics rather than only Android IM-keyboard snapshot invalidation, audit iOS text import/default-keyboard registration separately before claiming cross-platform parity.

## Current status

Open / plausible Android bug. Labeled `bug` + `Usability`, assigned to `jrywu`, and tracked in `docs/BACKLOG.md` under active issue follow-up. No APK retest request should be made until a newer Android APK includes a relevant fix. The first investigation pass should compare the #115 path against the recent `537a66c4` / `680d34e5` keyboard-startup fixes, because the symptom is likely in that same first-switch / active-IM fallback family but still reproduced on later APKs.
