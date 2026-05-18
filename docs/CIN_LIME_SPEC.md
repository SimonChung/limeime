# CIN and LIME Text Import Format Specification

This document describes the `.cin` and `.lime` text formats accepted by the current LimeIME importers, based on:

- Android: `LimeStudio/app/src/main/java/net/toload/main/hd/limedb/LimeDB.java`
- iOS: `LimeIME-iOS/Shared/Database/LimeDB.swift`

This file is the format contract only. Implementation tasks and test coverage are tracked in [CIN_LIME_IMPROVE_PLAN.md](CIN_LIME_IMPROVE_PLAN.md).

Android is the compatibility reference for historical behavior. Its `.lime` / `.cin` importer and `.lime` exporter have been used for decades, so iOS should align to Android behavior unless a deliberate difference is documented in this spec.

## 1. `.cin` Format

`.cin` is the traditional CIN input method format. Android treats files ending in `.cin` as CIN format and imports mapping records from `%chardef begin` through `%chardef end`.

### 1.1 Recommended Structure

```text
%version My IM Version
%cname My IM Display Name
%selkey 123456789
%endkey abcdefghijklmnopqrstuvwxyz
%spacestyle 0
%keyname begin
a A
b B
%keyname end
%chardef begin
a 測
b 試
%chardef end
```

### 1.2 Encoding

Use UTF-8 text. Android removes a UTF-8 BOM from the first line if present. Source files edited in this repo should follow repo policy and be saved as UTF-8 with BOM when modified.

### 1.3 Metadata Lines

Supported CIN metadata:

```text
%version My IM Version
%cname My IM Display Name
%selkey 123456789
%endkey ...
%spacestyle ...
```

Behavior:

- `%version` stores the IM version metadata.
- `%cname` stores the display name and is also used as version fallback when `%version` is absent.
- `%selkey`, `%endkey`, and `%spacestyle` store IM selection/end/space behavior metadata.
- Android parses the metadata value from the rest of the original line after the key, so spaces in metadata values are preserved.
- iOS parses `%version`, `%cname`, `%selkey`, `%endkey`, and `%spacestyle`.

### 1.4 `%keyname` Block

```text
%keyname begin
a ㄅ
b ㄆ
%keyname end
```

Android preserves key names from CIN files:

- `imkeys`: concatenated lowercased key codes
- `imkeynames`: display names joined by `|`

iOS currently does not import `%keyname` metadata.

### 1.5 `%chardef` Block

```text
%chardef begin
code word
%chardef end
```

Rules:

- Mapping records are imported only inside `%chardef begin/end`.
- Android stops reading CIN mappings at `%chardef end`.
- Lines beginning with `#` inside the block are skipped as comments.
- Records shorter than 3 characters are ignored.

### 1.6 Mapping Records

Common CIN record:

```text
code word
```

Android also accepts tab-delimited CIN records and optional score fields:

```text
code<TAB>word<TAB>score<TAB>basescore
code word score basescore
```

Field behavior:

- `code`: required; trimmed; lowercased before insert unless it is metadata.
- `word`: required; trimmed.
- `score`: optional integer; defaults to `0`.
- `basescore`: optional integer; Android calculates a base score from the Han converter when missing or `0`.

For the phonetic table, Android also writes `code3r`, derived by removing tone characters `[3467 ]` from `code`.

iOS currently imports only `code` and `word`.

## 2. `.lime` Format

`.lime` is LimeIME's delimiter-separated text format for regular IM table export/import.

### 2.1 Recommended Portable Structure

```text
@version@|My IM Version
@cname@|My IM Display Name
@selkey@|123456789
@endkey@|abcdefghijklmnopqrstuvwxyz
@spacestyle@|0
%chardef begin
code|word|score|basescore
aa|測|0|123
ab|試|0|456
%chardef end
```

Android can import `.lime` mapping lines even without `%chardef begin/end`. iOS currently imports mapping lines only while inside a `%chardef begin/end` block, so new portable files should include the block.

### 2.2 Encoding

Android export writes UTF-8. Use UTF-8 text for imports. Android removes a UTF-8 BOM from the first line if present.

### 2.3 Delimiter Detection

For non-`.cin` files, Android samples the first 100 lines and counts:

- comma: `,`
- tab: `\t`
- pipe: `|`
- space: ` `

It chooses the delimiter with the highest count. Ties resolve in this order: comma, tab, pipe, then space.

iOS detects from the first mapping data line inside `%chardef`, in this priority:

- pipe: `|`
- tab: `\t`
- comma: `,`
- space: ` `

Because Android and iOS differ, `|` is the safest delimiter only when code and word fields do not contain literal `|`.

### 2.4 Metadata Lines

LIME-style metadata uses the active delimiter. With pipe delimiter:

