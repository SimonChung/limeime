# Android Voice Input

This note documents how Android voice input should work in LIME, why Issue #63
can happen, and what to implement next.

## Voice Input Mechanisms

Android has several speech or voice-input mechanisms. For a keyboard IME like
LIME, the first two are the important ones.

| Mechanism | Android API | Use in LIME |
| --- | ---: | --- |
| Voice IME switching | API 3+ | Delegated fallback. Switch from LIME to an enabled voice-capable IME. |
| `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` | API 3+ | Fallback. Launch a speech recognition activity and commit the returned text. |
| `SpeechRecognizer` / `RecognitionService` | API 8+ | LIME inline dictation path when enabled and `RECORD_AUDIO` is granted. |
| `VoiceInteractionService` | API 21+ | Assistant/hotword framework; not normal keyboard dictation. |

LIME always uses automatic routing; there is no user-facing voice mode
preference. The order is now:

1. Use LIME-owned inline dictation when enabled, permitted, and available.
2. Find an enabled voice-capable IME and switch to it with
   `InputMethodService.switchInputMethod(...)`.
3. Use `RecognizerIntent` only if no suitable voice IME exists or switching
   fails.

## Version Cuts

| Android API | Change |
| ---: | --- |
| 3 | `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` and `InputMethodService.switchInputMethod(String)` exist. |
| 8 | `SpeechRecognizer` / `RecognitionService` exist. |
| 11 | `InputMethodSubtype.getMode()` exists, so voice subtype detection such as `mode == "voice"` is possible. |
| 28 | `InputMethodManager.setInputMethod(...)` is deprecated for IME developers. Use `InputMethodService.switchInputMethod(...)`. |
| 30 | Apps targeting Android 11 need `<queries>` visibility for `android.speech.RecognitionService` when using `SpeechRecognizer`. |
| 31 | On-device `SpeechRecognizer.createOnDeviceSpeechRecognizer(...)` exists. |
| 35 | Background activity launch and `PendingIntent` rules are tighter, but this does not make `RecognizerIntent` the preferred default over voice IME switching. |

## Current LIME Behavior

`LIMEService.startVoiceInput()` currently has two paths:

1. If `LIMEUtilities.isVoiceSearchServiceExist(...)` returns a known Google
   voice IME ID, LIME calls `switchInputMethod(voiceID)`.
2. If no voice IME is found, or the switch path falls back, LIME launches
   `RecognizerIntent` through `VoiceInputActivity`.

The fallback `RecognizerIntent` path sets `RecognizerIntent.EXTRA_LANGUAGE`
from the Android system locale:

- `LIMEService.getVoiceIntent()` reads the first resource configuration locale.
- It passes that locale tag as `RecognizerIntent.EXTRA_LANGUAGE`.
- `VoiceInputActivity` launches the provided recognizer intent.
- The first returned recognition result is committed directly.

Voice-recognized text is currently committed as-is. The existing Han converter
is used for normal candidate commits, but not for voice result commits.

## SweetLime Comparison

`plateaukao/sweetlime` keeps voice input on the voice IME path. Its
`LIMEService.startVoiceInput()` only does:

```java
String voiceID = LIMEUtilities.isVoiceSearchServiceExist(getBaseContext());
if (voiceID != null)
    this.switchInputMethod(voiceID);
```

SweetLime does not launch `RecognizerIntent` from LIME itself, so Google or the
vendor voice IME owns recognition, language selection, UI, and text commit.
This is likely why a reporter can see better Traditional Chinese behavior in
SweetLime: the Google voice language setting is more likely to be honored when
Google's voice IME owns the whole flow.

SweetLime also has broader voice IME detection:

- `com.google.android.voicesearch/.ime.VoiceInputMethodService`
- `com.google.android.googlequicksearchbox/com.google.android.voicesearch.ime.VoiceInputMethodService`
- `com.google.android.tts/com.google.android.apps.speech.tts.googletts.settings.asr.voiceime.VoiceInputMethodService`
- any enabled IME subtype whose mode is `voice`
- enabled IME IDs containing `voice` or `speech`
- Gboard fallback via `com.google.android.inputmethod.latin/`

The Google TTS voice IME ID was added in SweetLime commit `66d06ba` for Android
13 voice input compatibility. The subtype/heuristic/Gboard fallback was added
in commit `e30e1db`.

LIME now follows the SweetLime-style quick fix and tries broader enabled voice
IME targets before `RecognizerIntent`. The order is:

1. Exact known voice IME IDs, including legacy Google Voice Search and modern
   Google TTS/Speech Services voice IME.
