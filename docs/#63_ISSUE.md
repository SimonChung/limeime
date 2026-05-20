# Issue #63 - Google Voice Input Returns Simplified Chinese

**Status:** Implemented; device validation pending
**Date:** 2026-05-18
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

## Likely Root Cause

The likely root cause is not that `RecognizerIntent` must be used from a modern
Android version onward. The preferred IME behavior is still to switch to an
enabled voice IME first.

The likely root cause is:

1. LIME falls back to `RecognizerIntent` with modern Google Speech Services.
2. The fallback must avoid ambiguous or Simplified Chinese locale hints.
3. LIME commits the recognized text without Simplified-to-Traditional
   normalization.

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

Still needs device validation on the reporter-like setup.

## Why the Last Fix May Not Solve the Video Case

The last fix hardened LIME's fallback result path:

1. `LIMEService.getVoiceIntent()` now resolves the fallback recognizer language
   to `zh-TW` or `zh-HK`, never `zh-CN`.
2. `VoiceInputActivity` now uses the same resolver even if it has to create an
   emergency fallback intent.
3. Voice results can pass through LIME's existing Han converter before commit
   when the global conversion option is enabled.

That first fix did not broaden voice IME detection. SweetLime detects more
switch targets, including the Google TTS/Speech Services voice IME, any enabled
IME subtype whose mode is `voice`, enabled IME IDs containing `voice` or
`speech`, and Gboard as a fallback.

LIME now has a quick fix matching that broader detection strategy. The remaining
risk is platform behavior: switching to modern Google Speech Services or Gboard
can still be a no-op on some emulator/new Android builds. If Android accepts the
switch and the current IME changes, LIME reaches the voice IME path. If the
switch does not take, LIME falls back to `RecognizerIntent`.

So if the reporter's phone does not expose one of LIME's two legacy voice IME
IDs but does expose one of the broader SweetLime-style targets, the new quick
fix may reach the second screenshot path. If the target is absent or the switch
does not actually occur, LIME still reaches the first screenshot: Google's
recognizer activity with `中文 (台灣)`.

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
now implemented in source: LIME can route to inline dictation when microphone
permission is granted, keep the keyboard visible, show listening/partial/error
status in the candidate strip, and commit final text through the same
Traditional-first Han conversion path. Phase 2 still needs real-device
validation on the reporter-like Google voice setup.

## Verification Request For Reporter

Please help validate the two voice paths in this order:

1. **Without granting LIME microphone permission**, tap the microphone key and
   test the Google/vendor voice input path first. This should keep LIME out of
   direct audio capture and route through delegated VoiceIME when Android
   exposes a usable voice IME, otherwise through the Google recognizer fallback.
   Report whether the voice UI opens, whether LIME returns afterward, and
   whether the committed result is Traditional or Simplified Chinese.
2. **After that first test**, grant LIME microphone permission from the Setup
   tab and test LIME inline dictation. This should keep the LIME keyboard
   visible, show dictation status/partial text in the candidate strip, and
   commit final text through the Traditional-first conversion path.

For both tests, please include Android version, system language/locale, Google
voice language setting, and one example phrase with expected Traditional output
versus actual committed output.

## User Follow-up

Ask the reporter for:

- Android system language/locale
- Google voice input language setting screenshot
- LIME version tested
- whether 6.1.1 pre-release still reproduces the issue
- example phrase showing expected Traditional output and actual Simplified
  output

## Suggested Label

`bug`
