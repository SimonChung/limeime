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
    mEnglishOnly = true;
    mKeyboardSwitcher.setKeyboardMode(activeIM, LIMEKeyboardSwitcher.MODE_PHONE,
            mImeOptions, false, false, false);
    break;

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
- `TYPE_CLASS_NUMBER` currently uses the restricted phone-number layout. `TYPE_CLASS_DATETIME` still has a fallback `MODE_TEXT` with `isSymbol=true` code path, but observed Android/browser date-time fields show the system date/time picker instead of invoking LIME.
- LIME currently does not inspect `TYPE_NUMBER_VARIATION_*` separately; all number variations go through the same number class path.
- URL/email/password remain text-class variations. Email and password should continue to use inputType-specific English layouts; URL/URI is a separate product decision because address bars are often used for Chinese search keywords.

## Likely root cause / design gap

The original implementation treated number fields as generic English symbol entry instead of a distinct restricted numeric context. This made number fields show a broad symbol layout with mode switching, even though these fields should not allow arbitrary alphabet or Chinese entry. Date/time is different in practice: Android normally shows the system date/time picker, so LIME does not need a dedicated date/time layout unless a host app/WebView is found that actually invokes the IME for `TYPE_CLASS_DATETIME`.

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

3. Leave `TYPE_CLASS_DATETIME` unchanged for now:
   - Observed Android date/time controls show the system picker, so LIME is normally bypassed.
   - Revisit only if a real host app/WebView invokes LIME for `TYPE_CLASS_DATETIME` instead of using the picker.

4. Do not apply remembered Chinese/English mode to restricted number/date-time/phone/password/email fields.

5. URL/URI — keep current behaviour, drop unused dedicated assets:
   - Decision: URL/URI fields stay `mEnglishOnly = true` with the IM-family English layout (`lime_english_number*` / `lime_english*`, or `lime_abc*` for the WB IM) loaded on both Android and iOS. The `中` mode key on those layouts already lets users switch into the active Chinese IM for keyword search, so URL fields don't need a special "treat as normal text" branch.
   - Rationale: modern browser address bars do see Chinese keyword search, but the existing IM-family English layout already exposes a one-tap path into the IM via `中`. Forcing the active IM layout on URL focus (the previously contemplated "URL = normal text" plan) was withdrawn — that would have also dropped prediction-off and the persisted-mode bypass for URL fields, which are useful defaults.
   - This decision does **not** imply that number/date-time fields allow Chinese or alphabet mode switching — those remain restricted (see items 2 and 3).
   - Cleanup: the never-loaded `lime_url.xml` / `lime_url*.json` assets are deleted, along with the `R.xml.lime_url` switch-case entry in `LIMEKeyboardSwitcher.getKeyboardXMLID` and the matching `LimeIME.xcodeproj/project.pbxproj` entries. `lime_email.xml` / `lime_email*.json` get the same cleanup since `MODE_EMAIL` routes to the same `lime_english_number*` family.

6. Related iOS Enter-key adaptation:
   - `KeyboardViewController.initOnStartInput` now copies `textDocumentProxy.returnKeyType` into `KeyboardView.returnKeyType`, so LIME can adapt the Enter key to the focused field's action hint.
   - `KeyboardView.enterKeyOverride(for:)` changes the Enter key content without adding new layout JSON: search/google/yahoo use the `magnifyingglass` icon, `go` uses an arrow icon, and send/next/join/done/route/continue use matching text labels.
   - When an override is active, `KeyboardView.applyButtonStyle` paints the Enter key `.systemBlue` and `styleKeyContent` forces the icon/text foreground to white, matching Apple's primary action key treatment.
   - `KeyboardViewController.textDidChange` compares the current `keyboardType` and `returnKeyType` with the last adapted values. If either changes while the keyboard remains visible, it re-runs `initOnStartInput` so both layout selection and Enter-key icon/color/text update immediately for the newly focused field.

## Follow-up questions

- Should number and decimal keep sharing the existing `phone_number.xml` route, or should a later pass create a dedicated numeric XML with a different key set?
- Which number flags should affect the visible keys?
  - `TYPE_NUMBER_FLAG_DECIMAL`
  - `TYPE_NUMBER_FLAG_SIGNED`
  - `TYPE_NUMBER_VARIATION_PASSWORD`
- If a real Android app/WebView invokes LIME for `TYPE_CLASS_DATETIME`, which separators are needed: `:`, `/`, `-`, `.`, space?
- Should `inputmode=numeric`, `inputmode=decimal`, and `inputmode=tel` in Android WebView/Chrome map to the same behavior as native `TYPE_CLASS_NUMBER` / `TYPE_CLASS_PHONE`, or is this browser-dependent and only testable manually?
- Which iOS host fields reliably expose `.search`, `.go`, `.send`, `.done`, etc. through `textDocumentProxy.returnKeyType`, especially in Safari/WebView where HTML `enterkeyhint` behavior may vary?

## Verification plan

Manual verification should use both native Android fields and the local/static web field test page for browser/WebView behavior.

Verify these cases with LIME enabled:

- Normal text: remembered Chinese/English mode still works.
- URL/URI: opens English-only with the IM-family English layout. The `中` mode key remains present, so users can switch into the active Chinese IM for keyword search.
- Email/password: remains English/inputType-specific.
- Phone: shows restricted phone-number layout and no mode switch.
- Number: shows restricted numeric layout and no mode switch.
- Date/time: shows the Android system date/time picker; no LIME keyboard change is expected unless a browser/app actually invokes the IME instead of a native picker.
- Array 10 normal Chinese layout: still has the normal mode-switch behavior for Chinese/English transitions.
- iOS Enter key: URL/search fields show a magnifier or Go arrow when the host exposes those return-key hints; Send/Next/Done-style fields show the matching text label. Non-default actions use the blue primary-action Enter key with white icon/text, while default Enter keeps the normal modifier styling.
- iOS field switching: moving focus between fields with different `keyboardType` or `returnKeyType` while the keyboard remains visible re-adapts the layout and Enter key without dismissing/reopening the keyboard.

Suggested web fields to test:

- `<input type="tel">`
- `<input type="number">`
- `<input type="text" inputmode="numeric">`
- `<input type="text" inputmode="decimal">`
- `<input type="text" inputmode="tel">`
- `<input type="url">`
- `<input type="email">`
- `<input type="password">`
