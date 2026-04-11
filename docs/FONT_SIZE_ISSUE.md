# Font Size / Key Label Shrinkage Analysis

---

## 1. Issue

The key label font on the Android keyboard appears **smaller than expected**.

Observed behaviour:
- Force-stopping the service does **not** fix it — labels are still small after restarting the IME.
- Changing the **鍵盤大小 (Keyboard Size)** setting does **not** fix it.
- A full reinstall fixes it immediately.

SharedPreferences is the only state layer consistent with all three observations: it survives force-stop but is wiped on reinstall. The `keyboard_size` preference drives key label scale by design. Why changing `keyboard_size` back to normal does not restore labels cannot be explained by static analysis alone and requires device-level investigation (see Reproduction Steps).

---

## 2. Exactly What Font Sizes Are Used When Rendering a Key Label

All label rendering is in `LIMEKeyboardBaseView.onBufferDraw()`, lines 984–1124.

### Base sizes — fixed at view construction

Four integer pixel sizes are read from XML dimension attributes at construction and **never change at runtime**:

| Field | Default | Used for |
|-------|---------|----------|
| `mKeyTextSize` | 18 sp | Single-character label, no sub-label |
| `mLabelTextSize` | 14 sp | Multi-character label (length > 1), no sub-label |
| `mSmallLabelTextSize` | 14 sp | Main label on a key that also has a sub-label |
| `mSubLabelTextSize` | 14 sp | The sub-label itself |

---

### Scale factors applied at draw time

Two scale factors are multiplied in at every draw:

**`keySizeScale`** = `mKeyboard.getKeySizeScale()` — reads `LIMEBaseKeyboard.mKeySizeScale` (`private static`). Driven by the `keyboard_size` preference via `LIMEKeyboardSwitcher`. This is the only runtime variable that affects label size.

**`labelSizeScale`** = `key.getLabelSizeScale()` — reads `Key.mLabelSizeScale` (`private static`). Always `1.0` in portrait (no portrait key is narrower than `mDefaultWidth`). Has no effect in the reported scenario.

---

### Computed pixel size per key type

```java
// Key has a sub-label, main label is multi-char:
labelSize = (int)(mSmallLabelTextSize × keySizeScale × labelSizeScale × 0.8f)

// Key has a sub-label, main label is single char:
labelSize = (int)(mSmallLabelTextSize × keySizeScale × labelSizeScale)

// No sub-label, label length > 1 (e.g. "Del", "Enter"):
labelSize = (int)(mLabelTextSize × keySizeScale × labelSizeScale)

// No sub-label, single char (normal letter/digit key):
labelSize = (int)(mKeyTextSize × keySizeScale × labelSizeScale)

// The sub-label (top-left corner character):
subLabelSize = (int)(mSubLabelTextSize × keySizeScale × labelSizeScale)
```

**Conclusion:** the only runtime variable is `keySizeScale`, which is `keyboard_size`. The `font_size` preference has no path to any of these formulas — it controls candidate bar and composing pop-up sizes (`CandidateView.java`, `CandidateExpandedView.java`) and was never intended to affect key labels.

---

## 3. The Writer That Produces Smaller Labels

### `LIMEKeyboardSwitcher.getKeyboard()` via `keyboard_size` pref

When `keyboard_size` is set to a value < `1.0`, `getKeyboard()` detects the mismatch with `mKeySizeScale`, calls `clearKeyboards()`, and rebuilds all keyboards at the smaller scale. The smaller value is persisted in SharedPreferences, which survives force-stop but is wiped on reinstall — consistent with observations 1 and 3 from section 1.

Observation 2 — "changing `keyboard_size` back to 一般 does not fix it" — is not explained by static analysis. `getKeyboard()` explicitly watches `keyboard_size` and rebuilds when it changes, so setting it back to `1.0` should restore normal labels. The reason it does not requires device-level investigation (see Reproduction Steps).

---

## 4. Bug Assessment

No confirmed code bug from static analysis. Both preferences work as designed:
- `font_size` → candidate bar and composing pop-up text size (in `CandidateView`, `CandidateExpandedView`)
- `keyboard_size` → key label scale (in `LIMEKeyboardSwitcher` → `LIMEBaseKeyboard`)

### Code Hygiene — Wrong Preference in Constructor

**File:** `LIMEKeyboardSwitcher.java`, line 109

```java
mKeySizeScale = mLIMEPref.getFontSize();   // should be getKeyboardSize()
```

The constructor initializes `mKeySizeScale` from `font_size` instead of `keyboard_size`. This is harmless — `getKeyboard()` immediately overwrites it with `getKeyboardSize()` on the first keyboard request. But it is misleading and should be corrected for clarity:

```java
mKeySizeScale = mLIMEPref.getKeyboardSize();   // correct preference
```

### Open Investigation — Why Changing `keyboard_size` Back Does Not Restore Labels

`getKeyboard()` explicitly watches `keyboard_size` and calls `clearKeyboards()` + rebuild when it changes. By static analysis, setting `keyboard_size` back to `1.0` should restore normal labels. The reason it does not is unexplained without device investigation (see Reproduction Steps).

---



---

## Summary

| Question | Answer |
|----------|--------|
| What makes the font smaller? | `keyboard_size` pref set to < 1.0, persisted in SharedPreferences |
| Why doesn't force-stop fix it? | SharedPreferences survives process restart |
| Why does reinstall fix it? | SharedPreferences is wiped on reinstall |
| Why doesn't changing `keyboard_size` fix it? | Not explained by static analysis — requires device investigation |
| Does changing `font_size` affect key labels? | **No** — by design; `font_size` controls candidate bar and composing pop-up only |
| Is `Key.mLabelSizeScale` being static a bug? | **No** — intentional design; always locks to 1.0 in portrait; not involved in the reported shrinkage |
| Are there confirmed bugs? | No confirmed bugs from static analysis; one code hygiene issue (constructor reads wrong preference, harmless) |

---

## Reproduction Steps

### Step 1 — Confirm SharedPreferences is the persistence mechanism

1. Fresh reinstall.
2. Set **鍵盤大小 (Keyboard Size)** to 小 (0.9). Labels get smaller. ← confirms `keyboard_size` drives label scale.
3. Force-stop (`adb shell am force-stop net.toload.main.hd`), reopen keyboard. Labels still small. ← confirms SharedPreferences survives force-stop.
4. Reinstall. Labels normal. ← confirms SharedPreferences was wiped.

---

### Step 2 — Confirm `font_size` has no effect

1. Set `keyboard_size` to 小 (0.9) so labels are visibly small.
2. Change **字體大小 (Font Size)** to 特大 (1.2). Observe: **no change to label size**. ← confirms `font_size` pref is silently ignored.

---

### Step 3 — Investigate why changing `keyboard_size` back does not restore labels

This symptom cannot be explained by static analysis. Run logcat while reproducing:

```bash
adb logcat -s LIMEKeyboardSwitcher | grep -E "getKeyboard|clearKeyboards|mKeySizeScale"
```

Expected when `keyboard_size` is changed back to 一般 (1.0):
```
getKeyboard: keyboard_size=1.0 mKeySizeScale=0.9 → clearKeyboards, rebuild at 1.0
```

If this log fires but labels are still small, the view is not being redrawn — look for a missing `invalidateAllKeys()` or `requestLayout()` call after the keyboard switches. If the log does NOT fire, `getKeyboard()` is not being called after the settings change — look for a missing preference change listener.

