# Issue #74: Android remembered Chinese/English mode and restricted numeric field layouts

## Problem statement

Reporter SmithCCho asks how Android remembered Chinese/English mode should interact with field-specific input types. They use Array 10/行列10 with a numeric/phone-style layout for Chinese input, so switching to an English keyboard in URL or numeric fields can be inconvenient for one-handed input and mixed Chinese/number workflows.

The latest reporter clarification narrows one concrete request: since LIME already has a phone-number layout, phone and number input fields should be able to open a LIME numeric/phone-style layout instead of an English keyboard with a number row. Maintainer direction in comment `4509415304` accepts this direction with an important restriction: number/phone-only field layouts should not expose `中` or `abc` mode keys because those fields should not accept English or Chinese input. Number/date-time fields are restricted input contexts and should not expose a mode key that lets users switch into alphabet or Chinese input if the target field should not accept those characters.



After testing APK `6.1.10`, the reporter confirmed that number, decimal, and phone fields now open only the LIME phone-number keyboard. APK `6.1.11` changed URL/search fields to behave like normal text and follow remembered Chinese/English mode. The reporter then confirmed that the URL field does follow remembered mode, but initially clarified that this still did not match their preferred workflow: after using English in another text field, a browser URL/search field also opens in English, while they would prefer URL/search to default to Chinese or otherwise not inherit the previous English state the way restricted number fields ignore remembered mode. Maintainer follow-up clarified the trade-off, and the reporter later accepted the shipped behavior as sufficient to close #74.

Reporter later confirmed the shipped 6.1.11 behavior is acceptable and said the issue can be closed in comment `4527392181`: URL/search fields now follow remembered Chinese/English mode like normal text, and turning off `記憶中英模式` matches the reporter's preferred always-Chinese starting behavior. Treat #74 as reporter-confirmed completed for the Android APK-scoped behavior. Any future change such as a separate URL/search preference should be a new product decision, not an active #74 retest watch.

Issue URL: https://github.com/lime-ime/limeime/issues/74

Public field test page for reporter verification:
https://lime-ime.github.io/limeime/docs/keyboard-type-field-test.html

Relevant comments:

- Maintainer explanation: https://github.com/lime-ime/limeime/issues/74#issuecomment-4505846029
- Reporter numeric/phone follow-up: https://github.com/lime-ime/limeime/issues/74#issuecomment-4508837104
- Maintainer numeric-keyboard direction: https://github.com/lime-ime/limeime/issues/74#issuecomment-4509415304
- Reporter confirmation of numeric/phone restricted-keyboard behavior and remaining URL request: https://github.com/lime-ime/limeime/issues/74#issuecomment-4523823506
- Reporter 6.1.11 URL/search retest feedback: https://github.com/lime-ime/limeime/issues/74#issuecomment-4527330457
- Maintainer clarification/question after that retest: https://github.com/lime-ime/limeime/issues/74#issuecomment-4527361251
- Reporter closure confirmation: https://github.com/lime-ime/limeime/issues/74#issuecomment-4527392181
- Closing acknowledgement: https://github.com/lime-ime/limeime/issues/74#issuecomment-4527405069

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

Reporter-confirmed APK behavior from comment `4523823506`: APK `6.1.10` now routes number, decimal, and phone fields to the LIME phone-number keyboard for the reporter.

Observed implications:

- `TYPE_CLASS_PHONE` uses `MODE_PHONE`, which maps to `phone_number.xml` in `LIMEKeyboardSwitcher`; that restricted phone-number layout has no `中` / `ABC` / `EN` mode-switch key.
- `TYPE_CLASS_NUMBER` currently uses the restricted phone-number layout. `TYPE_CLASS_DATETIME` still has a fallback `MODE_TEXT` with `isSymbol=true` code path, but observed Android/browser date-time fields show the system date/time picker instead of invoking LIME.
- LIME currently does not inspect `TYPE_NUMBER_VARIATION_*` separately; all number variations go through the same number class path.
- URL/email/password remain text-class variations. Email and password should continue to use inputType-specific English layouts. APK `6.1.11` changed URL/URI and search to behave like normal text so remembered Chinese/English mode applies; reporter feedback in comment `4527330457` says this behavior is technically working but may still be undesirable when the remembered state is English from a previous normal text field.

## Root cause / design gap addressed

Before the scoped 6.1.10 fix, number fields were treated as a generic English/symbol entry context instead of a distinct restricted numeric context. That could expose a broad symbol layout and mode switching even though these fields should not allow arbitrary alphabet or Chinese entry. Date/time is different in practice: Android normally shows the system date/time picker, so LIME does not need a dedicated date/time layout unless a host app/WebView is found that actually invokes the IME for `TYPE_CLASS_DATETIME`.

There is also a naming/product distinction between two phone-like layouts:

- Restricted Android phone field layout: `phone_number.xml`, currently used by `TYPE_CLASS_PHONE`, no mode switch.
- General T9/phone-style Chinese/English layouts such as `phone.xml` / `phone_shift.xml`, where mode switching can make sense (`ABC` on Chinese side, `中` on English side).

For restricted Android input fields, the safer behavior is to hide mode switching.

## Implementation status and product decision

Keep field-specific restrictions separate from general Chinese/English IM switching. The number/decimal/phone field part is shipped and reporter-confirmed in APK `6.1.10`; URL/address-bar/search behavior was shipped as normal text in APK `6.1.11`, and the reporter accepted that behavior as sufficient to close #74 in comment `4527392181`:

