# Android IME Startup Optimization Plan

This plan follows the Issue #107 emulator profiling in `docs/STARTUP_PROFILING.md`.

The current measured startup shape is not acceptable. The local emulator spent about one second of LIME-side work before the keyboard became visible. The most obvious offender was emoji setup, where hidden emoji UI construction cost 418 ms in `onInitializeInterface()` and another 345 ms in `onCreateInputView()`. But the fix must not stop at emoji. The startup path should be reviewed end to end so every nonessential step is removed from the first visible keyboard frame.

Goal: make IME activation show the base keyboard first, then initialize optional or refreshable components after first display, on first use, or in small deferred chunks.

## Startup Budget

The first visible keyboard frame should have a strict budget.

Target max on the Pixel 9 Pro API 36 emulator:

- Cold-ish LIME-side activation: 300 ms max from service callback start to returned input view.
- Warm LIME-side activation: 150 ms max.
- `onInitializeInterface()`: 150 ms max cold-ish, 100 ms max warm.
- `onCreateInputView()`: 150 ms max cold-ish, 100 ms max warm.
- Any hidden optional component setup during startup: 20 ms max, or skipped.

The Samsung A52 report is about seven seconds. This plan does not assume the emulator reproduces that full delay. It removes known waste first, then makes remaining slow steps measurable.

## First-Frame Rule

Startup must only do work required for the first visible keyboard frame.

Required before first frame:

- Create or reuse the input candidate container.
- Create or reuse the normal keyboard view.
- Load enough preference state to choose the keyboard mode.
- Attach the active keyboard to the input view.
- Set candidate strip / empty toolbar visibility.
- Apply the minimum theme state needed for visible keyboard correctness.

Not required before first frame:

- Full emoji panel construction.
- Emoji category data rendering.
- Voice input controller warmup beyond cheap object creation.
- Full active-IM and keyboard config refresh if a valid snapshot is already available.
- Repeated keyboard reset when settings did not change.
- Repeated view inflation when the existing view is valid.
- Full accent/theme refresh when theme inputs did not change.
- DB-backed config queries that can be served from a short-lived startup snapshot.
- Any cache prefetch that does not affect the first key press.

## Measured Problems

Cold-ish emulator run:

- `LIMEService.onCreate()` total: 115 ms.
- `SearchServer` constructor total: 36 ms.
- `buildActivatedIMList()` during `onCreate()`: 12 ms.
- `onInitializeInterface()` total: 485 ms.
- `initialViewAndSwitcher(false)` inside `onInitializeInterface()`: 483 ms.
- First `setupEmojiKeyboardView()`: 418 ms.
- `onStartInput()` total: 18 ms.
- `onCreateInputView()` total: 354 ms.
- `initialViewAndSwitcher(true)` inside `onCreateInputView()`: 351 ms.
- Second `setupEmojiKeyboardView()`: 345 ms.
- `onStartInputView()` total: 5 ms.

Warm comparison:

- `LIMEService.onCreate()` total: 54 ms.
- `SearchServer` constructor total: 7 ms.
- `onInitializeInterface()` total: 195 ms.
- First `setupEmojiKeyboardView()`: 173 ms.
- `onCreateInputView()` total: 259 ms.
- Second `setupEmojiKeyboardView()`: 246 ms.

DB/config reads were small on this emulator, mostly 0-12 ms. They still matter because they are repeated and may be slower on older storage, restored databases, or larger tables.

## Root Cause Categories

### 1. Multi-Path Lifecycle Coverage With Repeated Heavy Work

Current shape:

- `onStartInput()` calls `super.onStartInputView(attribute, restarting)`.
- `onStartInputView()` also calls `super.onStartInputView(attribute, restarting)`.
- `initOnStartInput(attribute)` runs from both callbacks.
- `initialViewAndSwitcher(false)` runs in `onInitializeInterface()`.
- `initialViewAndSwitcher(true)` runs again in `onCreateInputView()`.

This is multi-path lifecycle coverage, and it exists for a reason. Different apps, physical-keyboard flows, orientation states, and Android framework paths may call different IME callbacks. LIME is especially sensitive here because candidates are embedded inside the input view for physical-keyboard compatibility. The optimization target is not "remove one of the init paths"; it is "remove or defer expensive optional work inside these paths while preserving coverage."

### LatinIME Reference Pattern

AOSP LatinIME keeps both `onStartInput(...)` and `onStartInputView(...)`, but it does not put the same heavy work in both paths.

Reference source:

- `https://android.googlesource.com/platform/packages/inputmethods/LatinIME/+/5657746/java/src/com/android/inputmethod/latin/LatinIME.java`

Observed pattern:

