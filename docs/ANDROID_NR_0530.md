# Android Next Release Implementation Plan

> **For Hermes:** Use `subagent-driven-development` to implement this plan task-by-task. Keep this as one Android next-release feature/fix train, but use small commits and review gates so regressions are isolated.

**Goal:** Finish the confirmed Android bug fixes and confirmed Android new-feature backlog in one coordinated next-release branch/APK.

**Architecture:** Treat import parsing, candidate ordering, backup/restore, keyboard theming, and keyboard-layout resources as separate vertical slices with their own regression tests, then run a full Android compile/test/release-candidate verification pass before building the APK. Do not expand into unconfirmed #90 button-layout customization scope; only implement the confirmed Android backlog items.

**Tech Stack:** Android Java, SQLite, XML keyboard resources, Android instrumentation tests (`connectedDebugAndroidTest`), Gradle under `LimeStudio/`.

---

## Scope

### Confirmed Android bugs

- #91 — `.cin` duplicate-code import/query order should preserve source-file order when selection sorting is disabled.
- #94 / PR #97 — backup must not create/report a 0 B `limeBackup.zip`; missing transient `lime.db-journal` must not break backup.
- #93 — Android `.lime` import should read/persist `@cname@` and `@version@`, including Array10-style files with `#` comments.

### Confirmed Android features

- #90 — keyboard theme option should optionally follow Android system accent / dynamic colors, not only system light/dark.
- #96 — support explicit Lime table end-key behavior for `.cin %limeendkey` and `.lime @limeendkey@` on Android, without breaking tables where `,` / `.` are roots.
- #96 — audit bundled/official Android table assets, if any, and either add opt-in Lime end-key metadata plus direct punctuation mappings for the tables Jeremy confirms or document that table-data release coordination is separate from the engine change.
- #99 — shifted symbol-keyboard layouts should remove Chinese IM root sub-labels only from non-alphabet shifted keys such as `!@#...`; shifted capital-letter keys may keep root sub-labels because `A-Z` can still be valid roots.

### Explicitly out of scope for this plan

- #90 button visibility/repositioning (`中英／123`, Emoji, voice) and old-style layout customization; this remains product-evaluation scope.
- iOS #86/#93/#96/#99 implementation. Mention parity in docs/backlog only if Android changes define shared table-format semantics.
- Public GitHub issue replies until a test APK exists and Jeremy approves wording.

---

## Working branch and checkpoints

### Task 1: Prepare one Android next-release branch

**Objective:** Start from clean `master` and isolate all next-release Android work.

**Files:**
- Modify: none initially

**Steps:**

1. Verify current branch and cleanliness:
   ```bash
   cd /home/jeremy/tmp/limeime
   git status --short
   git branch --show-current
   git fetch origin
   git log --oneline --decorate -5
   ```
   Expected: working tree clean; branch is `master`; local `master` is up to date or can be fast-forwarded.

2. Create branch:
   ```bash
   git switch -c android-next-release-all-fixes
   ```

3. Commit policy:
   - Use one commit per vertical slice below.
   - Do not squash until Jeremy has reviewed the whole plan/branch.
   - Keep each commit buildable.

---

## Task 2: Bring #94 backup fix into the branch or rebase PR #97

**Objective:** Ensure Android backup excludes optional rollback journal files, propagates failure to UI, and never reports success with a 0 B output.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java:397-483`
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEUtilities.java` if zip helper behavior must distinguish optional files from fatal files
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/DBServerTest.java`
- Reference: PR #97 (`fix/94-android-backup-zero-byte`) if still open

**Implementation requirements:**

1. Reuse PR #97 if it applies cleanly; otherwise re-implement the same behavior on the next-release branch.
2. Do not add `lime.db-journal` to the required backup list unless the file exists.
3. If the selected output URI cannot be opened/written, throw `RemoteException` or another caller-visible failure instead of swallowing it.
4. Show backup error only on failure and backup end only on success.
5. Always reopen DB and clear temporary files in `finally`.

**Test requirements:**

Add/keep Android tests that cover:

```java
@Test
public void backupDatabaseSkipsMissingRollbackJournal() throws Exception {
    // Arrange: live lime.db exists, lime.db-journal does not.
    // Act: call backupDatabase(testUri).
    // Assert: produced zip is non-empty and contains lime.db, shared prefs backup, and manifest.
    // Assert: zip does not require lime.db-journal.
}

