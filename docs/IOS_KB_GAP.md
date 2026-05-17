# iOS Keyboard — Implementation Gap Closure

Status: PLAN (no code yet)
Scope: gap between the design plan in [IOS_VOICE_INPUT.md](IOS_VOICE_INPUT.md) and the current state of `LimeIME-iOS/`.
Companion: this doc lists **what to build, in what order**. The "why / how" is in [IOS_VOICE_INPUT.md](IOS_VOICE_INPUT.md), [IPAD_KEYBOARD.md](IPAD_KEYBOARD.md), [CANDI_LAYOUT.md](CANDI_LAYOUT.md), and [IOS_FULL_PREMISSION.md](IOS_FULL_PREMISSION.md).

---

## 1. What's already in place

Audit of the live source — anchor for "do not re-do these":

| Capability | Location | State |
| --- | --- | --- |
| Candi-bar emoji button (left edge) | [CandidateBarView.swift:23, :659](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) | Fully wired — `emojiTapped` → `candidateBarViewDidRequestEmoji` → `KeyboardViewController.showEmojiPanel()` |
| Full Access entitlement | [LimeKeyboard/Info.plist:33](../LimeIME-iOS/LimeKeyboard/Info.plist), [project.yml:124](../LimeIME-iOS/project.yml) | `RequestsOpenAccess = YES` |
| iPad bottom-row template | `lime_*_ipad.json` (~30 files in [Layouts/](../LimeIME-iOS/LimeKeyboard/Layouts/)) | 7 cells: `[globe(8), .?123(10), 中(8), space(49), mic(7), .?123(10), dismiss(8)]` |
| iPad mic key slot | All `*_ipad.json` bottom rows | Placeholder `code = -99`, `icon = mic`, `widthPercent = 7` — slot exists, no dispatch |
| Space-trim already done on iPad | All `*_ipad.json` bottom rows | `space.widthPercent = 49.0` |
| iPad IM-toggle on home row | [IPAD_KEYBOARD.md §4.2.1](IPAD_KEYBOARD.md) | `注音` / `abc` modifier already specified as MOD_IM at left of asdf row |

Implication: the layout-side scaffolding is **most of the way there**.
The remaining gaps are (a) inserting an emoji cell left of space and
ensuring mic is right of space on every iPad bottom row (without
touching `中`, `.?123`, or any other existing cell), (b) the
speech-recognition pipeline, and (c) the candi-bar mic for
home-button iPhones.

---

## 2. Gap inventory

Ordered by phase below. Each row is one self-contained unit of work.

