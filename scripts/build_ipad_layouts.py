#!/usr/bin/env python3
# build_ipad_layouts.py
# Generates _ipad.json layout files from phone layouts for the iPad keyboard.
# Usage: python3 .claude/scripts/build_ipad_layouts.py  (run from repo root)
# Output: LimeIME-iOS/LimeKeyboard/Layouts/*_ipad.json

import json
import os
import copy

LAYOUTS_DIR = "LimeIME-iOS/LimeKeyboard/Layouts"

# -------------------------------------------------------------------------
# iPad top row: symbol/number dual-label row (14 keys, total 100%)
# Used for non-IM layouts: lime_abc, lime_english, lime_english_number,
# lime_email, lime_url, and their shift variants.
# -------------------------------------------------------------------------
IPAD_TOP_ROW = {
    "isBottomRow": False,
    "keys": [
        {"code": 126, "label": "~",   "sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": 33,  "label": "!\n1","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 49},
        {"code": 64,  "label": "@\n2","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 50},
        {"code": 35,  "label": "#\n3","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 51},
        {"code": 36,  "label": "$\n4","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 52},
        {"code": 37,  "label": "%\n5","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 53},
        {"code": 94,  "label": "^\n6","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 54},
        {"code": 38,  "label": "&\n7","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 55},
        {"code": 42,  "label": "*\n8","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 56},
        {"code": 40,  "label": "(\n9","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 57},
        {"code": 41,  "label": ")\n0","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 48},
        {"code": 95,  "label": "_\n-","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 45},
        {"code": 43,  "label": "+\n=","sublabel": "", "widthPercent": 6.5,  "icon": "", "isModifier": False, "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 61},
        {"code": -5,  "label": "",    "sublabel": "", "widthPercent": 15.5, "icon": "delete.backward", "isModifier": True, "isRepeatable": True, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
    ]
}

# -------------------------------------------------------------------------
# iPad bottom row (standard for all layouts)
# globe | .?123 | mic | space | .?123 | dismiss
# -------------------------------------------------------------------------
IPAD_BOTTOM_ROW = {
    "isBottomRow": True,
    "keys": [
        {"code": -200, "label": "globe",                      "sublabel": "", "widthPercent": 8.5,  "icon": "globe",                        "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": -2,   "label": "@string/label_symbol_key",   "sublabel": "", "widthPercent": 10.0, "icon": "",                             "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": -6,   "label": "",                            "sublabel": "", "widthPercent": 8.5,  "icon": "mic",                          "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": 32,   "label": "",                            "sublabel": "", "widthPercent": 37.0, "icon": "space.bar",                    "isModifier": False, "isRepeatable": True,  "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": -2,   "label": "@string/label_symbol_key",   "sublabel": "", "widthPercent": 10.0, "icon": "",                             "isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
        {"code": -3,   "label": "",                            "sublabel": "", "widthPercent": 26.0, "icon": "keyboard.chevron.compact.down","isModifier": True,  "isRepeatable": False, "isSticky": False, "popupKeyboard": "", "popupCharacters": "", "longPressCode": 0},
    ]
}

# -------------------------------------------------------------------------
# Layouts that use an IM number-row for the top row (keep existing top row,
# just widen proportionally). All other layouts get the symbol/number dual row.
# -------------------------------------------------------------------------
IM_LAYOUTS = {
    "lime_phonetic", "lime_phonetic_shift",
    "lime_array",    "lime_array_shift",
    "lime_array_number", "lime_array_number_shift",
    "lime_cj",       "lime_cj_shift",
    "lime_cj_number","lime_cj_number_shift",
    "lime_dayi",     "lime_dayi_shift",
    "lime_dayi_sym", "lime_dayi_sym_shift",
    "lime_et26",     "lime_et26_shift",
    "lime_et_41",    "lime_et_41_shift",
    "lime_ez",       "lime_ez_shift",
    "lime_hs",       "lime_hs_shift",
    "lime_hsu",      "lime_hsu_shift",
    "lime_wb",       "lime_wb_shift",
}

# Layouts that should NOT get the top-row replacement (keep all rows as-is,
# just widen). Includes IM layouts, symbols pages, number layout.
KEEP_ALL_ROWS_AS_IS = IM_LAYOUTS | {
    "lime_number", "lime_number_shift",
    "lime_shift",
    "symbols1", "symbols2", "symbols3",
}

# Layouts that have a 1-0 top row that needs replacing with IPAD_TOP_ROW.
# (lime_abc, lime_abc_shift, lime_english*, lime_email, lime_url)
# Everything not in KEEP_ALL_ROWS_AS_IS gets the iPad top row replacement.

# -------------------------------------------------------------------------
# Helper: check if a row is the "1-0 number top row" (to be replaced)
# Criteria: first key code is 49 or 33/1-0 symbols, 10 keys, not isBottomRow
# -------------------------------------------------------------------------
def is_number_top_row(row):
    """Return True if this row looks like a 1–0 number/symbol top row."""
    if row.get("isBottomRow", False):
        return False
    keys = row.get("keys", [])
    if len(keys) != 10:
        return False
    # Check if codes are the standard 1-0 number row: 49,50,51,52,53,54,55,56,57,48
    codes = [k["code"] for k in keys]
    return codes == [49, 50, 51, 52, 53, 54, 55, 56, 57, 48]


def is_symbol_top_row(row):
    """Return True if this row looks like the !@#... symbol top row (lime_abc_shift etc)."""
    if row.get("isBottomRow", False):
        return False
    keys = row.get("keys", [])
    if len(keys) != 10:
        return False
    codes = [k["code"] for k in keys]
    # !@#$%^&*(  )
    return codes == [33, 64, 35, 36, 37, 94, 38, 42, 40, 41]


# -------------------------------------------------------------------------
# Helper: normalise a key — ensure all standard fields present, add
# longPressCode if missing (defaults to 0).
# -------------------------------------------------------------------------
def normalise_key(key):
    k = copy.deepcopy(key)
    # Ensure popupCharacters field exists
    if "popupCharacters" not in k:
        k["popupCharacters"] = ""
    # Ensure longPressCode field exists
    if "longPressCode" not in k:
        k["longPressCode"] = 0
    return k


# -------------------------------------------------------------------------
# Helper: scale widths in a row proportionally so they sum to 100.0
# -------------------------------------------------------------------------
def scale_row_to_100(row):
    keys = row["keys"]
    total = sum(k["widthPercent"] for k in keys)
    if abs(total - 100.0) < 0.001:
        return row  # already correct
    factor = 100.0 / total
    for k in keys:
        k["widthPercent"] = round(k["widthPercent"] * factor, 4)
    # Fix floating-point residual: force exact sum=100
    diff = 100.0 - sum(k["widthPercent"] for k in keys)
    if abs(diff) > 0.0001:
        keys[-1]["widthPercent"] = round(keys[-1]["widthPercent"] + diff, 4)
    return row


# -------------------------------------------------------------------------
# Core transform: produce iPad layout from phone layout dict
# -------------------------------------------------------------------------
def make_ipad_layout(phone, source_id):
    ipad = {}
    ipad["id"] = source_id + "_ipad"
    ipad["defaultWidthPercent"] = 8.0

    rows_in = phone.get("rows", [])
    rows_out = []

    use_keep_all = source_id in KEEP_ALL_ROWS_AS_IS
    top_row_inserted = False  # track whether we've replaced/added the iPad top row

    for row_idx, row in enumerate(rows_in):
        row = copy.deepcopy(row)

        if row.get("isBottomRow", False):
            # Replace bottom row with iPad bottom row
            rows_out.append(copy.deepcopy(IPAD_BOTTOM_ROW))
            continue

        # Normalise every key in the row
        row["keys"] = [normalise_key(k) for k in row["keys"]]

        if use_keep_all:
            # Just widen proportionally, no structural changes
            rows_out.append(scale_row_to_100(row))
        else:
            # For non-IM layouts: replace the 1-0 number row or !@# symbol row
            # with the iPad symbol/number dual-label top row.
            if not top_row_inserted and (is_number_top_row(row) or is_symbol_top_row(row)):
                rows_out.append(copy.deepcopy(IPAD_TOP_ROW))
                top_row_inserted = True
            else:
                rows_out.append(scale_row_to_100(row))

    # If the layout had no bottom row, we still don't add one (preserve structure).
    # If the layout had no replaceable top row and it's not a keep_all layout,
    # prepend the iPad top row (e.g. lime_email / lime_url have no number top row).
    if not use_keep_all and not top_row_inserted:
        rows_out.insert(0, copy.deepcopy(IPAD_TOP_ROW))

    ipad["rows"] = rows_out
    return ipad


# -------------------------------------------------------------------------
# Jobs: (source_file_stem, output_file_stem)
# -------------------------------------------------------------------------
JOBS = [
    # lime_abc
    ("lime_abc",              "lime_abc_ipad"),
    ("lime_abc_shift",        "lime_abc_shift_ipad"),
    # lime_english
    ("lime_english",          "lime_english_ipad"),
    ("lime_english_shift",    "lime_english_shift_ipad"),
    # lime_english_number
    ("lime_english_number",   "lime_english_number_ipad"),
    ("lime_english_number_shift", "lime_english_number_shift_ipad"),
    # lime_phonetic
    ("lime_phonetic",         "lime_phonetic_ipad"),
    ("lime_phonetic_shift",   "lime_phonetic_shift_ipad"),
    # lime_array
    ("lime_array",            "lime_array_ipad"),
    ("lime_array_shift",      "lime_array_shift_ipad"),
    # lime_array_number
    ("lime_array_number",     "lime_array_number_ipad"),
    ("lime_array_number_shift","lime_array_number_shift_ipad"),
    # lime_cj
    ("lime_cj",               "lime_cj_ipad"),
    ("lime_cj_shift",         "lime_cj_shift_ipad"),
    # lime_cj_number
    ("lime_cj_number",        "lime_cj_number_ipad"),
    ("lime_cj_number_shift",  "lime_cj_number_shift_ipad"),
    # lime_dayi
    ("lime_dayi",             "lime_dayi_ipad"),
    ("lime_dayi_shift",       "lime_dayi_shift_ipad"),
    # lime_dayi_sym
    ("lime_dayi_sym",         "lime_dayi_sym_ipad"),
    ("lime_dayi_sym_shift",   "lime_dayi_sym_shift_ipad"),
    # lime_et26
    ("lime_et26",             "lime_et26_ipad"),
    ("lime_et26_shift",       "lime_et26_shift_ipad"),
    # lime_et_41
    ("lime_et_41",            "lime_et_41_ipad"),
    ("lime_et_41_shift",      "lime_et_41_shift_ipad"),
    # lime_ez
    ("lime_ez",               "lime_ez_ipad"),
    ("lime_ez_shift",         "lime_ez_shift_ipad"),
    # lime_hs
    ("lime_hs",               "lime_hs_ipad"),
    ("lime_hs_shift",         "lime_hs_shift_ipad"),
    # lime_hsu
    ("lime_hsu",              "lime_hsu_ipad"),
    ("lime_hsu_shift",        "lime_hsu_shift_ipad"),
    # lime_wb
    ("lime_wb",               "lime_wb_ipad"),
    ("lime_wb_shift",         "lime_wb_shift_ipad"),
    # lime_number
    ("lime_number",           "lime_number_ipad"),
    ("lime_number_shift",     "lime_number_shift_ipad"),
    # lime_shift (standalone shift layer used by lime_abc)
    ("lime_shift",            "lime_shift_ipad"),
    # lime_email / lime_url  (no top number row; iPad top row will be prepended)
    ("lime_email",            "lime_email_ipad"),
    ("lime_url",              "lime_url_ipad"),
    # symbols
    ("symbols1",              "symbols1_ipad"),
    ("symbols2",              "symbols2_ipad"),
    ("symbols3",              "symbols3_ipad"),
]


def main():
    generated = []
    errors = []

    for src_stem, out_stem in JOBS:
        src_path = os.path.join(LAYOUTS_DIR, src_stem + ".json")
        out_path = os.path.join(LAYOUTS_DIR, out_stem + ".json")

        if not os.path.exists(src_path):
            errors.append(f"  MISSING source: {src_path}")
            continue

        with open(src_path, "r", encoding="utf-8") as f:
            phone = json.load(f)

        ipad = make_ipad_layout(phone, src_stem)

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(ipad, f, indent=2, ensure_ascii=False)
            f.write("\n")

        generated.append(out_path)
        print(f"  OK  {out_stem}.json")

    print(f"\nGenerated {len(generated)} iPad layout files.")
    if errors:
        print("\nErrors:")
        for e in errors:
            print(e)


if __name__ == "__main__":
    main()
