---
name: android-visual-verify
description: Use when visually verifying the Android LimeIME keyboard on an emulator or device, especially after Android IME, LIME IM, keyboard layout, candidate, startup, emoji, theme, or physical-keyboard changes.
---

# Android Visual Verify

Use this skill to verify the actual Android LimeIME system keyboard surface. Do not treat the host app screen as proof that the keyboard works.

## Required Setup

Before visual verification:

1. Confirm a device/emulator is connected.
2. Confirm the LimeIME APK under test is installed only if the task requires testing a newly built APK.
3. Confirm Android's selected system IME is `net.toload.main.hd2026/net.toload.main.hd.LIMEService`.
4. Confirm LIME has real installed IM tables, not an empty first-run state.
5. Install at least these LIME IMs when they are missing:
   - `phonetic`
   - `dayi`
6. Confirm the active LIME IM is one of the installed tables before typing.
7. Confirm the DB has mappings/config rows for the active LIME IM.

Empty IM / empty DB verification is only first-run setup coverage. It is not valid evidence for normal startup, candidate, keyboard layout, or performance behavior.

## Verification Flow

Use a real text field in a host app such as Messages.

For each required LIME IM, at minimum `phonetic` and `dayi`:

1. Select the LIME IM inside LimeIME.
2. Focus the host app text field.
3. Verify `dumpsys input_method` shows `mSelectedMethodId=net.toload.main.hd2026/net.toload.main.hd.LIMEService`.
4. Verify the keyboard surface is visible, not Gboard/LatinIME or a host-app emoji/sticker panel.
5. Type a short code that should produce candidates for that LIME IM.
6. Capture a screenshot showing the keyboard and candidate behavior.
7. If emoji is relevant, open emoji from the LIME keyboard and capture a screenshot showing the LIME emoji panel.

## Evidence Rules

A valid handoff must state:

- Device/emulator id.
- Installed APK/version if changed.
- Selected Android system IME.
- Installed LIME IMs checked.
- Active LIME IM used for each screenshot.
- Whether DB/mapping rows were present.
- Screenshot paths.
- Test/build commands run.

Never claim visual verification passed if:

- Android selected IME is not LimeIME.
- The active LIME IM is empty or unknown.
- The DB is empty when testing normal behavior.
- The screenshot only shows a host app UI.
- The screenshot shows LatinIME/Gboard instead of LimeIME.