| # | Gap | Files touched | Phase |
| --- | --- | --- | --- |
| G1 | Add `LimeKeyCode.voiceInput = -220` | `Shared/Models/KeyLayout.swift` | 1 |
| G2a | **Chinese IM iPad layouts** (script-generated): update `IPAD_BOTTOM_ROW` in [scripts/build_ipad_layouts.py:24-34](../scripts/build_ipad_layouts.py) to insert `emoji` left of space and move `mic` right of space; regenerate 24 IM JSONs. Don't touch `.?123` or any IM-toggle. | [scripts/build_ipad_layouts.py](../scripts/build_ipad_layouts.py) + regenerated `lime_phonetic_ipad*.json`, `lime_array*_ipad*.json`, `lime_cj*_ipad*.json`, `lime_dayi*_ipad*.json`, `lime_et26_ipad*.json`, `lime_et_41_ipad*.json`, `lime_hs_ipad*.json`, `lime_hsu_ipad*.json`, `lime_wb_ipad*.json` | 1 |
| G2b | **English / ABC / symbol / URL / email iPad layouts** (hand-authored): per-file edit. Insert `emoji` immediately left of `space`; ensure `mic` is immediately right of `space` (move it if currently left). **Do not** touch `中` (-10), `.?123` / `abc` (-2), `globe` (-200), or `dismiss` (-3) cells. Trim `space.widthPercent` to absorb the new emoji cell. | `lime_english_ipad.json`, `lime_english_ipad_shift.json`, `lime_english_number_ipad.json`, `lime_english_number_ipad_shift.json`, `lime_abc_ipad.json`, `lime_abc_ipad_shift.json`, `symbols1_ipad.json`, `symbols2_ipad.json`, `symbols3_ipad.json`, `lime_email_ipad.json`, `lime_url_ipad.json` | 1 |
| G3 | Replace mic placeholder `code: -99` with `code: -220` everywhere it appears (post G2a/G2b) | All `*_ipad.json` containing the mic cell | 1 |
| G5 | KeyboardViewController dispatch: `case LimeKeyCode.voiceInput.rawValue: startVoiceInput()` (no-op stub in phase 1; real call in phase 3) | [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) `onKey` switch | 1 |
| G6 | Add `micButton` to CandidateBarView (right zone, mirrors `emojiButton`) | [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) | 2 |
| G7 | Visibility gating helpers (`shouldShowCandiBarMic`, `shouldShowCandiBarEmoji`) — gate emoji off on iPad | [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) `rebuildButtons` | 2 |
| G8 | Face ID detection via `LAContext.biometryType` (cached) | [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) or new `Shared/DeviceCapabilities.swift` | 2 |
| G9 | Plumb `isOnPad` from controller into CandidateBarView | [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) + [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) initializer | 2 |
| G10 | New delegate method `candidateBarViewDidRequestVoice(_:)` | [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) + [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) | 2 |
| G11 | Plist mic + speech keys (extension + host) | [LimeKeyboard/Info.plist](../LimeIME-iOS/LimeKeyboard/Info.plist), `LimeIME/Info.plist`, [project.yml](../LimeIME-iOS/project.yml) | 3 |
| G12 | `VoiceInputController.swift` — SFSpeechRecognizer + AVAudioEngine lifecycle, permission gate | NEW `LimeIME-iOS/LimeKeyboard/VoiceInputController.swift` | 3 |
| G13 | Wire controller into KeyboardViewController; route partial → composing strip; final → `insertText` | [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) | 3 |
| G14 | Composing-strip red-tint state for voice partials | [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift) `showComposingPopup` variant | 3 |
| G15 | Pre-A12 disable + lime_toast on tap | `VoiceInputController` + controller | 4 |
| G16 | Settings: locale picker + permission status row | [PreferencesTabView.swift](../LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift), [LIMEPreferenceManager.swift](../LimeIME-iOS/Shared/Preferences/LIMEPreferenceManager.swift) | 4 |
| G17 | Layout-shape unit tests (emoji left, voice right, sum-100, voice code) | [LimeTests/KeyboardViewControllerTest.swift](../LimeIME-iOS/LimeTests/KeyboardViewControllerTest.swift) | 1 then 4 |

`(NEW)` = new file. Encoding rules per global CLAUDE.md §5: `.swift` ⇒ UTF-8 with BOM. `.json` / `.plist` ⇒ UTF-8 without BOM. The two new doc-targeted files (`IOS_VOICE_INPUT.md`, this file) are `.md` ⇒ UTF-8 with BOM when they contain Chinese.

Out-of-scope, tracked elsewhere:

| Item | Tracking doc |
| --- | --- |
| `*_ipad_narrow.json` files for narrow iPad tier | [IPAD_KB_SIZE_TIERS.md](IPAD_KB_SIZE_TIERS.md) |
| `build_ipad_layouts.py` script | [IPAD_KB_SIZE_TIERS.md §6](IPAD_KB_SIZE_TIERS.md) — script will absorb the new 7-key template when it lands |
| Voice command parsing (comma / 句號 / newline) | [IOS_VOICE_INPUT.md §10.2](IOS_VOICE_INPUT.md) out-of-scope list |
| Cloud recognition fallback | [IOS_VOICE_INPUT.md §11](IOS_VOICE_INPUT.md) — App Store policy blocks |

---

## 3. Phase 1 — Layout + key-code wiring

Goal: iPad bottom row visually matches the final spec. Mic tap is a
logged no-op (no recognition yet). Phone behavior unchanged.

### 3.1 KeyCode enum

Edit `LimeIME-iOS/Shared/Models/KeyLayout.swift`:

```swift
enum LimeKeyCode: Int {
    // ... existing cases ...
    case emojiPanel = -201
    // ... emoji category codes -202..-212 ...

    case voiceInput = -220   // NEW
}
```

Place after the emoji range, leave gap before any future allocation.

### 3.2 iPad bottom-row updates — two paths

The iPad bottom row currently has **two distinct shapes** in the
codebase. Each shape gets the same logical change: **insert** an
`emojiPanel` (-201) cell immediately left of `space`, and **ensure**
the `mic` cell is immediately right of `space` (move it if currently
left). **Never touch** any existing `中` (-10), `.?123` / `abc` (-2),
`globe` (-200), or `dismiss` (-3) cell. `space.widthPercent` is the
only existing cell that changes — it trims by exactly the new emoji
cell's width (7).