@Test
public void backupDatabasePropagatesOutputWriteFailure() throws Exception {
    // Arrange: ContentResolver/openOutputStream path fails.
    // Act + assert: backupDatabase(...) throws and does not report success.
}
```

**Verification:**

```bash
cd /home/jeremy/tmp/limeime/LimeStudio
ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk ./gradlew :app:compileDebugJavaWithJavac :app:compileDebugAndroidTestJavaWithJavac
```
Expected: compilation succeeds.

If a device/emulator is connected:

```bash
ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=net.toload.main.hd.DBServerTest
```
Expected: DBServer backup tests pass.

**Commit:**

```bash
git add LimeStudio/app/src/main/java/net/toload/main/hd/DBServer.java \
        LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEUtilities.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/DBServerTest.java
git commit -m "fix(android): make backup robust without rollback journal"
```

---

## Task 3: Add Android `.cin` source-order regression for #91

**Objective:** Reproduce duplicate-code ordering drift before changing query logic.

**Files:**
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`
- Fixture: create temporary `.cin` file inside the test app cache directory

**Failing test shape:**

```java
@Test
public void cinImportPreservesDuplicateCodeOrderWhenSelectionSortDisabled() throws Exception {
    Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
    LimeDB limeDB = new LimeDB(appContext);
    assertTrue(initializeDatabase(limeDB));

    File fixture = new File(appContext.getCacheDir(), "issue91_order.cin");
    writeUtf8(fixture,
            "%ename issue91\n" +
            "%cname Issue91\n" +
            "%chardef begin\n" +
            "vmi 狀\n" +
            "vmi 绒\n" +
            "vmi 戕\n" +
            "%chardef end\n");

    limeDB.setTableName(LIME.DB_TABLE_CUSTOM);
    limeDB.clearTable(LIME.DB_TABLE_CUSTOM);
    limeDB.setFilename(fixture);
    limeDB.importTxtTable(LIME.DB_TABLE_CUSTOM, null);
    waitForImportThread(limeDB);

    List<Mapping> mappings = limeDB.getMappingByCode("vmi", false, true);
    assertEquals("狀", mappings.get(0).getWord());
    assertEquals("绒", mappings.get(1).getWord());
    assertEquals("戕", mappings.get(2).getWord());
}
```

If current method signatures differ, adapt to existing `LimeDBTest` helpers; preserve the assertion order.

**Verification:**

Run only `LimeDBTest` first and confirm this test fails before Task 4.

---

## Task 4: Fix #91 duplicate-code order when selection sorting is disabled

**Objective:** Make same-code exact matches fall back to `_id ASC` / source insertion order when sorting is disabled, while preserving learned sorting when enabled.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java` around `getMappingByCode(...)` query ordering
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`

**Implementation requirements:**

1. Inspect the current `ORDER BY` string in `LimeDB.getMappingByCode(...)`.
2. When the user-facing sort flag is false, do not let score/base-score single-character priority reorder same-code exact matches before `_id ASC`.
3. When sort is true, preserve `score DESC, basescore DESC` / existing learned-order behavior.
4. Do not change broader between-search or extension-candidate ordering unless required by the test.

**Suggested approach:**

- Split the order clause into named segments:
  - exact-code / code-length correctness terms that must always run;
  - learned/score terms that run only when sort is enabled;
  - `_id ASC` final tie-breaker.
- Move `(exactmatch = 1 and (score > 0 or basescore > 0) and length(word)=1) desc` into the sort-enabled segment, unless a narrower condition is discovered during implementation.

**Verification:**

- #91 test passes.
- Existing `LimeDBTest` ordering/search tests pass.
- Manual test with 哈哈倉頡 `vmi`: expected `狀`, `绒`, `戕` when selection sorting is disabled.

**Commit:**

```bash
git add LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java
git commit -m "fix(android): preserve cin duplicate-code source order"
```

---

## Task 5: Add `.lime` metadata/comment regression for #93

**Objective:** Lock Android parser behavior for Array10-style `.lime` files containing `#` comments and metadata rows.

