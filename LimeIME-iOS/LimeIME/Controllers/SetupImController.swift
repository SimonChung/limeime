// SetupImController.swift
// LimeIME-iOS
//
// Orchestrates IM import, backup/restore, seeding.
// Mirrors Android SetupImController.

import Foundation

// MARK: - SetupImController

@MainActor
final class SetupImController: BaseController {

    // MARK: - Dependencies

    private let progress: ProgressManager

    // MARK: - Init

    init(dbServer: DBServer = .shared, prefs: LIMEPreferenceManager = .shared,
         progress: ProgressManager) {
        self.progress = progress
        super.init(dbServer: dbServer, prefs: prefs)
    }

    // MARK: - Import txt file (.cin / .lime)

    func importTxtFile(url: URL, tableName: String, view: (any SetupImView)?) {
        progress.show(status: "匯入中…")
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            do {
                var lastCount = 0
                try server.importTxtFile(at: url.path, tableName: tableName) { count in
                    lastCount = count
                    Task { @MainActor in
                        view?.onProgress(50, status: "已匯入 \(count) 筆…")
                    }
                }
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onProgress(100, status: "文字檔匯入完成，共 \(lastCount) 筆")
                    view?.refreshImList()
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onError("匯入失敗：\(msg)")
                }
            }
        }
    }

    // MARK: - Import txt file (async, SwiftUI-friendly)

    func importTxtFile(url: URL, tableName: String) async -> Result<Int, Error> {
        await MainActor.run { progress.show(status: "匯入中…") }
        let server = self.dbServer
        return await Task.detached(priority: .userInitiated) {
            do {
                var lastCount = 0
                try server.importTxtFile(at: url.path, tableName: tableName) { count in
                    lastCount = count
                }
                return .success(lastCount)
            } catch {
                return .failure(error)
            }
        }.value
    }

    // MARK: - Import binary DB file (.db / .limedb)

    func importDBFile(url: URL, tableName: String, view: (any SetupImView)?) {
        progress.show(status: "匯入中…")
        let server = self.dbServer
        let safeTable = server.isValidTableName(tableName) ? tableName : "custom"
        Task.detached(priority: .userInitiated) {
            do {
                try server.importFromAttachedDB(sourcePath: url.path, tableName: safeTable)
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onProgress(100, status: "已成功匯入 \(safeTable)")
                    view?.refreshImList()
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onError("匯入失敗：\(msg)")
                }
            }
        }
    }

    // MARK: - Import DB file (async, SwiftUI-friendly)

    func importDBFile(url: URL, tableName: String) async -> Result<String, Error> {
        await MainActor.run { progress.show(status: "匯入中…") }
        let server = self.dbServer
        let safeTable = server.isValidTableName(tableName) ? tableName : "custom"
        return await Task.detached(priority: .userInitiated) {
            do {
                try server.importFromAttachedDB(sourcePath: url.path, tableName: safeTable)
                return .success(safeTable)
            } catch {
                return .failure(error)
            }
        }.value
    }

    // MARK: - Seed default IMs

    func seedDefaultIMs(view: (any SetupImView)?) {
        progress.show(status: "初始化預設輸入法…")
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            do {
                try server.seedDefaultIMs()
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onProgress(100, status: "預設輸入法已初始化")
                    view?.refreshImList()
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.progress.dismiss()
                    view?.onError("初始化失敗：\(msg)")
                }
            }
        }
    }

    // MARK: - Seed default IMs (async, SwiftUI-friendly)

    func seedDefaultIMs() async -> Result<String, Error> {
        await MainActor.run { progress.show(status: "初始化預設輸入法…") }
        let server = self.dbServer
        let result: Result<String, Error> = await Task.detached(priority: .userInitiated) {
            do {
                try server.seedDefaultIMs()
                return .success("預設輸入法已初始化")
            } catch {
                return .failure(error)
            }
        }.value
        await MainActor.run { progress.dismiss() }
        return result
    }

    // MARK: - Seed related phrases

    /// Seeds the related-phrase table from the bundled lime.db if it is currently empty.
    /// Only runs when the App Group DB has no related rows (first launch or after a full wipe).
    func seedRelatedIfNeeded() async {
        let server = self.dbServer
        await Task.detached(priority: .userInitiated) {
            guard !server.tableHasData("related") else { return }
            guard let bundledURL = Bundle.main.url(forResource: "lime", withExtension: "db") else { return }
            server.importDbRelated(sourcedb: bundledURL)
        }.value
    }

    // MARK: - Backup

    /// Backup the database to a temp .zip file and return its URL for sharing.
    /// Caller is responsible for deleting the temp file after sharing.
    func backupDB() throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("lime_backup_\(Int(Date().timeIntervalSince1970)).zip")
        try dbServer.backupDatabase(uri: dest)
        return dest
    }

    // MARK: - Restore

    func restoreDB(from url: URL, view: (any SetupImView)?) {
        progress.show(status: "還原中…")
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            server.restoreDatabase(uri: url)
            await MainActor.run {
                self.progress.dismiss()
                view?.onProgress(100, status: "資料庫還原完成")
                view?.refreshImList()
            }
        }
    }

    // MARK: - Restore (async, SwiftUI-friendly)

    func restoreDB(from url: URL) async -> Result<Void, Error> {
        await MainActor.run { progress.show(status: "還原中…") }
        let server = self.dbServer
        await Task.detached(priority: .userInitiated) {
            server.restoreDatabase(uri: url)
        }.value
        // Re-register all known IMs in iOS structured format.
        // Android backups store im configs as key-value rows; registerIM replaces
        // them with single iOS-format rows that getAllImConfigs() can read correctly.
        await reregisterKnownIMs()
        // Signal the keyboard extension to reload its database connection.
        // The keyboard holds a stale DatabaseQueue to the old file after restore.
        UserDefaults(suiteName: "group.net.toload.limeime")?
            .set(Date().timeIntervalSince1970, forKey: "lime_db_restored_at")
        await MainActor.run { progress.dismiss() }
        return .success(())
    }

    // MARK: - Re-register IMs after Android backup restore

    private func reregisterKnownIMs() async {
        let knownIMs: [(name: String, title: String, keyboard: String)] = [
            ("phonetic", "注音",     "lime_phonetic"),
            ("dayi",     "大易",     "lime_dayi"),
            ("cj",       "倉頡",     "lime_cj"),
            ("cj5",      "倉頡五代", "lime_cj"),
            ("array",    "行列",     "lime_array"),
            ("array10",  "行列十",   "lime_array"),
            ("wb",       "筆順五碼", "lime_wb"),
            ("hs",       "許氏",     "lime_hs"),
            ("ez",       "輕鬆",     "lime_ez"),
            ("scj",      "速成",     "lime_cj"),
            ("ecj",      "易倉頡",   "lime_cj"),
        ]
        let server = self.dbServer
        await Task.detached(priority: .userInitiated) {
            for im in knownIMs {
                guard server.tableHasData(im.name) else { continue }
                try? server.registerIM(imName: im.name, tableName: im.name,
                                       label: im.title, keyboardId: im.keyboard)
            }
        }.value
    }

    // MARK: - Sync keyboard state

    func syncIMActivatedState() {
        prefs.syncIMActivatedState(dbServer: dbServer)
    }
}