The unified rule applies to **all** iPad layouts; the **mechanism**
differs between Chinese IM (script-regenerated) and the hand-authored
English / ABC / symbol / context layouts.

**`.?123` label normalization (consistency check, all iPad layouts):**
while touching the bottom row, also normalize the `code: -2` cell's
`label` field. Current state is mixed — some files store the literal
`".?123"`, others store the Android-style reference
`"@string/label_symbol_key"`. For iPad layout consistency, the
`label` must be the **literal** `".?123"` on every iPad `code: -2`
cell that toggles into symbols mode. Exception: on
`symbols1/2/3_ipad.json` the same `-2` cell toggles **out** of
symbols and must carry the literal `"abc"` label (already the case
today — leave it). This normalization applies to both the script
template (§3.2.a) and the hand-authored families (§3.2.b).

#### 3.2.a Chinese IM iPad layouts — edit the generator

Source of truth: [scripts/build_ipad_layouts.py:24-34](../scripts/build_ipad_layouts.py).
This `IPAD_BOTTOM_ROW` constant produces every Chinese-IM `*_ipad.json`
listed in the script's `JOBS` table (24 files: phonetic, array,
array_number, cj, cj_number, dayi, dayi_sym, et26, et_41, hs, hsu, wb,
plus each `_shift` variant). Chinese IM layouts do **not** have `中`
in the bottom row — the IM-toggle (`abc`) lives on the asdf-row left
modifier per [IPAD_KEYBOARD.md §4.2.1](IPAD_KEYBOARD.md), inserted by
`prepend_abc_modifier`. So this path only needs the mic move + emoji
insert.

Current template (6 keys, sums to 100):

```python
# globe(8) | .?123(10) | mic(7) | space(57) | .?123(10) | dismiss(8)
```

New template (7 keys, sums to 100):

```python
# globe(8) | .?123(10) | emoji(7) | space(50) | mic(7) | .?123(10) | dismiss(8)
IPAD_BOTTOM_ROW = {
    "isBottomRow": True,
    "keys": [
        {"code": -200, "label": "globe", "sublabel": "", "widthPercent":  8.0, "icon": "globe",        "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": -100},
        {"code":   -2, "label": ".?123", "sublabel": "", "widthPercent": 10.0, "icon": "",             "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode":    0},
        {"code": -201, "label": "",      "sublabel": "", "widthPercent":  7.0, "icon": "face.smiling", "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode":    0},   # NEW emoji
        {"code":   32, "label": "",      "sublabel": "", "widthPercent": 50.0, "icon": "space.bar",    "isModifier": False, "isRepeatable": True,  "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode":    0},   # TRIMMED 57→50
        {"code": -220, "label": "",      "sublabel": "", "widthPercent":  7.0, "icon": "mic",          "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode":    0},   # MOVED + RECODED (-99→-220)
        {"code":   -2, "label": ".?123", "sublabel": "", "widthPercent": 10.0, "icon": "",             "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode":    0},
        {"code":   -3, "label": "",      "sublabel": "", "widthPercent":  8.0, "icon": "keyboard.chevron.compact.down", "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": -100},
    ]
}
```

Verify the comment block at lines 16-23 is updated to reflect the new
key order and the 8 + 10 + 7 + 50 + 7 + 10 + 8 = 100 sum.

After the constant changes, run:

```bash
python3 scripts/build_ipad_layouts.py
```

This regenerates all 24 Chinese-IM JSONs. The content rows above the
bottom row are untouched (`prepend_abc_modifier`, `append_semicolon_key`,
etc. all operate on non-bottom rows). Diff every regenerated file to
confirm the only change is the bottom row.

#### 3.2.b Hand-authored iPad layouts — per-file edit

These files are **not** in the script's `JOBS` table and must be
edited directly. They fall into three shape families:

**Family A** — `lime_english_ipad.json`, `lime_english_ipad_shift.json`,
`lime_english_number_ipad.json`, `lime_english_number_ipad_shift.json`,
`lime_abc_ipad.json`, `lime_abc_ipad_shift.json`. Current bottom row:

```
globe(8) | .?123(10) | 中(8) | space(49) | mic(7) | .?123(10) | dismiss(8)   = 100
```

Mic is already right of space. 中 stays untouched. **Insert** emoji
between 中 and space; **trim** space from 49 → 42:

```
globe(8) | .?123(10) | 中(8) | emoji(7) | space(42) | mic(7) | .?123(10) | dismiss(8)   = 100
                                ▲                       ▲
                              INSERT                 RECODE -99 → -220
```