- Public `onStartInput(...)` delegates to a handler, which eventually calls `onStartInputInternal(...)`.
- `onStartInputInternal(...)` calls `super.onStartInput(editorInfo, restarting)`.
- Public `onStartInputView(...)` delegates to the handler, which eventually calls `onStartInputViewInternal(...)`.
- `onStartInputViewInternal(...)` calls `super.onStartInputView(editorInfo, restarting)`.
- The handler tracks pending callbacks around orientation changes and delayed IME callback ordering.
- `onStartInputViewInternal(...)` explicitly returns early if the main keyboard view is not created yet, because landscape or framework states may call it without a view.
- LatinIME uses `inputTypeChanged` and `isDifferentTextField` to decide whether to reload settings and load the keyboard.
- If the field is not different and this is only `restarting`, it resets keyboard state / shift state instead of fully reloading the keyboard.

Takeaway for LIME, with an important difference:

- Keep both lifecycle entry points.
- Do not assume LatinIME's split can be copied directly.
- LatinIME does not have LIME's exact embedded-candidate physical-keyboard design.
- LIME must keep `onStartInput()` capable of preparing candidate/search state for hardware key events even when `onStartInputView()` is not called.
- Make each callback safe when the other callback did not run yet.
- Use LatinIME mainly as evidence that callbacks can arrive in unusual orders and should be guarded.
- First low-risk optimization should preserve LIME's current init routing and defer optional work inside it.
- Lifecycle refactoring, including superclass-call correction, should be a later separately measured phase because physical-keyboard behavior makes it higher risk.

Suggested LIME mapping:

- First pass: keep the existing callback structure and `initOnStartInput(...)` call sites.
- Optimize the functions called by those paths so optional components do not block startup.
- Add measurement/guards around heavy work rather than moving physical-keyboard-sensitive state between callbacks.
- Later pass, only after profiling and tests: consider a LIME-specific split of editor/session state and visible-view state, using LatinIME only as a lifecycle-safety reference.

### 2. Hidden Optional UI Built Synchronously

`setupEmojiKeyboardView()` currently does more than wire a view. It calls `renderEmojiContent("")`, which builds emoji sections, category tabs, and many emoji `TextView` keys. It runs even when the emoji panel is hidden and the user only wants the normal keyboard.

### 3. Repeated DB / Config Refresh

Startup calls active IM and keyboard config reads from several places:

- `onCreate()`
- `initialViewAndSwitcher(...)`
- `initOnStartInput(...)`

The measured emulator cost was small, but the pattern is still risky. Startup should have one config snapshot per activation, not repeated equivalent queries.

### 4. Keyboard Reset Without Change Detection

`initOnStartInput()` calls:

- `mKeyboardSwitcher.setImConfigKeyboardList(SearchSrv.getAllImKeyboardConfigList())`
- `mKeyboardSwitcher.resetKeyboards(...)`
- `buildActivatedIMList()`
- `initialIMKeyboard()` or `setKeyboardMode(...)`

Some of this is necessary per editor field. Some should run only when settings, active IM, keyboard layout, theme, or input type actually require it.

### 5. Theme / Accent Work On The Hot Path

`initialViewAndSwitcher(...)` applies follow-system accent colors and theme context work. Theme correctness matters, but full recomputation should be invalidated by theme/config changes, not blindly repeated on every startup callback.

### 6. Optional Service Objects And Receivers

`onCreate()` creates `SearchServer`, initializes preferences, dictation controller, vibrator/audio services, active IM list, and voice receiver. Most of this is cheap on the emulator, but the rule remains:

- Cheap handles are fine.
- Any slow setup should be lazy, posted, or made snapshot-based.
- Anything needed only for voice, emoji, settings screens, or backup/import should not block keyboard first frame.

## Optimization Architecture

Use a two-lane startup model.

### Lane A: Critical First Frame

Runs synchronously.

Responsibilities:

- Ensure `SearchSrv` exists.
- Ensure `mLIMEPref` exists.
- Ensure a valid keyboard config snapshot exists, using cached data if possible.
- Reuse or inflate the input container once.
- Attach visible keyboard.
- Select field-specific keyboard mode.
- Return the input view.

Lane A should not build optional UI, refresh all caches, or repeat equivalent work.

### Lane B: Deferred Optional Work

Runs after the first frame or on first use.

Responsibilities:

- Emoji shell setup.
- Emoji content rendering.
- Emoji category page prewarm.
- Voice UI/controller warm paths beyond minimal construction.
- Full config refresh if stale but not needed for first frame.
- Cache prefetch for the active table.
- Nonessential theme/accent refresh after visible keyboard is stable.

Lane B may use:

- Main-thread `post(...)` for Android `View` work.
- Background thread / executor for DB or pure data preparation.
- Generation tokens to avoid applying stale deferred work after view recreation.

Never mutate Android `View` objects from background threads.

## Implementation Plan

### Phase 1: Preserve Init Paths, Defer Optional Work

