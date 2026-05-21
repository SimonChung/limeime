# Issue #63 - Google Voice Input Returns Simplified Chinese

**Status:** Closed by maintainer as upstream/vendor recognizer limitation after device validation
**Reported:** 2026-05-17
**Closed:** 2026-05-21
**Reporter:** andyhsieh009
**GitHub:** https://github.com/lime-ime/limeime/issues/63
**Scope:** Android voice input integration
**Reference:** [ANDROID_VOICE_INPUT.md](ANDROID_VOICE_INPUT.md)

---

## Problem

The reporter says that when LIME starts Google voice input and Google voice is
configured for Chinese Taiwan, recognized output is Simplified Chinese. The
reporter also says plateaukao's SweetLime does not show the same behavior.

Reported device:

- Xiaomi 14 Ultra
- Voice input provider: Google voice input
- Expected result: Traditional Chinese output
- Actual result: Simplified Chinese output

## Current Finding

SweetLime does not launch `RecognizerIntent` itself. It only switches from LIME
to a detected voice-capable IME. That keeps recognition, language choice, UI,
and commit behavior inside Google/vendor voice input.

Screenshot interpretation from the reporter-provided video:

1. LIME 6.1.5 reaches a Google recognizer UI that displays `中文 (台灣)`, but
   the recognized text can still be Simplified Chinese.
2. SweetLime reaches the older Google voice IME-style UI. It does not show the
   locale on that screen, but the committed output is Traditional Chinese.
3. The built-in keyboard/Gboard-style screenshot keeps dictation inside the
   keyboard surface and shows live composing text above the keys. That is a
   different integration model from launching Google's `RecognizerIntent`
   activity.

Current LIME has a broader fallback path:

1. Try known Google voice IME IDs.
2. If unavailable or switching fails, launch `RecognizerIntent` through
   `VoiceInputActivity`.

Before the Issue #63 hardening, the fallback path set
`RecognizerIntent.EXTRA_LANGUAGE` from the Android system locale and committed
returned text as-is. If the system locale was not `zh-TW`, this could conflict
with the user's Google voice language setting and produce Simplified Chinese.

After the first hardening, the fallback path forced `zh-TW` or `zh-HK` and can
apply Han conversion before commit. That improved the `RecognizerIntent` path,
but it did not make LIME enter SweetLime's older voice IME UI.

The current quick fix broadens LIME's switch targets before `RecognizerIntent`:
legacy Google voice IMEs, modern Google Speech Services/TTS voice IME, voice
subtypes, heuristic `voice`/`speech` IDs, and Gboard as the last fallback.

## Root Cause Conclusion

The remaining behavior is best treated as an upstream/vendor recognizer
limitation on the reporter's Xiaomi/Google setup, not as an actionable
LIME-side locale-selection bug. LIME-side fixes removed the obvious ambiguous
locale paths by forcing Traditional Chinese hints (`zh-TW` / `zh-HK`) and using
the existing Han conversion commit path where LIME receives text it can convert.

Reporter testing on 6.1.6 still produced Simplified Chinese even when LIME
requested Traditional Chinese and when microphone permission was both disabled
and enabled. That indicates the recognizer backend can return Simplified Chinese
despite LIME passing Traditional Chinese hints.

## Implementation Summary

See [ANDROID_VOICE_INPUT.md](ANDROID_VOICE_INPUT.md) for the full version cuts,
SweetLime comparison, and implementation details.

Implemented:

1. Keep legacy Google voice IMEs as direct switch targets.
2. Prefer voice IME switching for all supported Android versions.
3. Use `RecognizerIntent` fallback for modern Google Speech Services.
4. Resolve fallback language from system locale, but only return `zh-TW` or
   `zh-HK`; never return `zh-CN`.
5. Apply existing Han conversion to voice results when global conversion is
   enabled.
6. Add focused tests for the active language hint and modern Google voice IME
   detection.
7. Align the `VoiceInputActivity` emergency fallback with the same Traditional
   Chinese language resolver, so even a missing passed intent does not use a raw
   Simplified/ambiguous system locale.
8. Add Phase 1 LIME-owned inline dictation using `SpeechRecognizer`,
   `LIMEDictationController`, candidate-strip partial text, and the shared Han
   conversion commit path.
