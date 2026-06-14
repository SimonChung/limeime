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

### Android startup after the first IM is installed/enabled

The important point is that startup is *not* supposed to default to English for a normal text field. On `master` at commit `387ea90e`:

1. `LIMEService.onCreate()` initializes default preferences, reads `activeIM = mLIMEPref.getActiveIM()`, then calls `buildActivatedIMList()` (`LIMEService.java` lines 400-442).
2. `LIMEPreferenceManager.getActiveIM()` defaults the persisted active IM (`keyboard_list`) to `phonetic` (`LIMEPreferenceManager.java` lines 487-495). The remembered language flag `language_mode` defaults to `no`/Chinese, and `persistent_language_mode` defaults to false (`LIMEPreferenceManager.java` lines 151-162, 404; `preference.xml` lines 132-134).
3. When the settings IM list is available, `buildActivatedIMList()` does **not** use the old `keyboard_state` preference as source of truth. It calls `SearchSrv.getImConfigList(null, LIME.IM_FULL_NAME)`, filters out `emoji`, filters disabled rows, maps DB rows to known `LIME.IM_CODES`, and builds `activatedIMList` / short names from the live DB (`LIMEService.java` lines 3833-3866). Only when `SearchSrv` is unavailable does it fall back to the persisted `keyboard_state` (`LIMEService.java` lines 3869-3905; default is all indices in `LIMEPreferenceManager.java` lines 478-485).
4. After the active list is built, `ensureActiveIMInActivatedList()` corrects `activeIM` only if it is not in the DB-derived enabled list and the enabled list is non-empty. The correction is persisted (`LIMEService.java` lines 3918-3949). This service-side guard also corrects stale `activeIM` when the DB-derived enabled list is available. Separately, commit `680d34e5` fixed the enable-UI path by making a newly enabled IM active when the persisted active IM is not enabled.
5. On the first `onStartInput()` for a normal text field, `initOnStartInput()` reloads `activeIM`, refreshes/applies the startup keyboard snapshot, loads preferences, and then:
   - uses an English/special keyboard only for restricted field classes/variations, or if `persistent_language_mode` is enabled and `language_mode=yes`;
   - otherwise sets `mEnglishOnly=false` and calls `initialIMKeyboard()` (`LIMEService.java` lines 895-999).
6. If the first focused field is an email/password/web-email text variation, that is an expected forced-English path: `isForcedEnglishTextVariation(...)` returns true for those variations, disables prediction, sets `mEnglishOnly=true`, and calls `setKeyboardMode(..., MODE_EMAIL, isIm=false, ...)` (`LIMEService.java` lines 149-154 and 974-980). That startup should show an English/email keyboard and does not by itself prove #115.
7. `initialIMKeyboard()` calls `mKeyboardSwitcher.setKeyboardMode(activeIM, ..., isIm=true, ...)`, so the first normal keyboard should be the active Chinese IM layout (`LIMEService.java` lines 5255-5340).

Therefore the screenshot/report wording should not be analyzed as "LIME defaulted to English." A real English keyboard would show the `中` mode key. The reported keyboard shows `EN`, so LIME is already in Chinese mode; it is resolving the active Chinese IM to the wrong/generic keyboard layout.

The concrete fallback path is in `LIMEKeyboardSwitcher.setKeyboardMode(...)`: for Chinese mode (`isIm=true`), it resolves the active IM through `imConfigMap`. If the mapping is missing, empty, or `custom`, it replaces the keyboard code with `lime` (`LIMEKeyboardSwitcher.java` lines 448-459), then loads that generic Chinese keyboard XML (`LIMEKeyboardSwitcher.java` lines 501-510). This is consistent with an English-looking keyboard with an `EN` key, but should be confirmed by logging/reproduction of the first-focus `imConfigMap` state.

Related prior fixes are important context but do not by themselves close this issue:

- Commit `537a66c4` (`#107 Optimize LimeIME startup without changing init path`) added the startup keyboard-config snapshot and version tracking.
- Commit `680d34e5` fixed only one first-enabled-IM failure: when persisted `activeIM` still pointed at a disabled/default IM, enabling the first IM now makes the enabled IM active.
- #115 still reproduces on 6.1.18/6.1.19, so the next investigation should focus on cases where the enabled active IM is correct, but the first startup snapshot / `imConfigMap` lacks the just-installed IM's keyboard mapping or uses the wrong mapping. In particular, `LimeDB.setIMConfigKeyboard(...)` writes the IM keyboard row (`LimeDB.java` lines 4879-4895) without bumping the startup config version, while the running `LIMEService` only refreshes the startup snapshot when the preference-backed startup version changes (`LIMEService.java` lines 1041-1093). That is a more direct lead hypothesis than "English default."

### Imported table default keyboard assignment

`LimeDB.importTxtTable(...)` stores metadata and then presets keyboard assignment by table name. In the inspected `LimeDB.java` branch around the import preset logic (lines 4186-4242), `arraynum` is the stored keyboard config for `array`, while `phonenum` is the stored keyboard config for `array10`. The reporter describes `phonenum` as the expected `電話數字鍵盤` behavior, but this still needs on-device/UI verification against current master.

- `array` -> `arraynum` (`LimeDB.java` lines 4227-4228)
- `array10` -> `phonenum` (`LimeDB.java` lines 4229-4230)
- otherwise, if no table-specific `Keyboard` exists, the surrounding import preset branch can fall back based on `number_row_in_english` (`LimeDB.java` lines 4235-4240):
  - `limenum` when enabled
  - `lime` when disabled