2. Enabled IMEs with a subtype whose mode is `voice`.
3. Enabled IME IDs containing `voice` or `speech`.
4. Gboard (`com.google.android.inputmethod.latin/`) as the last fallback.

This can reach the older voice IME UI shown in the reporter's SweetLime video
on devices where that switch target is usable. If Android accepts the target
but the switch does not actually happen, LIME still falls back to
`RecognizerIntent`.

## Issue #63 Risk

Issue #63 reports that Google voice input is configured for Chinese Taiwan, but
LIME receives Simplified Chinese output.

The most likely failure mode is:

1. LIME falls back to `RecognizerIntent` on modern Google Speech Services.
2. `RecognizerIntent.EXTRA_LANGUAGE` must be a Traditional Chinese locale.
3. Google recognition may return Simplified Chinese if the fallback language is
   ambiguous or Simplified Chinese.
4. LIME commits the returned text, optionally applying Han conversion first if
   the global Han conversion option is enabled.

The voice IME path can still return Simplified Chinese if Google chooses it, but
LIME has less direct control there. The fallback `RecognizerIntent` path is the
path where LIME is explicitly passing a language hint and committing the result.

## Implementation Status

Implemented in the current Android branch:

1. Legacy Google voice IMEs, modern Google Speech Services/TTS voice IME,
   voice subtypes, voice/speech ID heuristics, and Gboard fallback are switch
   targets through `LIMEUtilities.isVoiceSearchServiceExist(...)`.
2. Voice IME switching remains the first path for all Android versions.
3. `startVoiceInput()` now reaches the `RecognizerIntent` fallback when no voice
   IME is found, the input method manager is unavailable, or switching throws.
4. The fallback `RecognizerIntent` language comes from the system locale only
   when it is explicitly `zh-TW` or `zh-HK`.
5. Non-Chinese locales, ambiguous Chinese locales such as script-only
   `zh-Hans`, and Simplified Chinese locales fall back to `zh-TW`. LIME never
   chooses `zh-CN` for voice recognition.
6. Voice result commits now pass through the existing Han converter when the
   global Han conversion option is enabled.
7. Focused instrumentation tests cover Traditional Chinese fallback language and
   confirm modern Google Speech Services/Gboard-style voice targets are
   detected.

Still useful for device validation:

1. Capture diagnostics around voice input:
   - returned `voiceID`
   - current default IME before and after switching
   - active LIME IM / table
   - `RecognizerIntent.EXTRA_LANGUAGE`
   - recognizer component
   - returned voice text before commit
2. Verify voice result conversion with actual Google voice output.
3. Confirm no behavior change for normal candidate commits.

## Emulator Validation

On the Android Studio emulator, microphone capture may fail or provide no usable
audio. In that case Google's recognizer can show:

```text
Didn't catch that. Try speaking again.
```

This is normal emulator behavior and does not by itself mean LIME's microphone
button is broken.

The important visual verification signal is that tapping LIME's microphone icon
opens Google's recognizer dialog and the dialog shows:

```text
Chinese (Taiwan)
```

That confirms LIME reached the `RecognizerIntent` fallback and passed the
Traditional Chinese Taiwan language hint. If tapping the microphone produces no
Google dialog, no `startVoiceInput()` log, and no IME/recognizer activity, then
the bug is in LIME's microphone click path rather than in Google voice
recognition.

## Verification Matrix

Test these combinations:

| System locale | Google voice language | Expected |
| --- | --- | --- |
| `zh-TW` | Chinese Taiwan | Traditional Chinese |
| English | Chinese Taiwan | Traditional Chinese when voice IME path is used or fallback language is `zh-TW` |
| `zh-CN` | Chinese Taiwan | Traditional Chinese; fallback language must be `zh-TW` |
| English | English | English output remains unaffected |

Also verify:

- which path is active: voice IME switch or `RecognizerIntent` fallback
- fallback result delivery through `VoiceInputActivity`
- retry/pending voice commit behavior
- optional Han conversion does not affect non-voice typing paths

## Inline Dictation Permission Fallback

The LIME-owned inline dictation mode requires Android microphone
permission because it uses `SpeechRecognizer` directly. If the user does not
grant that permission, LIME should not treat voice input as unavailable.

Implemented fallback order:

1. Use LIME inline dictation only when enabled and microphone permission is
   granted.
2. If permission is denied or inline dictation is disabled, switch to a
   Google/vendor voice IME when available.
3. If no usable voice IME switch target exists, use the current
   `RecognizerIntent` fallback with the Traditional Chinese language hint and
   Han conversion.

This gives privacy-conscious users a path where LIME does not receive direct
microphone permission and Google/vendor voice input owns audio capture.
