# LIME 2026 — 版本 v6.0.1

**版本標籤：** `6.0.1-2026`
**APK：** `LIMEHD2026-6.0.1.apk`
**套件名稱：** `net.toload.main.hd2026`
**目標 SDK：** 36 | **最低 SDK：** 21
**前一版本：** v6.0.0

本次為 v6.0.0 之後的維護更新，集中修復使用者於 Android 16 / 含手勢列裝置上回報的兩個顯示問題，並補強鍵盤在不同視窗寬度下的版面計算。

---

## 更新內容

### 修正

- **#44 — 英文輸入：選關聯字後游標未移到字尾**
  - 問題：英文輸入模式下打一兩個字母後，從上方候選列直接點選關聯字，游標停留在原本位置而非移到該單字最後，導致接續輸入位置錯亂。
  - 根因：`LIMEService` 在英文候選字選取流程中以 `InputConnection.commitText(text, 0)` 提交文字，第二個參數 `0` 代表 commit 後游標停在新文字的起點；應使用 `1` 讓游標落在新文字之後。
  - 修正：將兩處英文候選字 commit（一般詞與 emoji）皆改為 `commitText(..., 1)`，游標即正確跳到單字尾端，可直接接續輸入。
  - 影響檔案：`LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`（約 line 3647 / 3652）

- **#46 — 深色鍵盤主題未連動系統導覽列顏色**
  - 問題：選用「深色」鍵盤主題時，鍵盤本體呈深灰 (`#FF373737`)，但底部系統導覽列仍維持淺色，於 Android 16（如 Samsung A16）出現一條明顯的淺色帶。
  - 根因有兩處：
    1. `LIMEService.setNavigationBarIconsDark()` 寫死「淺色背景／深色圖示」，與目前主題無關，且未設定導覽列背景顏色。
    2. API 35+ 的 edge-to-edge inset 處理只對 `mCandidateInInputView` 補上 `bottomInset` padding，但容器背景為透明，導致補出的區塊顯示為宿主 App 的導覽列底色。
  - 修正：以新的 `applyNavigationBarTheme()` 取代舊方法，讀取 `mKeyboardThemeIndex` 取得當前主題的鍵盤背景色（6 種主題：Light / Dark / Pink / TechBlue / FashionPurple / RelaxGreen），同時：
    - 將 `mCandidateInInputView` 的背景色直接塗成主題色（這是讓淺色帶消失的關鍵）。
    - 對 IME 視窗呼叫 `setNavigationBarColor()` 並依 Rec. 709 luma 自動選擇淺／深圖示，於有支援的裝置上直接連動系統列顏色。
    - 於 `onCreateInputView()` 與 `onStartInputView()` 兩處皆呼叫，使用者切換主題後可立即生效，不需重建輸入框。
  - 影響檔案：`LimeStudio/app/src/main/java/net/toload/main/hd/LIMEService.java`

- **#47 — 軟鍵盤右側按鍵被裁切**
  - 問題：QWERTY 配置最右邊一行（`p`、`0`、Backspace 一帶）在部分裝置上被切掉，難以點擊。
  - 根因：`LIMEBaseKeyboard` 以 `dm.widthPixels` 作為佈局寬度基準，但實際 IME 容器在有 display cutout、手勢列、分割視窗等情況下會比 `dm.widthPixels` 小；`LIMEKeyboardBaseView.onMeasure()` 雖將 view 寬度收斂至父層 spec，卻未重算每個按鍵的座標。
  - 修正：
    - `LIMEBaseKeyboard` 改以 `WindowManager.getCurrentWindowMetrics()` 扣除 `systemBars()` 與 `displayCutout()` insets，取得真正可用寬度（API 30+），舊版維持 `dm.widthPixels` fallback。
    - `LIMEKeyboardBaseView.onMeasure()` 於父層寬度仍小於計算寬度時，呼叫 `mKeyboard.resize()` 將所有按鍵依比例縮回，避免舍入誤差或多視窗動態調整造成的溢位。
  - 影響檔案：
    - `LimeStudio/app/src/main/java/net/toload/main/hd/keyboard/LIMEBaseKeyboard.java`
    - `LimeStudio/app/src/main/java/net/toload/main/hd/keyboard/LIMEKeyboardBaseView.java`

### 文件

- `docs/EDGE_TO_EDGE_REVIEW.md` § 2 補充交叉引用 #46，註明 inset padding 區塊需自行塗背景。
- 新增 `docs/#46_ISSUE.md`、`docs/#47_ISSUE.md` 完整記錄問題分析、修正策略與驗證步驟。

---
