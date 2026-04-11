// ManageRelatedControllerTest.swift
// LimeIMETests
//
// CRUD + pagination tests for ManageRelatedController.
// Uses a real LimeDB temp fixture and MockManageRelatedView.

import XCTest
@testable import LimeIME

// MARK: - MockManageRelatedView

@MainActor
class MockManageRelatedView: ManageRelatedView {
    var errors: [String] = []
    var progressCalls: [(Int, String)] = []
    var displayedPhrases: [LimeIME.Related] = []
    var refreshCount: Int = 0

    func onError(_ message: String) { errors.append(message) }
    func onProgress(_ percentage: Int, status: String) { progressCalls.append((percentage, status)) }
    func displayRelatedPhrases(_ phrases: [LimeIME.Related]) { displayedPhrases = phrases }
    func refreshPhraseList() { refreshCount += 1 }
}

// MARK: - ManageRelatedControllerTest

final class ManageRelatedControllerTest: XCTestCase {

    // MARK: - Helpers

    private func makeDB() throws -> (url: URL, db: LimeIME.LimeDB) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        let db = try LimeIME.LimeDB(path: url.path)
        _ = db.openDBConnection(false)
        return (url, db)
    }

    // MARK: - loadRelated

    func testLoadRelatedEmptyTable() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageRelatedView()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.loadRelated(query: nil, page: 0, view: mock) }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertTrue(mock.displayedPhrases.isEmpty)
            XCTAssertTrue(mock.errors.isEmpty)
        }
    }

    // MARK: - addRelated

    func testAddRelatedSuccess() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageRelatedView()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.addRelated(parentWord: "你好", childWord: "世界", view: mock) }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertEqual(mock.refreshCount, 1)
            XCTAssertTrue(mock.errors.isEmpty)
        }
    }

    func testAddRelatedEmptyParentReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageRelatedView()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRelated(parentWord: "", childWord: "world", view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    func testAddRelatedEmptyChildReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageRelatedView()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRelated(parentWord: "hello", childWord: "", view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    // MARK: - updateRelated

    func testUpdateRelatedAfterAdd() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.addRelated(parentWord: "一", childWord: "二", view: nil) }
        try await Task.sleep(nanoseconds: 300_000_000)

        let phrases = db.getRelated(nil, 10, 0)
        guard let first = phrases.first else {
            XCTFail("Expected a related phrase after add")
            return
        }

        let updateMock = await MockManageRelatedView()
        await MainActor.run {
            controller.updateRelated(id: first.id, parentWord: "一", childWord: "三",
                                     view: updateMock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertEqual(updateMock.refreshCount, 1)
            XCTAssertTrue(updateMock.errors.isEmpty)
        }

        let updated = db.getRelated(nil, 10, 0)
        XCTAssertTrue(updated.contains { $0.childWord == "三" })
    }

    func testUpdateRelatedEmptyWordReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageRelatedView()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.updateRelated(id: 1, parentWord: "", childWord: "三", view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    // MARK: - deleteRelated

    func testDeleteRelatedAfterAdd() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.addRelated(parentWord: "刪", childWord: "除", view: nil) }
        try await Task.sleep(nanoseconds: 300_000_000)

        let phrases = db.getRelated(nil, 10, 0)
        guard let toDelete = phrases.first(where: { $0.parentWord == "刪" }) else {
            XCTFail("Expected to find 刪 phrase")
            return
        }

        let deleteMock = await MockManageRelatedView()
        await MainActor.run { controller.deleteRelated(id: toDelete.id, view: deleteMock) }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run { XCTAssertEqual(deleteMock.refreshCount, 1) }

        let after = db.getRelated(nil, 10, 0)
        XCTAssertFalse(after.contains { $0.parentWord == "刪" })
    }

    // MARK: - Pagination

    func testPaginationPageSizeConstant() {
        XCTAssertEqual(LimeIME.ManageRelatedController.pageSize, 100)
    }

    func testLoadRelatedAfterMultipleAdds() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRelated(parentWord: "A", childWord: "B", view: nil)
            controller.addRelated(parentWord: "C", childWord: "D", view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let mock = await MockManageRelatedView()
        await MainActor.run { controller.loadRelated(query: nil, page: 0, view: mock) }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertGreaterThanOrEqual(mock.displayedPhrases.count, 2)
        }
    }

    func testLoadRelatedWithQuery() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRelated(parentWord: "搜尋", childWord: "結果", view: nil)
            controller.addRelated(parentWord: "其他", childWord: "詞彙", view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let mock = await MockManageRelatedView()
        await MainActor.run { controller.loadRelated(query: "搜", page: 0, view: mock) }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertTrue(mock.errors.isEmpty)
        }
    }

    // MARK: - Callbacks on main thread

    func testRefreshPhraseListOnMainThread() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }

        class ThreadCaptureMock: MockManageRelatedView {
            var capturedThread: Thread?
            override func refreshPhraseList() {
                capturedThread = Thread.current
                super.refreshPhraseList()
            }
        }

        let threadMock = await ThreadCaptureMock()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.addRelated(parentWord: "主線", childWord: "回呼", view: threadMock) }
        try await Task.sleep(nanoseconds: 400_000_000)

        await MainActor.run {
            if let t = threadMock.capturedThread {
                XCTAssertTrue(t.isMainThread, "refreshPhraseList must be called on main thread")
            }
        }
    }

    func testDisplayRelatedPhrasesOnMainThread() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }

        class ThreadCaptureMock: MockManageRelatedView {
            var capturedThread: Thread?
            override func displayRelatedPhrases(_ phrases: [LimeIME.Related]) {
                capturedThread = Thread.current
                super.displayRelatedPhrases(phrases)
            }
        }

        let threadMock = await ThreadCaptureMock()
        let controller = await LimeIME.ManageRelatedController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run { controller.loadRelated(query: nil, page: 0, view: threadMock) }
        try await Task.sleep(nanoseconds: 400_000_000)

        await MainActor.run {
            if let t = threadMock.capturedThread {
                XCTAssertTrue(t.isMainThread, "displayRelatedPhrases must be on main thread")
            }
        }
    }
}