First implementation should not change LIME's lifecycle routing. Keep `onStartInput()`, `onStartInputView()`, and their current `initOnStartInput(attribute)` coverage intact while optimizing the expensive work they reach.

This is the lowest-risk path because physical-keyboard behavior depends on LIME-specific candidate handling. LIME embeds the candidate view inside the input view for compatibility reasons, and some physical-keyboard flows may call `onStartInput()` before, or without, a visible soft-keyboard `onStartInputView()` path.

Current init path:

```text
LIMEService.onCreate()
  -> super.onCreate()
  -> new SearchServer(this)
      -> new/open LimeDB
      -> initialCache()
      -> preloadEmojiCategoryPages() on background thread
  -> PreferenceManager.setDefaultValues(...)
  -> new LIMEPreferenceManager(...)
  -> new LIMEDictationController(...)
  -> buildActivatedIMList()
      -> SearchSrv.getImConfigList(...)
      -> maybe setIMActivatedState(...)
  -> registerVoiceInputReceiver()

onInitializeInterface()
  -> initialViewAndSwitcher(false)
      -> maybe reset keyboard switcher theme
      -> maybe inflate R.layout.inputcandidate
      -> setupEmojiKeyboardView()
          -> renderEmojiContent("")
          -> build emoji pages / tabs / many TextViews
      -> applyFollowSystemAccentColors()
      -> buildActivatedIMList()
      -> maybe getKeyboardConfigList()
      -> maybe getAllImKeyboardConfigList()
  -> initCandidateView()
  -> resetKeyboards(true)
  -> super.onInitializeInterface()

onCreateInputView()
  -> mInputView = null
  -> initialViewAndSwitcher(true)
      -> inflate/rebuild candidate + keyboard view again
      -> setupEmojiKeyboardView() again
      -> renderEmojiContent("") again
      -> applyFollowSystemAccentColors() again
      -> buildActivatedIMList() again
  -> applyNavigationBarTheme()
  -> return mCandidateInInputView

onStartInput(attribute, restarting)
  -> super.onStartInputView(attribute, restarting)   // wrong superclass method
  -> initOnStartInput(attribute)
      -> maybe initialViewAndSwitcher(true)
      -> getAllImKeyboardConfigList()
      -> resetKeyboards(...)
      -> loadSettings()
      -> buildActivatedIMList()
      -> setKeyboardMode(...) or initialIMKeyboard()

onStartInputView(attribute, restarting)
  -> super.onStartInputView(attribute, restarting)
  -> resetEmojiKeyboardState()
  -> initOnStartInput(attribute) again
  -> restore physical-key composing state / show keyboard view
  -> commit pending voice text
  -> applyNavigationBarTheme()
```

Low-risk first-pass init path:

```text
LIMEService.onCreate()
  -> keep current required service setup
  -> keep SearchServer creation for now
  -> do not add new optional work
  -> make SearchServer preloads/background work nonblocking

onInitializeInterface()
  -> keep current callback coverage
  -> initialViewAndSwitcher(false)
      -> create/reuse required candidate + keyboard host
      -> setup emoji placeholder only
      -> do not render emoji content
      -> avoid full theme/accent recompute if unchanged
      -> use cached config snapshot if valid
  -> keep initCandidateView() and reset behavior unless a conservative predicate proves it is unnecessary

onCreateInputView()
  -> keep current callback coverage
  -> initialViewAndSwitcher(true)
      -> preserve physical-keyboard candidate host behavior
      -> setup emoji placeholder only
      -> do not render emoji content
      -> use cached config snapshot if valid
  -> post optional prewarm after first frame with generation guard
  -> return mCandidateInInputView

onStartInput(attribute, restarting)
  -> keep current route for first pass
  -> initOnStartInput(attribute)
      -> preserve physical-keyboard candidate/search readiness
      -> use cached startup config snapshot if valid
      -> reset keyboards only if conservative predicate says changed
      -> do not trigger optional emoji/content work

onStartInputView(attribute, restarting)
  -> keep current route for first pass
  -> resetEmojiKeyboardState()
  -> initOnStartInput(attribute)
      -> preserve current behavior
      -> share cached snapshot / reset predicate with onStartInput path
      -> do not trigger optional emoji/content work
  -> restore physical-key composing state / show keyboard view
  -> commit pending voice text
  -> apply nav/theme only if changed
```

Risk evaluation:

