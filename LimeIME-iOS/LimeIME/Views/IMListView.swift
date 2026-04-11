// IMListView.swift
// LimeIME-iOS
//
// IM Manager tab — list of installed IMs with enable/disable and reorder.
// Spec §5.1.

import SwiftUI

// MARK: - IMRow

struct IMRow: Identifiable {
    let id: Int64
    let imName: String
    let label: String
    let tableNick: String
    var enabled: Bool
    var sortOrder: Int
    var keyboardId: String
}

// MARK: - IMListView

struct IMListView: View {

    @EnvironmentObject private var manageImController: ManageImController

    @State private var imList: [IMRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("載入中…")
                } else if let err = errorMessage {
                    Text(err).foregroundColor(.secondary)
                } else {
                    List {
                        Section(header: Text("已安裝的輸入法")) {
                            if imList.isEmpty {
                                Text("尚未匯入任何輸入法")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach($imList) { $row in
                                    NavigationLink(destination: IMDetailView(im: row, onRefresh: loadIMs)) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(row.label)
                                                    .font(.body)
                                                    .opacity(row.enabled ? 1.0 : 0.5)
                                                Text(row.tableNick)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .opacity(row.enabled ? 1.0 : 0.5)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $row.enabled)
                                                .labelsHidden()
                                                .onChange(of: row.enabled) { newVal in
                                                    toggleIM(imName: row.imName, enabled: newVal)
                                                }
                                        }
                                    }
                                }
                                .onMove(perform: moveIMs)
                            }
                        }

                        Section(header: Text("輸入法庫")) {
                            NavigationLink(destination: IMInstallView(onRefresh: loadIMs)) {
                                Label("下載 / 匯入輸入法", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                    .toolbar { EditButton() }
                }
            }
            .navigationTitle("管理輸入法")
            .onAppear { loadIMs() }
            .onChange(of: manageImController.refreshToken) { _ in loadIMs() }
        }
    }

    // MARK: - Helpers

    private func loadIMs() {
        isLoading = true
        Task {
            let configs = await manageImController.loadIMList()
            let rows = configs.map { c in
                IMRow(id: c.id,
                      imName: c.imName,
                      label: c.label.isEmpty ? c.imName : c.label,
                      tableNick: c.tableNick,
                      enabled: c.enabled,
                      sortOrder: c.sortOrder,
                      keyboardId: c.keyboardId)
            }
            imList = rows
            isLoading = false
            errorMessage = nil
        }
    }

    private func toggleIM(imName: String, enabled: Bool) {
        Task {
            await manageImController.setIMEnabled(imName: imName, enabled: enabled)
        }
    }

    private func moveIMs(from source: IndexSet, to dest: Int) {
        imList.move(fromOffsets: source, toOffset: dest)
        for (idx, row) in imList.enumerated() {
            let id = row.id
            Task {
                await manageImController.setIMSortOrder(id: id, sortOrder: idx)
            }
        }
    }
}