1. Preserve current `TYPE_CLASS_PHONE` behavior unless testing shows a gap:
   - Use a restricted phone-number layout.
   - Do not show `中`, `ABC`, or `EN` mode-switch keys.

2. Shipped in APK `6.1.10`: `TYPE_CLASS_NUMBER` uses a restricted numeric/phone-style layout instead of the old broad symbol path:
   - No Chinese/English mode key.
   - Includes digits and phone/number-relevant controls.
   - Reporter confirmed the scoped behavior for number, decimal, and phone fields in comment `4523823506`.
   - Future refinement can still consider whether `TYPE_NUMBER_FLAG_DECIMAL`, `TYPE_NUMBER_FLAG_SIGNED`, and `TYPE_NUMBER_VARIATION_PASSWORD` should affect visible punctuation/actions.

3. Leave `TYPE_CLASS_DATETIME` effectively unchanged for now:
   - Observed Android date/time controls show the system picker, so LIME is normally bypassed.
   - Revisit only if a real host app/WebView invokes LIME for `TYPE_CLASS_DATETIME` instead of using the picker.

4. Do not apply remembered Chinese/English mode to restricted number/date-time/phone/password/email fields.

5. URL/URI/search — shipped and reporter-accepted behavior:
   - APK `6.1.11` treats URL/address-bar/search fields like normal text on Android: when `記憶中英模式` / persisted language mode is on, these fields restore the remembered Chinese/English mode instead of forcing English; when persisted language mode is off, they start in Chinese mode like normal text.
   - Reporter retest comment `4527330457` confirmed this shipped behavior and raised a possible alternate preference: after typing English elsewhere, a browser URL/search field also opens in English. Maintainer comment `4527361251` clarified why number fields are different and asked whether URL fields should always start Chinese regardless of remembered state.
   - Reporter follow-up comment `4527392181` accepted the current behavior and said the issue can be closed: the original forced-English URL behavior is resolved, and disabling `記憶中英模式` fits the reporter's always-Chinese preference.
   - Treat URL/search as resolved for #74. A future separate URL/search preference or always-Chinese rule remains an optional product enhancement only if Jeremy/maintainer opens that scope later.
   - Any URL/search decision does **not** imply that number/date-time fields allow Chinese or alphabet mode switching — those remain restricted (see items 2 and 3).
   - Optional code cleanup only if not already handled in the relevant commits: verify whether never-loaded `lime_url.xml` / `lime_url*.json` and `lime_email.xml` / `lime_email*.json` assets plus matching switch/project references remain. Do not treat that cleanup as part of the reporter-confirmed Android behavior unless a specific commit/build proves it.

6. Related iOS Enter-key adaptation (out of scope for #74 closure unless separately verified):
   - Prior notes mention iOS return-key adaptation work in `KeyboardViewController` / `KeyboardView`, but #74's reporter confirmation and closure are Android APK-scoped.
   - Do not claim #74 verified iOS behavior, TestFlight availability, or iOS field-switching parity unless a separate iOS build/commit and verification thread explicitly confirms it.

## Follow-up status

Reporter SmithCCho confirmed in comment `4527392181` that #74 can be closed after APK `6.1.11`: the original URL forced-English behavior is resolved by URL/search following normal remembered Chinese/English mode, and disabling `記憶中英模式` matches the reporter's preferred always-Chinese start. Numeric/decimal/phone behavior was already confirmed in APK `6.1.10`. #74 is resolved/closed as reporter-accepted for Android APK behavior; closing acknowledgement: https://github.com/lime-ime/limeime/issues/74#issuecomment-4527405069. Future URL/search preference changes are out of scope unless reopened or tracked separately.

## Optional future work / out-of-scope questions

- Reporter accepted the 6.1.11 URL/search remembered-mode behavior in comment `4527392181` and said the issue can be closed. No active reporter clarification is pending.
- Optional future product question only if reopened or separately requested: should URL/search get a separate always-Chinese/default-Chinese preference?
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

Public test page for reporter/manual verification:
https://lime-ime.github.io/limeime/docs/keyboard-type-field-test.html

Verify these cases with LIME enabled:

- Normal text: remembered Chinese/English mode still works.
- URL/URI/search: APK `6.1.11` follows normal text behavior. Reporter confirmed it restores remembered Chinese/English mode and then accepted that behavior as sufficient to close #74 in comment `4527392181`; no active #74 URL/search retest watch remains.
- Email/password: remains English/inputType-specific.
- Number/decimal/phone fields: reporter confirmed on APK `6.1.10` that these now show only the LIME phone-number keyboard; re-verify only as a regression check or when changing restricted numeric layouts again.
- Date/time: shows the Android system date/time picker; no LIME keyboard change is expected unless a browser/app actually invokes the IME instead of a native picker.
- Array 10 normal Chinese layout: still has the normal mode-switch behavior for Chinese/English transitions.
- iOS Enter key / field switching: out of scope for #74's reporter-confirmed Android closure unless a separate iOS build and verification path is requested.

Suggested web fields to test:

- `<input type="tel">`
- `<input type="number">`
- `<input type="text" inputmode="numeric">`
- `<input type="text" inputmode="decimal">`
- `<input type="text" inputmode="tel">`
- `<input type="url">`
- `<input type="email">`
- `<input type="password">`