| Change | Risk | Mitigation |
| --- | --- | --- |
| Preserve current init routing | Startup improvement is smaller than a deeper lifecycle refactor. | Accept this for the first pass; the goal is low-risk reduction of optional work, especially emoji. |
| Defer optional work inside current paths | Deferred work can run after IME view is recreated or hidden. | Use generation tokens and null checks before applying deferred work. |
| Lazy emoji content | First emoji open may be slower or briefly blank. | Show shell immediately; render first category first; chunk remaining categories; keep behavior tests for emoji search/recent/category selection. |
| Config snapshot in current paths | Missed invalidation can leave stale active IM/layout/theme. | Persistent `startup_config_version` uses `0` as always-dirty; config writers bump or reset it; service reloads conservatively when unsure. |
| Conservative keyboard reset predicate | Too conservative means less speedup; too aggressive can leave wrong keys/layout. | Start conservative. Skip only proven no-op resets with identical inputs. |
| Theme/accent caching | Stale color/theme after system or setting change. | Invalidate on config/theme changes; if uncertain, rerun theme path. |
| Future superclass/lifecycle split | Physical keyboard or host-app callback order can regress. | Defer this to a later phase with explicit tests; do not include it in first low-risk implementation. |

Recommended shape:

- Keep `onStartInput()` and `onStartInputView()` current coverage in the first pass.
- Keep physical-keyboard candidate/search readiness in `onStartInput()` reachable code.
- Make expensive optional substeps demand-driven or post-frame.
- Add conservative guards inside existing helpers rather than moving helpers between callbacks.
- Treat LatinIME as a reference for callback-order caution and reload predicates, not as a direct architecture template.

Physical-keyboard rule:

- Do not move all candidate/search initialization to `onStartInputView()`.
- `onStartInput()` must leave the service ready for hardware `onKeyDown(...)` / `onKeyUp(...)`.
- If candidates are embedded in `mCandidateInInputView`, create or reuse a minimal candidate host from `onStartInput()` when needed.
- The minimal candidate host should not run full soft-keyboard startup, emoji content render, theme/accent refresh, or full reset unless required.
- The soft keyboard view may stay `GONE` when `hasPhysicalKeyPressed` is true, but candidate strip/container must be able to show suggestions.

Possible guard inside existing setup helpers:

```java
private int mStartInputGeneration = 0;
private EditorInfo mAppliedVisibleEditorInfo = null;
private int mAppliedVisibleViewGeneration = -1;

private boolean shouldApplyVisibleStart(EditorInfo info) {
    return mAppliedVisibleViewGeneration != mInputViewGeneration
            || !sameInputClassAndVariation(mAppliedVisibleEditorInfo, info)
            || keyboardSnapshotInvalid();
}
```

Acceptance:

- Current lifecycle/init routing remains behavior-compatible in the first pass.
- Physical-keyboard candidate behavior remains intact if `onStartInputView()` does not run.
- Emoji content render is absent from first startup path.
- Optional work is deferred or lazy without changing callback semantics.
- Conservative config/reset guards do not skip required keyboard changes.
- Physical-keyboard composing preservation still works.
- Voice pending text commit still works.

### Phase 2: Reuse Input View Instead Of Rebuilding

Make `initialViewAndSwitcher(forceRecreate)` respect existing valid views.

Rules:

- Inflate `R.layout.inputcandidate` only if no view exists or a real invalidation occurred.
- Do not set `mInputView = null` in `onCreateInputView()` unless the existing view is invalid.
- Track invalidation reasons explicitly: theme change, orientation/config change, keyboard layout size change, destroyed view.
- `onInitializeInterface()` should not do the same heavy build that `onCreateInputView()` will immediately redo.

Suggested state:

- `private int mInputViewGeneration = 0;`
- `private int mKeyboardViewThemeIndex = -1;`
- `private boolean mInputViewReady = false;`
- `private boolean mKeyboardConfigSnapshotReady = false;`

Acceptance:

- First activation inflates once.
- Warm activation reuses the view when theme/config is unchanged.
- Configuration/theme change still rebuilds correctly.

### Phase 3: Lazy Optional Component Framework

Introduce a small startup deferral helper inside `LIMEService`.

Concept:

```java
private void postAfterFirstFrame(Runnable task) {
    if (mCandidateInInputView == null) return;
    int generation = mInputViewGeneration;
    mCandidateInInputView.post(() -> {
        if (generation != mInputViewGeneration) return;
        task.run();
    });
}
```

Use it for optional work only. Critical keyboard selection stays synchronous.

Acceptance:

- Deferred tasks do not crash after rapid IME switching.
- Deferred tasks are skipped for stale views.
- First visible keyboard is not delayed by deferred tasks.

### Phase 4: Emoji Becomes Demand-Driven

Split emoji startup into three stages.

Stage 0, startup placeholder:

- Store `mEmojiKeyboardView`.
- Set it to `GONE`.
- Reset emoji state.
- Do not call `renderEmojiContent("")`.

Stage 1, deferred shell:

- Create root, search field, scroll container, bottom bar, ABC button, backspace button.
- Do not create emoji grid cells yet.
- Post this after first frame, or create it lazily on first emoji open if even shell setup is measurable.

Stage 2, first-use content:

