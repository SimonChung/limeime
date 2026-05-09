# iPad Dual-Sliding Punctuation Keys vs. Chinese Composition

Status: ✅ FIXED

Scope: iOS only — `LimeIME-iOS`. iPad-only behavior change. Phone layouts
retain the legacy acceptance heuristic untouched. No DB / IM-table edit, no
JSON layout edit.

Affected files:

- [LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) — cache + refresh hooks + `handleCharacter` rule
- [LimeIME-iOS/Shared/Database/LimeDB.swift](../LimeIME-iOS/Shared/Database/LimeDB.swift) — new `imKeysForTable(_:)` accessor

Related design docs:

- [IPAD_KEYBOARD.md](IPAD_KEYBOARD.md) — overall iPad layout plan + dual-row key spec (§4.5)
- [IPAD_KB_LAYOUT_COVERTER.md](IPAD_KB_LAYOUT_COVERTER.md) — iPad-layout converter rules

---

## 1. Problem statement

On every Chinese-IM iPad layout (`lime_phonetic_ipad`, `lime_array_ipad`,
`lime_cj_ipad`, `lime_dayi_ipad`, `lime_et26_ipad`, `lime_et_41_ipad`,
`lime_hsu_ipad`, `lime_hs_ipad`, `lime_wb_ipad`, …), tapping or sliding-down
on any of the **dual-sliding punctuation keys** added by the iPad converter
(`scripts/build_ipad_layouts.py`) produced the right glyph in the document
but left Chinese composition broken: the next IM-key press either failed to
produce candidates or composed against a corrupted code buffer.

Reproduction (any Chinese IM on iPad):

1. Type a few IM keys (e.g. phonetic ㄐㄧㄚ).
2. Tap the ASDF row `；\n：` key, or the ZXCV `<\n,`/`>\n.`/`?\n/` cell, or
   slide-down on any of those keys.
3. Verify the punctuation lands in the document — it does.
4. Continue typing the same IM. Composition is corrupted: candidates either
   disappear or the lookup is misaligned. Backspace does not always recover.

Phone layouts were unaffected because they have no dual-sliding keys.

---

## 2. Root cause

The fault is entirely in
[`KeyboardViewController.handleCharacter(_:)`](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift),
specifically the acceptance table that decides whether an incoming code
should join `mComposing` or be flushed as direct output:

```swift
if !hasSymbol && !hasNumber {
    accepted = isLetter || (isPhonetic && isSpace) || isComma || isPeriod
} else if !hasSymbol && hasNumber {
    accepted = isLetter || isDigit
} else if hasSymbol && !hasNumber {
    let isSymbol = !isLetter && !isDigit && code > 32
    accepted = isLetter || isSymbol || (isPhonetic && isSpace)
} else {
    let isSymbol = !isLetter && !isDigit && code > 32
    accepted = isLetter || isDigit || isSymbol || (isPhonetic && isSpace)
}
```

`hasSymbol` / `hasNumber` come from `LimeDB.detectIMCapabilities(tableName:)`
and are set to **true** for every IM that has any code in the ASCII symbol
ranges 33-47 / 58-64 / 91-96 / 123-126 within its first 200 codes. Phonetic,
Array, Dayi, ET26, ET_41, Hsu, HS all qualify (they use `;`, `,`, `.`, `/`,
`'`, `[`, `]` as IM-input keys), so for them the rule reduces to:

> "Any printable code > 32 that isn't a letter/digit is accepted as IM input."

The iPad converter, however, **adds keys whose codes are not IM input at
all**:

| Key                | `code` (tap) | `longPressCode` (slide) | Where added |
|---|---|---|---|
| `；\n：`            | 65306 (；)   | 65307 (：)              | ASDF — `append_semicolon_key` |
| `。\n，`            | 65292 (，)   | 12290 (。)              | ASDF — `append_fullshape_period` |
| `<\n,`             | 44 (,)       | 60 (<)                  | ZXCV — `apply_zxcv_punct_sliding` (only when source key has no IM sublabel) |
| `>\n.`             | 46 (.)       | 62 (>)                  | ZXCV — same |
| `?\n/`             | 47 (/)       | 63 (?)                  | ZXCV — same |
| `{\n[` / `}\n]` / <code>&#124;\n\\</code> | 91/93/92 | 123/125/124 | QWERTY — `transform_qwerty_row` (no-sublabel branch) |
| `『\n「` / `』\n」` / `&#124;\n、` | 12300/12301/12289 | 12302/12303/124 | QWERTY — fallback / IM-sublabel branch |
| `~\n` `` ` ``       | 96 (`)       | 126 (~)                 | Digit row — `augment_im_digit_row` |
| `!\n1` … `)\n0`    | 49–48        | 33–41                   | Digit row — `augment_im_digit_row` (no-sublabel branch) |
| `_\n-` / `+\n=`    | 45 / 61      | 95 / 43                 | Digit row — same |
| `…\n—`             | 8212 (—)     | 8230 (…)                | Digit row fallback |

