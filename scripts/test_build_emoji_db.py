#!/usr/bin/env python3
# test_build_emoji_db.py - unit tests for the emoji.db v2 build helper.
# Usage: python3 scripts/test_build_emoji_db.py

import importlib.util
import filecmp
import sqlite3
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("build_emoji_db.py")


def load_builder():
    spec = importlib.util.spec_from_file_location("build_emoji_db", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BuildEmojiDbTests(unittest.TestCase):
    def test_build_from_files_copies_output_to_requested_targets(self):
        builder = load_builder()
        emoji_test = """
# group: Smileys & Emotion
# subgroup: face-smiling
1F600 ; fully-qualified # 😀 E1.0 grinning face
"""
        en_json = """
[
  {"hexcode": "1F600", "label": "grinning face", "tags": ["face", "grin"], "version": 1.0}
]
"""
        tw_json = """
[
  {"hexcode": "1F600", "label": "露齒笑臉", "tags": ["笑臉"]}
]
"""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            emoji_test_path = root / "emoji-test.txt"
            en_path = root / "en.json"
            tw_path = root / "zh-hant.json"
            output_path = root / "Database" / "emoji.db"
            android_copy = root / "LimeStudio" / "app" / "src" / "main" / "res" / "raw" / "emoji.db"
            emoji_test_path.write_text(emoji_test, encoding="utf-8")
            en_path.write_text(en_json, encoding="utf-8")
            tw_path.write_text(tw_json, encoding="utf-8")

            builder.build_from_files(
                emoji_test_path,
                en_path,
                tw_path,
                output_path,
                "17.0",
                "2026-05-09T00:00:00Z",
                [android_copy],
            )

            self.assertTrue(output_path.exists())
            self.assertTrue(android_copy.exists())
            self.assertTrue(filecmp.cmp(output_path, android_copy, shallow=False))

    def test_build_from_files_writes_database_from_local_sources(self):
        builder = load_builder()
        emoji_test = """
# group: Flags
# subgroup: country-flag
1F1EF 1F1F5 ; fully-qualified # 🇯🇵 E0.6 flag: Japan
"""
        en_json = """
[
  {"hexcode": "1F1EF-1F1F5", "label": "flag: Japan", "tags": ["flag", "Japan"], "version": 0.6}
]
"""
        tw_json = """
[
  {"hexcode": "1F1EF-1F1F5", "label": "日本國旗", "tags": ["國旗", "日本"]}
]
"""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            emoji_test_path = root / "emoji-test.txt"
            en_path = root / "en.json"
            tw_path = root / "zh-hant.json"
            output_path = root / "emoji.db"
            emoji_test_path.write_text(emoji_test, encoding="utf-8")
            en_path.write_text(en_json, encoding="utf-8")
            tw_path.write_text(tw_json, encoding="utf-8")

            builder.build_from_files(
                emoji_test_path,
                en_path,
                tw_path,
                output_path,
                "17.0",
                "2026-05-09T00:00:00Z",
            )

            with sqlite3.connect(output_path) as db:
                self.assertEqual(
                    ("🇯🇵", "日本國旗", "國旗|日本|國|旗|日|本"),
                    db.execute(
                        "SELECT value, name_tw, tags_tw FROM emoji_data"
                    ).fetchone(),
                )

    def test_parse_emoji_test_keeps_qualified_rows_with_group_order(self):
        builder = load_builder()
        text = """
# group: Smileys & Emotion
# subgroup: face-smiling
1F600 ; fully-qualified # 😀 E1.0 grinning face
263A FE0F ; minimally-qualified # ☺️ E0.6 smiling face
# group: Flags
# subgroup: country-flag
1F1EF 1F1F5 ; fully-qualified # 🇯🇵 E0.6 flag: Japan
"""

        rows = builder.parse_emoji_test(text)

        self.assertEqual(["1F600", "1F1EF-1F1F5"], [row["hexcode"] for row in rows])
        self.assertEqual(["😀", "🇯🇵"], [row["value"] for row in rows])
        self.assertEqual(["Smileys & Emotion", "Flags"], [row["group_name"] for row in rows])
        self.assertEqual([1, 2], [row["sort_order"] for row in rows])

    def test_parse_emojibase_records_accepts_label_tags_and_version(self):
        builder = load_builder()
        records = [
            {
                "hexcode": "1F1EF-1F1F5",
                "label": "flag: Japan",
                "tags": ["flag", "Japan"],
                "version": 0.6,
            },
            {
                "hexcode": "1F600",
                "annotation": "grinning face",
                "shortcodes": ["grinning"],
                "emojiVersion": 1.0,
            },
        ]

        parsed = builder.parse_emojibase_records(records)

        self.assertEqual("flag: Japan", parsed["1F1EF-1F1F5"]["label"])
        self.assertEqual(["flag", "Japan"], parsed["1F1EF-1F1F5"]["tags"])
        self.assertEqual(0.6, parsed["1F1EF-1F1F5"]["version"])
        self.assertEqual("grinning face", parsed["1F600"]["label"])
        self.assertEqual(["grinning"], parsed["1F600"]["tags"])
        self.assertEqual(1.0, parsed["1F600"]["version"])

    def test_build_rows_joins_sources_and_falls_back_cleanly(self):
        builder = load_builder()
        emoji_order = [
            {
                "hexcode": "1F600",
                "value": "😀",
                "group_name": "Smileys & Emotion",
                "subgroup": "face-smiling",
                "sort_order": 1,
            },
            {
                "hexcode": "1F1EF-1F1F5",
                "value": "🇯🇵",
                "group_name": "Flags",
                "subgroup": "country-flag",
                "sort_order": 2,
            },
        ]
        en = {
            "1F600": {
                "label": "grinning face",
                "tags": ["face", "grin"],
                "version": 1.0,
            },
            "1F1EF-1F1F5": {
                "label": "flag: Japan",
                "tags": ["flag", "Japan"],
                "version": 0.6,
            },
        }
        tw = {
            "1F1EF-1F1F5": {
                "label": "日本國旗",
                "tags": ["國旗", "日本"],
            },
        }

        rows = builder.build_rows(emoji_order, en, tw)

        self.assertEqual(["😀", "🇯🇵"], [row["value"] for row in rows])
        self.assertEqual("grinning face", rows[0]["name_tw"])
        self.assertEqual(["face", "grin"], rows[0]["tags_tw"])
        self.assertEqual("1F1EF,1F1F5", rows[1]["cp"])
        self.assertEqual("日本國旗", rows[1]["name_tw"])
        self.assertEqual(["國旗", "日本"], rows[1]["tags_tw"])

    def test_write_database_creates_schema_metadata_and_cjk_tokens(self):
        builder = load_builder()
        rows = [
            {
                "value": "🇯🇵",
                "cp": "1F1EF,1F1F5",
                "group_name": "Flags",
                "subgroup": "country-flag",
                "sort_order": 1,
                "name_en": "flag: Japan",
                "name_tw": "日本國旗",
                "tags_en": ["flag", "Japan"],
                "tags_tw": ["國旗", "日本"],
                "version": 0.6,
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "emoji.db"
            builder.write_database(db_path, rows, "17.0", "2026-05-09T00:00:00Z")

            with sqlite3.connect(db_path) as db:
                tables = {
                    row[0]
                    for row in db.execute(
                        "SELECT name FROM sqlite_master WHERE type='table'"
                    )
                }
                self.assertIn("emoji_data", tables)
                self.assertIn("im", tables)
                self.assertNotIn("emoji_fts", tables)

                emoji_row = db.execute(
                    "SELECT value, tags_tw FROM emoji_data WHERE value = ?",
                    ("🇯🇵",),
                ).fetchone()
                self.assertEqual("🇯🇵", emoji_row[0])
                self.assertEqual("國旗|日本|國|旗|日|本", emoji_row[1])

                metadata = dict(
                    db.execute(
                        "SELECT title, desc FROM im WHERE code = 'emoji'"
                    ).fetchall()
                )
                self.assertEqual("17.0", metadata["version"])
                self.assertEqual("Emoji 17.0 Dataset", metadata["name"])
                self.assertEqual("1", metadata["amount"])


if __name__ == "__main__":
    unittest.main()