**Files:**
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`
- Modify later: `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`

**Failing test shape:**

```java
@Test
public void limeImportSkipsHashCommentsAndPersistsCnameVersion() throws Exception {
    Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
    LimeDB limeDB = new LimeDB(appContext);
    assertTrue(initializeDatabase(limeDB));

    File fixture = new File(appContext.getCacheDir(), "issue93_array10.lime");
    writeUtf8(fixture,
            "# Array10 comment before metadata\n" +
            "@version@ |行列10測試版\n" +
            "# Comment between metadata\n" +
            "@cname@ |行列10測試\n" +
            "# Comment before mappings\n" +
            ",|，\n" +
            ".|。\n");

    limeDB.setTableName(LIME.DB_TABLE_CUSTOM);
    limeDB.clearTable(LIME.DB_TABLE_CUSTOM);
    limeDB.setFilename(fixture);
    limeDB.importTxtTable(LIME.DB_TABLE_CUSTOM, null);
    waitForImportThread(limeDB);

    assertEquals("行列10測試", limeDB.getImConfig(LIME.DB_TABLE_CUSTOM, "name"));
    assertEquals("行列10測試版", limeDB.getImConfig(LIME.DB_TABLE_CUSTOM, "version"));
    assertEquals("，", limeDB.getMappingByCode(",", false, true).get(0).getWord());
    assertEquals("。", limeDB.getMappingByCode(".", false, true).get(0).getWord());
}
```

**Expected pre-fix result:** failure if `#` comments are treated as rows or if `@cname@` / `@version@` are ignored/not persisted.

---

## Task 6: Fix Android `.lime` metadata and comment parsing for #93

**Objective:** Make `.lime` metadata robust and documented enough to support official Array10 and user tables.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java` in `.lime` / text import parser
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`
- Docs: `docs/CIN_LIME_SPEC.md` if current spec does not mention `.lime #` comments or `@cname@` / `@version@`

**Implementation requirements:**

1. For `.lime`, skip blank lines and `#` comment lines before parsing metadata or mappings.
2. Parse both formats consistently:
   - `.lime`: `@cname@ |Display Name`, `@version@ |Version`
   - `.cin`: `%cname`, `%version`
3. Persist metadata through existing `setImConfig(table, "name", ...)` and `setImConfig(table, "version", ...)` paths.
4. Do not treat comment lines as mappings.
5. Keep existing delimiter auto-detection behavior for non-`.lime` text imports unless a test proves it is wrong.

**Verification:**

- New #93 test passes.
- Existing import tests continue to pass.
- Manual import of official Array10-style `.lime` preserves name/version.

**Commit:**

```bash
git add LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java \
        docs/CIN_LIME_SPEC.md
git commit -m "fix(android): parse lime metadata with comments"
```

---

## Task 7: Add Lime end-key metadata model, parser tests, and editable IM detail field for #96

**Objective:** Define Android runtime representation for Lime-specific `%limeendkey` / `@limeendkey@`, expose it as editable per-IM metadata in LIME Settings IM detail view, and document how it differs from conventional `%endkey` / `@endkey@` compatibility metadata before implementing key behavior.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIME.java` if a constant for `limeendkey` is missing
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/controller/ManageImController.java:411-444`
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/view/ImDetailFragment.java:58-191,285-320,422-485`
- Modify: `LimeStudio/app/src/main/res/layout/fragment_im_detail.xml:86-192`
- Modify: `LimeStudio/app/src/main/res/values/strings_settings.xml:800-810`
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java`
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/ui/controller/ManageImControllerTest.java` or existing controller test seam if present
- Docs: `docs/CIN_LIME_SPEC.md`
- Docs: `docs/LIME_SETTINGS.md`

**Test requirements:**

Add tests for both import formats:

```java
@Test
public void cinImportPersistsLimeEndkeyMetadata() throws Exception {
    // Fixture includes "%limeendkey ;/".
    // Assert getImConfig(table, "limeendkey") returns ";/".
}

