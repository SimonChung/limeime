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

Current LIME has a broader fallback path:

1. Try known Google voice IME IDs.
2. If unavailable or switching fails, launch `RecognizerIntent` through
   `VoiceInputActivity`.

The fallback path sets `RecognizerIntent.EXTRA_LANGUAGE` from the Android system
locale and commits returned text as-is. If the system locale is not `zh-TW`,
this can conflict with the user's Google voice language setting and produce
Simplified Chinese.

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

Still needs device validation on the reporter-like setup.

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