**Family B** — `symbols1_ipad.json`, `symbols2_ipad.json`,
`symbols3_ipad.json`. Current bottom row (verified against
`symbols1_ipad.json`):

```
globe(8) | 中(10) | mic(7) | space(57) | abc(10) | dismiss(8)   = 100
```

Mic is left of space; 中 stays untouched. **Move** mic to right of
space; **insert** emoji left of space; **trim** space from 57 → 50:

```
globe(8) | 中(10) | emoji(7) | space(50) | mic(7) | abc(10) | dismiss(8)   = 100
                     ▲                       ▲
                   INSERT                  MOVED + RECODE -99 → -220
```

**Family C** — `lime_email_ipad.json`, `lime_url_ipad.json` (and
anything else whose bottom row currently matches the script's
6-key Chinese-IM shape). Current bottom row:

```
globe(8) | .?123(10) | mic(7) | space(57) | .?123(10) | dismiss(8)   = 100
```

Apply the same change as the script template — these become
identical to the regenerated Chinese-IM bottom row:

```
globe(8) | .?123(10) | emoji(7) | space(50) | mic(7) | .?123(10) | dismiss(8)   = 100
                         ▲                       ▲
                       INSERT                 MOVED + RECODE -99 → -220
```

To audit any layout family not enumerated above, run:

```bash
python3 -c "
import json, glob
for f in sorted(glob.glob('LimeIME-iOS/LimeKeyboard/Layouts/*_ipad*.json')):
    d = json.load(open(f))
    b = next((r for r in d['rows'] if r.get('isBottomRow')), None)
    if not b: continue
    codes = [k['code'] for k in b['keys']]
    print(f.split('/')[-1], codes)
"
```

Any shape not matching Family A / B / C requires a per-file decision
before editing.

### 3.3 Controller dispatch stub

In [KeyboardViewController.swift](../LimeIME-iOS/LimeKeyboard/KeyboardViewController.swift) `onKey(primaryCode:)`,
add to the switch:

```swift
case LimeKeyCode.voiceInput.rawValue:
    startVoiceInput()              // Phase 1: stub method below
```

Stub:

```swift
private func startVoiceInput() {
    // Phase 1: no-op stub. VoiceInputController wires in phase 3.
    LimeToast.show("語音輸入即將推出", duration: 1.2)
}
```

### 3.4 Layout-shape unit tests

Add to [KeyboardViewControllerTest.swift](../LimeIME-iOS/LimeTests/KeyboardViewControllerTest.swift):

```swift
func testIPadBottomRowFlanksSpaceWithEmojiLeftAndVoiceRight() throws {
    let iPadLayouts = ["lime_english_ipad", "lime_phonetic_ipad",
                       "lime_array_ipad", "lime_cj_ipad",
                       "lime_dayi_ipad", "symbols1_ipad"]
    for id in iPadLayouts {
        let layout = try loadKeyboardLayoutFixture(id)
        let bottom = try XCTUnwrap(layout.rows.first(where: { $0.isBottomRow }))
        let codes  = bottom.keys.map(\.code)
        let spaceIx = try XCTUnwrap(codes.firstIndex(of: 32))

        XCTAssertEqual(codes[spaceIx - 1], LimeKeyCode.emojiPanel.rawValue,
                       "\(id): emoji should be immediately left of space")
        XCTAssertEqual(codes[spaceIx + 1], LimeKeyCode.voiceInput.rawValue,
                       "\(id): voice should be immediately right of space")
    }
}

func testIPadBottomRowSumsToHundredPercent() throws {
    for id in iPadLayouts {
        let layout = try loadKeyboardLayoutFixture(id)
        let bottom = try XCTUnwrap(layout.rows.first(where: { $0.isBottomRow }))
        let sum    = bottom.keys.map(\.widthPercent).reduce(0, +)
        XCTAssertEqual(sum, 100.0, accuracy: 0.01)
    }
}

func testKeyLayoutHasVoiceInputCode() {
    XCTAssertEqual(LimeKeyCode.voiceInput.rawValue, -220)
}
```

### 3.5 Phase 1 done when

