# Issue #63 - Google Voice Input Returns Simplified Chinese Despite zh-TW Setting

**Status:** Triage document created; follow-up investigation needed  
**Date:** 2026-05-18  
**Reporter:** andyhsieh009  
**GitHub:** https://github.com/lime-ime/limeime/issues/63  
**Scope:** Android voice input integration

---

## Problem Statement

The reporter says that when LIME starts Google voice input and Google voice is configured for Chinese (Taiwan), the recognized output is Simplified Chinese. The reporter also says an older plateaukao build does not show the same behavior.

Reported device:

- Xiaomi 14 Ultra
- Voice input provider: Google voice input
- Expected result: Traditional Chinese output
- Actual result: Simplified Chinese output

This should be triaged as an Android voice-input compatibility bug until proven otherwise, because LIME owns the integration path that launches or switches to Google voice input and commits the returned text.

## Current Code Path

There are two possible voice-input paths in `LIMEService.startVoiceInput()`:

1. If a known Google voice IME is enabled, LIME tries to switch to that IME via `switchInputMethod(voiceID)`.
2. If switching is unavailable or fails, LIME launches `RecognizerIntent` through `VoiceInputActivity`.

The fallback `RecognizerIntent` path builds its language from the Android system locale:

- `LIMEService.getVoiceIntent()` reads `ConfigurationCompat.getLocales(getResources().getConfiguration()).get(0)`.
- It passes that value as `RecognizerIntent.EXTRA_LANGUAGE`.
- `VoiceInputActivity` launches the provided `RecognizerIntent` and returns the first recognized text result.
- LIME commits that result directly with `InputConnection.commitText(...)`.

There is no Traditional/Simplified post-processing step in the voice result path.

## Potential Root Causes

### RC1 - LIME uses system locale, not the user's Google voice language

The fallback `RecognizerIntent` path uses the Android system locale. If the phone system language is not exactly `zh-TW`, LIME may pass a language tag that makes Google recognition prefer Simplified Chinese, even when the user believes Google voice input is configured for Taiwan Chinese.

This is likely on devices where:

- system locale is `zh-CN`, `zh-Hans`, English, or another locale;
- Google voice settings are configured separately;
- the recognizer does not honor Google app UI settings when `EXTRA_LANGUAGE` is provided by the caller.

### RC2 - The Google voice IME path may bypass LIME language control

When LIME successfully switches to Google voice IME, the output is controlled by Google's IME/service. LIME currently does not pass an explicit Taiwan Traditional Chinese preference through that path. If Google's IME chooses Simplified Chinese, LIME only receives or observes the final text.

### RC3 - LIME commits recognized text without Traditional Chinese normalization

Both result paths eventually commit the recognized text as-is. If Google returns Simplified Chinese, LIME does not currently convert it to Traditional Chinese before committing.

This may explain why a different historical build appears better: the old behavior may have used a different language hint, a different Google voice path, or a Traditional conversion step.

## Proposed Solution

### Step 1 - Reproduce and log the active path

Add temporary diagnostics or use existing logs to confirm:

- whether the device uses the voice IME switch path or the `RecognizerIntent` fallback path;
- the exact `voiceID` returned by `LIMEUtilities.isVoiceSearchServiceExist(...)`;
- the exact language tag passed as `RecognizerIntent.EXTRA_LANGUAGE`;
- the returned recognized text before commit.

### Step 2 - Prefer an explicit Traditional Chinese voice language option

If fallback `RecognizerIntent` is used, consider choosing `zh-TW` when the active LIME input method is a Traditional Chinese table, or add a preference for voice recognition language.

Candidate behavior:

- default to current system locale for compatibility;
- allow explicit `zh-TW` / `zh-HK` / `zh-CN` selection;
- for Traditional Chinese IMs, optionally default voice recognition to `zh-TW`.

### Step 3 - Consider Traditional conversion after recognition

If Google still returns Simplified Chinese for `zh-TW`, consider applying LIME's Han converter to voice-recognized text before commit when the active IM is Traditional Chinese.

This should be guarded by a setting or narrowly scoped to voice input, because users may intentionally dictate Simplified Chinese text in some cases.

### Step 4 - Keep IME switching behavior separate from RecognizerIntent behavior

Do not assume the Google voice IME switch path and `RecognizerIntent` fallback path behave the same. They may require separate fixes or settings.

## Proposed User Follow-up

Ask the reporter to provide:

- Android system language/locale;
- Google voice input language setting screenshot;
- LIME version tested;
- whether 6.1.1 pre-release still reproduces the issue;
- a short example phrase showing expected Traditional output and actual Simplified output.

## Verification Plan

1. Test on a device/emulator with system locale set to `zh-TW`.
2. Test with system locale set to English but Google voice configured for Chinese (Taiwan).
3. Test with system locale set to Simplified Chinese.
4. Confirm which code path is used: Google voice IME switch or `RecognizerIntent` fallback.
5. Verify that the recognized text is Traditional Chinese when `zh-TW` is explicitly selected.
6. Verify that any optional Han conversion does not affect non-voice typing paths.
7. Verify that existing voice-input result delivery through `VoiceInputActivity` still commits text reliably.

## Suggested Label

`bug`
