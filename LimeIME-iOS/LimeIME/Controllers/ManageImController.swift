// ManageImController.swift
// LimeIME-iOS
//
// Async record CRUD + pagination for the IM Table Editor.
// Mirrors Android ManageImController.

import Foundation

// MARK: - ManageImController

@MainActor
final class ManageImController: BaseController {

    // MARK: - App Group

    private static let appGroupID = "group.net.toload.limeime"
    private static let cacheResetKey = "needsKeyboardCacheReset"

    /// Signal the keyboard extension to clear its in-memory search cache on next activation.
    private static func markKeyboardCacheDirty() {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: cacheResetKey)
    }

    static let pageSize = 100

    /// Incrementing this causes IMListView to reload its IM list.
    /// Call after seedDefaultIMs() or any external IM registration change.
    @Published var refreshToken: Int = 0

    func invalidate() { refreshToken += 1 }

    // MARK: - Init

    override init(dbServer: DBServer = .shared, prefs: LIMEPreferenceManager = .shared) {
        super.init(dbServer: dbServer, prefs: prefs)
    }

    // MARK: - SearchServer access

    /// SearchServer backed by the same LimeDB connection as DBServer — used for all queries.
    private var searchServer: SearchServer? { dbServer.makeSearchServer() }

    // MARK: - Load records (async, SwiftUI-friendly)

    /// Fetches one page of records AND the total count via SearchServer.
    /// Call on first appear, after query/mode change, and after any mutation.
    func loadRecords(table: String, query: String?, searchByCode: Bool,
                     page: Int) async -> (records: [LimeRecord], total: Int) {
        let offset = page * ManageImController.pageSize
        let ss = searchServer
        let q = query?.isEmpty == false ? query : nil
        return await Task.detached(priority: .userInitiated) {
            let records = ss?.getRecords(table, q, searchByCode: searchByCode,
                                         ManageImController.pageSize, offset) ?? []
            // No query → SearchServer.countRecords (fast, uses ifnull(word,'') <> '')
            // Active query → countRecordsByWordOrCode (filtered count for correct pagination)
            let total = q != nil
                ? (ss?.countRecordsByWordOrCode(table, q, searchByCode: searchByCode) ?? 0)
                : (ss?.countRecords(table) ?? 0)
            return (records, total)
        }.value
    }

    /// Fetches one page of records only — no COUNT query.
    /// Call for page-turn navigation where the total is already known.
    func loadPage(table: String, query: String?, searchByCode: Bool,
                  page: Int) async -> [LimeRecord] {
        let offset = page * ManageImController.pageSize
        let ss = searchServer
        let q = query?.isEmpty == false ? query : nil
        return await Task.detached(priority: .userInitiated) {
            ss?.getRecords(table, q, searchByCode: searchByCode,
                           ManageImController.pageSize, offset) ?? []
        }.value
    }

    // MARK: - Add record

    func addRecord(table: String, code: String, word: String,
                   score: Int) async -> Result<Void, Error> {
        guard !code.isEmpty, !word.isEmpty else {
            return .failure(ControllerError.validation("字根和文字不能為空"))
        }
        let ss = searchServer
        let rowID = await Task.detached(priority: .userInitiated) {
            ss?.addRecord(table, ["code": code, "word": word, "score": score]) ?? -1
        }.value
        if rowID > 0 {
            ManageImController.markKeyboardCacheDirty()
            return .success(())
        }
        return .failure(ControllerError.operation("新增失敗"))
    }

    // MARK: - Update record

    func updateRecord(table: String, id: String, code: String, word: String,
                      score: Int) async -> Result<Void, Error> {
        guard !code.isEmpty, !word.isEmpty else {
            return .failure(ControllerError.validation("字根和文字不能為空"))
        }
        let ss = searchServer
        let affected = await Task.detached(priority: .userInitiated) {
            ss?.updateRecord(table, ["code": code, "word": word, "score": score],
                             "_id = ?", [id]) ?? 0
        }.value
        if affected > 0 {
            ManageImController.markKeyboardCacheDirty()
            return .success(())
        }
        return .failure(ControllerError.operation("更新失敗"))
    }

    // MARK: - Delete record

    func deleteRecord(table: String, id: String) async -> Result<Void, Error> {
        let ss = searchServer
        let affected = await Task.detached(priority: .userInitiated) {
            ss?.deleteRecord(table, "_id = ?", [id]) ?? 0
        }.value
        if affected > 0 {
            ManageImController.markKeyboardCacheDirty()
            return .success(())
        }
        return .failure(ControllerError.operation("刪除失敗"))
    }

    // MARK: - IM list

    func loadIMList() async -> [ImConfig] {
        let server = self.dbServer
        return await Task.detached(priority: .userInitiated) {
            (try? server.getAllImConfigs()) ?? []
        }.value
    }

    // MARK: - Toggle IM enabled

    func setIMEnabled(imName: String, enabled: Bool) async {
        let server = self.dbServer
        let localPrefs = self.prefs
        await Task.detached(priority: .userInitiated) {
            server.updateIMEnabled(imName: imName, enabled: enabled)
            await MainActor.run { localPrefs.syncIMActivatedState(dbServer: server) }
        }.value
    }

    // MARK: - Update IM sort order

    func setIMSortOrder(id: Int64, sortOrder: Int) async {
        let server = self.dbServer
        await Task.detached(priority: .background) {
            try? server.updateIMSortOrder(id: id, sortOrder: sortOrder)
        }.value
    }

    // MARK: - Keyboard config

    func loadKeyboards(forIM tableNick: String) async -> (keyboards: [KeyboardConfig], selected: String) {
        let server = self.dbServer
        return await Task.detached(priority: .userInitiated) {
            let list = server.getKeyboardConfigList() ?? []
            let selected = (try? server.getAllImConfigs().first(where: { $0.tableNick == tableNick }))?.keyboardId ?? ""
            return (list.filter { !$0.isDisabled }, selected)
        }.value
    }

    func setKeyboard(forIM tableNick: String, keyboard: KeyboardConfig) async {
        let server = self.dbServer
        await Task.detached(priority: .background) {
            server.setImConfigKeyboard(tableNick, keyboard)
        }.value
    }

    // MARK: - Protocol-based methods (kept for unit tests with mock views)

    func addRecord(table: String, code: String, word: String,
                   score: Int, view: (any ManageImView)?) {
        guard !code.isEmpty, !word.isEmpty else {
            view?.onError("字根和文字不能為空"); return
        }
        let ss = searchServer
        Task.detached(priority: .userInitiated) {
            let rowID = ss?.addRecord(table, ["code": code, "word": word, "score": score]) ?? -1
            await MainActor.run {
                rowID > 0 ? view?.refreshRecordList() : view?.onError("新增失敗")
            }
        }
    }

    func updateRecord(table: String, id: String, code: String, word: String,
                      score: Int, view: (any ManageImView)?) {
        guard !code.isEmpty, !word.isEmpty else {
            view?.onError("字根和文字不能為空"); return
        }
        let ss = searchServer
        Task.detached(priority: .userInitiated) {
            let affected = ss?.updateRecord(table, ["code": code, "word": word, "score": score],
                                            "_id = ?", [id]) ?? 0
            await MainActor.run {
                affected > 0 ? view?.refreshRecordList() : view?.onError("更新失敗")
            }
        }
    }

    func deleteRecord(table: String, id: String, view: (any ManageImView)?) {
        let ss = searchServer
        Task.detached(priority: .userInitiated) {
            let affected = ss?.deleteRecord(table, "_id = ?", [id]) ?? 0
            await MainActor.run {
                affected > 0 ? view?.refreshRecordList() : view?.onError("刪除失敗")
            }
        }
    }

    func loadRecords(table: String, query: String?, searchByCode: Bool,
                     page: Int, view: (any ManageImView)?) {
        let offset = page * ManageImController.pageSize
        let ss = searchServer
        let q = query?.isEmpty == false ? query : nil
        Task.detached(priority: .userInitiated) {
            let records = ss?.getRecords(table, q, searchByCode: searchByCode,
                                         ManageImController.pageSize, offset) ?? []
            let total = q != nil
                ? (ss?.countRecordsByWordOrCode(table, q, searchByCode: searchByCode) ?? 0)
                : (ss?.countRecords(table) ?? 0)
            await MainActor.run {
                view?.displayRecords(records)
                view?.updateRecordCount(total)
            }
        }
    }

    func toggleIMEnabled(imName: String, enabled: Bool, view: (any ManageImView)?) {
        let server = self.dbServer
        let localPrefs = self.prefs
        Task.detached(priority: .userInitiated) {
            server.updateIMEnabled(imName: imName, enabled: enabled)
            await MainActor.run { localPrefs.syncIMActivatedState(dbServer: server) }
            await MainActor.run { view?.refreshRecordList() }
        }
    }

    func updateIMSortOrder(id: Int64, sortOrder: Int) {
        let server = self.dbServer
        Task.detached(priority: .background) {
            try? server.updateIMSortOrder(id: id, sortOrder: sortOrder)
        }
    }
}

// MARK: - ControllerError

enum ControllerError: LocalizedError {
    case validation(String)
    case operation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let msg), .operation(let msg): return msg
        }
    }
}