- `scripts/build_ipad_layouts.py IPAD_BOTTOM_ROW` updated; script re-run; all 24 Chinese-IM JSONs regenerated cleanly (no diff outside the bottom row).
- Family A / B / C hand-authored files manually edited per §3.2.b.
- Grep for `"code": -99` in `LimeIME-iOS/LimeKeyboard/Layouts/` returns 0 matches.
- Grep for `"@string/label_symbol_key"` in all `*_ipad*.json` returns 0 matches (all normalized to literal `.?123` or `abc` per §3.2 consistency rule).
- No `中` / `.?123` / `globe` / `dismiss` cell was touched in any file (diff review) — except the **label-only** normalization `@string/label_symbol_key` → `.?123`, which is permitted and required.
- `LimeKeyCode.voiceInput = -220` present.
- Unit tests pass.
- Manual on iPad simulator (one English layout, one symbol layout, one Chinese IM layout): emoji icon shows left of space, mic icon
  right of space; tap mic → toast "語音輸入即將推出"; tap emoji →
  emoji panel opens (existing wiring already routes -201).

---

## 4. Phase 2 — Candi-bar mic + visibility gating

Goal: home-button iPhones (SE 2/3) show a mic button at the right
edge of the candi bar (mirror of emoji at left). iPad hides both
candi-bar accessory icons.

### 4.1 `CandidateBarView` mic button

Mirror the existing emoji button setup.

Add private state:

```swift
private let micButton      = UIButton(type: .system)
private let lastColumnGuide = UILayoutGuide()      // mirror of firstColumnGuide
```

Setup block (paste after the `emojiButton` setup, swap `firstColumnGuide`
for `lastColumnGuide`, swap `face.smiling` icon for `mic`,
`emojiTapped` for `micTapped`).

Constraints:

```swift
addLayoutGuide(lastColumnGuide)
NSLayoutConstraint.activate([
    lastColumnGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
    lastColumnGuide.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.1),
    lastColumnGuide.topAnchor.constraint(equalTo: topAnchor),
    lastColumnGuide.bottomAnchor.constraint(equalTo: bottomAnchor),

    micButton.centerXAnchor.constraint(equalTo: lastColumnGuide.centerXAnchor),
    micButton.centerYAnchor.constraint(equalTo: centerYAnchor,
                                        constant: composingStripHeight / 2),
    micButton.heightAnchor.constraint(equalTo: heightAnchor,
                                       constant: -composingStripHeight),
    micButton.widthAnchor.constraint(equalTo: lastColumnGuide.widthAnchor,
                                      multiplier: 0.80),
])
```

Tap handler:

```swift
@objc private func micTapped() {
    if feedbackVibration { impactFeedback.impactOccurred() }
    delegate?.candidateBarViewDidRequestVoice(self)
}
```

### 4.2 Visibility gating

Replace the single `emojiButton.isHidden = hasCandidates` line in
`rebuildButtons()` with the full gate:

```swift
let hasCandidates = !candidates.isEmpty
let allowEmoji    = !isOnPad
let allowMic      = shouldShowCandiBarMic

dismissButton.isHidden = !hasCandidates
emojiButton.isHidden   = hasCandidates  || !allowEmoji
moreButton.isHidden    = !hasCandidates
moreSep.isHidden       = !hasCandidates
micButton.isHidden     = hasCandidates  || !allowMic
```

### 4.3 Device-class plumbing

`CandidateBarView` needs `isOnPad` and a Face ID flag.

Option A (minimal): add an initializer parameter `isOnPad: Bool` set
by `KeyboardViewController` (which already has the `isOnPad`
computed property).

Option B (cleaner, recommended): create a small read-only struct
`DeviceCapabilities`:

```swift
// Shared/DeviceCapabilities.swift  (NEW)
import LocalAuthentication
import Speech

struct DeviceCapabilities {
    let isOnPad: Bool
    let hasSystemMicBar: Bool
    let supportsOnDeviceSpeech: Bool

    static func capture(isOnPad: Bool, locale: Locale) -> DeviceCapabilities {
        let ctx = LAContext()
        var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        let faceID = ctx.biometryType == .faceID

        let supports = SFSpeechRecognizer.supportsOnDeviceRecognition(for: locale)

        return DeviceCapabilities(
            isOnPad: isOnPad,
            hasSystemMicBar: faceID,
            supportsOnDeviceSpeech: supports
        )
    }
}
```

`KeyboardViewController.viewDidLoad` constructs one and passes it into
`CandidateBarView`. Re-capture on `traitCollectionDidChange` if `isOnPad`
flips (rare — iPhone-only app moved into iPad multitasking).

`CandidateBarView.shouldShowCandiBarMic`:

```swift
private var shouldShowCandiBarMic: Bool {
    guard let caps                                    else { return false }
    guard !caps.isOnPad                               else { return false }
    guard !caps.hasSystemMicBar                       else { return false }
    guard hostHasFullAccess                           else { return false }
    return caps.supportsOnDeviceSpeech
}
```

`hostHasFullAccess` reads from App Group UserDefaults
`keyboard_has_full_access` — already written by the keyboard at
launch per [IOS_FULL_PREMISSION.md](IOS_FULL_PREMISSION.md).

### 4.4 New delegate method

In `CandidateBarViewDelegate`:

```swift
protocol CandidateBarViewDelegate: AnyObject {
    // ... existing methods ...
    func candidateBarViewDidRequestVoice(_ view: CandidateBarView)
}
```

`KeyboardViewController` implements:

```swift
func candidateBarViewDidRequestVoice(_ view: CandidateBarView) {
    startVoiceInput()
}
```

Same `startVoiceInput()` stub as Phase 1. Real body lands in Phase 3.

### 4.5 Phase 2 done when

- iPhone SE simulator (or `LIME_FORCE_FACEID=0` env var) shows mic at
  right edge of candi bar when empty; tap → toast.
- iPhone 17 Pro simulator: no mic on candi bar.
- iPad simulator: no mic, no emoji on candi bar (both gated off).
- Mic + chevron never visible together (swap on candidate state).
- No regression to existing emoji button on iPhone.

---

## 5. Phase 3 — Speech recognition

Goal: tap mic → live recognition → text committed.

### 5.1 Info.plist additions

[LimeKeyboard/Info.plist](../LimeIME-iOS/LimeKeyboard/Info.plist) +
`LimeIME/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>萊姆輸入法需要麥克風以提供離線語音輸入；錄音不會離開您的裝置。</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>萊姆輸入法以裝置上的語音辨識將語音轉為文字；不會傳送音訊或文字至雲端。</string>
```

Mirror in [project.yml](../LimeIME-iOS/project.yml) under both targets'
`infoPlist:` sections so xcodegen regen doesn't drop them.

### 5.2 `VoiceInputController.swift`

NEW file at `LimeIME-iOS/LimeKeyboard/VoiceInputController.swift`.
Full design in [IOS_VOICE_INPUT.md §5](IOS_VOICE_INPUT.md). Public
shape:

```swift
protocol VoiceInputControllerDelegate: AnyObject {
    func voiceInputDidUpdatePartial(text: String)
    func voiceInputDidFinish(text: String)
    func voiceInputDidFail(_ reason: VoiceInputFailure)
    func voiceInputDidEnterState(_ state: VoiceInputController.State)
}

final class VoiceInputController {
    enum State { case idle, requestingPermission, listening, finalizing, error }
    enum Failure { case speechAuthDenied, micAuthDenied, engineError(Error),
                   notSupported, fullAccessMissing }

    weak var delegate: VoiceInputControllerDelegate?

    init(locale: Locale) { ... }
    func start() { ... }      // Permission gate then listen
    func stop()  { ... }      // Finalize partial as final
    func cancel(){ ... }      // Discard, no commit
}
```

Internals follow [IOS_VOICE_INPUT.md §5.2](IOS_VOICE_INPUT.md) — silence
timer 1.5 s, `requiresOnDeviceRecognition = true`, `taskHint =
.dictation`, `AVAudioSession.record + .duckOthers`.

### 5.3 Wire into KeyboardViewController

Replace stub `startVoiceInput()`:

```swift
private lazy var voiceInputController: VoiceInputController = {
    let locale = Locale(identifier:
        prefManager.string(forKey: "voice_input_locale") ?? "zh-TW")
    let c = VoiceInputController(locale: locale)
    c.delegate = self
    return c
}()

private func startVoiceInput() {
    guard hasFullAccess else {
        LimeToast.show("語音輸入需要允許完整取用", duration: 1.5)
        return
    }
    if mComposing.isEmpty == false {
        cancelComposing()   // Mutual exclusion per IOS_VOICE_INPUT §5.5
    }
    voiceInputController.start()
}
```

Delegate conformance:

```swift
extension KeyboardViewController: VoiceInputControllerDelegate {
    func voiceInputDidUpdatePartial(text: String) {
        candidateBar.showVoicePartial(text)
    }
    func voiceInputDidFinish(text: String) {
        textDocumentProxy.insertText(text)
        candidateBar.hideVoicePartial()
    }
    func voiceInputDidFail(_ reason: VoiceInputController.Failure) {
        candidateBar.hideVoicePartial()
        LimeToast.show(reason.userMessage, duration: 2.0)
    }
    func voiceInputDidEnterState(_ state: VoiceInputController.State) {
        candidateBar.setMicListening(state == .listening)
    }
}
```

