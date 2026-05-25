# LIME 2026 — 版本 v6.1.12

**版本標籤：** `v6.1.12`
**APK：** [`LIMEHD2026-6.1.12.apk`](https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.12.apk)
**套件名稱：** `net.toload.main.hd2026`
**目標 SDK：** 36 | **最低 SDK：** 21
**前一正式版本：** [v6.0.2](https://github.com/lime-ime/limeime/releases/tag/v6.0.2)

v6.0.2 之後的維護更新：本版整理 6.1.x 測試 APK 已累積的 Android 修正與跨平台資料／設定更新，包含候選列與鍵盤互動、輸入欄位模式、表格／備份還原、深色模式與 emoji 搜尋、下載表格，以及多項 iOS 來源同步更新。

---

## 更新內容

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
  - 6.1.12 支援中文 emoji 搜尋；6.1.11 與更早版本不支援此路徑。
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

- **#72 / PR #84 — 新增可下載「哈哈倉頡／四碼倉頡」表格**
  - 新增 `cj4.limedb` 下載表格與 Android/iOS catalog 條目，並補上來源與授權資訊。
  - Android APK 6.1.12 已可下載使用；iOS catalog/source 更新已在 `master`，實際使用仍需 iOS/TestFlight 發布流程。
  - 相關 issue：<https://github.com/lime-ime/limeime/issues/72>
  - 相關 PR：<https://github.com/lime-ime/limeime/pull/84>
  - 相關提交：<https://github.com/lime-ime/limeime/commit/fccf1fb64b6c91db25b744de2a09814e4d6d9940>
  - 分析文件：<https://github.com/lime-ime/limeime/blob/master/docs/%2372_ISSUE.md>

- **跨平台偏好設定備份／還原**
  - 新增跨平台 preference backup / restore 支援，並讓 Android 與 iOS 的資料庫備份格式更一致。
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

- 更新 release draft、issue analysis、automation memory 與多份 iOS/Android 設計文件。
- 新增／更新的重點文件：
  - <https://github.com/lime-ime/limeime/blob/master/docs/AUTOMATION_MEMORY.md>
  - <https://github.com/lime-ime/limeime/blob/master/docs/LIME_SETTINGS.md>
  - <https://github.com/lime-ime/limeime/blob/master/docs/IOS_KB_GAP.md>
  - <https://github.com/lime-ime/limeime/blob/master/docs/IOS_FULL_PREMISSION.md>

---

## 下載

- Android APK：<https://raw.githubusercontent.com/lime-ime/limeime/master/LimeStudio/app/release/LIMEHD2026-6.1.12.apk>
- GitHub compare：<https://github.com/lime-ime/limeime/compare/v6.0.2...master>

---

## 已知提醒

- 這個 Release 的附件是 Android APK；iOS 來源更新不代表 iOS/TestFlight 已同步可安裝。
- #85 的 Android 還原失敗回報與舊備份相容性已進入 6.1.12 APK；iOS restore 狀態同步仍由 #86 追蹤。
- #79 的 Android 深色模式 emoji 搜尋欄已由回報者確認改善；若仍遇到中文 emoji 搜尋輸入差異，請確認已安裝 6.1.12 或更新版本。
