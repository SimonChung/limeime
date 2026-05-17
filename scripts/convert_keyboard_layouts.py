#!/usr/bin/env python3
# convert_keyboard_layouts.py
#
# Purpose: Convert Android XML keyboard layout files to JSON for the iOS port.
# Usage:   python3 convert_keyboard_layouts.py <input_dir> <output_dir>
#          python3 convert_keyboard_layouts.py \
#              LimeStudio/app/src/main/res/xml \
#              LimeIME-iOS/LimeIMEKeyboard/Layouts
#
# Input:  Android Keyboard XML files (lime_phonetic.xml, lime_abc.xml, etc.)
# Output: JSON files (lime_phonetic.json, lime_abc.json, etc.)
#
# JSON format:
# {
#   "id": "lime_phonetic",
#   "defaultWidthPercent": 10,
#   "rows": [
#     {
#       "isBottomRow": false,
#       "keys": [
#         { "code": 49, "label": "1", "sublabel": "ㄅ", "widthPercent": 10,
#           "icon": "", "isModifier": false, "isRepeatable": false, "isSticky": false,
#           "popupKeyboard": "" }
#       ]
#     }
#   ]
# }

import os
import sys
import json
import xml.etree.ElementTree as ET
from pathlib import Path

# Android namespace for attribute lookup
NS = "http://schemas.android.com/apk/res-auto"

# Android @string/alternates_for_X → actual character strings
ALTERNATES_STRINGS = {
    "@string/alternates_for_a": "àáâãäåæ",
    "@string/alternates_for_e": "èéêë",
    "@string/alternates_for_i": "ìíîï",
    "@string/alternates_for_o": "òóôõöœø",
    "@string/alternates_for_u": "ùúûü",
    "@string/alternates_for_s": "§ß",
    "@string/alternates_for_n": "ñ",
    "@string/alternates_for_c": "ç",
    "@string/alternates_for_y": "ýÿ",
    "@string/alternates_for_d": "",
    "@string/alternates_for_r": "",
    "@string/alternates_for_t": "",
    "@string/alternates_for_z": "",
    "@string/alternates_for_l": "",
    "@string/alternates_for_g": "",
    "@string/alternates_for_slash": ",",
}

# Special code meanings (mirrors Android Keyboard.java constants)
SPECIAL_CODES = {
    -1:   {"icon": "shift",          "label": ""},
    -2:   {"icon": "symbol",         "label": "#+"},
    -3:   {"icon": "keyboard.chevron.compact.down", "label": ""},    # done / hide keyboard
    -5:   {"icon": "delete.backward","label": ""},
    -9:   {"icon": "",               "label": "ABC"},
    -10:  {"icon": "",               "label": "中文"},
    -15:  {"icon": "symbol",         "label": ""},
    10:   {"icon": "return",         "label": ""},
    32:   {"icon": "space.bar",      "label": ""},
}

SKIP_FILES = {
    "file_paths.xml", "method.xml", "preference.xml",
    "templime.xml", "symbols1.xml", "symbols2.xml", "symbols3.xml",
    # These are hand-authored from symbols1/2/3.xml (3-page symbol keyboard).
    # The lime_number_symbol*.xml files are Dayi IM layouts — NOT the symbol keyboard.
    "lime_number_symbol.xml", "lime_number_symbol_shift.xml",
    # phone_number.json is hand-authored to match Android phone_number.xml exactly.
    "phone_number.xml",
}

# IM-specific key → sublabel mappings (mirrors LimeDB.java DAYI_KEY/CHAR, CJ_KEY/CHAR, etc.)
# Key: layout filename prefix → (key_string, char_string_pipe_separated)
IM_KEY_SUBLABELS = {
    "lime_dayi": (
        "1234567890qwertyuiopasdfghjkl;zxcvbnm,./",
        "言|牛|目|四|王|門|田|米|足|金|石|山|一|工|糸|火|艸|木|口|耳|人|革|日|土|手|鳥|月|立|女|虫|心|水|鹿|禾|馬|魚|雨|力|舟|竹",
    ),
    "lime_cj": (
        "qwertyuiopasdfghjklzxcvbnm",
        "手|田|水|口|廿|卜|山|戈|人|心|日|尸|木|火|土|竹|十|大|中|重|難|金|女|月|弓|一",
    ),
    "lime_scj": (
        "qwertyuiopasdfghjklzxcvbnm",
        "手|田|水|口|廿|卜|山|戈|人|心|日|尸|木|火|土|竹|十|大|中|重|難|金|女|月|弓|一",
    ),
    "lime_cj5": (
        "qwertyuiopasdfghjklzxcvbnm",
        "手|田|水|口|廿|卜|山|戈|人|心|日|尸|木|火|土|竹|十|大|中|重|難|金|女|月|弓|一",
    ),
    "lime_ecj": (
        "qwertyuiopasdfghjklzxcvbnm",
        "手|田|水|口|廿|卜|山|戈|人|心|日|尸|木|火|土|竹|十|大|中|重|難|金|女|月|弓|一",
    ),
    "lime_array": (
        "qazwsxedcrfvtgbyhnujmik,ol.p;/",
        "1^|1-|1v|2^|2-|2v|3^|3-|3v|4^|4-|4v|5^|5-|5v|6^|6-|6v|7^|7-|7v|8^|8-|8v|9^|9-|9v|0^|0-|0v|",
    ),
    "lime_array10": (
        "qazwsxedcrfvtgbyhnujmik,ol.p;/",
        "1^|1-|1v|2^|2-|2v|3^|3-|3v|4^|4-|4v|5^|5-|5v|6^|6-|6v|7^|7-|7v|8^|8-|8v|9^|9-|9v|0^|0-|0v|",
    ),
}