@Test
public void limeImportPersistsLimeEndkeyMetadata() throws Exception {
    // Fixture includes "@limeendkey@ |;/".
    // Assert getImConfig(table, "limeendkey") returns ";/".
}
```

Add controller/UI-seam coverage where practical:

```java
@Test
public void updateIMMetadataFieldAllowsLimeEndkey() {
    assertTrue(controller.updateIMMetadataField("custom", "limeendkey", ";/"));
    assertEquals(";/", searchServer.getImConfig("custom", "limeendkey"));
}
```

**Implementation requirements:**

1. Normalize metadata value by stripping optional delimiter/prefix whitespace.
2. Persist as `setImConfig(table, "limeendkey", normalizedValue)`.
3. Do not infer Lime end keys from direct punctuation mappings or conventional `endkey` metadata. Lime end-key behavior must be explicit.
4. Update `ManageImController.updateIMMetadataField(...)` so editable metadata fields include `name`, `version`, and `limeendkey`.
   - `name` remains required/non-empty.
   - `version` and `limeendkey` may be blank; blank `limeendkey` means no Lime runtime end-key commit triggers for that table.
   - Trim leading/trailing whitespace, but do **not** sort or deduplicate characters unless the runtime parser also does so consistently.
5. Add an **Endkey / 結束鍵** row in `fragment_im_detail.xml` under the same 輸入法資訊 card as 名稱 and 版本, using the same tappable/editable row pattern and chevron icon.
6. In `ImDetailFragment`, load `getImConfig(tableCode, "limeendkey")`, display `-` when empty, and open the same metadata edit dialog for field `"limeendkey"`.
7. Editing the Endkey row saves immediately through `updateIMMetadataField(table, "limeendkey", editedValue)`, updates the row text, and refreshes any metadata/cache needed by the active IM.
8. Hide the Endkey row for the synthetic `related` table just like editable name/version rows.
9. Document `.lime @limeendkey@ |;/` and `.cin %limeendkey ;/` as opt-in Lime runtime metadata in `docs/CIN_LIME_SPEC.md`; document `.cin %endkey` / `.lime @endkey@` as conventional compatibility metadata.
10. Update `docs/LIME_SETTINGS.md` so the LIME Settings IM detail view spec includes an editable Endkey metadata field alongside cname/name and version. Explain that users can view or edit the table's end-key list there, and that empty means disabled.
11. Search the repo for bundled `.lime`, `.cin`, or generated table assets. If Android ships official table data in this repo, list affected tables and add opt-in metadata/mappings only for tables Jeremy confirms should support one-key commit triggers. If no bundled table assets exist, record that table-data coordination is separate from the engine change.

**Manual acceptance examples:**

- LIME Settings → 輸入法 → IM detail shows editable rows for 名稱, 版本, and Endkey/結束鍵.
- Tapping Endkey opens an edit dialog prefilled with the current `limeendkey` metadata value such as `;/`.
- Saving `;/` persists `getImConfig(table, "limeendkey") == ";/"`; reopening the screen shows `;/`.
- Clearing the Endkey field persists an empty value and the detail row displays `-`.

---

## Task 8: Implement Android end-key runtime behavior

**Objective:** Implement `limeendkey` as a general per-table commit trigger. When the user presses **any key in the active table's end-key list** while composing, LIME should end composition immediately and commit the currently highlighted candidate item, matching the existing confirm behavior for Space and Enter. This is not a comma/period-only feature.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java` around key input / composing dispatch / Space/Enter candidate-confirm behavior / `commitTyped(...)`
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/SearchServer.java` only if the current highlighted-candidate flow cannot be reused without a small API seam
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/global/LIMEPreferenceManager.java` or related config cache if IM metadata is cached there
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LIMEServiceTest.java` or `SearchServerTest.java` depending on current test seams

**Implementation requirements:**

1. Load active table Lime end-key metadata when the active IM/table changes. Treat it as a character set/list, not as special handling for comma and period.
2. If currently composing and the pressed key is in the active table's `limeendkey` set:
   - do **not** append the end-key character to the composing code;
   - do **not** query for a special direct punctuation mapping unless the existing Space/Enter confirm path already does so;
   - immediately commit the currently highlighted candidate item using the same selected-candidate path as Space/Enter;
   - clear composing state;
   - consume the key event so the raw end-key character is not emitted afterward.
3. If there is no highlighted candidate but the normal Space/Enter path has an established fallback, reuse that fallback exactly. Do not invent a separate end-key-specific fallback.
4. If no Lime end-key metadata exists, preserve current behavior exactly.
5. If the active table uses any potential end-key character as a normal root but does not opt into end keys, preserve root input.
6. Do not change candidate-list ordering; the first candidate remains composing-code fallback. Endkey changes commit behavior only.
7. Keep physical-keyboard and soft-keyboard behavior consistent unless code inspection shows separate intentional paths.

**Test requirements:**

- Regression test with a table whose end-key list contains more than comma/period, e.g. `%limeendkey ;/` or `@limeendkey@ |;/`:
  - type a composing code that shows candidates;
  - move/highlight a non-first candidate if the test seam allows;
  - press `;` or `/`;
  - assert the highlighted candidate is committed and composing is cleared;
  - assert the raw `;` or `/` is not committed.
- Compatibility test for comma/period as normal roots with no Lime end-key metadata: they remain input roots and are not treated as commit triggers.
- Test that Space/Enter behavior remains unchanged after refactoring shared confirm logic.

**Manual acceptance examples:**

- Required visual verification: run `android-visual-verify` with Computer Use and inspect the composing/candidate strip before and after the end-key press, confirming the highlighted candidate commits and composing clears.
- Table with `%limeendkey ;/`: after typing a code and highlighting a candidate, pressing `;` or `/` commits that highlighted candidate immediately, just like pressing Space/Enter would.
- `.lime` with `@limeendkey@ |,.`: comma/period are only examples of keys in the list; they should use the same general end-key path.
- 行列30/大易 style table without endkey metadata: comma/period or any other punctuation roots remain usable roots.

**Commit:**

```bash
git add LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java \
        LimeStudio/app/src/main/java/net/toload/main/hd/SearchServer.java \
        LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/LIMEServiceTest.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/SearchServerTest.java \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/LimeDBTest.java \
        docs/CIN_LIME_SPEC.md