```text
@format@|lime-text-v2
@version@|My IM Version
@cname@|My IM Display Name
@selkey@|123456789
@endkey@|...
@spacestyle@|...
```

Android recognizes a metadata line when the parsed `code` field starts with `@`. It supports:

- `@version@`
- `@cname@`
- `@selkey@`
- `@endkey@`
- `@spacestyle@`
- `@format@`

These lines are not inserted as mappings.

Metadata meaning:

- `@format@|lime-text-v2` enables escaped field parsing for the rest of the file.
- `@version@` stores the IM version metadata.
- `@cname@` stores the IM display name, equivalent to CIN `%cname`.
- `@selkey@`, `@endkey@`, and `@spacestyle@` store IM selection/end/space behavior metadata.

When both `@version@` and `@cname@` are present, `@version@` remains the version value and `@cname@` is the display name value.

### 2.4.1 Escaped v2 Fields

Files without `@format@|lime-text-v2` use legacy unescaped parsing. In v2, fields are split on the active delimiter while ignoring escaped delimiter characters, then escapes are decoded.

Supported v2 escapes:

```text
\\ = literal backslash
\| = literal pipe when `|` is the delimiter
\@ = literal at-sign
\% = literal percent
\t = tab
\n = newline
```

Exporters may keep the legacy v1 format when no field needs escaping. They should write `@format@|lime-text-v2` before records when a value contains the active delimiter, backslash, tab/newline, or when a mapping code would otherwise be mistaken for metadata.

### 2.5 Mapping Records

Canonical record:

```text
code|word|score|basescore
```

Minimum accepted record:

```text
code|word
```

Field behavior:

- `code`: required; trimmed; Android lowercases non-metadata mapping codes before insert.
- `word`: required; trimmed.
- `score`: optional integer; defaults to `0` on Android; currently ignored by iOS text import.
- `basescore`: optional integer; Android calculates a base score from the Han converter when missing or `0`; currently ignored by iOS text import.

Android inserts regular mappings into:

```text
code, word, score, basescore
```

iOS currently inserts only:

```text
code, word
```

### 2.6 Space-Delimited `.lime`

Space-delimited records are supported, but fragile:

```text
code word score basescore
```

Android collapses runs of two to five spaces before parsing. Space-delimited records cannot safely contain spaces inside the code or word field.

## 3. Related Phrase Text Format

For the `related` table, Android pipe-delimited import uses:

```text
pword|cword|basescore|userscore
```

Legacy format is still accepted:

```text
pword+cword|basescore|userscore
```

The legacy importer splits the first field heuristically into parent and child words, so new exports should use the four-field format.

## 4. Export Format

### 4.1 Android `.lime` Export

Regular table export writes:

```text
@version@|...
@cname@|...
@selkey@|...
@endkey@|...
@spacestyle@|...
code|word|score|basescore
```

Related table export writes:

```text
pword|cword|basescore|userscore
```

### 4.2 iOS `.lime` Export

iOS regular table export currently wraps records in `%chardef begin/end`:

```text
@version@|...
@cname@|...
%chardef begin
code|word|score|basescore
%chardef end
```

iOS related export also wraps the related rows in `%chardef begin/end`.

## 5. Current Limitations

The current text formats have no escaping or quoting layer.

Important consequences:

- In pipe-delimited `.lime`, literal `|` cannot safely appear in `code`, `word`, `pword`, or `cword`.
- In comma-delimited `.lime`, literal `,` cannot safely appear inside fields.
- In tab-delimited `.lime`, literal tab cannot safely appear inside fields.
- In space-delimited `.cin` or `.lime`, literal spaces cannot safely appear inside mapping fields.
- A `.lime` mapping whose `code` begins with `@` is treated as LIME metadata and skipped.
- A CIN mapping whose `code` begins with `%version`, `%cname`, `%selkey`, `%endkey`, or `%spacestyle` is treated as metadata and skipped.
- Android metadata parsing recognizes metadata by `contains(...)`, not exact key equality, after delimiter parsing.

Literal `@` is safe in a `.lime` `word` field today, but not as the first character of the parsed `code` field.

## 6. Compatibility Rules for New Files

For `.cin` files:

1. Use UTF-8 text.
2. Put metadata before `%chardef begin`.
3. Use `%version ...` and `%cname ...` for version/name metadata.
4. Put mappings inside `%chardef begin/end`.
5. Avoid spaces inside `code` and `word`.

For `.lime` files:

1. Use UTF-8 text.
2. Prefer `|` as delimiter unless code or word values need literal `|`.
3. Always include `%chardef begin` and `%chardef end` for Android/iOS portability.
4. Put metadata before `%chardef begin`.
5. Use `@version@|...` for version metadata.
6. Use `@cname@|...` for display-name metadata.
7. Avoid literal delimiter characters in `code` and `word`.