None of those codes appear in any IM's `imkeys` (the converter explicitly
*only* adds dual-sliding keys when the source key has no IM sublabel — i.e.
when the code is provably **not** an IM-input character; see
[IPAD_KB_LAYOUT_COVERTER.md §4](IPAD_KB_LAYOUT_COVERTER.md)).

But the acceptance rule above does not consult `imkeys`. It only asks
"hasSymbol?" — true — "is this code in the symbol range?" — also true for
all the codes in the table — and therefore appends the punctuation to
`mComposing`. The IM lookup against `ㄐㄧㄚ；` (or whichever corrupted code
buffer results) returns nothing, candidates clear, and the user perceives
composition as broken.

The bug exists on phone too in principle, but phone layouts never produce
those codes (phone source JSONs have no dual-sliding keys), so it never
fires.

---

## 3. Why the obvious-looking alternatives don't fit

- **"Detect dual-sliding keyDef in `didPress` and bypass `handleCharacter`."**
  Two of the three dual-sliding entry points
  ([`KeyboardView.dualRowPanned`](../LimeIME-iOS/LimeKeyboard/KeyboardView.swift)
  and `dualRowLongPressed`) synthesize a fresh `KeyDef` with
  `longPressCode = 0`, so the controller cannot distinguish a slide/long-press
  output from a normal key press without changing the synthesis or the
  delegate signature. The tap path does carry `longPressCode != 0`, but
  some non-dual-slide keys (globe, dismiss) also do. Net: requires a
  KeyboardView change *and* a controller change *and* a careful predicate.

- **"Hard-code the offending code points as a deny-list."** Brittle —
  the converter adds new dual-sliding keys per layout (CJK brackets, digit
  row symbols, em-dash fallback). The deny-list would have to track every
  edit to `scripts/build_ipad_layouts.py`.

- **"Drop the `hasSymbol` heuristic globally."** Phone layouts rely on it
  to admit `;`, `,`, `.`, `/` etc. as IM input. Replacing it everywhere is
  a phone-side regression risk we do not need to take.

The right axis is the IM table itself: it already lists exactly which
characters compose for the active IM.

---

## 4. Solution implemented

Authoritative source for "valid IM input characters" = the same key strings
the database already uses to render keynames: `BPMF_KEY` (phonetic),
`ETEN26_KEY`, `HSU_KEY`, `ETEN_KEY`, `CJ_KEY`, `DAYI_KEY`, `ARRAY_KEY`,
plus the im table's `imkeys` row for IMs without a hardcoded keymap.