git commit -m "feat(android): support table end-key commit trigger"
```

---

## Task 9: Respect system accent color in follow-system mode for #90

**Objective:** Do **not** add a new keyboard theme. Keep existing `6 = 系統設定` as the only follow-system choice, and make that mode respect the Android system accent color where available. The LIME Settings app should also use the system accent color instead of fixed LIME blue/green accents.

**Files:**
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java:6063-6244`
- Modify: `LimeStudio/app/src/main/res/values/themes.xml:30-59`
- Modify: `LimeStudio/app/src/main/res/values/colors.xml:122-126` only if fallback/static accent colors need clearer naming
- Modify: `LimeStudio/app/src/main/java/net/toload/main/hd/ui/LIMESettings.java:145-181` only if runtime Material dynamic-color application is needed before `setContentView(...)`
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/LIMEServiceTest.java` or a new focused color-helper test
- Test: existing settings activity/theme instrumentation tests if present; otherwise add a small theme-resolution test only if practical

**Design:**

- Keep `keyboard_themes_options` / `keyboard_themes_values` unchanged. Do not add `系統色彩`, `動態色彩`, value `7`, or any new preference UI.
- Existing fixed keyboard themes `0-5` remain visually fixed.
- Existing `6 = 系統設定` continues to resolve light/dark from `uiMode`.
- When theme `6` is active, use system accent color for LIME UI accents where Android exposes a useful accent:
  - keyboard key pressed/highlight color, if currently using fixed green highlight;
  - candidate/emoji selected-category highlight where currently theme-index based;
  - navigation bar or related strip only if contrast remains correct and it still visually belongs to the light/dark base keyboard.
- On devices/OS versions without a useful system accent, fall back to existing light/dark theme colors. No crash and no behavior change for fixed themes.
- LIME Settings app (`LIMESettingsTheme` / `AppTheme`) should follow system day/night **and** system accent color. Replace hard-coded `colorPrimary=@color/material_blue` and `colorSecondary=@color/lime_green` usage with system/dynamic accent resolution where supported; keep `material_blue` / `lime_green` only as fallback colors if needed.

**Implementation notes:**

1. In `LIMEService`, add helpers that are used only when `mKeyboardThemeIndex == 6`:
   ```java
   private boolean isFollowSystemTheme() { return mKeyboardThemeIndex == 6; }
   private int resolveSystemAccentColor(int fallbackColor) { ... }
   private int resolveFollowSystemHighlightColor(boolean dark) { ... }
   ```
2. Resolve accent from theme/system attributes first, with safe fallback:
   - Prefer Material/system accent attributes available from the current context, e.g. `colorAccent`, `colorPrimary`, or Material `colorPrimary`/`colorSecondary` depending on which is reliable in this app theme.
   - On Android 12+ / Material You devices, verify the resolved value changes with system wallpaper/accent.
   - If resolution fails or returns an unusable transparent/default value, fall back to the existing green highlight colors.
3. Thread the resolved follow-system accent through the existing color helpers instead of creating `KEYBOARD_THEMES[7]` or new styles.
4. Preserve text contrast. Do not recolor key text, candidate text, or sub-labels unless contrast is explicitly checked with `isColorLight(...)` or equivalent.
5. For Settings app accent:
   - Remove or neutralize hard-coded blue/green `colorPrimary` / `colorSecondary` in `themes.xml` so Material widgets can use the system accent when supported.
   - If Material Components requires runtime dynamic color, apply it before `setContentView(...)` in `LIMESettings.onCreate(...)`, with fallback to current colors on unsupported devices.
   - Verify BottomNavigationView, NavigationRailView, switches, buttons, tabs, and text fields follow the same accent family.

**Do not:**

- Do not add a new keyboard-theme option or value.
- Do not modify `strings_settings.xml` theme arrays for #90.
- Do not modify `preference.xml` / `xml-v17/preference.xml` for #90 unless a test proves the existing preference binding is broken.
- Do not make pink/tech-blue/fashion-purple/relax-green follow the system accent.
- Do not replace the whole keyboard background with a saturated accent color if it hurts readability; the goal is accent/highlight consistency, not a new theme.

**Test requirements:**

- Test helper behavior:
  - theme `6` light mode returns existing light base colors plus resolved/fallback accent highlights;
  - theme `6` dark mode returns existing dark base colors plus resolved/fallback accent highlights;
  - themes `0-5` do not call or use follow-system accent colors;
  - invalid/unavailable accent falls back to existing highlight colors.
- Resource/theme test verifies `keyboard_themes_options` and `keyboard_themes_values` remain unchanged and do **not** contain value `7`.
- Settings theme test, if practical, resolves `colorPrimary`/`colorSecondary` or the actual Material widget tint under `LIMESettingsTheme` and confirms it is not hard-coded to `@color/material_blue` / `@color/lime_green` on dynamic-color-capable devices.

**Manual verification:**

- Android 12+ device/emulator: set keyboard theme to `系統設定`, change wallpaper/accent, restart/reopen keyboard if needed, confirm LIME highlights/selection accents follow the system accent while light/dark still follows system theme.
- Android 12+ device/emulator: open LIME Settings app and confirm navigation selected state, switches, buttons, tabs, and text fields use the system accent family.
- Android 11 or older emulator: confirm no crash and existing fallback accents remain acceptable.
- Fixed keyboard themes `淺色`, `深色`, `粉紅`, `科技藍`, `時尚紫`, `放鬆綠` remain unchanged.

**Commit:**

```bash
git add LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java \
        LimeStudio/app/src/main/java/net/toload/main/hd/ui/LIMESettings.java \
        LimeStudio/app/src/main/res/values/themes.xml \
        LimeStudio/app/src/main/res/values/colors.xml \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/LIMEServiceTest.java