### 5.4 Composing-strip voice partial mode

Add to [CandidateBarView.swift](../LimeIME-iOS/LimeKeyboard/CandidateBarView.swift):

```swift
func showVoicePartial(_ text: String) {
    composingLabel.text = text
    composingLabel.textColor = .systemRed
    composingLabel.isHidden = false
    isShowingVoicePartial = true
}
func hideVoicePartial() {
    isShowingVoicePartial = false
    composingLabel.textColor = palette.composingText      // restore
    composingLabel.text = nil
    composingLabel.isHidden = true
}
func setMicListening(_ listening: Bool) {
    let symbolName = listening ? "mic.fill" : "mic"
    micButton.setImage(UIImage(systemName: symbolName), for: .normal)
    micButton.tintColor = listening ? .systemRed : palette.label
}
```

Guard `hideComposingPopup()` so it doesn't clobber voice partial mid-recognition
(mirror existing `isShowingReverseLookup` guard).

### 5.5 Phase 3 done when

- iPhone SE 3rd gen + iPad: tap mic → permission prompt (first run);
  speak "你好世界"; partial appears in composing strip (red);
  auto-stop → text committed.
- iPad with active composing then mic tap → composing cancelled,
  voice session starts cleanly.
- Dismiss (✕) during voice session → no text committed.

---

## 6. Phase 4 — Polish + settings

### 6.1 Pre-A12 disable UX

Check `caps.supportsOnDeviceSpeech` at iPad mic tap. If false:

```swift
guard caps.supportsOnDeviceSpeech else {
    LimeToast.show("此裝置不支援裝置內語音辨識", duration: 2.0)
    return
}
```

Candi-bar mic is already hidden on pre-A12 phones via §4.3 gating.

### 6.2 Settings — locale picker + permission status

In [PreferencesTabView.swift](../LimeIME-iOS/LimeSettings/Views/PreferencesTabView.swift):

```swift
Section("語音輸入") {
    Picker("辨識語言", selection: $voiceLocale) {
        ForEach(supportedLocales, id: \.identifier) { loc in
            Text(loc.localizedString).tag(loc.identifier)
        }
    }

    HStack {
        Text("麥克風權限")
        Spacer()
        Text(micAuthStatus.label)
            .foregroundColor(micAuthStatus == .authorized ? .green : .orange)
    }
    HStack {
        Text("語音辨識權限")
        Spacer()
        Text(speechAuthStatus.label)
            .foregroundColor(speechAuthStatus == .authorized ? .green : .orange)
    }
    if micAuthStatus != .authorized || speechAuthStatus != .authorized {
        Button("前往設定授權") { openAppSettings() }
    }
}
```

`supportedLocales` enumerates `SFSpeechRecognizer.supportedLocales()`
filtered by `supportsOnDeviceRecognition(for:)`. Default `zh-TW`.

`LIMEPreferenceManager` gains `voiceInputLocale` reader and the
`voice_speech_auth` / `voice_mic_auth` cache keys.

### 6.3 Phase 4 done when

- Pre-A12 iPad simulator (none exists for iOS 16 — verify via locale
  override): mic tap → device-not-supported toast.
- Settings tab shows current permission state and locale picker.
- Locale change → next voice session uses new locale.

---

## 7. Cross-cutting concerns

### 7.1 Key code allocation

| Code | Use | Status |
| --- | --- | --- |
| -99 | iPad mic placeholder (pre-this-plan) | **Decommission** in G3 — replace everywhere with -220 |
| -200 | globe | Existing |
| -201 | emojiPanel | Existing |
| -202..-212 | emoji categories | Existing |
| -220 | voiceInput | **New** |

`-99` is not in `LimeKeyCode`. After G3, grep
`LimeIME-iOS/LimeKeyboard/Layouts/` for any leftover `"code": -99`;
zero matches is the gate.

### 7.2 File encoding

Per CLAUDE.md §5:

- `KeyLayout.swift`, `CandidateBarView.swift`, `KeyboardViewController.swift`,
  `VoiceInputController.swift` → UTF-8 with BOM (Swift tolerates BOM
  and the project contains Chinese strings).
- `*_ipad.json` files → UTF-8 **without** BOM (JSON parsers reject BOM).
- `Info.plist` → UTF-8 without BOM (Apple's plist parser tolerates BOM
  but xcodebuild can complain; safest is no BOM).
