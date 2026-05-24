# Android Manifest Permission Review

**Updated**: 2026-05-24  
**Project**: LimeIME  
**Target SDK**: 36 (Android 16)  
**Min SDK**: 21 (Android 5.0)

## Summary

This report reviews the permissions currently declared in
`LimeStudio/app/src/main/AndroidManifest.xml` and explains why each permission
is still needed after adding LIME-owned inline dictation.

The current manifest declares 5 permissions. Four support existing keyboard,
download, backup/restore, and notification behavior. The new permission,
`RECORD_AUDIO`, is required only when the user chooses LIME's built-in inline
voice input. Users can decline it and continue using the Google/vendor voice
input fallback paths.

---

## Required Permissions

### 1. `POST_NOTIFICATIONS` - Required

**Location**: `LimeStudio/app/src/main/AndroidManifest.xml:49`

**Usage**:

- `LIMEUtilities.showNotification(...)`
- `DBServer.showNotificationMessage(...)`
- `SearchServer` download/import notifications

**Purpose**: Required on Android 13+ for app-posted notifications. LIME uses
notifications for database download, backup, restore, and import status.

**Status**: Keep.

---

### 2. `VIBRATE` - Required

**Location**: `LimeStudio/app/src/main/AndroidManifest.xml:50`

**Usage**:

- `LIMEService.getVibrator()`
- `LIMEService.vibrate()`
- Keyboard keypress haptic feedback
- Candidate selection feedback

**Purpose**: Provides optional haptic feedback while typing and selecting
candidates.

**Status**: Keep.

---

### 3. `INTERNET` - Required

**Location**: `LimeStudio/app/src/main/AndroidManifest.xml:51`

**Usage**:

- `LIMEUtilities.downloadRemoteFile(...)`
- Input method table downloads
- Database/import download flows

**Purpose**: Allows LIME to download input method databases and related data
only when the user starts a download/import action.

**Status**: Keep.

---

### 4. `ACCESS_NETWORK_STATE` - Required

**Location**: `LimeStudio/app/src/main/AndroidManifest.xml:52`

**Usage**:

- `SetupImController.isNetworkAvailable(...)`
- `ConnectivityManager` network checks before downloads

**Purpose**: Checks whether a usable network is available before starting
download operations.

**Status**: Keep.

---

### 5. `RECORD_AUDIO` - Required For Optional Inline Dictation

**Location**: `LimeStudio/app/src/main/AndroidManifest.xml:53`

**Usage**:

- `VoicePermissionHelper.hasRecordAudioPermission(...)`
- `SetupFragment` runtime permission request
- `AndroidSpeechRecognizerAdapter` / `SpeechRecognizer`
- `LIMEDictationController`
- `LIMEService` inline dictation route

**Purpose**: Android requires microphone permission before LIME can run its own
inline dictation through `SpeechRecognizer`. This lets the keyboard keep its
own surface visible while showing partial and final speech results.

**Runtime behavior**:

1. LIME requests the permission from the Settings Setup tab, not silently from
   the keyboard.
2. If granted, the microphone key can use LIME-owned inline dictation.
3. If denied or not yet granted, the microphone key falls back to Google/vendor
   VoiceIME switching, then `RecognizerIntent`.
4. If permanently denied, Setup opens Android app settings and the fallback
   voice paths remain available.

**Status**: Keep. This is a runtime permission and should be presented as
optional in user-facing text.

---

## Removed Permissions

These permissions were previously reviewed as unused and are no longer declared
in the main manifest:

| Permission | Reason |
|------------|--------|
| `READ_USER_DICTIONARY` | LIME uses its own database instead of Android's `UserDictionary` API. |
| `WRITE_USER_DICTIONARY` | LIME does not write Android's system user dictionary. |
| `WAKE_LOCK` | No `PowerManager.WakeLock` usage remains. |
| `WRITE_SETTINGS` | LIME reads input method state but does not write system settings. |
| `ACCESS_WIFI_STATE` | Network checks use `ConnectivityManager` and only need `ACCESS_NETWORK_STATE`. |

---

## Permission Summary

| Permission | Status | User-facing purpose |
|------------|--------|---------------------|
| `POST_NOTIFICATIONS` | Keep | Shows download, backup, restore, and import status notifications. |
| `VIBRATE` | Keep | Provides keyboard haptic feedback. |
| `INTERNET` | Keep | Downloads selected input method databases and import data. |
| `ACCESS_NETWORK_STATE` | Keep | Checks network availability before downloads. |
| `RECORD_AUDIO` | Keep | Enables optional LIME-owned inline voice input. |

---

## User Communication Notes

- Public documentation should say LIME declares 5 permissions.
- `RECORD_AUDIO` should be described as optional and only for built-in LIME
  voice input.
- Users who do not grant microphone permission can still use Google/vendor
  voice input fallback.
- Do not describe microphone permission as required for typing, database
  downloads, backup, restore, or basic keyboard use.

## Verification Checklist

- [x] Main manifest permission list reviewed.
- [x] New `RECORD_AUDIO` permission documented.
- [x] Optional runtime behavior documented.
- [x] Previously removed permissions kept out of the current permission list.
- [x] README privacy text updated to match the current manifest.

**Conclusion**: The current Android app declares 5 permissions. All are
justified. `RECORD_AUDIO` is the only new user-sensitive permission, and it is
limited to optional LIME-owned inline dictation with delegated voice fallback
available when the permission is not granted.
