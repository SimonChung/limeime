# English Keyboard — Behavior Reference & Improvement Plan

Comparison of LimeIME's English-mode behavior against AOSP **LatinIME** (the
open-source ancestor of Google's gboard; gboard itself is closed-source but
shares this core IME logic). Goal: identify high-value, low-risk improvements
for LimeIME §8.7 「英文鍵盤」.

Spec touchpoints: §8.7 (English Keyboard), §8.4 (IM Behaviour).

---

## 1. Auto-Capitalization

### LatinIME

- `RichInputConnection.getCursorCapsMode(inputType, SpacingAndPunctuations,
  hasSpaceBefore)` **does not** delegate to the host `InputConnection`. It
  walks its own committed-text cache through `CapsModeUtils.getCapsMode()`.
- Look-back is **unbounded** — it skips trailing whitespace and closing
  punctuation (quotes, parens) to find the last sentence terminator or
  paragraph boundary.
- Abbreviation FSM matches `(\w\.){2,}` so `Mr.`, `U.S.`, `e.g.` do **not**
  re-trigger sentence-cap.
- Locale flags in `SpacingAndPunctuations`:
  - `mUsesAmericanTypography` — skip trailing `"`, `'`, `)` before terminator
    check, so `She said "Hello." |` capitalizes correctly.
  - `mUsesGermanRules` — `digit.` is not a sentence terminator.

### LimeIME today

- **iOS** (`KeyboardViewController.updateShiftForAutoCap`, ~line 1395)
  - Gated on `mEnglishOnly`, `!isShiftOn`, `!mCapsLock`, pref `autoCap`,
    and host `textDocumentProxy.autocapitalizationType`.
  - Heuristic: `before.isEmpty || hasSuffix(". " / "! " / "? ")`.
  - **No** abbreviation guard — `Mr. |` will mis-capitalize.
  - **No** quote/paren skip — `"Hello." |` will not capitalize.
  - **No** paragraph/newline trigger — only `". "` family.
- **Android** (`LIMEService.java:1851`)
  - Delegates entirely to `InputConnection.getCursorCapsMode(inputType)`.
  - Behavior matches whatever the host editor reports — usually fine for
    `TYPE_TEXT_FLAG_CAP_SENTENCES`, but loses control over abbreviations,
    quotes, and the LimeIME-specific timing.

### Gap

| Behavior                        | LatinIME | LimeIME-iOS | LimeIME-Android |
| ------------------------------- | :------: | :---------: | :-------------: |
| Sentence end (`. ` / `! ` / `?`)|   ✓      |   ✓         |   ✓ (host)      |
| Start-of-document               |   ✓      |   ✓         |   ✓ (host)      |
| After newline / paragraph       |   ✓      |   ✗         |   depends       |
| Skip closing quotes/parens      |   ✓      |   ✗         |   ✗             |
| Abbreviation guard (`Mr.`)      |   ✓      |   ✗         |   ✗             |
| After `?!` not just `.`         |   ✓      |   ✓         |   ✓ (host)      |

### Recommendation

1. **iOS — extend the suffix check** (`KeyboardViewController.swift`):
   - Trigger when `before` ends with **`. ` / `! ` / `? ` / `\n` / `\n\n`**,
     or ends with one of those followed by `"`, `'`, `)`, `]`, `}`.
   - Add an abbreviation guard: if the char before `". "` is a single
     letter (e.g. `r. `) **and** the run before is `\w\.`-pattern repeating,
     suppress. Cheap version: skip auto-cap when `documentContextBeforeInput`
     ends with `[A-Za-z]\. ` and the preceding char (if any) is alpha (covers
     `Mr.`, `Dr.`, `e.g.`, `U.S.`).
2. **Android** — keep host `getCursorCapsMode()` as the baseline, but when
   `mAutoCap && caps == 0` and `mEnglishOnly`, run the same suffix/abbrev
   heuristic on `ic.getTextBeforeCursor(3, 0)` as a fallback. Many WebView
   editors return `0` for caps mode even on sentence-cap fields.

---

## 2. Smart Space / Smart Period

### LatinIME

