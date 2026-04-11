// ManageRelatedController.swift
// LimeIME-iOS
//
// Async related-phrase CRUD + pagination.
// Mirrors Android ManageRelatedController (part of ManageImController).

import Foundation

// MARK: - ManageRelatedController

@MainActor
final class ManageRelatedController: BaseController {

    static let pageSize = 100

    /// Incrementing this causes RelatedListView to reload its data.
    /// Call after seeding or any external data change.
    @Published var refreshToken: Int = 0

    func invalidate() { refreshToken += 1 }

    // MARK: - Init

    override init(dbServer: DBServer = .shared, prefs: LIMEPreferenceManager = .shared) {
        super.init(dbServer: dbServer, prefs: prefs)
    }

    // MARK: - Load (async, SwiftUI-friendly)

    func loadRelated(query: String?, page: Int) async -> (phrases: [Related], total: Int) {
        let offset = page * ManageRelatedController.pageSize
        let server = self.dbServer
        let q: String? = (query?.isEmpty == false) ? query : nil
        return await Task.detached(priority: .userInitiated) {
            let phrases = server.getRelated(q, ManageRelatedController.pageSize, offset)
            let total = server.countRecords("related", nil, nil)
            return (phrases, total)
        }.value
    }

    func addRelated(parentWord: String, childWord: String) async -> Result<Void, Error> {
        guard !parentWord.isEmpty, !childWord.isEmpty else {
            return .failure(ControllerError.validation("詞彙和關聯詞不能為空"))
        }
        let server = self.dbServer
        let rowID = await Task.detached(priority: .userInitiated) {
            server.addRecord("related",
                             ["pword": parentWord, "cword": childWord,
                              "user_score": 0, "base_score": 0])
        }.value
        return rowID > 0 ? .success(()) : .failure(ControllerError.operation("新增失敗"))
    }

    func updateRelated(id: Int64, parentWord: String,
                       childWord: String) async -> Result<Void, Error> {
        guard !parentWord.isEmpty, !childWord.isEmpty else {
            return .failure(ControllerError.validation("詞彙和關聯詞不能為空"))
        }
        let server = self.dbServer
        let affected = await Task.detached(priority: .userInitiated) {
            server.updateRecord("related",
                                ["pword": parentWord, "cword": childWord],
                                "_id = ?", ["\(id)"])
        }.value
        return affected > 0 ? .success(()) : .failure(ControllerError.operation("更新失敗"))
    }

    func deleteRelated(id: Int64) async -> Result<Void, Error> {
        let server = self.dbServer
        let affected = await Task.detached(priority: .userInitiated) {
            server.deleteRecord("related", "_id = ?", ["\(id)"])
        }.value
        return affected > 0 ? .success(()) : .failure(ControllerError.operation("刪除失敗"))
    }

    // MARK: - Protocol-based methods (kept for unit tests with mock views)

    func loadRelated(query: String?, page: Int, view: (any ManageRelatedView)?) {
        let offset = page * ManageRelatedController.pageSize
        let server = self.dbServer
        let q: String? = (query?.isEmpty == false) ? query : nil
        Task.detached(priority: .userInitiated) {
            let phrases = server.getRelated(q, ManageRelatedController.pageSize, offset)
            await MainActor.run { view?.displayRelatedPhrases(phrases) }
        }
    }

    func addRelated(parentWord: String, childWord: String, view: (any ManageRelatedView)?) {
        guard !parentWord.isEmpty, !childWord.isEmpty else {
            view?.onError("詞彙和關聯詞不能為空"); return
        }
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            let rowID = server.addRecord("related",
                                        ["pword": parentWord, "cword": childWord,
                                         "user_score": 0, "base_score": 0])
            await MainActor.run {
                rowID > 0 ? view?.refreshPhraseList() : view?.onError("新增失敗")
            }
        }
    }

    func updateRelated(id: Int64, parentWord: String, childWord: String,
                       view: (any ManageRelatedView)?) {
        guard !parentWord.isEmpty, !childWord.isEmpty else {
            view?.onError("詞彙和關聯詞不能為空"); return
        }
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            let affected = server.updateRecord("related",
                                               ["pword": parentWord, "cword": childWord],
                                               "_id = ?", ["\(id)"])
            await MainActor.run {
                affected > 0 ? view?.refreshPhraseList() : view?.onError("更新失敗")
            }
        }
    }

    func deleteRelated(id: Int64, view: (any ManageRelatedView)?) {
        let server = self.dbServer
        Task.detached(priority: .userInitiated) {
            let affected = server.deleteRecord("related", "_id = ?", ["\(id)"])
            await MainActor.run {
                affected > 0 ? view?.refreshPhraseList() : view?.onError("刪除失敗")
            }
        }
    }
}
