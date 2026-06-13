# UI Kit — LIME Settings (iOS, 4-tab)

A high-fidelity, interactive recreation of the **LimeIME container app** — the
iOS Settings app the user sees on the Home Screen (not the keyboard extension).
Re-laid-out from the canonical spec in
[`docs/LIME_SETTINGS.md`](https://github.com/lime-ime/limeime/blob/master/docs/LIME_SETTINGS.md)
and the SwiftUI source under `LimeIME-iOS/LimeSettings/`.

## The four tabs

| Tab | SF Symbol | Screen file | Source |
|---|---|---|---|
| **設定** App Setup | `gearshape` | `SetupTab.jsx` | `SetupTabView.swift` §4 |
| **輸入法** IM Manager | `list.bullet` | `IMTab.jsx` | `IMListView.swift` §5.1 + `IMDetailView` §5.2 |
| **喜好設定** Preferences | `slider.horizontal.3` | `PrefsTab.jsx` | `PreferencesTabView.swift` §8 |
| **資料庫** DB Manager | `archivebox` | `DBTab.jsx` | `DBManagerView.swift` §7 |

## What's interactive
- Bottom **TabBar** switches between the four roots (scroll resets per tab).
- Every **Switch** toggles; the 簡繁轉換 **SegmentedControl** changes.
- Tapping an IM row in **輸入法** pushes the **IMDetailView** drill-down
  (輸入法資訊 / 軟鍵盤配置 / 字根資料表 / 移除輸入法); back chevron pops it.
- A floating **+ FAB** sits on the IM list (download / import entry point).

## Composition
Screens compose the design-system primitives from `window.LIMEDesignSystem_6ca3c0`
(`ListGroup`, `ListRow`, `Switch`, `SegmentedControl`, `Button`, `StatusBanner`,
`TabBar`). Icons are Lucide-style stroke equivalents of the app's SF Symbols
(`icons.jsx`) — flagged as a substitution since SF Symbols can't be redistributed.

Open `index.html` to view inside the iPhone frame.