`SpaceState` enum drives this:

| State              | Meaning                                                    |
| ------------------ | ---------------------------------------------------------- |
| `NONE`             | Normal                                                     |
| `DOUBLE`           | Just performed double-space → `". "`                       |
| `SWAP_PUNCTUATION` | Just swapped weak space with picked punctuation            |
| `WEAK`             | Auto-inserted space after a suggestion pick (swappable)    |
| `PHANTOM`          | Deferred space — emitted before next non-separator char    |

- **Double-space → `". "`** (`InputLogic.tryPerformDoubleSpacePeriod`):
  requires `<char><space>` before cursor; rewrites to `<char>. `.
- **Swap with punctuation** (`trySwapSwapperAndSpace`): if you pick a
  suggestion (weak space auto-inserted), then type `,`, the result is
  `word, ` not `word ,`.
- **Phantom space**: picking a suggestion does not literally insert a space;
  the IME marks `PHANTOM` so the next letter is preceded by a space, but
  a separator like `.` overrides it (no `word .`).

### LimeIME today

- **Neither platform** implements any of the four states. There is no
  double-space-to-period and no swap-with-punctuation.
- iOS does have an `isSelfUpdate` recursion guard but that is unrelated.

### Recommendation

Two low-risk wins on both platforms (English-mode only, behind `auto_cap`
or a new pref):

1. **Double-space → `". "`**
   - On `space` keypress in English mode, peek `documentContextBeforeInput`
     (iOS) / `getTextBeforeCursor(2, 0)` (Android). If it is
     `[A-Za-z0-9)\]"' ]<space>`, delete one char and insert `". "`.
   - Skip when the previous non-space char is already terminal punctuation
     (`.!?,:;`).
   - Compose well with the new auto-cap path above — `". "` then triggers
     sentence-cap on the next letter.
2. **Defer** SWAP/WEAK/PHANTOM — those only matter once we have
   English-suggestion picks (see §4 below). Re-evaluate after that lands.

---

## 3. Shift State Machine

### LatinIME

`KeyboardState` has states `UNSHIFT`, `MANUAL_SHIFT`, `AUTOMATIC_SHIFT`,
`SHIFT_LOCK_SHIFTED`. Auto-shift is applied at **release**, not press.
Double-tap timeout `isInDoubleTapShiftKeyTimeout()` toggles caps-lock.
Chording (hold shift + type letter) keeps shift through the letter, releases
after.

### LimeIME today

iOS uses `ShiftResetPolicy.shouldResetAfterCharacter` /
`shouldResetAfterShiftRelease` — already implements chording vs. tap.
`KeyboardViewController.swift:1312-1325` covers single-tap, double-tap-lock,
and tap-to-lock-off. **This is on par with LatinIME.** No change needed.

---

## 4. English Prediction Pipeline

### LatinIME

- `DictionaryFacilitatorImpl` loads `main` (binary LM), `user_history`,
  `user` (system Personal Dictionary), `contacts`.
- `Suggest.getSuggestedWords()` ranks via `NgramContext` (bigram/trigram).
- Auto-commit on separator gated by `mAutoCorrectionEnabledPerUserSettings`
  AND `InputAttributes.mInputTypeNoAutoCorrect`.
- Capitalized-word learning capped at
  `CAPITALIZED_FORM_MAX_PROBABILITY_FOR_INSERT = 140` so accidental
  `Hello`-after-`. ` doesn't displace `hello` in user history.

### LimeIME today

- iOS surfaces English candidates via `updateEnglishPrediction()` from a
  shipped English dictionary — no n-gram, no user-history learning, no
  contacts integration.
- Android surfaces English candidates through the existing IM candidate
  pipeline when `english_dictionary_enable` is on; same limitations.
- Neither platform auto-commits on space — the user must tap a candidate.

### Recommendation

Out of scope for a §8.7 polish pass — these are multi-week changes
(binary LM, history DB, ngram lookups). Park for a future "English IME v2"
proposal. The immediate auto-cap + double-space-period improvements deliver
80% of the perceived gboard parity at <1% of the cost.

---