> **Why the im table's `imkeys` field alone is not enough:** for the IMs
> with hardcoded keymaps (phonetic family, cj, dayi, array — i.e. the
> ones in the `case` blocks of [`LimeDB.keyToKeyName(_:_:_:)`](../LimeIME-iOS/Shared/Database/LimeDB.swift#L1410))
> the `im` table row may be empty or absent on iOS. `getImConfig("dayi", "imkeys")`
> returns `""`, the cache stays empty, the iPad guard `!currentImKeys.isEmpty`
> falls through, and the legacy heuristic re-fires the bug. The fix has to
> walk the same switch as `keyToKeyName` and only fall back to the im
> table's `imkeys` field for IMs that genuinely live there.

### 4.1 New DB accessor — `LimeDB.imKeysForTable(_:)`

[`LimeDB.swift`](../LimeIME-iOS/Shared/Database/LimeDB.swift#L2596) gains a
single public accessor that mirrors the keyname-display switch:

```swift
func imKeysForTable(_ tableName: String) -> String {
    let kbType = phoneticKeyboardType
    switch tableName {
    case "phonetic", "et41", "et_41", "eten":
        if kbType.hasPrefix("eten26") || kbType == "et26" { return LimeDB.ETEN26_KEY }
        if kbType.hasPrefix("hsu")                        { return LimeDB.HSU_KEY }
        if kbType == "et_41" || kbType == "eten"          { return LimeDB.ETEN_KEY }
        return LimeDB.BPMF_KEY
    case "cj", "scj", "cj5", "ecj":
        return LimeDB.CJ_KEY
    case "dayi":
        return LimeDB.DAYI_KEY
    case "array", "array10":
        return LimeDB.ARRAY_KEY
    default:
        return getImConfig(tableName, "imkeys") ?? ""
    }
}
```

The constants are the same `private static let` strings the existing
keyname code already uses — no duplication, just exposed once via a
public method.

### 4.2 Cache `currentImKeys` in the controller

```swift
/// Cached imkeys for the active IM. Refreshed on every setTableName /
/// setPhoneticKeyboardType so iPad handleCharacter can route out-of-imkeys
/// codes (full-shape Chinese punct, brackets, half-shape <>?:, etc.) to the
/// direct-output branch instead of corrupting the composing buffer.
private var currentImKeys: String = ""

private func refreshImKeys() {
    currentImKeys = db?.imKeysForTable(activeIM) ?? ""
}
```

### 4.3 Refresh on every IM / kbType change

`refreshImKeys()` is called at five points so the cache is never stale:

| Call site | Purpose |
|---|---|
| `initOnStartInput` saved-IM restore (≈ L373) | First-launch / restore path; runs after `setTableName` and `setPhoneticKeyboardType` |
| `setupDatabase` async tail (≈ L490) | DB-load completion; **deliberately placed AFTER `setPhoneticKeyboardType` because phonetic-family `imKeysForTable` resolves on `kbType`** |
| `refreshPhoneticKeyboardPrefs` kbType change (≈ L536) | User changed `phonetic_keyboard_type` in Settings; phonetic-family imkeys flips between BPMF / ETEN26 / HSU / ETEN |
| `switchToNextActivatedIM` (≈ L2144) | Globe / next-IM cycle |
| `switchIM(toIndex:)` (≈ L2644) | Direct IM-list jump |

### 4.4 Use `imkeys` in `handleCharacter` — iPad layouts only

```swift
let isIPadLayout = isOnPad && currentLayout.id.hasSuffix("_ipad")
let accepted: Bool
if isIPadLayout && !currentImKeys.isEmpty {
    let inImKeys = currentImKeys.contains(charStr)
                || currentImKeys.contains(charStr.lowercased())
    accepted = isLetter || inImKeys || (isPhonetic && isSpace)
} else if !hasSymbol && !hasNumber {
    accepted = isLetter || (isPhonetic && isSpace) || isComma || isPeriod
} else if !hasSymbol && hasNumber {
    accepted = isLetter || isDigit
} else if hasSymbol && !hasNumber {
    let isSymbol = !isLetter && !isDigit && code > 32
    accepted = isLetter || isSymbol || (isPhonetic && isSpace)
} else {
    let isSymbol = !isLetter && !isDigit && code > 32
    accepted = isLetter || isDigit || isSymbol || (isPhonetic && isSpace)
}
```

The iPad branch fires only when

1. the controller is running on iPad (`isOnPad` — host trait collection check), **and**
2. the active layout id ends with `_ipad` (matches the `LayoutLoader._ipad`
   variant lookup in [IPAD_KEYBOARD.md §3](IPAD_KEYBOARD.md)), **and**
3. `imKeysForTable` returned a non-empty string (defensive — if a future
   IM lacks both a hardcoded keymap and an `im.imkeys` row, the legacy
   heuristic still applies).

Inside the iPad branch the rule is simply:

> *Compose iff the character is a letter, or it's literally listed in the
> IM's `imkeys`, or it's the phonetic tone-1 space marker. Otherwise commit
> the highlighted candidate, insert the character directly, and finish
> composing.*

The `isLetter` clause is preserved as a safety net for IMs whose `imkeys`
might omit the letter range (none currently do — but cheap and harmless).

### 4.5 What happens on the not-accepted path

The existing `else` branch in `handleCharacter` already does exactly what
the user asked for ("treat as English mode / reset composition before and
after"):

```swift
_ = pickHighlightedCandidate()      // commit current candidate
let insertChar = isShiftOn ? charStr.uppercased() : charStr
isSelfUpdate = true
textDocumentProxy.insertText(insertChar)
isSelfUpdate = false
finishComposing()                   // mComposing = "", composingLength = 0
```

So tapping `；\n：` mid-composition now (a) commits the highlighted
candidate to the document, (b) inserts `；`, (c) resets composing state.
The next IM keystroke starts a clean composition.

---

## 5. Behavior matrix after the fix

iPad layouts only — phone unchanged.

| Keystroke (active IM) | Code | In `imkeys`? | Old behavior | New behavior |
|---|---|---|---|---|
| Phonetic `ㄅ` (`1`) | 49 | ✅ yes | compose | compose (unchanged) |
| Phonetic `;` (ㄤ tone, IM-sublabel key) | 59 | ✅ yes | compose | compose (unchanged) |
| Phonetic ASDF `；\n：` tap | 65306 | ❌ no | append → corrupt | commit + direct insert ✅ |
| Phonetic ASDF `；\n：` slide | 65307 | ❌ no | append → corrupt | commit + direct insert ✅ |
| Phonetic ASDF `。\n，` tap | 65292 | ❌ no | append → corrupt | commit + direct insert ✅ |
| Phonetic ASDF `。\n，` slide | 12290 | ❌ no | append → corrupt | commit + direct insert ✅ |
| Hsu ASDF `；\n：` tap | 65306 | ❌ no | append → corrupt | commit + direct insert ✅ |
| Hsu ZXCV `<\n,` tap | 44 | ❌ no (Hsu = a-z only) | append (isComma) | commit + direct insert ✅ |
| Hsu ZXCV `<\n,` slide | 60 | ❌ no | append (isSymbol) | commit + direct insert ✅ |
| CJ alpha `a` | 97 | ✅ yes | compose | compose (unchanged) |
| CJ digit `1` (no IM sublabel → dual-slide) | 49 | ❌ no (CJ = a-y only) | not accepted (isDigit) | not accepted (unchanged) |
| CJ digit slide `!` | 33 | ❌ no | append (isSymbol) | commit + direct insert ✅ |
| Array10 digit `1` (IM-sublabel key, no dual-slide) | 49 | ✅ yes | compose | compose (unchanged) |
| QWERTY `『\n「` tap (CJK bracket) | 12300 | ❌ no | append (isSymbol) | commit + direct insert ✅ |
| QWERTY `&#124;\n、` tap when `、` is IM input | 12289 | ✅ yes | compose | compose (unchanged) |
| QWERTY `&#124;\n、` slide | 124 | ❌ no | append (isSymbol) | commit + direct insert ✅ |

The "no behavior change" rows confirm that legitimate IM-input keys
(letters, IM-component punct, IM-component digits) keep composing exactly
as before. Only the dual-sliding keys that carry non-IM glyphs change.

---

## 6. Out of scope

- Phone layouts (`lime_*.json` without `_ipad` suffix) — the iPad gate
  ensures the legacy rule is used unchanged.
- The English / `lime_abc` / `lime_english` iPad layouts — `mEnglishOnly`
  short-circuits before the acceptance table, so the new rule is never
  consulted there.
- The DB and IM tables — no schema or row edits. `imkeys` was already
  populated by the import seeds.
- Android (`LimeStudio/`) — unchanged.
- The iPad converter script (`scripts/build_ipad_layouts.py`) and existing
  `*_ipad.json` files — unchanged.

---

## 7. Manual test plan

iPad simulator + iPad device, every Chinese IM:

1. Type a partial code (e.g. phonetic ㄐㄧㄚ, CJ `hi`, Array `as`).
2. Tap each dual-sliding punctuation key in turn:
   - ASDF `；\n：`, `。\n，`
   - ZXCV `<\n,`, `>\n.`, `?\n/`
   - QWERTY `{\n[`, `}\n]`, <code>&#124;\n\\</code> (or CJK
     `『\n「` / `』\n」` / `&#124;\n、` for IMs that have those)
   - Digit row `!\n1` … `)\n0`, `_\n-`, `+\n=`, `~\n` `` ` ``
3. Verify in each case:
   - The highlighted candidate is committed (or — if no candidate —
     nothing extra is inserted).
   - The punctuation/digit/symbol appears in the document.
   - The candidate bar clears.
   - The next IM keystroke produces a fresh, correct candidate list.
4. Repeat steps 2-3 with a slide-down gesture instead of a tap.
5. Repeat with a long-press (≥ `dualRowHoldDuration`) and release.
6. Cycle IMs via the globe key or IM list — verify composition still
   works correctly after each switch (this confirms `refreshImKeys()`
   fires at every switch site).
7. iPhone build: type the same Chinese IMs, confirm no behavior change
   (no dual-sliding keys exist on phone, and the iPad branch never fires
   because `isOnPad == false` and no layout id ends with `_ipad`).
8. English mode (`lime_abc_ipad`, `lime_english_ipad`) on iPad: type
   normally — `mEnglishOnly` short-circuits the acceptance table, so this
   path is unaffected.

---

## 8. Implementation footprint

```
LimeIME-iOS/Shared/Database/LimeDB.swift
  + func imKeysForTable(_:) -> String                              (≈ 25 lines incl. doc comment)

LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift
  + private var currentImKeys: String                              (≈ 5 lines incl. doc comment)
  + private func refreshImKeys()                                   (≈ 10 lines incl. doc comment)
  + 5 × refreshImKeys() call sites (4 × after setTableName, 1 × in
    refreshPhoneticKeyboardPrefs after kbType change)              (1 line each)
  ~ handleCharacter — iPad branch added before legacy heuristic    (≈ 17 lines incl. doc comment)
```

No JSON layout edit. No DB row / IM-table edit. No KeyboardView /
KeyDef / delegate-protocol change.
