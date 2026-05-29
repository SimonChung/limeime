# Issue #99: Android caps-lock state changes phonetic candidate matching

## Problem statement

Community reporter `kenny72014a` reports that when Android LIME's 注音 keyboard is in caps-lock / shifted state, the same intended phonetic input can produce different composing codes and candidates than the normal lowercase state. The reporter's example is typing `測試`: lowercase state produces the expected candidate, while caps-lock state leaves an uppercase/symbol composing string and the candidate list no longer matches the intended phrase.

Issue: https://github.com/lime-ime/limeime/issues/99

## Reported reproduction

1. Use the Android 注音 keyboard.
2. Type the key sequence for `測試` in normal lowercase keyboard state.
3. Observe that the candidate list includes `測試` as the highlighted candidate.
4. Enable caps lock / shifted keyboard state, then type the same intended 注音 sequence.
5. Observe that the composing text and candidate list change; the reporter's screenshot shows a composing string like `HK$G` and candidates such as `次`, `此`, `差`, `測`, `詞` instead of directly matching `測試`.

The reporter notes a common mixed-language workflow: after typing uppercase English, they may continue typing Chinese, but the caps-lock state can keep affecting Chinese input and make the desired Chinese candidates unavailable.

## Evidence summary

The issue includes two screenshots:

- Normal/lowercase state: composing string `hk4g` with the candidate list highlighting `測試`.
- Caps-lock/shifted state: keyboard letter labels are uppercase/symbol-shifted, composing string becomes `HK$G`, and the candidate list no longer highlights `測試`.

## Current classification

Plausible Android bug in Chinese IM key normalization while caps lock / shifted keyboard state is active.

For Chinese input methods such as 注音, the candidate lookup should normally treat Latin key labels as input-method codes rather than English text case. A caps-lock state that is useful for English typing should not make the same 注音 key positions query a different uppercase/symbol code unless a specific table intentionally distinguishes those codes.

## Relevant code observed

Android soft-key handling in `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`:

- `onKey(...)` adjusts `primaryCode` to uppercase whenever `mCapsLock` is true:
  - lines around `2002-2008`: if `mCapsLock` and `primaryCode` is `a-z`, it subtracts 32 before later dispatch.
- Chinese-mode `handleCharacter(...)` appends the resulting `primaryCode` directly into `mComposing` for valid letters / symbols / digits:
  - lines around `4892-4964`: in `!mEnglishOnly`, matching branches call `mComposing.append((char) primaryCode)` and then `updateCandidates()`.
- Candidate lookup uses `mComposing.toString()` directly:
  - `updateCandidates(...)` builds `keyString = mComposing.toString()` and calls `SearchSrv.getMappingByCode(finalKeyString, ...)`.
- `handleShift()` / `toggleCapsLock()` can apply the shifted/caps-locked visual state even when the current keyboard is an IM keyboard, not only English alphabet mode.

These paths plausibly explain the screenshot through two related mechanisms:

1. The `mCapsLock` branch can convert lowercase letters such as `h`, `k`, and `g` into `H`, `K`, and `G` before Chinese composing-code handling.
2. The shifted soft-keyboard layout/state can emit a shifted symbol primary code for number-row keys, such as `4` becoming `$`. This is not explained by the `mCapsLock` `a-z` conversion alone and must be checked in the keyboard XML / `LIMEKeyboardSwitcher` shifted-state path.

Together, Chinese candidate lookup can receive `HK$G` instead of the lowercase 注音 code sequence that maps to `測試`.

## Existing test coverage assessment

Relevant Android instrumentation tests exist for broad IME service behavior (`LIMEServiceTest`, `LIMEServiceWithStubActivityTest`), keyboard-switcher policy (`LIMEKeyboardSwitcherPolicyTest`), candidate rendering (`CandidateViewTest`), and search/database behavior (`SearchServerTest`, `LimeDBTest`).

No existing test was found that specifically verifies Chinese-mode key normalization under caps-lock / shifted keyboard state, or that 注音 candidate lookup is invariant when the user returns from uppercase English typing to Chinese input.

## Code fragility assessment

The suspected path is fragile because the same `primaryCode` variable is shared between English text entry, Chinese IM composing-code entry, physical-keyboard selection handling, and shifted/caps-lock visual state. The current early uppercase conversion in `onKey(...)` is broad and happens before `handleCharacter(...)` knows whether the key will be committed as English text or used as a Chinese IM code.

A safe fix likely needs to avoid changing Chinese IM composing codes to uppercase/symbol forms while preserving intended uppercase behavior in English-only mode and any table IM that intentionally supports case-sensitive or symbol roots.

## Suspected root cause

Likely root cause: caps-lock / shifted state is being applied to `primaryCode` before Chinese-mode composing-code handling. For letters, the broad `mCapsLock` conversion in `onKey(...)` can turn `a-z` into `A-Z`; for number-row keys, the shifted keyboard state can emit symbols such as `$`. `handleCharacter(...)` then records those shifted characters in `mComposing`, so 注音 lookup queries a different code string from the normal lowercase path.

This should remain a hypothesis until reproduced in a local Android IME test or device/emulator run.

## Proposed solution / implementation plan

1. Add a focused Android regression test for Chinese-mode key handling:
   - activate 注音 / IM mode;
   - simulate the key sequence that should produce `測試`;
   - verify the composing code / candidate query path stays normalized when caps lock or shifted visual state is active.
2. In `LIMEService.onKey(...)` / `handleCharacter(...)`, separate English text casing from Chinese IM code lookup:
   - keep uppercase transformation for English-only commit paths;
   - normalize alphabetic `primaryCode` to the table's expected code case before appending to `mComposing` in Chinese IM mode, at least for 注音 and other case-insensitive table codes.
3. Verify that physical keyboard caps-lock behavior still works for English typing and does not break selection-key handling when candidates are shown.
4. Keep symbol/root-sensitive table IM behavior in mind before globally lowercasing every shifted character.

## Follow-up questions

The current screenshots are sufficient to start investigation. If reproduction is inconsistent, ask the reporter for:

- Android APK version used for the screenshots;
- whether the caps-lock state was triggered from the LIME soft-keyboard Shift key or a physical keyboard / hardware caps lock;
- the exact key sequence used after returning from uppercase English typing to 注音 input.

## Platform impact analysis

### Confirmed reporter platform behavior

Android soft keyboard / 注音 is affected according to the screenshots.

### Android impact

Plausible Android bug. The likely code path is Android-specific (`LIMEService`, `LIMEKeyboardSwitcher`, and Android keyboard XML/key codes).

### iOS impact

No iOS impact is confirmed from this report. iOS has a separate keyboard implementation, so the Android `LIMEService` caps-lock path does not directly apply. A minimal iOS parity check should still verify that iOS 注音 input ignores English caps-lock/shift state when composing Chinese codes.

## Verification plan

- Android regression test for 注音 input code normalization with caps-lock / shifted keyboard state.
- Manual Android verification:
  - normal 注音 key sequence for `測試` highlights `測試`;
  - same key sequence after enabling caps lock still highlights `測試`;
  - switching to English mode still allows uppercase English input when caps lock is active;
  - physical keyboard caps-lock behavior remains acceptable.
- Ask the reporter to retest only after a newer Android APK contains a targeted caps-lock/Chinese-code normalization fix.