git commit -m "feat(android): respect system accent in follow-system theme"
```

---

## Task 10: Update shifted symbol-keyboard labels for #99

**Objective:** Remove misleading Chinese IM root sub-labels from shifted **non-alphabet symbol keys** only. Shifted capital-letter keys may keep their IM root sub-labels because `A-Z` can still be valid roots; symbol outputs such as `!@#...` cannot input the original Chinese IM roots, so those root sub-labels should be removed.

**Files:**
- Modify only these shifted XML layouts under `LimeStudio/app/src/main/res/xml/` because they contain non-alphabet shifted symbol keys with Chinese IM root sub-labels:
  - `lime_phonetic_shift.xml` — remove 注音 sub-labels from shifted symbol keys such as `!@#$%^&*()`, `:`, `<`, `>`, `?`, `_`; keep `Q-Z` capital-letter root sub-labels.
  - `lime_ez_shift.xml` — remove Chinese/Bopomofo root sub-labels from shifted symbol keys such as `@#$%^&*()`, `:`, `?`; keep shifted capital-letter root sub-labels.
  - `lime_et_41_shift.xml` — remove Chinese/Bopomofo root sub-labels from shifted symbol/punctuation keys such as `&*()`, `:`, `"`, `,`, `.`, `/`, `-`, `=`, `<`, `>`, `?`; keep shifted capital-letter root sub-labels.
  - `lime_dayi_sym_shift.xml` — remove Chinese root sub-labels from shifted symbol keys such as `!@#$%^&*()`, `:`, `<`, `>`, `?`; keep shifted capital-letter root sub-labels.
