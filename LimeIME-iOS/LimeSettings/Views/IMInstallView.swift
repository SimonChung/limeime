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
    @EnvironmentObject private var manageRelatedController: ManageRelatedController

    @State private var showFilePicker = false
    @State private var pickerType: ImportType = .db
    @State private var pendingTableName: String = ""  // §13.3: fixed tableName for the pending import
    @State private var isImporting = false
    @State private var statusMessage = ""

    // Cloud download state
    @StateObject private var downloadManager = IMDownloadManager()
    @State private var expandedFamilies: Set<String> = []
    @State private var searchText = ""
    @State private var relatedInstalled: Bool = false

    enum ImportType { case db, txt, relatedDb }

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
                    FamilyInstallGroup(
                        family: family,
                        isInstalled: downloadManager.installedTables.contains(family.id),
                        isExpanded: Binding(
                            get: { !downloadManager.installedTables.contains(family.id) && expandedFamilies.contains(family.id) },
                            set: { expanded in
                                guard !downloadManager.installedTables.contains(family.id) else { return }
                                if expanded { expandedFamilies.insert(family.id) }
                                else { expandedFamilies.remove(family.id) }
                            }
                        ),
                        downloadManager: downloadManager,
                        onImportDB: {
                            pickerType = .db
                            pendingTableName = family.id
                            showFilePicker = true
                        },
                        onImportTxt: {
                            pickerType = .txt
                            pendingTableName = family.id
                            showFilePicker = true
                        }
                    )
                }

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !relatedInstalled && expandedFamilies.contains("related") },
                        set: { expanded in
                            guard !relatedInstalled else { return }
                            if expanded { expandedFamilies.insert("related") }
                            else { expandedFamilies.remove("related") }
                        }
                    )
                ) {
                    Button {
                        pickerType = .relatedDb
                        pendingTableName = "related"
                        showFilePicker = true
                    } label: {
                        Label("匯入 .limedb", systemImage: "archivebox")
                            .foregroundColor(.accentColor)
                    }
                } label: {
                    HStack {
                        Label("聯想詞庫", systemImage: "text.bubble")
                        if relatedInstalled {
                            Spacer()
                            Text("已安裝")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
            refreshInstallStates()
        }
        .onChange(of: downloadManager.installedTables) { newTables in
            // Expand groups for tables that just became uninstalled
            for family in IMCatalog.families where !newTables.contains(family.id) {
                expandedFamilies.insert(family.id)
            }
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
        .onChange(of: downloadManager.installedTables) { _ in
            onRefresh?()
        }
    }

    // MARK: - Helpers

    private func allowedTypes() -> [UTType] {
        switch pickerType {
        case .db, .relatedDb: return [UTType.item]
        case .txt:            return [UTType.plainText, .item]
        }
    }

    private func refreshInstallStates() {
        downloadManager.refreshInstalledTables()
        // All families start expanded; isExpanded binding getter collapses installed ones.
        expandedFamilies = Set(IMCatalog.families.map { $0.id }).union(["related"])
        Task.detached(priority: .background) {
            let hasData = DBServer.shared.tableHasData("related")
            await MainActor.run {
                relatedInstalled = hasData
                if hasData { expandedFamilies.remove("related") }
            }
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
            if pickerType == .relatedDb {
                let server = DBServer.shared
                await Task.detached(priority: .userInitiated) {
                    server.importDbRelated(sourcedb: url)
                }.value
                statusMessage = "聯想詞庫匯入完成"
                manageRelatedController.invalidate()
            } else if ext == "db" || ext == "limedb" {
                let restoreLearning = UserDefaults.standard.object(
                    forKey: "restore_on_import_\(tableName)") as? Bool ?? true
                let r = await setupController.importDBFile(url: url, tableName: tableName,
                                                           restoreLearning: restoreLearning)
                switch r {
                case .success(let table):
                    if seedCustomAfter { try? DBServer.shared.seedCustomIM() }
                    statusMessage = "已成功匯入 \(table)"
                    downloadManager.refreshInstalledTables()
                    onRefresh?()
                case .failure(let error):
                    statusMessage = "匯入失敗：\(error.localizedDescription)"
                }
            } else {
                let restoreLearning = UserDefaults.standard.object(
                    forKey: "restore_on_import_\(tableName)") as? Bool ?? true
                let r = await setupController.importTxtFile(url: url, tableName: tableName,
                                                            restoreLearning: restoreLearning)
                switch r {
                case .success(let count):
                    if seedCustomAfter { try? DBServer.shared.seedCustomIM() }
                    statusMessage = "文字檔匯入完成，共 \(count) 筆"
                    downloadManager.refreshInstalledTables()
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

// MARK: - FamilyInstallGroup

private struct FamilyInstallGroup: View {
    let family: IMFamily
    let isInstalled: Bool
    @Binding var isExpanded: Bool
    let downloadManager: IMDownloadManager
    let onImportDB: () -> Void
    let onImportTxt: () -> Void

    @State private var hasBackup: Bool = false

    private var restoreOnImport: Bool {
        get { UserDefaults.standard.object(forKey: "restore_on_import_\(family.id)") as? Bool ?? true }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: "restore_on_import_\(family.id)") }
    }
    private var restoreOnImportBinding: Binding<Bool> {
        Binding(get: { restoreOnImport }, set: { restoreOnImport = $0 })
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if hasBackup {
                Toggle("還原已學習記錄", isOn: restoreOnImportBinding)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ForEach(family.variants) { variant in
                VariantRow(variant: variant, manager: downloadManager, installOverride: { v in
                    downloadManager.install(v, restoreLearning: restoreOnImport)
                })
            }
            Button(action: onImportDB) {
                Label("匯入 .limedb", systemImage: "archivebox")
                    .foregroundColor(.accentColor)
            }
            Button(action: onImportTxt) {
                Label("匯入 .cin / .lime", systemImage: "doc.text")
                    .foregroundColor(.accentColor)
            }
        } label: {
            HStack {
                Label(family.chineseName, systemImage: family.systemIcon)
                if isInstalled {
                    Spacer()
                    Text("已安裝")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task(id: isInstalled) {
            // Backup tables are keyed by the variant's `tableName` (set when the IM was
            // imported), which is NOT always equal to `family.id` — e.g. cangjie family
            // has variants with tableNames "cj", "cj5", "scj", "ecj". Check every
            // distinct tableName the family covers, plus family.id as fallback.
            //
            // Also honour the `user_backed_up_<tableNick>` flag set by IMDetailView
            // when the user removed the IM with backup enabled. checkBackupTable
            // returns false when the backup table has 0 rows (no learned records
            // existed at delete time, since backup only includes score>0). The
            // toggle should still appear so the user's intent is preserved.
            let candidates: Set<String> = Set(family.variants.map { $0.tableName }).union([family.id])
            let ud = UserDefaults.standard
            let userOpted = candidates.contains { ud.bool(forKey: "user_backed_up_\($0)") }
            let backup = await Task.detached(priority: .background) {
                let ss = DBServer.shared.makeSearchServer()
                return candidates.contains { ss?.checkBackupTable($0) ?? false }
            }.value
            hasBackup = backup || userOpted
            if hasBackup && !isInstalled {
                isExpanded = true
            }
        }
    }
}
