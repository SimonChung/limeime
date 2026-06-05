# English Pick→Space Punctuation Swap — Design

## Goal

Replicate AOSP **LatinIME** behavior: after the user picks an English suggestion
(which auto-appends a space → `word `), typing punctuation should "swap" so the
result is `word, ` not `word ,`. Implement on **both Android and iOS**. Update
[ENGLISH_KB.md](../../ENGLISH_KB.md) §2a / backlog #0 and
[ENG_AUTO_COMPLETION.md](../../ENG_AUTO_COMPLETION.md).

This is ENGLISH_KB.md backlog item **#0**, specced in §2a.

## Decisions (locked)

- **Trigger:** flag set only when a candidate pick appends a space (LatinIME `WEAK`
  state). Manually-typed spaces do not trigger the swap.
- **Gate:** always on in English mode. No preference.
- **Punctuation classes:** full LatinIME 3-class model (replicate exactly).
- **Approach:** Option A — inline flag + inline swap at each punctuation site, with
  the punctuation character sets as named constants for cross-platform parity.

## LatinIME source of truth

From `InputLogic.java` / `SpacingAndPunctuations.java` /
`donottranslate-config-spacing-and-punctuations.xml` (en_US defaults):

| Class | Chars (en_US) | Rule when typed after `word ` (auto-space present) |
| --- | --- | --- |
| `symbols_followed_by_space` | `. , ; : ! ? ) ] }` | **swap**: delete the space, commit `punct + " "` → `word, ` |
| `symbols_preceded_by_space` | `( [ {` | **keep**: leave the space, commit the bracket → `word (` |
| other strip punct | `- / @ _ '` | **strip**: delete the space, commit the punct bare → `word-` |

`&` appears in both AOSP sets; treat as ambiguous and **exclude** it (commit bare,
no swap) to avoid undefined behavior. Letters/digits are not punctuation — they
materialize the pending word normally (flag just clears, space stays → `word x`).

## State model

One boolean per platform: "the last commit was an auto-space from a candidate pick."

- Android: `private boolean mPickedAutoSpace = false;` (LIMEService)
- iOS: `private var pickedAutoSpace = false` (KeyboardViewController)

Lifecycle:

1. **Set `true`** right after each pick-commit appends `" "`:
   - Android: LIMEService.java:5431 (emoji pick), :5438 (suffix pick)
   - iOS: `commitEnglishSuggestion` (KeyboardViewController.swift:2454)
2. **Consume + clear** when the next key is punctuation → run the 3-class swap.
3. **Clear, no swap** on any other input: letter/digit, backspace, space, mode
   switch, candidate dismiss, new compose.

### Defensive clear

At the top of the English character handler, read the flag into a local and
immediately set the member `false`. Only the punctuation branch acts on the local.
Every non-swap path therefore clears the flag automatically — no scattered resets,
no stale swap.

```
wasPicked = mPickedAutoSpace      // read
mPickedAutoSpace = false          // clear unconditionally
... only punctuation branch uses `wasPicked` ...
```

### Cursor-move safety

Before deleting the space, verify the char before the cursor really is a space:

- Android: `ic.getTextBeforeCursor(1, 0)` equals `" "`
- iOS: `documentContextBeforeInput?.hasSuffix(" ") == true`

If not a space (user moved the cursor after the pick), skip the delete and commit
the punctuation normally. The flag is an optimization, never a correctness
dependency.

## Per-platform implementation

### Android — `LIMEService.java`

- Add `mPickedAutoSpace` member; named constant strings for the three classes
  (e.g. `ENG_SWAP_FOLLOWED_BY_SPACE = ".,;:!?)]}"`, `ENG_SWAP_PRECEDED_BY_SPACE = "([{"`,
  `ENG_SWAP_STRIP = "-/@_'"`).
- Set the flag `true` after the two `commitText(word + " ", 1)` sites (5431, 5438).
- In the English-mode handler (`handleCharacter`, the `else` block ~5265), at the
  punctuation entry point (the `else` at ~5298 / `commitText` at ~5306):
  - read+clear the flag into `wasPicked`;
  - if `wasPicked` and the typed char is in one of the three sets and the char
    before cursor is a space → apply the class rule using
    `ic.deleteSurroundingText(1,0)` + `ic.commitText(...)`, wrapped in
    `beginBatchEdit()/endBatchEdit()`. Mirrors the existing double-space-period
    block at 5285-5286.
  - else commit the punctuation normally (existing path).
- Scope guard: English path only (the `else` branch is already `mEnglishOnly`).
  Do not touch the Chinese/table-IM `if` branch.

### iOS — `KeyboardViewController.swift`

- Add `pickedAutoSpace` member; same three named constant sets.
- Set the flag `true` at the end of `commitEnglishSuggestion` (after insert, 2454).
- In `handleEnglishCharacter` (1412), in the non-letter branch (1418-1422):
  - read+clear the flag into `wasPicked`;
  - if `wasPicked` and the char is in one of the three sets and
    `documentContextBeforeInput` ends with a space → apply the class rule using
    `deleteBackward()` + `insertText(...)`, all inside the existing
    `isSelfUpdate = true / false` guard.
  - else insert the punctuation normally (existing path).
- Respect `isSelfUpdate` recursion guard; English mode only (`mEnglishOnly`).

## Worked examples (must match on both platforms)

| After pick | Type | Result | Class |
| --- | --- | --- | --- |
| `word ` | `,` | `word, ` | followed-by-space (swap) |
| `word ` | `.` | `word. ` (then auto-cap next) | followed-by-space (swap) |
| `word ` | `?` | `word? ` | followed-by-space (swap) |
| `word ` | `)` | `word) ` | followed-by-space (swap) |
| `word ` | `(` | `word (` | preceded-by-space (keep) |
| `word ` | `-` | `word-` | strip |
| `word ` | `/` | `word/` | strip |
| `word ` | `a` | `word a` | letter — flag clears, space stays |
| pick, move cursor, `,` | `,` | normal `,`, no delete | cursor-move safety |
| pick, backspace, `,` | `,` | flag cleared, normal `,` | non-punct clears flag |

## Out of scope

- §2 double-space→`". "` (separate backlog #4).
- LatinIME PHANTOM space / full `SpaceState` enum (parked; we use literal swap
  because LimeIME commits a literal space).
- iOS shared dictionary (keeps `UITextChecker`).
- Chinese / table-IM candidate commit and end-key behavior — untouched.

## Verification

- Manual: walk the worked-examples table on both platforms.
- Android: confirm `:app:compileDebugJavaWithJavac` passes; ideally add a focused
  case to the existing English integration test family.
- iOS: confirm the keyboard target compiles; manual keyboard test on device/sim.
- Regression: Chinese IM candidate pick → flag never set, behavior unchanged.