- Do not modify layouts that have only alphabet-key IM root sub-labels, such as `lime_cj_shift.xml`, `lime_cj_number_shift.xml`, `lime_et26_shift.xml`, `lime_hsu_shift.xml`, or `lime_wb_shift.xml`; capital-letter roots remain valid in shifted state.
- Test: `LimeStudio/app/src/androidTest/java/net/toload/main/hd/KeyboardLayoutResourceTest.java` if practical for XML resource coverage

**Implementation rules:**

1. Do not change Shift, Caps Lock, key-code mapping, composing-code logic, candidate lookup, or emitted `limehd:codes` for #99.
2. Do not remove sub-labels from shifted alphabet keys (`A-Z`), because capital letters can still function as IM roots.
3. Remove Chinese IM root sub-labels only from shifted keys whose output is non-alphabet punctuation/symbol text such as `!@#$%^&*()_+-=[]{};:'",.<>/?` and therefore cannot input the original Chinese IM root.
4. Preserve the visible symbol label itself, e.g. change `!\nㄅ` to `!`, `@\nㄉ` to `@`, `?\nㄥ` to `?`.
5. Do not bulk-strip every second-line label; some shifted labels may describe actual shifted output or valid alphabet roots.

**Test requirements:**

Add XML resource assertions where feasible:

```java
@Test
public void shiftedSymbolKeysDoNotShowChineseRootSubLabels() {
    Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
    assertNoChineseRootSubLabelsOnShiftedSymbols(context, R.xml.lime_phonetic_shift);
    // Add each edited shifted IM resource.
}
```

The helper should inspect each `<Key>` where `limehd:codes` emits a non-alphabet printable symbol and fail if `limehd:keyLabel` contains a newline plus a Chinese IM root sub-label. It should allow labels like `Q\nㄆ`, `A\nㄇ`, or `Z\nㄈ` because shifted capital letters can still be roots.

**Manual verification:**

- 注音 + Shift: symbol keys such as `!@#$...` no longer show 注音 root sub-labels.
- Shifted capital-letter keys still show their root sub-labels.
- The same symbol keys still input symbols exactly as before.
- Shift/caps-lock behavior and candidate lookup are unchanged.

**Commit:**

```bash
git add LimeStudio/app/src/main/res/xml/*shift*.xml \
        LimeStudio/app/src/androidTest/java/net/toload/main/hd/KeyboardLayoutResourceTest.java
git commit -m "feat(android): remove root labels from shifted symbol keys"
```

---

## Task 11: Documentation/backlog synchronization

**Objective:** Keep public repo docs aligned with the implementation without exposing local automation state.

**Files:**
- Modify: `docs/BACKLOG.md`
- Modify: `docs/#91_ISSUE.md`
- Modify: `docs/#93_ISSUE.md`
- Modify: `docs/#94_ISSUE.md`
- Modify: `docs/#96_ISSUE.md`
- Modify/create: `docs/ANDROID_NR.md` (this plan)
- Modify: `docs/CIN_LIME_SPEC.md` if `%endkey` / `@endkey@` semantics changed
- Modify: `docs/ANDROID_THEME.md` if dynamic-color architecture is implemented

**Requirements:**

