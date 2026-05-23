# Database Backup And Restore

## Purpose

This document records the expected archive layouts for LIME database exchange formats and the platform compatibility rules for backup and restore.

LIME has two different ZIP-based formats:

- `.limedb`: portable single-table import/export format.
- Full database backup: complete app database plus preferences.

These formats should not be treated as interchangeable.

## `.limedb` Table Export

`.limedb` is for one input-method table or the related-phrase table.

Expected archive layout:

```text
<tableName>.db
```

Examples:

```text
array.db
array10.db
custom.db
related.db
```

The inner entry should be a bare filename. It should not include app cache paths, external storage paths, package names, or `databases/`.

Current platform behavior:

| Platform | Export | Import |
|---|---|---|
| Android | Exports a bare `<tableName>.db` entry. | Accepts bare entries and older relative path entries such as `storage/emulated/.../array.db`. |
| iOS | Exports a bare `<tableName>.db` entry. | Accepts bare entries and relative path entries by locating a `.db` file and importing it through a temporary DB path. |

Compatibility rule:

- Keep import tolerant of older `.limedb` files that contain relative Android cache paths.
- Do not emit those paths in new exports.

## Full Database Backup

Full backup is for the runtime database and preferences, not a single input method.

Preferred shared layout:

```text
databases/lime.db
databases/lime.db-journal
shared_prefs.bak
```

`lime.db-journal` is optional. WAL/SHM files are not part of the intended backup contract.

Android currently exports this Android-compatible relative layout. It starts from absolute app paths, strips the app data root, and stores entries relative to that root.

Example Android source path:

```text
/data/user/0/net.toload.main.hd2026/databases/lime.db
```

Archive entry:

```text
databases/lime.db
```

iOS currently writes bare full-backup entries:

```text
lime.db
lime.db-journal
shared_prefs.bak
```

This restores on iOS, but it is less compatible with Android restore because Android restores ZIP entries under its app data root.

## Restore Compatibility

Restore should be more tolerant than export.

Accepted DB entry names:

```text
databases/lime.db
lime.db
```

Recommended behavior:

| Platform | Restore rule |
|---|---|
| Android | Search the archive for a file whose last path component is `lime.db`, then restore it to `ctx.getDatabasePath("lime.db")`. Keep support for `shared_prefs.bak` at the archive root. |
| iOS | Continue searching by last path component `lime.db`, then restore into the app group database path. |

This allows Android to restore older iOS backups that contain bare `lime.db`, while keeping future backups in the Android-compatible `databases/lime.db` layout.

## Alignment Plan

1. Keep `.limedb` exports as bare `<tableName>.db` entries on both platforms.
2. Change iOS full backup export to use `databases/lime.db` and `databases/lime.db-journal`.
3. Keep iOS restore tolerant of both `lime.db` and `databases/lime.db`.
4. Improve Android restore so it searches for `lime.db` by last path component and restores it into the Android database folder.
5. Add regression tests for:
   - Android restore of `databases/lime.db`.
   - Android restore of bare `lime.db`.
   - iOS backup archive entries using `databases/lime.db`.
   - iOS restore of old bare `lime.db` backups.

## Non-Goals

- Do not make `.limedb` contain `databases/`.
- Do not make full backups use external storage or cache paths inside the archive.
- Do not rely on absolute `/data/...` paths for normal backup interchange.
- Do not require `lime.db-journal` to exist for restore.