- Trigger from `showEmojiKeyboard()`.
- Render content only when the user opens emoji.
- If data is not ready, show the shell immediately and fill content when loaded.
- Render first category first; append additional categories in posted chunks if full render still stalls.

Acceptance:

- Startup no longer pays the 418 + 345 ms emoji cost.
- Pressing emoji opens a correct panel.
- Emoji search and recent emoji still work.
- Recent emoji invalidates content without rebuilding while hidden.

### Phase 5: Startup Config Snapshot

Create one short-lived startup snapshot for values needed during activation.

Do not rely on `LIMESettings` instance variables or `static` Java flags. `LIMEService` is a system-invoked `InputMethodService`; it may be started by another app focusing a text field when no settings UI exists. The invalidation signal must be persistent and readable by the service on cold start.

Snapshot fields:

- Active IM.
- Activated IM list and short names.
- Keyboard config list.
- IM keyboard config list.
- Show-arrow setting.
- Split-keyboard setting.
- Keyboard theme.
- Persistent language mode.

Use a persistent version in default `SharedPreferences`, exposed through `LIMEPreferenceManager`.

Version rule:

- `startup_config_version == 0`: dirty / uninitialized / force reload.
- `startup_config_version > 0`: normal comparable version.
- `LIMEService` stores only a local applied version, initialized to `-1`.

Service-side shape:

```java
private long mAppliedStartupConfigVersion = -1L;

private boolean isStartupConfigDirty() {
    long current = mLIMEPref.getStartupConfigVersion();
    return current == 0L || current != mAppliedStartupConfigVersion;
}

private void markStartupConfigApplied() {
    long current = mLIMEPref.getStartupConfigVersion();
    if (current == 0L) {
        current = mLIMEPref.initializeStartupConfigVersion();
    }
    mAppliedStartupConfigVersion = current;
}
```

This makes reset safe. If any writer resets the persistent version to `0`, a live service treats it as dirty even if its local applied version was also `0` or any previous value. After a successful reload, the service normalizes `0` to a real version such as `1` so it does not reload forever.

Load the snapshot once per activation or reuse it if the persistent version is unchanged.

Invalidate when:

- User changes keyboard settings.
- Active table / enabled table list changes.
- Import/restore changes DB config.
- Theme changes.
- Keyboard size/layout setting changes.
- App upgrade, preference migration, or DB schema migration changes startup defaults/config.

Where to invalidate:

- Persistent config writers should bump `startup_config_version`, or conservatively reset it to `0`.
- `LIMEService` write paths that matter:
  - `mLIMEPref.setSplitKeyboard(...)` from the keyboard menu should invalidate keyboard/startup config.
  - `mLIMEPref.setActiveIM(activeIM)` from IM switching should invalidate active-IM/startup config.
- `LIMEService` write paths that usually should not invalidate startup config:
  - `setHanCovertOption(...)`, unless the snapshot starts caching conversion behavior.
  - `setReverseLookupTable(...)`, unless the snapshot starts caching reverse lookup behavior.
  - `recordEmojiUsage(...)`, which should invalidate emoji content/recent cache only.
  - `setLanguageMode(...)`, unless persistent language mode is included in the startup snapshot. If it is included, invalidate a lightweight startup-state version or the broad startup version.
- Do not invalidate merely because `SearchServer` starts, opens the DB, preloads emoji, or because `buildActivatedIMList()` syncs DB-derived active state into preferences. Those are read/sync paths and would create unnecessary reload loops.

Acceptance:

- `buildActivatedIMList()` is not called from three startup locations for the same activation.
- `SearchSrv.getAllImKeyboardConfigList()` is not repeated when snapshot data is still valid.
- Settings changes still take effect.
- Resetting `startup_config_version` to `0` forces reload for live and cold service instances.

### Phase 6: Keyboard Reset Change Detection

Wrap keyboard reset behind a predicate.

Reset only when one of these changes:

- Active IM.
- Keyboard layout/config snapshot version.
- Arrow key setting.
- Split keyboard setting.
- Theme/context.
- Relevant input type mode.

Do not clear/recreate keyboards just because a lifecycle callback fired.

Acceptance:

- `resetKeyboards(...)` is skipped on repeated callbacks with unchanged inputs.
- Number/date/phone/text field modes still switch correctly.
- Persistent language mode still restores correctly.

### Phase 7: Theme And Accent Caching

Cache applied theme/accent state.

Track:

- Keyboard theme index.
- Effective dark/light mode.
- Accent color values.
- Navigation bar background color.

Run full theme/accent application only when inputs changed. For startup, apply the already-known visible colors first, then post any expensive refresh.

Acceptance:

- Theme changes still apply after system dark/light change.
- Startup does not repeat accent work when theme state is unchanged.
- Navigation bar remains visually correct.

