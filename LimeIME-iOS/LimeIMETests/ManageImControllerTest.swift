// ManageImControllerTest.swift
// LimeIMETests
//
// CRUD + pagination tests for ManageImController.
// Uses a real LimeDB temp fixture and MockManageImView.

import XCTest
@testable import LimeIME

// MARK: - MockManageImView

@MainActor
class MockManageImView: ManageImView {
    var errors: [String] = []
    var progressCalls: [(Int, String)] = []
    var displayedRecords: [LimeIME.LimeRecord] = []
    var recordCount: Int = 0
    var refreshCount: Int = 0

    func onError(_ message: String) { errors.append(message) }
    func onProgress(_ percentage: Int, status: String) { progressCalls.append((percentage, status)) }
    func displayRecords(_ records: [LimeIME.LimeRecord]) { displayedRecords = records }
    func updateRecordCount(_ count: Int) { recordCount = count }
    func refreshRecordList() { refreshCount += 1 }
}

// MARK: - ManageImControllerTest

final class ManageImControllerTest: XCTestCase {

    private let testTable = "custom"

    // MARK: - Helpers

    private func makeDB() throws -> (url: URL, db: LimeIME.LimeDB) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        let db = try LimeIME.LimeDB(path: url.path)
        _ = db.openDBConnection(false)
        return (url, db)
    }

    // MARK: - loadRecords

    func testLoadRecordsEmptyTable() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.loadRecords(table: testTable, query: nil, searchByCode: true,
                                   page: 0, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertTrue(mock.displayedRecords.isEmpty)
            XCTAssertTrue(mock.errors.isEmpty)
        }
    }

    // MARK: - addRecord

    func testAddRecordSuccess() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "abc", word: "測試",
                                 score: 5, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertEqual(mock.refreshCount, 1)
            XCTAssertTrue(mock.errors.isEmpty)
        }
    }

    func testAddRecordEmptyCodeReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "", word: "測試",
                                 score: 0, view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    func testAddRecordEmptyWordReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "abc", word: "",
                                 score: 0, view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    // MARK: - updateRecord

    func testUpdateRecordAfterAdd() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "xyz", word: "原文",
                                 score: 1, view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let records = db.getRecordList(testTable, nil, searchByCode: true, 10, 0)
        guard let first = records.first else {
            XCTFail("Expected a record after add")
            return
        }

        let updateMock = await MockManageImView()
        await MainActor.run {
            controller.updateRecord(table: testTable, id: first.id,
                                    code: "xyz", word: "新文", score: 2, view: updateMock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertEqual(updateMock.refreshCount, 1)
            XCTAssertTrue(updateMock.errors.isEmpty)
        }

        let updated = db.getRecordList(testTable, nil, searchByCode: true, 10, 0)
        XCTAssertTrue(updated.contains { $0.word == "新文" })
    }

    func testUpdateRecordEmptyCodeReportsError() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.updateRecord(table: testTable, id: "1",
                                    code: "", word: "test", score: 0, view: mock)
            XCTAssertFalse(mock.errors.isEmpty)
        }
    }

    // MARK: - deleteRecord

    func testDeleteRecordAfterAdd() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "del", word: "刪除",
                                 score: 0, view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let records = db.getRecordList(testTable, nil, searchByCode: true, 10, 0)
        guard let toDelete = records.first(where: { $0.word == "刪除" }) else {
            XCTFail("Expected to find 刪除 record")
            return
        }

        let deleteMock = await MockManageImView()
        await MainActor.run {
            controller.deleteRecord(table: testTable, id: toDelete.id, view: deleteMock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertEqual(deleteMock.refreshCount, 1)
        }

        let after = db.getRecordList(testTable, nil, searchByCode: true, 10, 0)
        XCTAssertFalse(after.contains { $0.word == "刪除" })
    }

    // MARK: - Pagination

    func testPaginationPageSizeConstant() {
        XCTAssertEqual(LimeIME.ManageImController.pageSize, 100)
    }

    func testLoadRecordsReturnsCorrectCount() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "a", word: "一", score: 0, view: nil)
            controller.addRecord(table: testTable, code: "b", word: "二", score: 0, view: nil)
            controller.addRecord(table: testTable, code: "c", word: "三", score: 0, view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let mock = await MockManageImView()
        await MainActor.run {
            controller.loadRecords(table: testTable, query: nil, searchByCode: true,
                                   page: 0, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertGreaterThanOrEqual(mock.displayedRecords.count, 3)
            XCTAssertGreaterThanOrEqual(mock.recordCount, 3)
        }
    }

    // MARK: - Search

    func testLoadRecordsWithCodeQuery() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "search1", word: "找到", score: 0, view: nil)
            controller.addRecord(table: testTable, code: "other",   word: "其他", score: 0, view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let mock = await MockManageImView()
        await MainActor.run {
            controller.loadRecords(table: testTable, query: "search", searchByCode: true,
                                   page: 0, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertTrue(mock.displayedRecords.allSatisfy { $0.code.hasPrefix("search") })
        }
    }

    func testLoadRecordsWordSearch() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: testTable, code: "w1", word: "測試詞", score: 0, view: nil)
            controller.addRecord(table: testTable, code: "w2", word: "其他",   score: 0, view: nil)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        let mock = await MockManageImView()
        await MainActor.run {
            controller.loadRecords(table: testTable, query: "測試", searchByCode: false,
                                   page: 0, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            XCTAssertTrue(mock.displayedRecords.allSatisfy { $0.word.contains("測試") })
        }
    }

    // MARK: - toggleIMEnabled

    func testToggleIMEnabledDoesNotCrash() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let mock = await MockManageImView()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.toggleIMEnabled(imName: "phonetic", enabled: true, view: mock)
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        // No crash is sufficient; error for missing row is acceptable
    }

    // MARK: - Callbacks on main thread

    func testRefreshCallbackOnMainThread() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }

        class ThreadCaptureMock: MockManageImView {
            var capturedThread: Thread?
            override func refreshRecordList() {
                capturedThread = Thread.current
                super.refreshRecordList()
            }
        }

        let threadMock = await ThreadCaptureMock()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.addRecord(table: "custom", code: "t", word: "T", score: 0, view: threadMock)
        }
        try await Task.sleep(nanoseconds: 400_000_000)

        await MainActor.run {
            if let t = threadMock.capturedThread {
                XCTAssertTrue(t.isMainThread, "refreshRecordList must be on main thread")
            }
        }
    }

    func testDisplayRecordsCallbackOnMainThread() async throws {
        let (url, db) = try makeDB()
        defer { try? FileManager.default.removeItem(at: url) }

        class ThreadCaptureMock: MockManageImView {
            var capturedThread: Thread?
            override func displayRecords(_ records: [LimeIME.LimeRecord]) {
                capturedThread = Thread.current
                super.displayRecords(records)
            }
        }

        let threadMock = await ThreadCaptureMock()
        let controller = await LimeIME.ManageImController(dbServer: LimeIME.DBServer(_testDatasource: db))

        await MainActor.run {
            controller.loadRecords(table: "custom", query: nil, searchByCode: true,
                                   page: 0, view: threadMock)
        }
        try await Task.sleep(nanoseconds: 400_000_000)

        await MainActor.run {
            if let t = threadMock.capturedThread {
                XCTAssertTrue(t.isMainThread, "displayRecords must be on main thread")
            }
        }
    }
}
