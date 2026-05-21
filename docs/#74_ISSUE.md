# Issue #74: Android remembered Chinese/English mode and restricted numeric field layouts

## Problem statement

Reporter SmithCCho asks how Android remembered Chinese/English mode should interact with field-specific input types. They use Array 10/行列10 with a numeric/phone-style layout for Chinese input, so switching to an English keyboard in URL or numeric fields can be inconvenient for one-handed input and mixed Chinese/number workflows.

The latest reporter clarification narrows one concrete request: since LIME already has a phone-number layout, phone and number input fields should be able to open a LIME numeric/phone-style layout instead of an English keyboard with a number row. Maintainer direction in comment `4509415304` accepts this direction with an important restriction: number/phone-only field layouts should not expose `中` or `abc` mode keys because those fields should not accept English or Chinese input. Number/date-time fields are restricted input contexts and should not expose a mode key that lets users switch into alphabet or Chinese input if the target field should not accept those characters.

Issue URL: https://github.com/lime-ime/limeime/issues/74

Relevant comments:

- Maintainer explanation: https://github.com/lime-ime/limeime/issues/74#issuecomment-4505846029
- Reporter numeric/phone follow-up: https://github.com/lime-ime/limeime/issues/74#issuecomment-4508837104
- Maintainer numeric-keyboard direction: https://github.com/lime-ime/limeime/issues/74#issuecomment-4509415304

## Current Android behavior

`LIMEService.initOnStartInput(EditorInfo attribute)` switches on `attribute.inputType & EditorInfo.TYPE_MASK_CLASS`.

Current code paths:

```java
case EditorInfo.TYPE_CLASS_NUMBER:
case EditorInfo.TYPE_CLASS_DATETIME:
    mEnglishOnly = true;
    mKeyboardSwitcher.setKeyboardMode(activeIM, LIMEKeyboardSwitcher.MODE_TEXT,
            mImeOptions, false, true, false);
    break;

case EditorInfo.TYPE_CLASS_PHONE:
    mEnglishOnly = true;
    mKeyboardSwitcher.setKeyboardMode(activeIM, LIMEKeyboardSwitcher.MODE_PHONE,
            mImeOptions, false, false, false);
    break;
```

Observed implications:

- `TYPE_CLASS_PHONE` uses `MODE_PHONE`, which maps to `phone_number.xml` in `LIMEKeyboardSwitcher`; that restricted phone-number layout has no `中` / `ABC` / `EN` mode-switch key.
- `TYPE_CLASS_NUMBER` and `TYPE_CLASS_DATETIME` currently use `MODE_TEXT` with `isSymbol=true`, which opens the first symbol keyboard (`symbols1.xml`). That layout contains mode keys (`EN` and `中`) and more symbols than a restricted numeric/date-time field normally needs.
- LIME currently does not inspect `TYPE_NUMBER_VARIATION_*` separately; all number variations go through the same number class path.
- URL/email/password remain text-class variations. Email and password should continue to use inputType-specific English layouts; URL/URI is a separate product decision because address bars are often used for Chinese search keywords.

## Likely root cause / design gap

The current implementation treats number and date-time fields as generic English symbol entry instead of distinct restricted numeric/date-time contexts. This makes number/date-time fields show a broad symbol layout with mode switching, even though these fields should not allow arbitrary alphabet or Chinese entry.

There is also a naming/product distinction between two phone-like layouts:

- Restricted Android phone field layout: `phone_number.xml`, currently used by `TYPE_CLASS_PHONE`, no mode switch.
- General T9/phone-style Chinese/English layouts such as `phone.xml` / `phone_shift.xml`, where mode switching can make sense (`ABC` on Chinese side, `中` on English side).

For restricted Android input fields, the safer behavior is to hide mode switching.

## Proposed solution

Keep field-specific restrictions separate from general Chinese/English IM switching:

1. Preserve current `TYPE_CLASS_PHONE` behavior unless testing shows a gap:
   - Use a restricted phone-number layout.
   - Do not show `中`, `ABC`, or `EN` mode-switch keys.

2. Change `TYPE_CLASS_NUMBER` to use a restricted numeric layout instead of `MODE_TEXT + isSymbol=true`:
   - No Chinese/English mode key.
   - Include digits, delete, done/enter, and only number-relevant punctuation such as decimal point and sign when appropriate.
   - Consider `TYPE_NUMBER_FLAG_DECIMAL`, `TYPE_NUMBER_FLAG_SIGNED`, and `TYPE_NUMBER_VARIATION_PASSWORD` before deciding which punctuation/actions are visible.

3. Change `TYPE_CLASS_DATETIME` to use a restricted date/time layout instead of the general symbol keyboard:
   - No Chinese/English mode key.
   - Include digits plus date/time separators such as `/`, `-`, `:`, maybe space depending on practical field behavior.

4. Do not apply remembered Chinese/English mode to restricted number/date-time/phone/password/email fields.

5. Treat URL/URI separately:
   - Product direction may allow URL/URI fields to behave closer to normal text because users often type Chinese search keywords in address bars.
   - This should not imply that number/date-time fields allow Chinese or alphabet mode switching.

## Follow-up questions

- Should number and date-time share one restricted layout, or should they use separate `number` and `datetime` XML layouts?
- Which number flags should affect the visible keys?
  - `TYPE_NUMBER_FLAG_DECIMAL`
  - `TYPE_NUMBER_FLAG_SIGNED`
  - `TYPE_NUMBER_VARIATION_PASSWORD`
- For date/time fields, which separators are needed in real Android apps/WebViews: `:`, `/`, `-`, `.`, space?
- Should `inputmode=numeric`, `inputmode=decimal`, and `inputmode=tel` in Android WebView/Chrome map to the same behavior as native `TYPE_CLASS_NUMBER` / `TYPE_CLASS_PHONE`, or is this browser-dependent and only testable manually?

## Verification plan

Manual verification should use both native Android fields and the local/static web field test page for browser/WebView behavior.

Verify these cases with LIME enabled:

- Normal text: remembered Chinese/English mode still works.
- URL/URI: follows the chosen product behavior for URL/search use.
- Email/password: remains English/inputType-specific.
- Phone: shows restricted phone-number layout and no mode switch.
- Number: shows restricted numeric layout and no mode switch.
- Date/time: shows restricted date/time layout and no mode switch, when the browser/app actually invokes the IME instead of a native picker.
- Array 10 normal Chinese layout: still has the normal mode-switch behavior for Chinese/English transitions.

Suggested web fields to test:

- `<input type="tel">`
- `<input type="number">`
- `<input type="text" inputmode="numeric">`
- `<input type="text" inputmode="decimal">`
- `<input type="text" inputmode="tel">`
- `<input type="url">`
- `<input type="email">`
- `<input type="password">`
