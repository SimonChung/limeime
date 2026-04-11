// IMInstallView.swift
// LimeIME-iOS
//
// IM install screen — local file import + cloud download.
// Spec §5.3.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - IMInstallView

struct IMInstallView: View {

    let onRefresh: (() -> Void)?

    @EnvironmentObject private var setupController: SetupImController

    @State private var showFilePicker = false
    @State private var pickerType: ImportType = .db
    @State private var pendingTableName: String = ""  // §13.3: fixed tableName for the pending import
    @State private var isImporting = false
    @State private var statusMessage = ""

    // Cloud download state
    @StateObject private var downloadManager = IMDownloadManager()
    @State private var expandedFamilies: Set<String> = []
    @State private var searchText = ""

    enum ImportType { case db, txt }

    init(onRefresh: (() -> Void)? = nil) {
        self.onRefresh = onRefresh
    }

    var filteredFamilies: [IMFamily] {
        if searchText.isEmpty { return IMCatalog.families }
        let q = searchText.lowercased()
        return IMCatalog.families.compactMap { family in
            let nameMatch = family.chineseName.localizedCaseInsensitiveContains(q) ||
                            family.englishName.localizedCaseInsensitiveContains(q)
            // Keep families with no variants if the family name matches (e.g. 自建)
            if family.variants.isEmpty {
                return nameMatch ? family : nil
            }
            let variants = family.variants.filter {
                $0.name.localizedCaseInsensitiveContains(q) || nameMatch
            }
            guard !variants.isEmpty else { return nil }
            return IMFamily(id: family.id, chineseName: family.chineseName,
                            englishName: family.englishName, description: family.description,
                            systemIcon: family.systemIcon, variants: variants)
        }
    }

    var body: some View {
        List {
            // MARK: Status
            if !statusMessage.isEmpty {
                Section(header: Text("狀態")) {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: Per-IM DisclosureGroups (§5.3 / §13.3)
            // Each group shows cloud variant rows (built-in IMs only) + local import buttons.
            // The 自建 group shows only local import buttons (no cloud variants).
            Section(header: Text("下載 / 匯入輸入法")) {
                ForEach(filteredFamilies) { family in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFamilies.contains(family.id) },
                            set: { expanded in
                                if expanded { expandedFamilies.insert(family.id) }
                                else { expandedFamilies.remove(family.id) }
                            }
                        )
                    ) {
                        // Cloud download rows (built-in IMs only)
                        ForEach(family.variants) { variant in
                            VariantRow(variant: variant, manager: downloadManager)
                        }
                        // Local import buttons — tableName fixed to the family's IM code
                        Button {
                            pickerType = .db
                            pendingTableName = family.id
                            showFilePicker = true
                        } label: {
                            Label("匯入 .limedb", systemImage: "archivebox")
                                .foregroundColor(.accentColor)
                        }
                        Button {
                            pickerType = .txt
                            pendingTableName = family.id
                            showFilePicker = true
                        } label: {
                            Label("匯入 .cin / .lime", systemImage: "doc.text")
                                .foregroundColor(.accentColor)
                        }
                    } label: {
                        Label(family.chineseName + " (" + family.englishName + ")",
                              systemImage: family.systemIcon)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜尋輸入法")
        .navigationTitle("下載 / 匯入輸入法")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { downloadManager.refreshInstalledTables() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            expandedFamilies = Set(IMCatalog.families.map { $0.id })
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedTypes(),
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("匯入中…")
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 8))
                }
            }
        }
    }

    // MARK: - Helpers

    private func allowedTypes() -> [UTType] {
        switch pickerType {
        case .db:  return [UTType.item]
        case .txt: return [UTType.plainText, .item]
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        isImporting = true
        statusMessage = ""

        let ext = url.pathExtension.lowercased()
        // Use pendingTableName (set by the import button that launched the picker);
        // fall back to deriving from filename for any legacy generic picker path.
        let tableName = pendingTableName.isEmpty
            ? (url.deletingPathExtension().lastPathComponent
                .components(separatedBy: .init(charactersIn: "-_")).first ?? "custom")
            : pendingTableName
        let seedCustomAfter = (tableName == "custom")

        Task {
            if ext == "db" || ext == "limedb" {
                let r = await setupController.importDBFile(url: url, tableName: tableName)
                switch r {
                case .success(let table):
                    if seedCustomAfter { try? DBServer.shared.seedCustomIM() }
                    statusMessage = "已成功匯入 \(table)"
                    onRefresh?()
                case .failure(let error):
                    statusMessage = "匯入失敗：\(error.localizedDescription)"
                }
            } else {
                let r = await setupController.importTxtFile(url: url, tableName: tableName)
                switch r {
                case .success(let count):
                    if seedCustomAfter { try? DBServer.shared.seedCustomIM() }
                    statusMessage = "文字檔匯入完成，共 \(count) 筆"
                    onRefresh?()
                case .failure(let error):
                    statusMessage = "匯入失敗：\(error.localizedDescription)"
                }
            }
            isImporting = false
            pendingTableName = ""
        }
    }
}
