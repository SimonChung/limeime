# iOS Chinese / English Mode Mismatch

## Issue

When typing on the Chinese IM keyboard layout, no Chinese composing appears and the
candidate bar shows English prediction instead.

Reported symptom:
- Keyboard visually shows the Chinese IM layout (e.g. 注音, 倉頡, 行列)
- Typing letters does not build a composing code strip
- The candidate bar shows English autocomplete words instead of Chinese candidates

---

## Root Cause 1 — `mEnglishOnly` not reset on field switch (main cause)

`initOnStartInput()` maps `textDocumentProxy.keyboardType` to `mEnglishOnly`:

```swift
switch textDocumentProxy.keyboardType ?? .default {
case .emailAddress, .URL:
    mEnglishOnly = true; mPredictionOn = false
...
default:
    mEnglishOnly = false
}
```

`initOnStartInput()` is called only from `viewWillAppear` — i.e. when the keyboard
extension's view first becomes visible for a given focus session.

On iOS, when the user taps a different text field **while the keyboard stays visible**
(common in forms: URL field → body text field, login email → password note, etc.),
`viewWillAppear` does **not** fire again. Only `textWillChange` / `textDidChange` fire.

This means:

| Transition (keyboard stays visible) | `mEnglishOnly` after | Layout after | Symptom |
|--------------------------------------|----------------------|--------------|---------|
| email/URL → normal text field        | `true` (stale)       | English (stale) | English prediction in what user expects to be Chinese mode |
| normal text → email/URL              | `false` (stale)      | Chinese (stale) | Chinese composing in email field (opposite problem) |

The first row is the reported bug: `handleCharacter` calls `handleEnglishCharacter`
(because `mEnglishOnly = true`), builds `tempEnglishWord`, and calls
`updateEnglishPrediction()`. Chinese composing never starts.

### Fix

Track `lastKnownKeyboardType`. In `textDidChange`, if the keyboard type has changed,
call `initOnStartInput()` to re-evaluate mode and layout:

```swift
// New property
private var lastKnownKeyboardType: UIKeyboardType = .default

// In initOnStartInput(), record current type:
lastKnownKeyboardType = textDocumentProxy.keyboardType ?? .default

// In textDidChange(), before the composing-integrity check:
override func textDidChange(_ textInput: UITextInput?) {
    guard !isSelfUpdate else { return }
    let newType = textDocumentProxy.keyboardType ?? .default
    if newType != lastKnownKeyboardType {
        lastKnownKeyboardType = newType
        initOnStartInput()
        return
    }
    // ... existing composing-integrity check ...
}
```

`initOnStartInput()` already clears composing, resets `tempEnglishWord`, sets the
correct layout, and re-reads the persisted IM — no extra work needed.

---

## Root Cause 2 — Dead code in `switchToSymbol()` (symbol layout bug)

`switchToSymbol()` at line 2080 sets `mEnglishOnly = true` immediately, then on
line 2086 checks `if !mEnglishOnly` — which is **always false**:

```swift
mEnglishOnly = true          // line 2080
...
if !mEnglishOnly {           // line 2086 — always false, dead code
    // IM-specific symbol layout resolution (symbolkb / symbolshiftkb from DB)
    // This block is never reached
} else {
    symbolLayouts = ["symbols1", "symbols2", "symbols3"]   // always taken
}
```

Effect: IM-specific symbol layouts configured in the DB (`symbolkb`, `symbolshiftkb`)
are silently ignored. The generic English symbol set is always used regardless of the
active Chinese IM.

### Fix (already applied)

Change the condition to check `preSymbolEnglish` — the state saved *before*
`mEnglishOnly` was overwritten:

```swift
preSymbolEnglish = mEnglishOnly
mEnglishOnly     = true
...
if !preSymbolEnglish {          // was: if !mEnglishOnly
    // IM-specific symbol layout resolution
```

Commit: fix applied to `KeyboardViewController.swift` line 2086.

---

## Secondary trigger — Persistent Language Mode

If `persistent_language_mode = true` and the user previously switched to English
(persisting `persisted_english_mode = true` in `UserDefaults`), then every
`viewWillAppear` → `initOnStartInput()` restores `mEnglishOnly = true` for all
text fields including normal ones. The user sees the English layout and English
prediction even on fields where they expect Chinese input.

This is intentional behaviour (persist the last user choice), but it can surprise
users who forget they switched to English. No code fix required; the Chinese/English
toggle key on the keyboard resets it.

---

## Files / lines of interest

| Location | Note |
|----------|------|
| `KeyboardViewController.swift:326–342` | `initOnStartInput` keyboard-type → `mEnglishOnly` map |
| `KeyboardViewController.swift:295–306` | `textDidChange` — where the field-switch detection fix belongs |
| `KeyboardViewController.swift:1096–1099` | `handleCharacter` gate: routes to `handleEnglishCharacter` when `mEnglishOnly` |
| `KeyboardViewController.swift:1939–1972` | `updateEnglishPrediction` |
| `KeyboardViewController.swift:2076–2113` | `switchToSymbol` — dead-code bug (fixed) |
