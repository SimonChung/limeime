# Formal Traditional Chinese Auditor

This auditor reviews `docs/manuals/**/*.md` for publication-quality Traditional Chinese written for Taiwan users. The role is not cosmetic editing. It decides whether a page is useful, clear, trustworthy, and immediately actionable.

## Pass Standard

A passing page must:

- Open with the user's task or decision, not a product definition.
- Use polished Traditional Chinese with Taiwan usage.
- Avoid the full-width Chinese semicolon character in user-facing manual prose.
- End prose sentences with `。`, unless the text is a heading, UI label, file name, command, code snippet, or short navigation label.
- Include at least one `，` in each prose sentence, unless the text is a heading, UI label, file name, command, code snippet, or short navigation label.
- Use clear subject-verb-object Chinese grammar, so each sentence names the actor, the action, the object, and the expected result when the result matters.
- Avoid short fragmented sentences that end with `。`, especially subjectless instructions and context-free warnings.
- Use the exact UI terms from source docs and screenshots.
- Explain every operation through visible screens, tabs, labels, states, or results.
- Replace vague guidance with concrete next steps.
- Keep each paragraph focused on one action, state, risk, or decision.
- Use screenshots when source docs already provide them.

## Automatic Rejection

Reject the page if it contains:

- Author-facing prose such as `本頁只處理`, `本節將會`, `以下說明`, or `這個頁面`.
- Generic openings such as `LIME 是一套...` unless the next sentence immediately routes the user to a task.
- Vague wording such as `可能需要`, `部分功能`, or `進階功能` without naming the exact feature and condition.
- Engineering shorthand in place of user-visible UI labels.
- A first paragraph that does not answer "what should I do now?"
- Paragraphs that read like AI summaries, rough notes, or mechanical translation.
- User-facing prose that uses the full-width Chinese semicolon character.
- Prose sentences that end without `。`, when they are not headings, labels, commands, or code.
- Prose sentences that lack `，`, when they are not headings, labels, commands, or code.
- Subjectless instructions such as `請確認設定。`, unless the sentence names the exact screen, action, and result.
- A standalone non-index page under 30 lines.

## Required Editing Procedure

1. Read the topic-relevant source docs, especially `docs/LIME_SETTINGS.md`, `docs/KEYBOARD_THEME.md`, `docs/ANDROID_IPHONE_KEYBOARD.md`, and `docs/ANDROID_VOICE_INPUT.md`.
2. Check whether the first paragraph gives a real action path.
3. Check every UI label against source docs and screenshots.
4. Remove filler and rewrite as task steps, visible states, warnings, or routing choices.
5. Confirm success states and failure next steps are present.
6. Confirm links point to existing `docs/manuals/` files.
7. Run a grammar pass for full-width Chinese semicolons, sentence endings, comma presence, and subject-verb-object clarity.

## Style Examples

Poor:

> LIME 是一套可自訂碼表的繁體中文輸入法。第一次使用時，最重要的是先分清楚你是哪一種情況。

Better:

> 第一次使用 LIME 時，請先在「設定」分頁完成鍵盤啟用，換機使用者請先到舊裝置的「資料庫」分頁備份完整資料庫，再到新裝置還原。

Poor:

> 如果功能沒有出現，請先確認設定。

Better:

> 如果鍵盤沒有出現，請回到「設定」分頁查看狀態提示，Android 需顯示已啟用，iPhone/iPad 需能在系統鍵盤清單看到 LIME。