The attached table's `@cname@` is `行列10`, but the issue needs live reproduction or code tracing to confirm which internal table code LIME uses during manual import. If the table is not imported under the exact `array10` code path, the fallback can plausibly choose `limenum`, which would explain the intermittent `行列+數字列鍵盤` default.

## Likely root cause / hypotheses

### Problem 1 lead hypothesis: Chinese-mode fallback after the active IM's keyboard mapping is missing/stale on first focus

The first keyboard should be Chinese by default for normal text input. #115 is better described as: after installing/enabling `行列` / `行列10`, LIME enters Chinese mode, but the first `setKeyboardMode(..., isIm=true, ...)` cannot resolve the intended IM keyboard mapping and falls back to generic `lime`. That fallback looks QWERTY/English-like while still showing `EN`, because it is still Chinese mode.

Specific suspect areas:

- `buildActivatedIMList()` builds the active IM list from live DB `im` rows when `SearchSrv` is available, not from `keyboard_state`. The old `keyboard_state` preference is only a fallback when `SearchSrv` is unavailable. If the first-installed/enabled IM path races with async DB writes, either the DB-derived enabled list or, more directly, the IM keyboard mapping snapshot can be incomplete.
- `680d34e5` repairs only the case where persisted `activeIM` points outside the enabled list. It does not guarantee that the first startup keyboard-config snapshot already contains the new IM's `title='keyboard'` mapping.
- `setIMConfigKeyboard(...)` and related DB writes can update the IM keyboard assignment without changing the preference-backed startup-config version. If `LIMEService` already applied a snapshot, `refreshStartupConfigSnapshotIfNeeded()` can decide it is clean and keep an old `imConfigMap` for the first focus after install/import.
- The `LIMEKeyboardSwitcher` fallback to `lime` masks this as a usable but wrong keyboard instead of a hard failure.

This is now the lead hypothesis. The older wording "falls back to English" is misleading; the observed `EN` key indicates wrong Chinese keyboard layout, not real English mode.

### Problem 2 hypothesis: custom/manual Array10 imports can miss the `array10` preset-keyboard branch

The attached `.lime` file contains metadata for `行列10`, but the preset keyboard logic inspected in `LimeDB.importTxtTable(...)` is keyed on the internal destination table name (`array10`). If manual import stores the table under `custom` or another table code, the code path may skip the `array10 -> phonenum` assignment and fall back to `limenum` / `lime` based on `number_row_in_english`. This should be confirmed by tracing the import entry point and stored IM config for the reporter's exact manual-import path.

This should be treated as a hypothesis until reproduced on-device or with an import integration test.

## Proposed investigation / solution

1. Instrument or test the exact first-install/first-focus sequence, not just generic startup:
   - before enabling/importing: persisted `keyboard_list`, `language_mode`, `persistent_language_mode`, startup-config version, current `activatedIMList`, current `imConfigMap` entry for `array` / `array10`;
   - immediately after enabling/import completion: DB `im` rows for `title='name'` and `title='keyboard'`, disabled flags, startup-config version;
   - at the first `initOnStartInput()`: record the first field's `inputType` / variation, active IM, DB-derived enabled list, snapshot version decision, `mStartupImKeyboardConfigList`, and the `localImCode` chosen in `LIMEKeyboardSwitcher.setKeyboardMode()`.
   - run the first-focus check twice: once on a normal text field, and once on an email/password field. The email/password field should take the forced-English `MODE_EMAIL` path; only the next normal text focus should be evaluated against the Chinese IM layout invariant.
2. Add a regression test for the intended invariant: after `array` or `array10` is installed/enabled as the first usable IM, the first normal text `initOnStartInput()` must route to Chinese mode and resolve the active IM to its configured keyboard (`arraynum` for `array`, `phonenum` for `array10`), never generic `lime` because of a missing mapping.
3. If the test confirms stale snapshot/versioning, fix the root cause by making IM DB changes that affect startup keyboard resolution invalidate/bump startup config, especially `setIMConfigKeyboard(...)`, import completion, and enable/disable changes. The fix should refresh `getAllImKeyboardConfigList()` before the first focus after install/import.
4. If the test instead shows the active list is built before the async enable/import write commits, fix the sequencing so the enable/import completion signal and active-IM correction happen after the DB state is durable, or force a one-shot startup snapshot invalidation before returning to another app.
5. Add debug logging for missing `imConfigMap` mappings so future cases report `activeIM`, `isIm`, `localImCode`, and whether fallback to `lime` happened.
6. For manual `.lime` imports, separately verify whether `@cname@|行列10` should select the `array10` preset or whether the import UI should store an explicit default keyboard assignment based on detected key metadata (`@imkeys@|1234567890`) / selected import target.

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

Open / plausible Android bug. Labeled `bug` + `Usability`, assigned to `jrywu`, and tracked in `docs/BACKLOG.md` under active issue follow-up. No APK retest request should be made until a newer Android APK includes a relevant fix. Revised lead analysis: the first normal text startup should be Chinese, not English; #115 may occur because the active IM's keyboard mapping is missing/stale in the first startup snapshot, causing Chinese-mode fallback to generic `lime` while still showing the `EN` key. Confirm with logging or a focused regression test before implementing the fix.