def build_sublabel_map(layout_id):
    """Return a char→sublabel dict for the given layout id, or empty dict."""
    if layout_id == "lime_dayi":
        return {}
    for prefix, (keys, chars) in IM_KEY_SUBLABELS.items():
        if layout_id.startswith(prefix):
            char_list = chars.split("|")
            return {k: c for k, c in zip(keys, char_list) if c}
    return {}

def attr(element, name, default=""):
    """Read a limehd-namespaced attribute, or None if missing."""
    return element.get(f"{{{NS}}}{name}", default)

def parse_width(w_str, default_pct=10.0):
    """Parse '10%p', '15%p', etc. → float percentage."""
    if not w_str:
        return default_pct
    w_str = w_str.strip()
    if w_str.endswith("%p"):
        try:
            return float(w_str[:-2])
        except ValueError:
            pass
    return default_pct

def parse_codes(codes_str):
    """Parse comma-separated codes like '49' or '49,50' → list of ints."""
    if not codes_str:
        return []
    try:
        return [int(c.strip()) for c in codes_str.split(",") if c.strip()]
    except ValueError:
        return []

def parse_label(raw_label):
    """Split 'primary\\nsublabel' into (primary, sublabel).
    Android XML uses the two-character sequence backslash-n as a separator.
    Python's ET parser gives us a literal backslash-n (not a newline char).

    Android also uses backslash-escaping for characters that have special XML meaning:
      \\@ → @   (@ starts resource references in Android XML)
      \\# → #   (# starts colour literals)
      question-mark escapes are normalized to bare ?
    These must be unescaped so the key shows the bare character.
    """
    if not raw_label:
        return "", ""
    # Strip Android @string/ resource references (unescaped @)
    if raw_label.startswith("@"):
        return raw_label, ""
    # Unescape Android XML escape sequences for literal key labels.
    def unescape(s):
        result = []
        i = 0
        while i < len(s):
            if s[i] == '\\' and i + 1 < len(s) and s[i+1] in ('@', '#', '?', '\\'):
                result.append(s[i+1])
                i += 2
            else:
                result.append(s[i])
                i += 1
        return ''.join(result)
    raw_label = unescape(raw_label)
    # Split on literal backslash-n (the Android XML \n separator)
    parts = raw_label.split("\\n", 1)
    if len(parts) == 2:
        return parts[0].strip(), parts[1].strip()
    return parts[0].strip(), ""

def resolve_icon(icon_str):
    """Map Android drawable names → SF Symbol names."""
    mapping = {
        "sym_keyboard_shift":       "shift",
        "sym_keyboard_delete_light":"delete.backward",
        "sym_keyboard_return_light":"return",
        "sym_keyboard_done_light":  "keyboard.chevron.compact.down",
        "sym_keyboard_space_light": "space.bar",
        "sym_flat_keyboard_space":  "space.bar",
    }
    if not icon_str:
        return ""
    # Strip @drawable/ prefix
    name = icon_str.replace("@drawable/", "").strip()
    return mapping.get(name, name)