### Phase 8: DB And SearchServer Startup

Keep `SearchServer` creation synchronous only as far as needed to serve first keyboard setup.

Rules:

- DB open required for active config can stay synchronous until proven slow on device.
- Cache prewarm remains background-only.
- Emoji category preload remains background-only.
- Any DB upgrade/import/restore path must be measured separately and should not be hidden inside normal IME switch startup.

Add readiness checks rather than blocking:

- `hasEmojiCategoryPagesCache()`
- `getCachedKeyboardConfigSnapshot()`
- `refreshKeyboardConfigSnapshotAsync()`

Acceptance:

- Normal startup does not wait for emoji category preload.
- Config reads are bounded and logged.
- If DB open is slow on Samsung A52, it becomes the next explicit target.

### Phase 9: Optional Feature Lazy Init

Audit all feature-specific setup in `onCreate()`, `onInitializeInterface()`, `onCreateInputView()`, and `initOnStartInput()`.

Move noncritical work out of Lane A:

- Voice/dictation expensive setup: lazy when mic/voice action is used.
- Emoji: lazy/deferred as above.
- Backup/import/export helpers: never in IME startup.
- Full candidate/search prefetch: after first frame or first key.
- UI-only helper objects: create on first display if cheap, otherwise after first frame.

Do not defer:

- Haptic/audio handles if they are cheap and needed for first key feedback.
- EditorInfo-based keyboard mode selection.
- Minimum preference reads needed for first keyboard state.

## Verification Plan

Use the same focused flow as `docs/STARTUP_PROFILING.md`.

Pre-flight test coverage check:

Existing tests give partial coverage, but they are not enough by themselves to protect the init path after this optimization.

Current useful coverage:

| Area | Existing coverage | Limit |
| --- | --- | --- |
| Service creation | `LIMEServiceWithStubActivityTest.test_5_24_1_OnCreateWithContext()` attaches context and runs `onCreate()` on the main thread. | Covers service creation only, not the full IME startup sequence. |
| Input view creation | `LIMEServiceTest.test_5_2_1_5_OnCreateInputView()` calls `onInitializeInterface()` then `onCreateInputView()`. | Mostly proves code is exercised; exceptions are accepted, and it does not assert candidate/search readiness. |
| Visible input start | `LIMEServiceTest.test_5_1_2_5_OnStartInputView()` calls `onStartInput()` then repeated `onStartInputView()` variants. | Good branch exercise, but exceptions are accepted and the test does not assert the post-init contract. |
| Integration lifecycle setup | `RegressionTest` setup calls `onCreate()`, `onInitializeInterface()`, `onStartInput()`, and `onStartInputView()` before search tests. | Useful smoke coverage, but it only covers the visible soft-keyboard path. |
| Emoji helper behavior | Existing `LIMEServiceTest` cases cover emoji key constants, search mode helpers, recent insertion logic, and sizing helpers. | They do not prove emoji content is lazy, absent from startup, or ready on first emoji open. |

Missing tests that should be added before the low-risk optimization lands:

1. `onStartInput()`-only physical-keyboard contract test.
   - Sequence: `onCreate()` -> `onInitializeInterface()` -> `onStartInput(textEditor, false)`.
   - Do not call `onCreateInputView()` or `onStartInputView()`.
   - Assert `SearchSrv`, active IM state, composing buffer, prediction state, keyboard switcher state, and candidate/search fields needed by physical-key processing are initialized.
   - Assert no eager emoji content render is required for this path.

2. Normal visible soft-keyboard contract test.
   - Sequence: `onCreate()` -> `onInitializeInterface()` -> `onStartInput()` -> `onCreateInputView()` -> `onStartInputView()`.
   - Assert returned input view is the embedded `CandidateInInputViewContainer`.
   - Assert candidate strip host and keyboard view are valid.
   - Assert emoji shell exists only if required, but full emoji pages are not rendered before emoji open.

3. `onCreateInputView()` without prior `onStartInputView()` contract test.
   - Sequence: `onCreate()` -> `onInitializeInterface()` -> `onCreateInputView()`.
   - This protects framework/app paths that ask for the input view before the visible start callback finishes.
   - Assert first visible keyboard dependencies are ready and deferred work is not required for returning the view.

4. Repeated callback generation test.
   - Sequence: visible startup, then repeated `onStartInput()` / `onStartInputView()` with equivalent `EditorInfo`.
   - Assert optional deferred tasks are generation-guarded and stale tasks do not mutate the new session.
   - Assert keyboard reset/config reload runs only when the tracked config snapshot changes.

5. Config invalidation test between `LIMESettings` and `LIMEService`.
   - Mutate startup-relevant preferences using the same persistent preference paths that settings uses.
   - Assert version `0` is treated as dirty/newer.
   - Assert positive versions reload only once per service-side applied version.
   - Assert non-startup writes do not force startup rebuild.