## 5. Input-Type Awareness

### LatinIME (`InputAttributes.java`)

- **Suggestions off** for: passwords, `isEmailVariation()`,
  `TYPE_TEXT_VARIATION_URI`, `TYPE_TEXT_VARIATION_FILTER`,
  `TYPE_TEXT_FLAG_NO_SUGGESTIONS`, `TYPE_TEXT_FLAG_AUTO_COMPLETE`.
- **Auto-correct off** for: `TYPE_TEXT_VARIATION_WEB_EDIT_TEXT` (unless
  explicit auto-correct flag), `TYPE_TEXT_FLAG_NO_SUGGESTIONS`, any
  single-line field without `TYPE_TEXT_FLAG_AUTO_CORRECT`.

### LimeIME today

- Android (`LIMEService.java:895-945`) already detects
  `EMAIL_ADDRESS`, `URI`, `WEB_EMAIL_ADDRESS` and forces the English
  layout for those fields (see project memory: "URL fields stay
  English-only #74").
- iOS gates `lime_url_*` / `lime_email_*` layouts via `keyboardType` —
  also force-English.
- Neither platform suppresses suggestions in password fields beyond the
  layout switch. That is a defect for any future English-prediction work
  but **not** for the current candidate-list behavior (no auto-correct
  exists today, so nothing to suppress).

### Recommendation

When (and only when) English prediction grows beyond the current
read-only dictionary, mirror LatinIME's `InputAttributes` gate to
disable the English suggestion strip for password / NO_SUGGESTIONS
fields. Until then, no action.

---

## 6. Prioritized Backlog

Ordered by user-visible impact ÷ engineering cost:

| # | Item                                                            | Platform | Est. effort | Spec note |
| - | --------------------------------------------------------------- | -------- | ----------- | --------- |
| 1 | Auto-cap after `\n` / paragraph boundary                        | iOS      | ~5 LOC      | §8.7      |
| 2 | Auto-cap skip-trailing-quote/paren (`"Hello." `)                | iOS      | ~10 LOC     | §8.7      |
| 3 | Abbreviation guard (`Mr.`, `e.g.`)                              | both     | ~20 LOC     | §8.7      |
| 4 | Double-space → `". "` (English-only, behind `auto_cap` pref)    | both     | ~30 LOC ea  | §8.7      |
| 5 | Android: fallback heuristic when host returns `caps == 0`       | Android  | ~15 LOC     | §8.7      |
| 6 | English n-gram / user-history dictionary                        | both     | weeks       | future    |
| 7 | Disable English suggestions in password / NO_SUGGESTIONS fields | both     | small       | after #6  |

Items 1–5 are independently shippable and share the existing `auto_cap`
preference — no new UI required. Recommend bundling 1–3 in one PR for iOS,
5 alone for Android, then 4 as a second PR per platform.

---

## 7. Source References

AOSP LatinIME (mirrors: `aosp-mirror/platform_packages_inputmethods_LatinIME`):

- `java/src/com/android/inputmethod/latin/RichInputConnection.java`
- `java/src/com/android/inputmethod/latin/utils/CapsModeUtils.java`
- `java/src/com/android/inputmethod/latin/settings/SpacingAndPunctuations.java`
- `java/src/com/android/inputmethod/latin/inputlogic/InputLogic.java`
- `java/src/com/android/inputmethod/latin/inputlogic/SpaceState.java`
- `java/src/com/android/inputmethod/keyboard/internal/KeyboardState.java`
- `java/src/com/android/inputmethod/latin/DictionaryFacilitatorImpl.java`
- `java/src/com/android/inputmethod/latin/InputAttributes.java`

LimeIME:

- `LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift` —
  `updateShiftForAutoCap` (~1395), `handleEnglishCharacter` (~1231),
  `handleEnterOrSpace` (~1091).
- `LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java` —
  `mAutoCap` (156), `loadSettings()` (~999), runtime gate (~1851),
  input-type detection (~895-945).
- `LimeStudio/app/src/main/res/xml/preference.xml` — `auto_cap` toggle.
- `LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift` — §8.7 UI.
