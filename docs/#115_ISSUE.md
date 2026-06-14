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

Code inspected on `master` at `1ae6ad1ed274`. `LIMEService.initOnStartInput(EditorInfo attribute)` refreshes startup keyboard configuration, applies it to `LIMEKeyboardSwitcher`, loads preferences, then chooses Chinese/English/special-field keyboard mode.

Important code paths:

- `LIMEService.refreshStartupConfigSnapshotIfNeeded()` reads:
  - `SearchSrv.getKeyboardConfigList()`
  - `SearchSrv.getAllImKeyboardConfigList()`
- `LIMEService.applyStartupConfigSnapshotToKeyboardSwitcher()` calls:
  - `mKeyboardSwitcher.setKeyboardConfigList(...)`
  - `mKeyboardSwitcher.setImConfigKeyboardList(...)`
- `LIMEService.initialIMKeyboard()` calls `mKeyboardSwitcher.setKeyboardMode(activeIM, MODE_TEXT, ..., true, false, false)` for `array`, `array10`, phonetic, and other Chinese IMs. In `LIMEKeyboardSwitcher.setKeyboardMode(String imCode, int mode, int imeOptions, boolean isIm, boolean isSymbol, boolean isShift)`, that fourth argument is `isIm`, the Chinese-IM path.
- `LIMEKeyboardSwitcher.setKeyboardMode(...)` resolves the IM's keyboard assignment from `imConfigMap`. If the map lacks the active table's keyboard assignment or the assignment is `custom`, it falls back to `lime`, which is the generic QWERTY-like Chinese keyboard layout with an `EN` mode key.

This fallback shape matches the reporter's textual description: a keyboard that looks English-like but is actually Chinese mode (`EN` key).

### Imported table default keyboard assignment

`LimeDB.loadFile(...)` stores metadata and then presets keyboard assignment by table name. In the inspected `LimeDB.java` branch around the import preset logic, `arraynum` is the stored keyboard config for `array`, while `phonenum` is the stored keyboard config for `array10` / phone-number-style Array10 layout.

- `array` -> `arraynum`
- `array10` -> `phonenum`
- otherwise, if no table-specific `Keyboard` exists, the surrounding import preset branch can fall back based on `number_row_in_english`:
  - `limenum` when enabled
  - `lime` when disabled

The attached table's `@cname@` is `行列10`, but the issue needs live reproduction or code tracing to confirm which internal table code LIME uses during manual import. If the table is not imported under the exact `array10` code path, the fallback can plausibly choose `limenum`, which would explain the intermittent `行列+數字列鍵盤` default.

## Likely root cause / hypotheses

### Problem 1 hypothesis: stale or incomplete IM keyboard configuration snapshot after import/activation

The wrong first keyboard is likely caused by the service using a stale or incomplete `imConfigMap` on the first `onStartInput` after a table is loaded/activated. When `LIMEKeyboardSwitcher` cannot find the active IM's assigned keyboard, it falls back to the generic `lime` layout. Toggling `EN` / `中` or reopening the app likely forces a later path to use refreshed configuration, so the correct layout appears.

Specific suspect areas:

- IM keyboard assignment changes in `LimeDB.setIMConfigKeyboard(...)` may not bump the startup-config version used by `LIMEService.isStartupConfigSnapshotDirty()`.
- Import/activation may update the `im` table and active IM preference, but the running `LIMEService` may keep an older `mStartupImKeyboardConfigList` until a later focus/session refresh.
- The reporter's note that `注音` is intermittent while `行列` / `行列10` are consistent could fit this snapshot hypothesis if phonetic sometimes already has a valid assignment in the cached map while newly loaded Array-family assignments are missing on first focus; this needs reproduction rather than assumption.
- The fallback in `LIMEKeyboardSwitcher.setKeyboardMode(...)` masks missing IM keyboard config by silently showing `lime`, making the bug appear as a wrong but usable keyboard rather than a hard failure.

### Problem 2 hypothesis: custom/manual Array10 imports can miss the `array10` preset-keyboard branch

The attached `.lime` file contains metadata for `行列10`, but the preset keyboard logic is keyed on the internal table name (`array10`). If manual import stores the table under `custom` or another table code, the code path may skip the `array10 -> phonenum` assignment and fall back to `limenum` / `lime` based on `number_row_in_english`.

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
- Add a regression test or instrumentation coverage proving that after `setIMConfigKeyboard(array10, ..., phonenum)` / active IM switch, `initOnStartInput()` uses the updated `phonenum` / Array layout on the first input session.
- Import the attached `.lime` file and verify the assigned keyboard is deterministic and matches the intended Array10 default.
- Verify `行列`, `行列10`, and `注音` still show their intended layouts after toggling `EN` / `中`, reopening apps, orientation changes, and normal text vs restricted field types.
- Request reporter retest only after a newer Android APK contains a relevant fix.

### iOS

- Confirmed reporter platform is Android; the report references Android APK versions and Android soft-keyboard behavior.
- iOS has separate keyboard/input-method registration code and does not use `LIMEService`, `LIMEKeyboardSwitcher`, or Android `EditorInfo`, so the first-keyboard-display symptom is probably Android-only.
- Implementation owner should still audit iOS text import/default-keyboard registration for the attached `.lime` metadata if the chosen fix changes shared `.lime` metadata interpretation or import-target semantics.

## Current status

Open / plausible Android bug. Label as `bug` + `Usability`, assign `jrywu`, and wait for implementation investigation. No APK retest request should be made until a newer Android APK includes a relevant fix. No `docs/BACKLOG.md` update yet because the exact fix direction is not confirmed beyond investigation of import/keyboard-config invalidation.
