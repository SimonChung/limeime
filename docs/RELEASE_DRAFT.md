# LIME 2026 — 版本 v6.0.2

**版本標籤：** `6.0.2-2026`
**APK：** `LIMEHD2026-6.0.2.apk`
**套件名稱：** `net.toload.main.hd2026`
**目標 SDK：** 36 | **最低 SDK：** 21
**前一版本：** v6.0.1

v6.0.1 之後的維護更新：修復候選字學習順序、深色模式連動、#47 縮放遺留的標籤字體異常，以及電話鍵盤符號鍵多擊不穩定。

---

## 更新內容

### 修正

- **#49 — 候選字學習順序無法即時更新**
  - 問題：重複選同一候選字（含 partial match）排序與 DB 分數不會即時反映；需切換 IME 或重開 App 才生效。
  - 修正：`SearchServer.updateScoreCache()` 改為 iOS 的 evict-and-re-warm 模式——逐出該 code 與所有前綴快取，同條背景 thread 呼叫 `getMappingByCode(..., prefetchCache=true)` 重查 DB；取消原本在 background thread 上就地改 `ArrayList` 的 race path。另外拆除原本隱藏 partial-match 分支的 `cachedList != null` gate，確保 partial match 選取也會逐出前綴快取，避免 addScore 持續寫回 stale score+1。
  - 影響檔案：`SearchServer.java`
  - 相關提交：`b04af8b0`、`3f478563`；詳細分析見 `docs/#49_CACHE_UPDATE_ISSUE.md`。

- **#50 (A) — 深色模式未連動系統與 App 各畫面**
  - 問題：鍵盤深色主題外，MainActivity、設定頁、選單、狀態列／導覽列仍是淺色，系統切換時不跟。
  - 修正：新增鍵盤主題 6 (跟隨系統)，以 `isEffectiveDarkTheme()` 供 dialog / icon 動態選色；Activity 主題改繼承 `Theme.AppCompat.DayNight` 並於 static init 呼叫 `setDefaultNightMode(MODE_NIGHT_FOLLOW_SYSTEM)`；狀態列／導覽列圖示依 `uiMode` 透過 `WindowInsetsControllerCompat` 切換；清掉寫死的淺色 tint / 底色。
  - 影響檔案：`LIMEService.java`、`MainActivity.java`、`LIMEPreference.java`、`res/values/styles.xml`、`res/drawable/outline_{share,settings}_24.xml`、`res/layout/main.xml`；詳細主題架構見 `docs/ANDROID_THEME.md`。

- **#50 (B) — 空白鍵未能 commit partial-match 候選字**
  - 問題：輸入 partial code（如「38783」對應完整「387833」）時，第一字不高亮，按空白鍵送出原始組字碼而非候選字。
  - 修正：`CandidateView.setSuggestions()` 與 `LIMEService` 空白鍵提交條件加上 `isPartialMatchToCodeRecord()`。
  - 影響檔案：`CandidateView.java`、`LIMEService.java`
  - 相關提交：`2a915289`（與 #50 (A) 一併）。

- **#51 — 按鍵標籤字體在升級後變小**
  - 問題：6.0.0 → 6.0.1 後按鍵文字縮小約兩級，重裝行為不一致；大螢幕更明顯。
  - 根因：6.0.1 為修 #47 在 `onMeasure()` 後呼叫 `scaleHorizontally()` 調整每顆鍵的 `x / width / gap`，但 `mDefaultWidth` 沒跟著更新 → `Key.getLabelSizeScale()` 對每顆鍵都走到 `mSplitedKeyWidthScale (<1.0)` 分支；`labelSizeScale` 被 static 欄位快取並擴散到整個 process。
  - 修正：刪除 `scaleHorizontally()` 及其呼叫點；改以 `WindowManager.getCurrentWindowMetrics()` 扣除 `systemBars + displayCutout` insets（API 30+，舊版 fallback `dm.widthPixels`）在建構時直接算對可用寬度。同時修直式堆疊標籤 baseline（上下緣錨點、剩餘空間三等分）解決字體恢復 1.0 後兩行擠在一起的問題。
  - 影響檔案：`LIMEBaseKeyboard.java`、`LIMEKeyboardBaseView.java`
  - 相關提交：`ce40a617`、`984c5b4b`、`fd1ed10d`；詳細分析見 `docs/#51_#47_ISSUES.md`。

