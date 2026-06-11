# LimeIME Privacy Policy / 萊姆輸入法 隱私權政策

**App:** LIME IME 6 (萊姆輸入法 6) — package `org.limeime` *(current beta builds use `net.toload.main.hd2026`)*
**Publisher:** The LimeIME Open Source Project
**Contact:** GitHub Issues — <https://github.com/lime-ime/limeime/issues>
**Project:** <https://github.com/lime-ime/limeime>
**Website:** <https://lime-ime.github.io/limeime/>
**Last updated:** 2026-06-07

> Publishing note: this file is the source draft. To satisfy Google Play's
> "privacy policy at a public HTTPS URL" requirement, publish it via GitHub
> Pages (the repo already uses Jekyll). Suggested public URL once the page is
> live: `https://lime-ime.github.io/limeime/PRIVACY/`. Add it under
> **Play Console → App content → Privacy policy**.

---

## English

### Summary

LimeIME is an offline-first input method (keyboard). **Your typing stays on your
device.** LimeIME does not have any server that collects, stores, or receives
the text you type, your learned words, or your personal user dictionary.

### What LimeIME stores on your device

- **Typed-text learning data.** To improve candidate ordering, LimeIME keeps a
  local, per-user score for words/phrases you use. This data is stored **only on
  your device** and is never uploaded.
- **User dictionaries and settings.** Custom phrases, enabled input methods, and
  preferences are stored locally.
- **Backup files.** When you choose to back up, LimeIME writes a `.zip` file to a
  location **you select** through the Android file picker (Storage Access
  Framework). LimeIME does not send this file anywhere; you control where it goes.

### What LimeIME sends over the network

LimeIME requests the `INTERNET` and `ACCESS_NETWORK_STATE` permissions for one
purpose only:

- **Downloading input-method tables (碼表) you choose** from the project's
  distribution server, and checking network availability before doing so.

LimeIME does **not** transmit your keystrokes, typed text, learned words, or
personal dictionary over the network.

### Microphone / voice input

LimeIME requests `RECORD_AUDIO` to offer **optional** in-keyboard voice typing.

- Voice typing is **opt-in** and only active when you tap the voice key.
- Speech recognition is performed by the **device's system speech service**
  (Android's `RECOGNIZE_SPEECH`), not by a LimeIME server. LimeIME does not
  record, store, or upload audio itself.
- If you do not grant the microphone permission, only in-keyboard voice typing is
  unavailable; all other keyboard features — every Chinese and English input
  method, word completion, emoji, and so on — are unaffected. You can still use
  Google's or the system's voice input by switching away from the LIME keyboard
  and back.

### Permissions and why they are used

| Permission | Purpose |
| --- | --- |
| `RECORD_AUDIO` | Optional in-keyboard voice typing; recognition handled by the system speech service. |
| `INTERNET` | Download user-selected input-method tables. |
| `ACCESS_NETWORK_STATE` | Check connectivity before a download. |
| `POST_NOTIFICATIONS` | Show status/progress notifications (e.g., downloads). |
| `VIBRATE` | Optional haptic feedback on key press. |

### Data sharing and selling

LimeIME does **not** sell or share your personal data with third parties.

### Children

LimeIME is a general-purpose keyboard and is not directed at children. It does
not knowingly collect personal information from children.

### Data deletion

Because data is stored locally, you can remove it at any time by clearing the
app's data or uninstalling the app. Uninstalling removes all on-device LimeIME
data except backup files you explicitly saved elsewhere.

### Open source

LimeIME is free software licensed under the GNU General Public License v3. The
full source is available at <https://github.com/lime-ime/limeime>. The bundled
English frequency dictionary is derived from Google Books Ngrams (CC BY 3.0); see
[LICENSE.md](../LICENSE.md).

### Changes to this policy

We may update this policy as features change. The "Last updated" date above
reflects the latest revision.

### Contact

Questions: open an issue at <https://github.com/lime-ime/limeime/issues>.

---

## 中文（繁體）

### 摘要

萊姆輸入法是一套以離線為主的輸入法（鍵盤）。**您輸入的文字保留在您的裝置上。**
萊姆輸入法沒有任何伺服器會蒐集、儲存或接收您輸入的文字、學習詞彙或個人使用者
詞庫。

### 萊姆輸入法在您裝置上儲存的資料

- **輸入學習資料。** 為了改善候選字排序，萊姆會在本機保存您使用詞彙的個人分數。
  此資料**僅儲存於您的裝置**，不會上傳。
- **使用者詞庫與設定。** 自訂詞彙、啟用的輸入法與偏好設定均儲存於本機。
- **備份檔。** 當您選擇備份時，萊姆會透過 Android 檔案選取器（SAF）將 `.zip`
  寫入**您所選擇**的位置。萊姆不會將該檔案傳送至任何地方。

### 萊姆透過網路傳送的資料

萊姆僅為以下用途要求 `INTERNET` 與 `ACCESS_NETWORK_STATE` 權限：

- **下載您所選擇的輸入法碼表**，並在下載前檢查網路是否可用。

萊姆**不會**透過網路傳送您的按鍵、輸入文字、學習詞彙或個人詞庫。

### 麥克風／語音輸入

萊姆要求 `RECORD_AUDIO` 以提供**選用的**鍵盤內語音輸入。

- 語音輸入為**選用**功能，僅在您點擊語音鍵時啟動。
- 語音辨識由**裝置的系統語音服務**（Android `RECOGNIZE_SPEECH`）執行，並非由
  萊姆伺服器處理。萊姆本身不會錄製、儲存或上傳音訊。
- 若您不授予麥克風權限，僅鍵盤內語音輸入無法使用；所有中英文輸入法、字詞補全、Emoji 等其餘鍵盤功能皆不受影響。您仍可改用 Google 或系統提供的語音輸入（需離開 LIME 鍵盤畫面再返回）。

### 權限用途

| 權限 | 用途 |
| --- | --- |
| `RECORD_AUDIO` | 選用的鍵盤內語音輸入；辨識由系統語音服務處理。 |
| `INTERNET` | 下載使用者選擇的輸入法碼表。 |
| `ACCESS_NETWORK_STATE` | 下載前檢查網路連線。 |
| `POST_NOTIFICATIONS` | 顯示狀態／進度通知（例如下載）。 |
| `VIBRATE` | 選用的按鍵震動回饋。 |

### 資料分享與販售

萊姆**不會**販售或與第三方分享您的個人資料。

### 兒童

萊姆為通用鍵盤，並非以兒童為對象，且不會在知情情況下蒐集兒童的個人資訊。

### 資料刪除

由於資料儲存於本機，您可隨時透過清除應用程式資料或解除安裝來移除。

### 開源

萊姆為自由軟體，採用 GNU GPL v3 授權，原始碼位於
<https://github.com/lime-ime/limeime>。內建英文詞頻字典衍生自 Google Books
Ngrams（CC BY 3.0），詳見 [LICENSE.md](../LICENSE.md)。

### 聯絡方式

問題請於 <https://github.com/lime-ime/limeime/issues> 提出。
