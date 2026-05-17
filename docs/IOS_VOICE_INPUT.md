# iOS Voice Input — Decision Record

Status: NOT FEASIBLE with public iOS APIs.
Scope: LimeIME-iOS keyboard extension.
Decision date: 2026-05-17.

LimeIME must not expose a working iOS microphone key. iOS does not provide a
public API for a third-party keyboard extension to start Apple Dictation, show
the system dictation dialog, receive dictated text, or capture microphone audio
directly.

This supersedes the earlier implementation plan that proposed an
`SFSpeechRecognizer` + `AVAudioEngine` pipeline inside `LimeKeyboard`.

## Why

Apple's custom keyboard extension guide states that custom keyboards do not
have access to the device microphone, so dictation input is not possible inside
a custom keyboard extension:

- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html

Apple's app extension guide also lists camera and microphone access as
unavailable to iOS app extensions:

- https://developer-mdn.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html

The extension can insert and delete text through `textDocumentProxy`, and it
can ask iOS to advance to the next input mode. It cannot select Apple Dictation
as a target input mode, trigger dictation on behalf of the user, or receive a
callback containing dictated text.

## Current Product Behavior

- `LimeKeyCode.voiceInput` remains reserved as `-220` only so stale layouts or
  old test fixtures do not crash the keyboard.
- No shipped iPhone or iPad layout should expose `-220`.
- `CandidateBarView` keeps its mic button hidden.
- `KeyboardViewController.startVoiceInput()` is a silent no-op. It intentionally
  does not show a toast, because the user should never be able to tap this path
  in a shipped layout.

## Rejected Alternatives

### In-extension speech recognition

Rejected. `SFSpeechRecognizer` still needs microphone audio, and iOS app
extensions cannot access the microphone. Keeping recognition on-device does not
remove that extension-level restriction.

### Start Apple Dictation from the mic key

Rejected. There is no public API for a third-party keyboard extension to launch
system dictation and receive the text result. Private selector or responder-chain
hacks would be brittle and App Store-risky.

### Companion app dictation

Rejected for keyboard UX. The containing app could record and transcribe audio,
but it cannot reliably return to the original host text field and insert text
there. At best it could copy recognized text to the clipboard, which is outside
the keyboard flow and does not match Android voice input.

## Design Rule

For iOS, voice input is system-owned. LimeIME should avoid custom mic affordances
unless Apple adds a public API that allows keyboard extensions to invoke system
dictation or receive dictated text safely.
