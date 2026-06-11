# Chinese Phrase Learning And Runtime Phrase Suggestion

This document explains two related but separate Chinese input features:

- LD (`連打`) input and LD learning: learns new multi-character phrases after the user commits text.
- Runtime phrase suggestion: builds temporary phrase candidates while the user is still composing.

For the complete write-path audit and preference gates, see [LEARING_PATH.md](LEARING_PATH.md).

## Learning Gates And Written Records

| Feature / path | Main gate | Additional gate | Record written | Table |
|---|---|---|---|---|
| Candidate score update | none | `learning_switch` only controls whether score affects sorting | Updated score on the selected mapping | Current IM table, for example `cj`, `dayi`, or `phonetic` |
| Related phrase learning | `candidate_suggestion` (`啟動自建關聯字`) | none | Parent word plus following word, for example `分` -> `鍾` | Related phrase table |
| Related-phrase-triggered LD learning | `candidate_suggestion` | `learn_phrase` (`自動學習新詞`), and related-pair score must be greater than 20 | Learned phrase mapping, for example `分鍾` | Current IM table |
| Continuous LD learning | `learn_phrase` | phrase must contain more than one committed mapping and stay within the phrase length limit | Learned phrase mapping from the continuous committed candidates | Current IM table |
| Runtime-built phrase learning | `smart_chinese_input` builds the runtime candidate | `learn_phrase`, and the user must select the runtime-built phrase | Runtime phrase component mappings that match the selected phrase | Current IM table |

In short: `candidate_suggestion` writes related-word pairs, and `learn_phrase` writes learned phrase mappings into the active IM table. `smart_chinese_input` is a runtime suggestion display gate; it only leads to learning if the user selects a runtime-built phrase and `learn_phrase` is enabled.

## LD Input And LD Learning

LD means `連打`. LD learning records phrases after user selections have already been committed. It is controlled by `learn_phrase` (`自動學習新詞`). Candidate score updates are separate: scores may still update even when `learn_phrase` is off, while `learning_switch` controls whether learned scores affect candidate ordering.

There are three LD-related input paths:

| Path | Trigger | Learned data |
|---|---|---|
| Continuous LD learning | The user keeps composing and commits multiple Chinese candidates from one input flow. | A phrase made from the committed mappings. |
| Related-phrase-triggered LD learning | Consecutive committed candidates are written to the related table; when the related-pair score becomes high enough, the pair is promoted as an LD phrase. | A phrase in the main IM table. |
| Runtime-built phrase learning | The user selects a runtime-built phrase from runtime phrase suggestion. | The runtime phrase components that match the selected phrase. |

LD learning writes to the main IM table through `addOrUpdateMappingRecord()`. The learned phrase is limited to short Chinese phrases: the current implementations process phrase lists smaller than five characters, so LD phrase learning is effectively for two- to four-character phrases.

Example: if the user repeatedly commits「分」then「鍾」, the related phrase path can learn the connection「分」->「鍾」. If that pair becomes frequent enough and `learn_phrase` is on, LD learning can promote「分鍾」into the main IM table so future input can find it directly as a phrase candidate.

### Phonetic Tone Handling In LD Learning

Phonetic input has special code handling because tone keys are not always part of the stored lookup key. The tone symbols are `3`, `4`, `6`, `7`, and space, corresponding to the four tones (`四聲`) and neutral tone (`輕聲`) in Zhuyin phonetic input.

When LD learning writes a phonetic phrase, it builds:

- `LDCode`: the `連打` code, built from the full concatenated phrase code with tone symbols removed.
- `QPCode`: the `快拼` code, built from the first key of each character code.

Both are lowercased before writing. For example, if a learned phonetic phrase has a base code containing tone keys, LD learning strips the four-tone keys `3`, `4`, `6`, `7` and the neutral-tone space before writing the phrase lookup code. The database also stores `code3r`, the tone-stripped code column, for phonetic records.

QP (`快拼`) phrase learning is phonetic-only in the current Android and iOS implementations. For the phonetic table, LD learning writes both `LDCode` and `QPCode` when each code is longer than one character. For non-phonetic IMs, LD learning writes only the concatenated `baseCode` directly and does not write a QP record.

## Runtime Phrase Suggestion

Runtime phrase suggestion is controlled by `smart_chinese_input` (`開啟中文智慧組詞`). It does not wait until input is committed. Instead, while the user is still typing, `makeRunTimeSuggestion()` keeps a short runtime history of exact-match candidates and tries to combine the previous exact match with an exact match from the remaining code.

Example: if `8n` can select「分」and `0vf` can select「鍾」, then while the user types `8n0vf`, runtime phrase suggestion can combine「分」and「鍾」and show「分鍾」as a runtime-built candidate. If the related table already knows that「分」is related to「鍾」, the runtime phrase receives an additional score boost and is more likely to appear near the top.

The runtime suggestion has three stages:

| Stage | What happens |
|---|---|
| Exact-match tracking | When the current code has exact matches, the best exact candidates are stored in `suggestionLoL` and `bestSuggestionStack`. |
| Remaining-code search | When the current full code is not an exact phrase, the engine checks whether a previous exact candidate plus an exact candidate from the remaining code can form a phrase. |
| Candidate assembly | The best runtime-built phrase may be inserted after the composing-code echo and before DB candidates. |

Runtime phrase suggestion only controls whether runtime phrase candidates are built and shown. It does not by itself write the phrase to the main IM table. A runtime-built phrase is written only if the user selects it and `learn_phrase` is also on.

### Phonetic Tone Handling In Runtime Phrase Suggestion

Runtime phrase suggestion uses the same DB lookup path as normal candidate search. For phonetic lookup, the DB search handles tone keys specially:

- If the query has no tone symbol, phonetic search uses `code3r`, the no-tone code column.
- If the query has a tone symbol in the middle, or has a tone symbol and the code is longer than a normal single phonetic syllable, the query strips tone symbols before searching.
- If the tone symbol is only the final key of a normal single syllable, the original phonetic code is kept.

When the user selects a candidate, `getRealCodeLength()` also has phonetic-specific handling so the composing buffer is split at the right point. If the selected mapping code contains tone symbols but the current composing text starts with the tone-stripped version, the consumed length is the no-tone length. This matters for both LD input and runtime phrase suggestion because the remaining composing text and runtime suggestion history must be pruned using the real consumed code length.

One Android-only special case remains: when dual-mapped code mode is active, Android abandons LD-style partial code length support and treats the selected mapping as consuming the whole current composing code. The iOS port does not currently expose that same dual-mapped branch in `getRealCodeLength()`.