def convert_key(key_elem, default_width_pct=10.0, sublabel_map=None):
    """Convert a <Key> XML element to a JSON key dict.
    sublabel_map: optional char→sublabel dict for IM-specific key labelling
                  (e.g. Dayi '1'→'言', CJ 'q'→'手').
    """
    codes_str = attr(key_elem, "codes")
    codes = parse_codes(codes_str)
    code = codes[0] if codes else 0

    raw_label   = attr(key_elem, "keyLabel")
    raw_icon    = attr(key_elem, "keyIcon")
    label, sub  = parse_label(raw_label)
    icon        = resolve_icon(raw_icon)

    # For special codes, fill in icon/label from the table
    if code in SPECIAL_CODES and not icon and not label:
        icon  = SPECIAL_CODES[code]["icon"]
        label = SPECIAL_CODES[code]["label"]

    # Fill in missing sublabel from IM key-char mapping (e.g. Dayi, CJ, Array)
    if not sub and sublabel_map and label and label in sublabel_map:
        sub = sublabel_map[label]

    width_str   = attr(key_elem, "keyWidth")
    width_pct   = parse_width(width_str, default_width_pct)

    is_mod      = attr(key_elem, "isModifier", "false").lower() == "true"
    is_rep      = attr(key_elem, "isRepeatable", "false").lower() == "true"
    is_sticky   = attr(key_elem, "isSticky", "false").lower() == "true"
    popup_kb    = attr(key_elem, "popupKeyboard")

    # Resolve popupCharacters: an @string/ reference or a raw character string.
    # If the resolved value is empty, both popupKeyboard and popupCharacters are cleared.
    raw_popup_chars = attr(key_elem, "popupCharacters")
    if raw_popup_chars in ALTERNATES_STRINGS:
        popup_chars = ALTERNATES_STRINGS[raw_popup_chars]
    else:
        popup_chars = raw_popup_chars

    # If popupKeyboard is @xml/popup_template, it is only meaningful when
    # popupCharacters is non-empty. Clear both when chars are empty.
    if popup_kb == "@xml/popup_template" and not popup_chars:
        popup_kb = ""

    return {
        "code":             code,
        "label":            label,
        "sublabel":         sub,
        "widthPercent":     round(width_pct, 2),
        "icon":             icon,
        "isModifier":       is_mod,
        "isRepeatable":     is_rep,
        "isSticky":         is_sticky,
        "popupKeyboard":    popup_kb,
        "popupCharacters":  popup_chars,
    }

def convert_keyboard_xml(xml_path):
    """Parse one Android keyboard XML and return a JSON-serialisable dict."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Default key width from the Keyboard element
    default_width_pct = parse_width(attr(root, "keyWidth"), 10.0)
    layout_id = Path(xml_path).stem  # filename without extension

    # Build IM-specific key→sublabel map (e.g. for Dayi, CJ, Array)
    sublabel_map = build_sublabel_map(layout_id)

    rows = []
    for row_elem in root.iter("Row"):
        row_edge = attr(row_elem, "rowEdgeFlags", "")
        is_bottom = "bottom" in row_edge

        # Android <Row limehd:keyboardMode="@+id/mode_xxx"> filters the row to a
        # specific EditorInfo input mode (normal / url / email / im). We only
        # emit the "normal" mode so the default keyboard matches what users see
        # on a standard text field. Rows without keyboardMode apply to all modes.
        row_mode = attr(row_elem, "keyboardMode", "")
        if row_mode and "mode_normal" not in row_mode:
            continue

        # Row-level default override
        row_default_width = parse_width(attr(row_elem, "keyWidth"), default_width_pct)

        keys = []
        for key_elem in row_elem.iter("Key"):
            key_dict = convert_key(key_elem, row_default_width, sublabel_map=sublabel_map)
            keys.append(key_dict)

        if keys:
            rows.append({
                "isBottomRow": is_bottom,
                "keys": keys,
            })

    return {
        "id": layout_id,
        "defaultWidthPercent": default_width_pct,
        "rows": rows,
    }

def main():
    if len(sys.argv) < 3:
        print("Usage: convert_keyboard_layouts.py <input_xml_dir> <output_json_dir>")
        sys.exit(1)

    input_dir  = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    xml_files = sorted(input_dir.glob("lime_*.xml")) + sorted(input_dir.glob("popup_*.xml"))
    converted = 0
    skipped   = 0
    errors    = []

    for xml_path in xml_files:
        if xml_path.name in SKIP_FILES:
            skipped += 1
            continue
        try:
            layout = convert_keyboard_xml(xml_path)
            out_path = output_dir / (xml_path.stem + ".json")
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(layout, f, ensure_ascii=False, indent=2)
            print(f"  ✓  {xml_path.name}  →  {out_path.name}  ({len(layout['rows'])} rows)")
            converted += 1
        except Exception as e:
            print(f"  ✗  {xml_path.name}: {e}")
            errors.append(xml_path.name)

    print(f"\nDone: {converted} converted, {skipped} skipped, {len(errors)} errors.")
    if errors:
        print("Errors:", ", ".join(errors))

if __name__ == "__main__":
    main()
