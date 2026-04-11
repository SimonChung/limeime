// IMDetailView.swift
// LimeIME-iOS
//
// IM detail drill-down showing metadata, keyboard picker, and table editor link.
// Spec §5.2.

import SwiftUI

// MARK: - IMDetailView

struct IMDetailView: View {

    let im: IMRow
    let onRefresh: (() -> Void)?

    private let sharedUD = UserDefaults(suiteName: "group.net.toload.limeime")

    // §13.3 — custom IM mapping toggles (only shown when tableNick == "custom")
    @AppStorage("accept_number_index", store: sharedDefaults) private var acceptNumberIndex: Bool = false
    @AppStorage("accept_symbol_index", store: sharedDefaults) private var acceptSymbolIndex: Bool = false

    init(im: IMRow, onRefresh: (() -> Void)? = nil) {
        self.im = im
        self.onRefresh = onRefresh
    }

    private var mappingVersion: String {
        sharedUD?.string(forKey: im.tableNick + "mapping_version") ?? "—"
    }

    private var totalRecord: String {
        sharedUD?.string(forKey: im.tableNick + "total_record") ?? "—"
    }

    var body: some View {
        List {
            Section(header: Text("輸入法資訊")) {
                LabeledContent("代碼", value: im.tableNick)
                LabeledContent("版本", value: mappingVersion)
                LabeledContent("字數", value: totalRecord)
                LabeledContent("狀態", value: im.enabled ? "已安裝" : "停用")
            }

            Section(header: Text("軟鍵盤配置")) {
                NavigationLink(destination: KeyboardPickerView(im: im, onSave: onRefresh)) {
                    LabeledContent("鍵盤佈局", value: im.keyboardId.isEmpty ? "—" : im.keyboardId)
                }
            }

            Section(header: Text("字根對應表")) {
                NavigationLink(destination: RecordListView(tableName: im.tableNick,
                                                           imLabel: im.label)) {
                    Label("瀏覽 / 編輯對應表", systemImage: "tablecells")
                }
            }

            // §13.3 — shown only for the user-built custom IM
            if im.tableNick == "custom" {
                Section(header: Text("字根對應設定")) {
                    Toggle("數字字根對應", isOn: $acceptNumberIndex)
                    Toggle("符號字根對應", isOn: $acceptSymbolIndex)
                }
            }
        }
        .navigationTitle(im.label)
    }
}
