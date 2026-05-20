# Android LIME Dictation

**Status:** Phase 1 implemented; pending Phase 2 device verification
**Scope:** LIME-owned inline dictation for Android IME
**Related:** [ANDROID_VOICE_INPUT.md](ANDROID_VOICE_INPUT.md), [#63_ISSUE.md](#63_ISSUE.md)

---

## Goal

Build a LIME-owned dictation mode that keeps the keyboard visible while speech
recognition runs, similar to the built-in keyboard/Gboard-style flow shown in
Issue #63.

This is separate from the quick voice IME fix. The quick fix still delegates to
Google/vendor voice input. This feature makes LIME own the dictation UI,
recognizer lifecycle, partial composing text, final commit, and Traditional
Chinese post-processing.

## Current Voice Stack

LIME currently has two voice paths:

1. Voice IME switching: preferred quick path. LIME switches to an enabled
   voice-capable IME and lets Google/vendor code handle recognition and commit.
2. `RecognizerIntent`: fallback path. LIME launches Google's recognizer
   activity, receives final text, applies optional Han conversion, and commits.

Neither path can show live speech text inside LIME's own keyboard surface.

## Delegated VoiceIME Detection And Fallback

The current quick fix keeps Google/vendor voice input as the preferred
delegated path before `RecognizerIntent`. Future inline dictation must preserve
this behavior as the fallback when LIME dictation is disabled, unavailable, or
not permitted.

Detection entry point:

- `LIMEUtilities.isVoiceSearchServiceExist(context)` returns a switch target
  from Android's enabled input method list.
- `LIMEService.startVoiceInput()` calls this before launching
  `RecognizerIntent`.

Detection order:

1. Exact known voice IME IDs:
   - `com.google.android.voicesearch/.ime.VoiceInputMethodService`
   - `com.google.android.googlequicksearchbox/com.google.android.voicesearch.ime.VoiceInputMethodService`
   - `com.google.android.tts/com.google.android.apps.speech.tts.googletts.settings.asr.voiceime.VoiceInputMethodService`
2. First enabled IME with an `InputMethodSubtype` whose mode is `voice`.
3. First enabled IME whose ID contains `voice` or `speech`.
4. Gboard fallback: first enabled IME whose ID starts with
   `com.google.android.inputmethod.latin/`.
5. If none are found, return `null`.

Selection rules:

- Prefer exact known voice IME IDs over heuristics.
- Prefer voice subtypes over string heuristics.
- Prefer explicit `voice`/`speech` IDs over Gboard.
- Use Gboard only as the last delegated voice-capable IME fallback.

Switch-and-verify flow:

1. Build a Traditional-first fallback `RecognizerIntent`.
2. Resolve `voiceID` with `LIMEUtilities.isVoiceSearchServiceExist(...)`.
3. If `voiceID` exists, call `InputMethodService.switchInputMethod(voiceID)`.
4. After a short delay, read `Settings.Secure.DEFAULT_INPUT_METHOD`.
5. If the current IME equals `voiceID`, mark voice input active and monitor IME
   changes so LIME can switch back afterward.
6. If the current IME does not equal `voiceID`, stop monitoring and launch the
   `RecognizerIntent` fallback.
7. If switching throws, if `InputMethodManager` is unavailable, or if no
   `voiceID` exists, launch the `RecognizerIntent` fallback.

Recognizer fallback rules:

- Use `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`.
- Use `LANGUAGE_MODEL_FREE_FORM`.
- Set `RecognizerIntent.EXTRA_LANGUAGE` with LIME's Traditional-first resolver:
  `zh-TW` by default, `zh-HK` for Hong Kong/Macau, never `zh-CN`.
- Deliver results through `VoiceInputActivity`.
- Apply existing Han conversion before commit when the global conversion option
  is enabled.
- If `InputConnection` is null, use the pending voice text retry path.

Future inline dictation priority:

1. Try LIME inline dictation only when enabled and `RECORD_AUDIO` permission is
   granted.
2. If permission is denied, unavailable, or inline dictation is disabled, use the
   delegated VoiceIME detection and switch flow above.
3. If delegated VoiceIME is absent or switching fails, use the
   `RecognizerIntent` fallback above.

## Implemented Phase 1 Pipeline

1. User taps the LIME microphone key.
2. `LIMEService` asks `LIMEVoiceInputRouter` for a route from feature flag,
   user mode, permission state, inline recognizer availability, VoiceIME
   availability, and `RecognizerIntent` availability.
3. In `AUTO`, LIME inline dictation runs only when `RECORD_AUDIO` is granted
   and a direct recognizer is available.
4. If inline dictation is unavailable or permission is denied, LIME delegates
   to VoiceIME switching, then to `RecognizerIntent`.
5. Inline dictation uses `LIMEDictationController` and
   `AndroidSpeechRecognizerAdapter` around Android `SpeechRecognizer`.
6. Partial recognition results appear in the candidate strip.
7. Final recognition result is optionally Han-converted through the existing
   voice commit path.
8. LIME commits final text through the current `InputConnection`, with pending
   retry behavior when the connection is temporarily null.

## Architecture

Implemented components:

- `LIMEDictationController`: owns `SpeechRecognizer`, state transitions,
  timeout, retry, cancellation, and final result delivery.
- `DictationState`: enum for idle/listening/partial/finalizing/error/cancelled.
- `SpeechRecognizerAdapter` and `AndroidSpeechRecognizerAdapter`: testable seam
  over Android recognition.
- `LIMEVoiceInputRouter`: pure routing model for inline, VoiceIME,
  `RecognizerIntent`, or unavailable.
- `CandidateView`: renders listening, partial, finalizing, and error text.
- `LIMEService`: bridges microphone key events, permission status,
  `InputConnection`, Han conversion, and preference lookup.

Keep the controller independent from keyboard drawing as much as practical, so
recognizer lifecycle tests can run without a full IME UI.

## Language And Conversion

Use the same Traditional-first resolver as the fallback voice path:

- `zh-TW` for Taiwan, non-Chinese, ambiguous Chinese, and Simplified Chinese
  system locales.
- `zh-HK` for Hong Kong or Macau locales.
- Never request `zh-CN` from LIME-owned dictation.

Before commit:

1. Trim empty or duplicate final results.
2. Apply existing Han conversion when the global conversion option is enabled.
3. Commit through `InputConnection.commitText(...)`.
4. If `InputConnection` is temporarily null, reuse the pending voice text retry
   pattern from the current `RecognizerIntent` path.

## Permission UX

Android requires `RECORD_AUDIO` for direct `SpeechRecognizer` use.

Planned behavior:

1. If permission is granted, start inline dictation immediately.
2. If permission is missing and the settings activity is available, ask through
   a clear runtime permission flow.
3. If permission is denied, keep the keyboard usable and fall back to
   Google/vendor voice IME switching.
4. If no usable voice IME switch target exists, fall back to
   `RecognizerIntent`.
5. If the user permanently denies permission, offer a path to app settings but
   keep the Google/vendor fallback paths available.

Do not silently fall back to always-on recording behavior. Dictation should only
listen while the user has explicitly started it.

This also supports privacy-conscious users. Some users may prefer not to grant
microphone permission to LIME and may prefer Google's own voice service to own
audio capture. In that case, LIME should respect the denial and route the
microphone key to the existing delegated voice paths instead of treating denial
as a hard failure.

## Setup Tab Permission Step

If LIME-owned inline dictation ships, add an optional recording-permission step
to the Settings app Setup tab. The current setup flow already teaches users how
to enable LIME and grant keyboard access. Dictation should fit into that same
first-run checklist rather than surprising users from inside the keyboard.

Proposed Setup tab row:

| Step | Icon | Label | Action |
| --- | --- | --- | --- |
| 4 | microphone | 允許語音輸入 | Request Android `RECORD_AUDIO` permission for LIME inline dictation |

Behavior:

1. Show this row only when LIME inline dictation is available or the feature
   flag is enabled.
2. Display status as granted, not granted, or permanently denied.
3. If not granted, tapping the row launches the runtime permission request from
   the Settings app.
4. If permanently denied, tapping the row opens the app's Android system
   settings page.
5. Make the row explicitly optional: users can still use Google/vendor voice
   IME fallback without granting microphone permission to LIME.

Suggested copy:

- Title: `允許語音輸入`
- Granted detail: `可使用萊姆內建語音輸入`
- Not granted detail: `可略過，仍可使用 Google 語音輸入`
- Denied detail: `已拒絕；可至系統設定重新開啟`

This is a privacy-sensitive permission. The Setup tab should explain that
granting microphone permission enables LIME's own inline dictation, while
denying it keeps delegated Google/vendor voice input available.

If we decide to proceed, add the following explicit block to
[LIME_SETTINGS.md](LIME_SETTINGS.md) under `## 4. Feature: App Setup (設定 Tab)`.

```markdown
### 4.x Optional Voice Input Permission

When Android LIME inline dictation is enabled, the Setup tab includes an
optional fourth setup step for microphone permission. This step is only for
LIME-owned inline dictation. Users who do not grant microphone permission can
still use Google/vendor VoiceIME fallback, then `RecognizerIntent` fallback.

| Step | Icon | Label | Status detail | Action |
|---:|---|---|---|---|
| 4 | `mic` / `keyboard_voice` | `允許語音輸入` | `可略過，仍可使用 Google 語音輸入` | Request Android `RECORD_AUDIO` permission |

State-specific detail text:

| Permission state | Detail text | Tap behavior |
|---|---|---|
| Granted | `可使用萊姆內建語音輸入` | No-op or show short confirmation |
| Not granted, can ask | `可略過，仍可使用 Google 語音輸入` | Request `RECORD_AUDIO` once from the Settings app |
| Denied once | `已略過；將使用 Google 語音輸入` | Use delegated voice fallback; do not repeatedly prompt |
| Permanently denied | `已拒絕；可至系統設定重新開啟` | Open Android app system settings |

Runtime rules:

1. Show the row only when the LIME inline dictation feature flag is enabled.
2. Poll permission state when the Setup tab resumes, matching the existing
   keyboard-enabled/full-access status refresh pattern.
3. The microphone key should not nag on every tap. If the user denies
   permission once, route future mic taps to VoiceIME first, then
   `RecognizerIntent`.
4. The row must describe microphone permission as optional because Google/vendor
   voice input remains available without granting direct microphone access to
   LIME.
```

Also update the App Setup checklist in [LIME_SETTINGS.md](LIME_SETTINGS.md):

```markdown
- [ ] Optional `RECORD_AUDIO` setup step for LIME inline dictation, hidden when
      inline dictation is disabled; denial falls back to Google/vendor VoiceIME.
```

## Recognition API Notes

Use Android `SpeechRecognizer` first:

- `SpeechRecognizer.createSpeechRecognizer(context)` for general recognition.
- `RecognizerIntent.EXTRA_LANGUAGE_MODEL =
  RecognizerIntent.LANGUAGE_MODEL_FREE_FORM`.
- `RecognizerIntent.EXTRA_LANGUAGE` from LIME's Traditional-first resolver.
- Enable partial results with `RecognizerIntent.EXTRA_PARTIAL_RESULTS`.

Consider on-device recognition later:

- `SpeechRecognizer.createOnDeviceSpeechRecognizer(...)` is API 31+.
- Availability varies by device/language pack.
- It should be optional, not required for the first feature cut.

## State Model

Minimum states:

- `Idle`: normal keyboard.
- `Listening`: microphone active, no text yet.
- `Partial`: microphone active, partial text visible.
- `Finalizing`: final result received, preparing commit.
- `Error`: recoverable recognizer failure.
- `Cancelled`: user stopped or dismissed dictation.

Minimum actions:

- Start dictation.
- Stop and commit final result.
- Cancel without commit.
- Retry after no-speech or recognizer-busy errors.
- Return to voice IME / `RecognizerIntent` fallback if direct recognition is
  unavailable.

## UI Plan

Use the existing keyboard surface rather than launching a separate activity:

1. Replace or overlay the candidate strip with listening state and partial text.
2. Keep a stop/cancel control reachable near the microphone area.
3. Keep keys visible unless a compact dictation panel is needed.
4. Avoid blocking text field focus.
5. Preserve theme colors and dark/light navigation bar behavior.

The first version can be minimal: candidate strip status plus partial text. A
full Gboard-like animated dictation surface can come after the lifecycle is
stable.

## Fallback Strategy

Inline dictation should not remove existing voice input paths.

Recommended priority after this feature exists:

1. LIME inline dictation when enabled and microphone permission is granted.
2. If LIME inline dictation is disabled, unavailable, or microphone permission
   is denied, use voice IME switching when a known/suitable enabled voice IME
   exists.
3. `RecognizerIntent` fallback with Traditional language hint and Han
   conversion.

Voice routing must stay automatic. Do not expose a user-facing mode preference;
LIME chooses inline dictation, delegated VoiceIME, or Google recognizer fallback
through the auto route order.

Implemented Setup tab permission row:

- `voicePermissionCard` in `fragment_setup.xml`
- Requests `RECORD_AUDIO` from the Settings tab.
- Opens Android app settings if permanently denied.
- Stays optional; denial routes microphone taps to VoiceIME first, then
  `RecognizerIntent`.

## Test Plan

Unit or instrumentation tests:

- Language resolver never returns `zh-CN`.
- Dictation state transitions for start, partial, final, cancel, and error.
- Final text passes through Han conversion when enabled.
- Pending commit handles null `InputConnection`.
- Existing voice IME and `RecognizerIntent` paths remain available.

Device validation:

- Android 13, 14, 15, and 16 if available.
- Google Speech Services installed and disabled.
- Gboard installed and absent.
- System locale English, `zh-TW`, and `zh-CN`.
- Google voice language set to Chinese Taiwan.
- Long dictation, no-speech timeout, cancel, screen rotation, and app switch.

## Delivery Status

Phase 1 implemented:

1. Broadened VoiceIME detection and switch fallback protection.
2. Voice routing model and preference modes.
3. `RECORD_AUDIO` permission helper, manifest permission, and Setup tab row.
4. `SpeechRecognizer` adapter and `LIMEDictationController`.
5. `LIMEService` inline dictation integration.
6. Candidate strip listening/partial/error UI.
7. Shared final commit path with Han conversion and pending retry.
8. Automated compile gates for main and androidTest sources.

Phase 2 remains:

1. Device verification across Android versions and Google Speech/Gboard states.
2. Human validation for permission denied/granted/permanently denied paths.
3. Long dictation, no-speech timeout, focus loss, and Traditional Chinese
   output validation.

## Open Questions

- Should inline dictation be default once stable, or opt-in for one release?
- Should partial text be committed as composing text or only shown in the
  candidate strip until final?
- Which recognizer errors should fall back to voice IME automatically?
- Should on-device recognition be exposed as a separate preference?