9. Keep voice routing automatic. Do not expose a user-facing voice mode
   preference; LIME should always choose inline dictation, delegated VoiceIME,
   or `RecognizerIntent` through the auto fallback order.
10. Add Setup tab microphone-permission guidance for inline dictation:
    green/red/yellow state text matching the LIME setup style, explanation text
    below the status row, explicit buttons, and Android app-info fallback when
    Android has hard-denied the runtime permission.

Reporter-device validation on 6.1.6 did not resolve the Simplified Chinese output, leading to maintainer closure as an upstream/vendor limitation.

## Why The LIME-Side Fixes Did Not Solve The Reporter Case

The LIME-side fixes hardened the fallback result path:

1. `LIMEService.getVoiceIntent()` resolves the fallback recognizer language to
   `zh-TW` or `zh-HK`, never `zh-CN`.
2. `VoiceInputActivity` uses the same resolver even if it has to create an
   emergency fallback intent.
3. Voice results can pass through LIME's existing Han converter before commit
   when the global conversion option is enabled.
4. Voice IME detection was broadened to include legacy Google voice IMEs, Google
   TTS/Speech Services voice IME, voice subtypes, `voice`/`speech` IDs, and
   Gboard as a fallback.

The reporter's 6.1.6 result shows that these mitigations were not enough on the
Xiaomi/Google recognizer path. The remaining gap is platform behavior: modern
Android/Google Speech Services may not expose or accept the legacy VoiceIME path
that SweetLime reaches, and the recognizer path can still return Simplified
Chinese despite LIME passing Traditional Chinese hints.

## Maintainer Conclusion (2026-05-21)

After reporter testing on 6.1.6, the issue was closed by maintainer `jrywu` as
an upstream/vendor recognizer limitation rather than an actionable LIME bug:

- The reporter clarified that SweetLime is the path producing normal
  Traditional Chinese output.
- LIME 6.1.6 still produced Simplified Chinese with LIME microphone permission
  both disabled and enabled.
- The maintainer observed that the Xiaomi/Google recognizer UI shows LIME
  passing `zh-TW` / Chinese (Taiwan), but the recognizer still returns
  Simplified Chinese.
- SweetLime reaches the older legacy voice IME path; LIME 6 targets newer
  Android API levels where that legacy UI is no longer available to invoke in
  the same way, so LIME falls back to the recognizer/inline dictation paths.

Future follow-up should only reopen or resume active watch if the reporter adds
new device evidence, a vendor/Google workaround is found, or a new LIME-side
voice integration approach becomes available.

## Inline Dictation Feasibility And Status

Gboard-style dictation inside the soft keyboard is possible in principle, but
not by asking Google's `RecognizerIntent` dialog to embed inside LIME. There
are two distinct choices:

1. Keep using Google/vendor voice input as another IME or activity. This is
   simpler and preserves Google's UI/language behavior, but LIME cannot show
   live composing text inside its own keyboard.
2. Build a LIME-owned dictation mode using `SpeechRecognizer` (or a custom
   recognition provider). LIME would request microphone permission, run
   recognition while its keyboard view stays visible, display partial results
   in the composing/candidate area, and commit final recognized text through
   the current `InputConnection`.

The second option is the path to the third screenshot's behavior. Phase 1 is
implemented in source: LIME can route to inline dictation when microphone
permission is granted, keep the keyboard visible, show listening/partial/error
status in the candidate strip, and commit final text through the same
Traditional-first Han conversion path. The reporter's 6.1.6 test with
microphone permission enabled is a negative real-device data point for this
approach on the Xiaomi/Google recognizer backend.

## Verification / Follow-up Status

Reporter validation on 6.1.6 is complete enough for the current conclusion:
LIME still receives Simplified Chinese from the Xiaomi/Google recognizer path
even when LIME passes Traditional Chinese hints. No additional routine retest or
evidence request is pending.

If this issue is revisited, ask for only new information that could change the
upstream/vendor-limitation conclusion, such as a Xiaomi/Google Speech Services
update that changes recognizer behavior, a device where a modern callable
VoiceIME path is available, or a concrete LIME-side API/workaround.

## Suggested Classification

Closed by maintainer as upstream/vendor recognizer limitation after LIME-side
mitigations and reporter validation. Keep historical `bug` label only if the
project wants to preserve the original triage label; otherwise an
`upstream limitation` / vendor-limitation classification is more accurate.
