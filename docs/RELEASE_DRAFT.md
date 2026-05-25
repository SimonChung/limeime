# LIME 2026 — 版本 v6.1.12

**版本標籤：** `v6.1.12`
**APK：** [`LIMEHD2026-6.1.12.apk`](https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.12.apk)
**套件名稱：** `net.toload.main.hd2026`
**目標 SDK：** 36 | **最低 SDK：** 21
**前一正式版本：** [v6.0.2](https://github.com/lime-ime/limeime/releases/tag/v6.0.2)

## 更新內容

### 新功能與鍵盤體驗重大更新

- **全新萊姆輸入法設定 app**
  - 這是 LIME 2026 第一個 6.1 正式版本，最大更新是全新的萊姆輸入法設定。
  - 重新設計整體 UI 與操作流程，讓輸入法、喜好設定、碼表資料與備份還原更簡單、直覺。

- **全新 emoji 鍵盤與 Emoji 17.0 資料庫**
  - emoji 資料庫升級到最新 Emoji 17.0，補齊新版 emoji、分類與搜尋資料。
  - 新增 LIME 內建 emoji 鍵盤，不需離開 LIME 鍵盤即可瀏覽、搜尋與輸入 emoji。
  - 相關文件：<https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_KEYBOARD.md>、<https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_DB_V2.md>

- **候選列關閉按鈕與組字取消**
  - 候選列新增關閉／取消按鈕，可直接取消目前組字或收合候選狀態，減少需要反覆按退格鍵的情境。
  - 相關文件：<https://github.com/lime-ime/limeime/blob/master/docs/CANDI_FUNCTION_KEYS.md>

- **LIME 內建聽寫功能**
  - 新增 LIME 自有的鍵盤內聽寫流程，讓語音辨識可在 LIME 鍵盤內顯示與送出。
  - 保留系統／Google 語音輸入作為 fallback，並改善語音輸入與繁體中文處理流程。
  - 相關文件：<https://github.com/lime-ime/limeime/blob/master/docs/ANDROID_LIME_DITACTION.md>、<https://github.com/lime-ime/limeime/blob/master/docs/ANDROID_VOICE_INPUT.md>

- **新增可下載「四碼倉頡／哈哈倉頡」碼表**
  - 新增 `cj4.limedb` 下載碼表與 Android/iOS catalog 條目，可在下載清單中安裝「四碼倉頡／哈哈倉頡」。
  - 感謝 GitHub 使用者 [@ejmoog](https://github.com/ejmoog) 提供碼表資料與測試確認；授權與來源資訊已補入專案文件。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/72>
  - 相關 PR：<https://github.com/lime-ime/limeime/pull/84>

### Android 修正與改善

- **#54 — Brave URL 欄候選字重疊／白色區塊問題**
  - 修正 URL/瀏覽器輸入情境下候選列與鍵盤區域顯示異常，改善候選字不正常覆蓋與底部白色區塊。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/54>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2354_ISSUE.md>

- **#55 — 按鍵預覽延遲**
  - 改善新版 Android 上按鍵 popup preview 的顯示延遲，讓按鍵回饋更接近舊版行為。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/55>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2355_ISSUE.md>

- **#62 — Ext-B 字首相關詞／連打詞問題**
  - 修正 CJK Ext-B 代理對字元在相關詞、連打詞與候選處理時的字首判斷問題。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/62>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2362_ISSUE.md>

- **#64 — 設定畫面文字、縮排與捲動顯示問題**
  - 修正設定頁在新版 UI/系統環境下的文字截斷、縮排與捲動顯示不一致。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/64>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2364_ISSUE.md>

- **#65 — Android 表格／相關詞編輯器軟鍵盤覆蓋問題**
  - 修正表格、相關詞與關聯資料編輯畫面中軟鍵盤彈出時的內容遮蔽與 bottom-sheet 行為。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/65>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2365_ISSUE.md>

- **#67、#68、#69 — 候選列觸控、收合與工具圖示穩定性**
  - 修正點擊最後一個可見候選字附近時誤開啟完整候選清單的問題。
  - 修正候選列展開／收合後的狀態殘留，並改善工具圖示閃爍。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/67>、<https://github.com/lime-ime/limeime/issues/68>、<https://github.com/lime-ime/limeime/issues/69>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2367_ISSUE.md>、<https://github.com/lime-ime/limeime/blob/master/docs/%2368_ISSUE.md>、<https://github.com/lime-ime/limeime/blob/master/docs/%2369_ISSUE.md>

- **#71 — 中英切換時組字狀態取消／送出行為**
  - 調整中英模式切換時 composing text 的取消與送出流程，避免切換後留下錯誤組字狀態。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/71>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2371_ISSUE.md>

- **#74 — 數字、電話、URL 與搜尋欄位的鍵盤模式**
  - 數字、日期、電話等欄位改用更合適的受限鍵盤配置。
  - URL 與搜尋欄位改回較接近一般文字欄位的行為，可依「記憶中英模式」保留使用者期待的中／英文狀態。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/74>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2374_ISSUE.md>

- **#75 — 鍵盤 redraw 與 popup 生命週期問題**
  - 修正候選列、按鍵 popup 與鍵盤重繪之間的狀態同步問題，避免顯示殘影或 popup 狀態卡住。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/75>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2375_ISSUE.md>

- **#76 —「建議字顯示數量 = 0」與自動學習詞控制**
  - `建議字顯示數量` 設為 0 時，候選邏輯改為 exact-match-only，避免繼續顯示延伸編碼候選。
  - 修正 `learn_phrase=false` 時仍可能產生 runtime phrase / 連打詞學習資料的路徑。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/76>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2376_ISSUE.md>

- **#78 — 選用候選字不應攔截功能鍵**
  - 修正選用候選字狀態下功能鍵被候選處理攔截的問題，改善 Android 與 iOS 共同的候選列功能鍵行為。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/78>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2378_ISSUE.md>

- **#79 — 深色模式 emoji 搜尋欄與中文 emoji 搜尋**
  - 修正 Android 深色模式下 emoji 面板搜尋欄背景與圖示過亮的問題。
  - 6.1.12 改善中文 emoji 搜尋輸入路徑；6.1.11 與更早版本不支援此路徑。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/79>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2379_ISSUE.md>

- **#81 — 英文鍵盤自動大寫行為**
  - 改善英文鍵盤 auto-capitalization 行為，並將相關設定整理為「英文鍵盤」脈絡。
  - 相關提交：<https://github.com/lime-ime/limeime/commit/dd5312ea9205>

- **#83 — 移除舊版 Android 設定頁**
  - 移除 legacy Android settings UI，避免新舊設定入口混用造成維護與使用混淆。
  - 相關提交：<https://github.com/lime-ime/limeime/commit/491ca1c616bb>

- **#85 / PR #87 — Android 資料庫備份還原失敗處理與舊備份相容性**
  - 還原流程現在會更明確回報資料庫備份還原失敗，而不是靜默忽略錯誤。
  - 修正舊版 Android 備份壓縮檔內含 leading-slash entry 時的還原相容性。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/85>
  - 相關 PR：<https://github.com/lime-ime/limeime/pull/87>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2385_ISSUE.md>

### 表格、資料與備份更新

- **跨平台喜好設定備份／還原**
  - 新增跨平台喜好設定備份／還原支援，並讓 Android 與 iOS 的資料庫備份格式更一致。
  - 相關提交：<https://github.com/lime-ime/limeime/commit/e57b62e>、<https://github.com/lime-ime/limeime/commit/1351048>

- **CIN/LIME 匯入與授權頁連結整理**
  - 對齊 CIN / LIME text import 行為，補強授權頁與 permission notice 連結。
  - 相關文件：<https://github.com/lime-ime/limeime/blob/master/docs/CIN_LIME_SPEC.md>、<https://github.com/lime-ime/limeime/blob/master/docs/IM_VERSION.md>

### iOS 來源同步更新

> 本次 GitHub Release 附上的安裝檔是 Android APK。以下為同一期間已合併到 `master` 的 iOS 來源與測試更新；iOS 使用者仍需等待後續 TestFlight／App Store 發布。

- **iOS 候選列與鍵盤互動修正**
  - 修正候選列 `…` / `hasMoreMark` sentinel 不應保留在候選列或展開格線中的問題。
  - 修正 optional suggestions 攔截功能鍵的跨平台問題。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/77>、<https://github.com/lime-ime/limeime/issues/78>
  - 相關提交：<https://github.com/lime-ime/limeime/commit/c828a2d2>、<https://github.com/lime-ime/limeime/commit/5819fc4>、<https://github.com/lime-ime/limeime/commit/2e278c46>

- **iPhone SE / iPhone 8 類型機型的 globe 鍵支援**
  - 新增 legacy iPhone globe key 支援，改善實體 Home 鍵機型的鍵盤切換體驗。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/82>
  - 相關提交：<https://github.com/lime-ime/limeime/commit/a1e6fca>
  - 設計文件：<https://github.com/lime-ime/limeime/blob/master/docs/IPHONE_LEGACY_KB.md>

- **iPad 版面、DB 與 gesture policy 整理**
  - 更新 iPad keyboard layout、測試、DB 與手勢策略，持續縮小 Android/iOS 版面與行為差距。
  - 相關提交：<https://github.com/lime-ime/limeime/commit/b92e32f>

- **iOS restore 狀態同步追蹤**
  - 新增 iOS restore 後鍵盤 extension 仍可能顯示零輸入法的追蹤分析，作為後續修正依據。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/86>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2386_ISSUE.md>

### 文件與維護

- 更新 release draft、issue analysis，以及多份設定、候選列、鍵盤、emoji、碼表規格與備份還原設計文件。
- 新增／更新的重點設計文件（不列 automation state 與 GAP analysis 文件）：
  - 設定：[LIME_SETTINGS.md](https://github.com/lime-ime/limeime/blob/master/docs/LIME_SETTINGS.md)、[PREFS_TABLE.md](https://github.com/lime-ime/limeime/blob/master/docs/PREFS_TABLE.md)
  - 資料表規格：[CIN_LIME_SPEC.md](https://github.com/lime-ime/limeime/blob/master/docs/CIN_LIME_SPEC.md)、[LIMEDB_SPEC.md](https://github.com/lime-ime/limeime/blob/master/docs/LIMEDB_SPEC.md)、[LIME_DB_104.md](https://github.com/lime-ime/limeime/blob/master/docs/LIME_DB_104.md)
  - 備份還原：[DB_BAK_RES.md](https://github.com/lime-ime/limeime/blob/master/docs/DB_BAK_RES.md)、[PREF_BAK_RES.md](https://github.com/lime-ime/limeime/blob/master/docs/PREF_BAK_RES.md)
  - 候選列與輸入行為：[CANDI_LAYOUT.md](https://github.com/lime-ime/limeime/blob/master/docs/CANDI_LAYOUT.md)、[CANDI_FUNCTION_KEYS.md](https://github.com/lime-ime/limeime/blob/master/docs/CANDI_FUNCTION_KEYS.md)、[TWO_STAGE_CANDI.md](https://github.com/lime-ime/limeime/blob/master/docs/TWO_STAGE_CANDI.md)、[IOS_CANDI_TOUCH.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_CANDI_TOUCH.md)、[IOS_FN_KEY_SPLIT.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_FN_KEY_SPLIT.md)、[IOS_POPUP_COMPOSING.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_POPUP_COMPOSING.md)
  - 鍵盤版面與主題：[KEYBOARD_TYPE.md](https://github.com/lime-ime/limeime/blob/master/docs/KEYBOARD_TYPE.md)、[KEYBOARD_THEME.md](https://github.com/lime-ime/limeime/blob/master/docs/KEYBOARD_THEME.md)、[PHONETIC_KEYBOARD.md](https://github.com/lime-ime/limeime/blob/master/docs/PHONETIC_KEYBOARD.md)、[ENGLISH_KB.md](https://github.com/lime-ime/limeime/blob/master/docs/ENGLISH_KB.md)、[ANDROID_THEME.md](https://github.com/lime-ime/limeime/blob/master/docs/ANDROID_THEME.md)、[IPHONE_LEGACY_KB.md](https://github.com/lime-ime/limeime/blob/master/docs/IPHONE_LEGACY_KB.md)
  - iPad 鍵盤：[IPAD_KEYBOARD.md](https://github.com/lime-ime/limeime/blob/master/docs/IPAD_KEYBOARD.md)、[IPAD_ASSIST_BAR.md](https://github.com/lime-ime/limeime/blob/master/docs/IPAD_ASSIST_BAR.md)、[IPAD_DUAL_SLIDING_SYMBOLS.md](https://github.com/lime-ime/limeime/blob/master/docs/IPAD_DUAL_SLIDING_SYMBOLS.md)、[IPAD_KB_SIZE_TIERS.md](https://github.com/lime-ime/limeime/blob/master/docs/IPAD_KB_SIZE_TIERS.md)、[IPAD_KB_LAYOUT_COVERTER.md](https://github.com/lime-ime/limeime/blob/master/docs/IPAD_KB_LAYOUT_COVERTER.md)
  - emoji：[EMOJI_KEYBOARD.md](https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_KEYBOARD.md)、[EMOJI_DB_V2.md](https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_DB_V2.md)、[EMOJI_BAR.md](https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_BAR.md)、[EMOJI_SEACH_PANEL.md](https://github.com/lime-ime/limeime/blob/master/docs/EMOJI_SEACH_PANEL.md)
  - 語音與 iOS 行為：[ANDROID_LIME_DITACTION.md](https://github.com/lime-ime/limeime/blob/master/docs/ANDROID_LIME_DITACTION.md)、[ANDROID_VOICE_INPUT.md](https://github.com/lime-ime/limeime/blob/master/docs/ANDROID_VOICE_INPUT.md)、[IOS_VOICE_INPUT.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_VOICE_INPUT.md)、[IOS_CHN_ENG.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_CHN_ENG.md)、[IOS_LIGHT_DARK.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_LIGHT_DARK.md)、[IOS_HAPTIC.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_HAPTIC.md)、[IOS_FULL_PREMISSION.md](https://github.com/lime-ime/limeime/blob/master/docs/IOS_FULL_PREMISSION.md)