6. Emoji lazy-init test.
   - Assert normal startup does not populate full emoji pages.
   - Open emoji once and assert pages, search field, bottom bar, category selection, and recent category behavior are valid.
   - Return to the source keyboard and assert candidate strip visibility is restored.

7. Physical-keyboard first-key preservation test.
   - Simulate a hardware key path after `onStartInput()` and before `onStartInputView()`.
   - Assert composing text and candidates survive when the input view later appears.
   - Assert soft keyboard view stays hidden when `hasPhysicalKeyPressed` is true, while the embedded candidate host can show candidates.

The pass/fail bar should be contract assertions, not only "method was called" or "exception was acceptable." The existing coverage-style tests can stay, but they are not enough to approve an init-path-sensitive optimization.

Required runtime verification baseline:

- Do not verify startup against an empty LIME IM list or empty DB.
- Install at least `phonetic` and `dayi` LIME IMs before profiling or visual verification.
- Confirm the DB contains mappings/config rows for those IMs.
- Confirm the active LIME IM is one of the installed tables before each startup run.
- Run the startup profile and visual check for both `phonetic` and `dayi`.
- Treat empty-IM / empty-DB runs as first-time setup coverage only, not representative startup performance or behavior evidence.

Temporary timing logs should measure:

- `onCreate()` total.
- `SearchServer` constructor / DB open.
- Default preference initialization.
- `buildActivatedIMList()`.
- `onInitializeInterface()` total.
- `onCreateInputView()` total.
- Input view inflation.
- Emoji placeholder/shell/content separately.
- `applyFollowSystemAccentColors()`.
- `getKeyboardConfigList()` and `getAllImKeyboardConfigList()`.
- `onStartInput()` total.
- `onStartInputView()` total.
- `initOnStartInput()` total.
- `resetKeyboards(...)`.
- `initialIMKeyboard()`.
- First post-frame deferred task total.

Performance acceptance:

- First visible keyboard appears before emoji content render.
- `setupEmojiKeyboardView()` replacement is 50 ms max if run before first frame.
- Full emoji content render is absent from startup logs.
- First-pass changes preserve current lifecycle/init routing.
- Heavy optional setup is absent from startup logs or posted after first frame.
- Input view inflates once per valid view generation.
- Repeated config queries are reduced to one snapshot load per activation.
- Warm switch is meaningfully faster than current 195-259 ms interface/view setup.

Behavior acceptance:

- Text, number, date, phone, password/email, and short-message fields choose correct keyboard modes.
- Chinese and English persistent language modes restore correctly.
- Candidate strip / empty toolbar remains correct.
- Physical keyboard flow works when only `onStartInput()` runs before hardware key events.
- Physical keyboard candidates remain visible through the embedded `CandidateInInputViewContainer` even when the soft keyboard view is hidden.
- Physical keyboard first-key preservation still works.
- Voice pending text still commits.
- Emoji opens and works on first use.
- Emoji search works.
- Recent emoji updates.
- Theme and navigation bar colors remain correct.
- Config/theme changes still invalidate and rebuild what they must.

Regression tests:

- First-pass regression tests should not require changing lifecycle routing.
- Lifecycle tests for three sequences: `onStartInput()` only, `onStartInputView()` after `onStartInput()`, and repeated `onStartInputView()` with equivalent `EditorInfo`.
- Instrumentation hook proving heavy optional setup is skipped/deferred for a normal visible startup, not proving callbacks only happen once.
- Physical-keyboard lifecycle test where `onStartInput()` prepares candidate/search state and embedded candidate host without requiring `onStartInputView()`.
- Snapshot invalidation tests for active IM/config/theme changes.
- Emoji lazy-init tests if emoji state is extracted into a helper.
- Manual startup profiling checklist for cold and warm IME switch.

## Implementation Order

Recommended order:

1. Add or strengthen the lifecycle contract tests listed in the pre-flight coverage check.
2. Add temporary timing logs and a lightweight activation counter.
3. Remove eager emoji content rendering from startup while keeping current init paths.
4. Add post-frame optional startup queue with generation guards.
5. Add startup config snapshot with conservative invalidation.
6. Add conservative keyboard reset change detection inside the existing paths.
7. Add theme/accent change detection inside the existing paths.
8. Re-profile cold, warm, and physical-keyboard flows.
9. Only after the low-risk pass is proven, consider input-view reuse changes.
10. Treat any superclass/lifecycle split as a later high-risk phase, using LatinIME as a reference for callback safety but adapting the design to LIME's physical-keyboard candidate model.

This order preserves LIME's current lifecycle coverage first, removes the largest measured optional component cost, then reduces repeated smaller costs with conservative guards.

## Expected Result

The startup path should stop doing hidden optional work before the user sees the keyboard, without first changing callback routing.