- `IOS_KB_GAP.md`, `IOS_VOICE_INPUT.md` → UTF-8 with BOM (contain Chinese).

### 7.3 No-touch policies

Per [IPAD_KEYBOARD.md §12](IPAD_KEYBOARD.md) DB policy:

- `Database/*.limedb` — off-limits.
- Runtime `lime.db` in App Group container — off-limits.
- No `keyboard` / `im` table edits.

Voice input has zero DB interaction; this constraint is naturally satisfied.

### 7.4 Android side

Android already implements voice input ([CANDI_LAYOUT.md §8](CANDI_LAYOUT.md)).
This plan is iOS catch-up only. **No Android files in this gap plan.**

---

## 8. Verification gates

Between phases, the following must be green before advancing:

### Gate 1 → 2

- `xcodebuild test -only-testing:LimeTests` passes 729 + 3 new layout
  tests (G17 phase-1 subset).
- iPad sim manual: emoji-icon-left-of-space + mic-icon-right-of-space
  on at least one English, one symbol, and one Chinese-IM layout.
- Grep `"code": -99` in `Layouts/` returns 0 matches.
- Diff review of regenerated Chinese-IM JSONs confirms no content-row drift; script template update is the only behavioral change.
- No `中` / `.?123` cell modified in any hand-authored file (diff review).

### Gate 2 → 3

- iPhone home-button sim manual: candi-bar mic visible when empty,
  hidden when chevron present.
- Face ID sim manual: candi-bar mic hidden.
- iPad sim manual: candi-bar mic hidden, candi-bar emoji hidden.
- No xcodebuild warnings about missing usage descriptions (Phase 3
  hasn't added them yet; if iOS warns on import of `Speech` or `AVFoundation`,
  that's the Phase 3 trigger).

### Gate 3 → 4

- All Phase 3 done-when items pass.
- TestFlight build: external testers (3+) confirm voice input works
  end-to-end on iPhone SE 3 + iPad.
- App Store guidelines self-check: `requiresOnDeviceRecognition = true`
  asserted in code; no network calls from VoiceInputController.

### Gate 4 → ship

- Settings tab shows correct state across permission flips.
- Locale change verified for at least zh-TW, en-US.
- Pre-A12 path tested (force `supportsOnDeviceSpeech = false` via debug
  override).
- Update release notes per [IOS_VOICE_INPUT.md §10.3](IOS_VOICE_INPUT.md)
  banner copy check.

---

## 9. Risk register

| Risk | Mitigation |
| --- | --- |
| iPhone home-button users (SE 2/3) have older OS where on-device speech is locale-restricted | `supportsOnDeviceRecognition(for: locale)` gates per-locale; fall back to disabling mic key with toast |
| `LAContext` extension-incompatibility on some iOS minor versions | Fallback to screen-size heuristic in DeviceCapabilities (detect bottom safe-area inset > 0 in keyboard host window) |
| `AVAudioSession.record` conflicts with host app's own session (e.g. Voice Memos) | `.duckOthers` declared; surface error toast on failure to activate; no retry loop |
| App Store rejection over speech recognition | Mandatory `requiresOnDeviceRecognition = true` set at request init; never sent over network |
| BOM in `.json` breaks `JSONDecoder` | CLAUDE.md §5 explicitly excludes `.json` from BOM rule; editor presets must enforce no-BOM |
| Hand-authored layout edit accidentally touches `中` or `.?123` | Diff-only review gate before commit (no cell other than `space` may change `widthPercent`; no cell may be deleted; only the new emoji cell may be added; for layouts where mic was left of space, only its `code`/position changes) |
| Voice partial in composing strip races IM reverse-lookup | `isShowingVoicePartial` guard mirrors existing `isShowingReverseLookup`; both states are exclusive |

---

## 10. Done definition

The full feature is "shipped" when:

1. iPhone SE 2/3 user can tap candi-bar mic and dictate text.
2. iPad user can tap keyboard mic key and dictate text.
3. iPhone Face ID user sees no LimeIME mic (Apple's system bar
   continues to handle it).
4. Pre-A12 user sees graceful disabled state.
5. Permission denial routes to Settings via clear toast.
6. Settings exposes locale picker + permission status.
7. All 729 + new unit tests pass.
8. No App Store policy violations.
9. Release notes mention the new feature and the iPhone-Face-ID
   intentional omission.

Until item 9 is checked, the feature is "internal-test" not "released".