- **#53 — 電話鍵盤 `= + - * /` 符號鍵多擊不穩定**
  - 問題：`phone_simple` 鍵盤第二列最右符號鍵預期連點循環 `= + - * /`，實際連點會沒反應或跳字。
  - 修正：改為單碼 `=` 鍵＋長按 popup 送出 `+ - * /`，繞過多擊狀態機與 `DELETE + 新碼` 雙 IPC 路徑。標籤保留 `+-*/\n=`。T9 版 `phone.xml` 不動。
  - 影響檔案：`res/xml/phone_simple.xml`；詳細分析見 `docs/#53_ISSUE.md`。

### 文件

- 新增：`docs/#49_ISSUE.md`、`docs/#49_CACHE_UPDATE_ISSUE.md`、`docs/ANDROID_THEME.md`、`docs/#53_ISSUE.md`。
- `docs/#51_#47_ISSUES.md` 狀態由 *Investigation* 轉為 *Fixed*（新增 § 16 記錄最終 baseline 算法）。

---

## iOS 版本同步更新（LimeIME-iOS）

### 新增功能 — 語音輸入

- **iPad 鍵盤底列加入語音輸入鍵**：在所有 iPad 版面（英文、ABC、注音／行列／倉頡／大易／嘸蝦米／Hsu／EZ／HS、符號、URL、Email、Number、Shift；共 40 個 `*_ipad*.json`）的底列空白鍵兩側加入 emoji（左）與 mic（右）鍵：`[ globe | .?123 | emoji | space | mic | .?123 | dismiss ]`。所有 `code: -99` 暫存碼替換為新增的 `LimeKeyCode.voiceInput = -220`；所有 `@string/label_symbol_key` 標籤統一為字面值 `.?123`；中文輸入法 IM 版面由 `scripts/build_ipad_layouts.py` 重新產生，英文／符號／URL／Email 版面以 `.claude/scripts/update_hand_authored_ipad_bottom_rows.py` 一次性轉換。三家族（A 含中字鍵、B 符號版、C 通用版）皆未動到 `中` 鍵與 `.?123` 鍵；空白鍵寬度按家族略為微調以保持每列總和 100。
- **iPhone 實體 Home 鍵機型加入候選列語音圖示**：iPhone SE 第 2／3 代等沒有系統 mic 列的機型，現在於候選列右側顯示語音麥克風圖示（候選字出現時改顯示展開鍵）。Face ID 機型不顯示（系統已內建 mic 列）；iPad 不顯示（鍵盤底列已有 mic 鍵）。
- **離線語音辨識（VoiceInputController）**：新增 `LimeIME-iOS/LimeKeyboard/VoiceInputController.swift`。採用 `SFSpeechAudioBufferRecognitionRequest` 強制 `requiresOnDeviceRecognition = true`（符合 App Store 對鍵盤擴充功能的政策）；錄音與語音辨識皆在裝置內離線完成，不傳送至雲端。靜默 1.5 秒自動斷句並 commit；可長按再按或按 `✕` 取消。需「允許完整取用」並支援裝置內辨識（A12 仿生晶片以上）才會啟用；不符條件時鍵盤顯示提示，候選列圖示自動隱藏。
- **權限與設定**：擴充功能 `Info.plist` 加入 `NSMicrophoneUsageDescription` 與 `NSSpeechRecognitionUsageDescription`。設定 App 的「喜好設定」加入「語音輸入」分區，可選擇辨識語言（預設 `zh-TW`，支援繁體中文（台灣／香港）、簡體中文、英文（US／UK）、日文）。
- **裝置能力偵測**：新增 `LimeIME-iOS/Shared/DeviceCapabilities.swift`，以 `LAContext.biometryType` 判斷是否為 Face ID 機型、以 `SFSpeechRecognizer.supportsOnDeviceRecognition(for:)` 判斷裝置／語系是否支援離線辨識，作為候選列 mic 圖示顯示閘門。

### 文件

- 新增：`docs/IOS_VOICE_INPUT.md`（語音輸入設計總覽）、`docs/IOS_KB_GAP.md`（落差實作計畫與驗證閘門）。
- 更新：`docs/LIME_SETTINGS.md` §4.1（設定 App「允許完整取用」說明用語修正）。
- `docs/IOS_FULL_PREMISSION.md` 中關於「語音輸入需要完整取用」之描述持續有效，本次實作落實該前提。

### 測試

- `LimeTests` 共 733 個測試全數通過（5 個 skip 為既有），新增 3 個版面驗證測試：底列 emoji 左／voice 右於空白鍵兩側、底列寬度合計 100%、`LimeKeyCode.voiceInput` 為 `-220`。

---