1. Mark entries as implemented in source but awaiting APK/reporter retest where applicable.
2. For #94, note whether PR #97 was merged/rebased or superseded by this branch.
3. For #96, keep bug and feature scopes separate:
   - direct mapping selection fix;
   - opt-in end-key feature.
4. For #90, state only dynamic-color/accent support was implemented; leave button/layout customization out of backlog until confirmed.
5. Do not update local-only `github-mutable-state.md` in this repo commit; that lives outside the repo and should be updated separately after the APK/release state changes.
6. For #96 end-key support, document whether bundled Android table assets existed in the repo and whether any official table metadata/mapping updates were included or deferred for separate table-data coordination.

**Commit:**

```bash
git add docs/BACKLOG.md docs/#91_ISSUE.md docs/#93_ISSUE.md docs/#94_ISSUE.md \
        docs/#96_ISSUE.md docs/ANDROID_NR.md docs/CIN_LIME_SPEC.md docs/ANDROID_THEME.md
git commit -m "docs: update Android next-release plan and issue status"
```

---

## Task 12: Full Android verification pass

**Objective:** Prove the branch is ready for Jeremy review and APK build.

**Commands:**

```bash
cd /home/jeremy/tmp/limeime/LimeStudio
ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk ./gradlew :app:compileDebugJavaWithJavac :app:compileDebugAndroidTestJavaWithJavac
```

Expected: Java and androidTest compilation pass.

If device/emulator is available:

```bash
ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk ./gradlew :app:connectedDebugAndroidTest
```

Expected: all connected Android tests pass. If a device is unavailable, record that as the only blocked verification item.

**Manual smoke tests:**

1. Backup:
   - create backup;
   - confirm output ZIP is non-empty;
   - restore it successfully.
2. `.cin` import order:
   - import 哈哈倉頡 `.cin`;
   - type `vmi`;
   - confirm `狀`, `绒`, `戕` order with sorting disabled.
3. `.lime` metadata:
   - import Array10-style `.lime` with `#` comments;
   - confirm display name/version persist.
4. Direct punctuation:
   - table with `, = ，`, `. = 。` highlights direct punctuation first.
5. Endkey:
   - opt-in table with `%limeendkey ,.` / `@limeendkey@ |,.` commits punctuation directly;
   - table without Lime endkey still treats `,` / `.` as roots if defined.
6. Dynamic color:
   - theme 0-6 unchanged;
   - new dynamic/accent theme follows accent where supported and falls back safely where not.
7. Shifted symbol labels:
   - shifted symbol keys such as `!@#$...` no longer show Chinese IM root sub-labels;
   - shifted capital-letter keys still keep useful root sub-labels;
   - Shift/caps-lock behavior and candidate lookup are unchanged.

---

## Task 13: Build review APK and prepare retest notes

**Objective:** Produce a single Android APK for Jeremy review and later reporter retest.

**Commands:**

```bash
cd /home/jeremy/tmp/limeime/LimeStudio
ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk ./gradlew :app:assembleRelease
```

Expected: release APK produced under `LimeStudio/app/build/outputs/apk/release/` or the repo's configured release-output path.

**Retest-note draft topics after Jeremy approval:**

- #91: ask reporter to retest `.cin` duplicate-code order with 哈哈倉頡 `vmi`.
- #94: ask reporter to retest non-empty backup creation and restore.
- #96: ask reporters to retest direct punctuation mappings and, if they have an opt-in endkey table, direct comma/period commit.
- #90: describe as new optional dynamic/accent theme behavior, not a bug retest request.
- #99: describe the shifted-symbol-label UI clarification; no retest request for input behavior because Shift/Caps Lock behavior is unchanged by design.
- #93 is maintainer-created; no community retest needed unless Jeremy asks.

---

## Final review checklist

- [ ] All confirmed Android backlog items above have code changes or an explicit reason for deferral.
- [ ] #90 unconfirmed button/layout customization remains out of scope.
- [ ] Tests compile and targeted regression tests pass.
- [ ] Connected Android tests run, or lack of device/emulator is explicitly documented.
- [ ] Manual APK smoke tests are recorded.
- [ ] `docs/BACKLOG.md` and issue docs match branch state.
- [ ] No local-only automation state is committed into the repo.
- [ ] Jeremy reviews before merge/release/public replies.