Exact before/after callback-chain profile on Pixel 9 Pro API 36 emulator:

- Before profile source: `docs/STARTUP_PROFILING.md`.
- After profile source: temporary `LIME_STARTUP_PROFILE` logs, removed from source after capture.
- Runtime host: Chrome URL field, package `com.android.chrome`.
- Selected Android IME: `net.toload.main.hd2026/net.toload.main.hd.LIMEService`.
- LIME IM data installed through LIMESettings: `phonetic=34833`, `dayi=23117`.
- Cold run: Chrome and `net.toload.main.hd2026` force-stopped, then LimeIME re-selected and Chrome URL field focused.
- Warm run: same service process kept alive, keyboard hidden, Chrome URL field focused again.

| Real API call chain segment | Before cold-ish | Before warm | After cold `phonetic` | After warm `phonetic` | After cold `dayi` | After warm `dayi` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `LIMEService.onCreate()` | 115 ms | 54 ms | 159 ms | not called | 93 ms | not called |
| `onInitializeInterface()` | 485 ms | 195 ms | 94 ms | not called | 78 ms | not called |
| `onInitializeInterface()` -> `initialViewAndSwitcher(false)` | 483 ms | not captured | 92 ms | not called | 76 ms | not called |
| `onInitializeInterface()` -> `initialViewAndSwitcher(false)` -> `setupEmojiKeyboardView()` | 418 ms | 173 ms | 11 ms | not called | 14 ms | not called |
| `onInitializeInterface()` -> `...` -> guarded `renderEmojiContent()` | included in 418 ms | included in 173 ms | 0 ms | not called | 0 ms | not called |
| `onStartInput()` after service init | 18 ms | 28 ms | 48 ms | not called | 43 ms | not called |
| `onCreateInputView()` | 354 ms | 259 ms | 179 ms | not called | 132 ms | not called |
| `onCreateInputView()` -> `initialViewAndSwitcher(true)` | 351 ms | not captured | 134 ms | not called | 109 ms | not called |
| `onCreateInputView()` -> `initialViewAndSwitcher(true)` -> `setupEmojiKeyboardView()` | 345 ms | 246 ms | 28 ms | not called | 8 ms | not called |
| `onCreateInputView()` -> `...` -> guarded `renderEmojiContent()` | included in 345 ms | included in 246 ms | 0 ms | not called | 0 ms | not called |
| First visible `onStartInputView()` | 5 ms | 6 ms | 84 ms | 7 ms | 24 ms | 5 ms |
| Sum of top-level LIME callback durations | 977 ms | 542 ms | 560 ms | 7 ms | 370 ms | 5 ms |

Notes:

- The after cold totals are sums of callback durations, not wall-clock time between shell commands.
- `onCreate()` was triggered by `ime set`; `onCreateInputView()` and `onStartInputView()` were triggered later by focusing Chrome's URL field.
- Some Chrome/focus transitions emitted extra short `onStartInput()` callbacks. The table uses the service-init `onStartInput()` and the first visible `onStartInputView()` for the focused keyboard path.
- Full emoji page rendering is absent from startup. `setupEmojiKeyboardView()` now builds only the lightweight shell before first frame.
- The temporary timing logs were removed from `LIMEService.java` after profiling.

Implementation verification:

- Implemented lazy emoji content rendering.
- Implemented startup config snapshot/versioning in `LIMEService`, `LIMEPreferenceManager`, and the settings preference-change path.
- Implemented conservative navigation-bar theme caching.
- Added SearchServer emoji preload readiness guards.
- Focused startup instrumentation tests passed: emoji startup lazy-render, emoji first-open render, `onStartInput()` physical-key readiness, visible startup readiness, startup version bumping, unchanged snapshot query suppression, and IM picker selection.
- Full `./gradlew :app:connectedDebugAndroidTest` still failed with 5 existing/order-dependent `LIMEServiceTest` endkey failures; those failures are not startup-path failures.
- Android visual verification used real IM data installed through LIMESettings, not an empty DB or manually built DB.
- Visual evidence:
  - `.Codex/txt/limeime_visual_phonetic_after_startup_opt.png`
  - `.Codex/txt/limeime_visual_dayi_after_startup_opt.png`

Stretch target after the low-risk pass is proven: cold-ish visible startup max 300 ms, warm visible startup max 150 ms, and no startup segment over 100 ms unless it is required for the first visible keyboard or physical-keyboard candidate readiness.

The first keyboard frame should be a small, deterministic path:

1. Ensure minimal service/preferences/search handles.
2. Reuse or inflate the visible keyboard view once.
3. Apply active field mode.
4. Return the input view.
5. Defer everything else.

Emoji is the most obvious current offender, but the broader rule is stronger: every startup step must prove it is needed for the first visible keyboard or move out of the hot path.
