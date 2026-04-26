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
    let fullName: String
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

    // Selection-driven navigation. The parent owns the "currently shown
    // detail" identity. After a delete, IMDetailView calls back with
    // `clearSelection()` which sets this to nil — `NavigationSplitView`
    // reacts by reverting the detail column to the placeholder on iPad,
    // and by popping the pushed view on iPhone.
    //
    // We use NavigationSplitView (iOS 16+) instead of the deprecated
    // `NavigationView` + `NavigationLink(tag:selection:)` combo because
    // the latter has a long-standing SwiftUI bug: setting selection to nil
    // does NOT clear the iPad detail column, so a deleted IM's detail pane
    // would stay on screen. NavigationSplitView handles this correctly.
    private enum DetailSelection: Hashable {
        case im(Int64)
        case related
        case install
    }
    @State private var selection: DetailSelection?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("管理輸入法")
                .onAppear { loadIMs() }
                .onChange(of: manageImController.refreshToken) { _ in loadIMs() }
        } detail: {
            NavigationStack {
                detailContent
            }
        }
    }

    // MARK: - Sidebar (master column)

    @ViewBuilder
    private var sidebar: some View {
        Group {
            if isLoading {
                ProgressView("載入中…")
            } else if let err = errorMessage {
                Text(err).foregroundColor(.secondary)
            } else {
                List(selection: $selection) {
                    Section(header: Text("已安裝的輸入法")) {
                        if imList.isEmpty {
                            Text("尚未匯入任何輸入法")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach($imList) { $row in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(row.label)
                                            .font(.body)
                                            .opacity(row.enabled ? 1.0 : 0.5)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $row.enabled)
                                        .labelsHidden()
                                        .onChange(of: row.enabled) { newVal in
                                            toggleIM(imName: row.imName, enabled: newVal)
                                        }
                                }
                                .tag(DetailSelection.im(row.id))
                            }
                            .onMove(perform: moveIMs)
                        }
                    }

                    Section(header: Text("聯想詞庫")) {
                        Label("關聯詞庫", systemImage: "text.bubble")
                            .tag(DetailSelection.related)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        selection = .install
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding([.bottom, .trailing], 20)
                }
            }
        }
    }

    // MARK: - Detail column

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .im(let id):
            if let row = imList.first(where: { $0.id == id }) {
                IMDetailView(im: row, onRefresh: loadIMs, onDeleted: clearSelection)
            } else {
                placeholder
            }
        case .related:
            IMDetailView(
                im: IMRow(id: -1, imName: "related", label: "關聯詞庫",
                          tableNick: "related", fullName: "",
                          enabled: true, sortOrder: 0, keyboardId: ""),
                onRefresh: nil,
                onDeleted: clearSelection)
        case .install:
            IMInstallView(onRefresh: loadIMs)
        case .none:
            placeholder
        }
    }

    private var placeholder: some View {
        Text("選擇一個輸入法")
            .font(.title3)
            .foregroundColor(.secondary)
    }

    /// Called by IMDetailView after a successful remove. Setting selection to
    /// nil tells `NavigationSplitView` to dismiss the detail pane: on iPad
    /// the detail column reverts to the placeholder; on iPhone the pushed
    /// detail view pops back to this list.
    private func clearSelection() {
        selection = nil
    }

    // MARK: - Helpers

    private func loadIMs() {
        Task {
            let configs = await manageImController.loadIMList()
            let rows = configs.map { c in
                IMRow(id: c.id,
                      imName: c.imName,
                      label: c.label.isEmpty ? c.imName : c.label,
                      tableNick: c.tableNick,
                      fullName: c.fullName,
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
