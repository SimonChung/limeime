# Android Theme Literal Centralization Plan

## Scope

Mirror the iOS first-pass flow for Android without broad XML churn:

1. Target the highest-risk hardcoded Android color found by the guard: `ic_candidate_emoji_face.xml` using raw black fill/stroke values.
2. Move that fallback icon color into the existing Android resource source of truth, `res/values/colors.xml`.
3. Keep theme-specific emoji drawables (`sym_candidate_emoji_*`) as resource-backed theme assets.
4. Re-run the repo UI literal guard and Android build/test checks.
5. Leave the large Android layout metric debt documented in `docs/MAGIC_NUMBER.md` for a separate pass using `res/values/dimens.xml` and shared styles.

## Verification

- `python3 scripts/check_ui_theme_literals.py --no-baseline --limit 260 | rg "ic_candidate_emoji_face|HIGH   color"`
- `python3 scripts/check_ui_theme_literals.py --limit 0`
- Android Gradle build/check command from `LimeStudio`.
- Android visual smoke verification on the existing Pixel 9 Pro API 36 emulator if it is available.
