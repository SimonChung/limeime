// ShareManager.swift
// LimeIME-iOS
//
// Prepares export URLs for the share sheet.
// Mirrors Android ShareManager.

import Foundation

// MARK: - ShareManager

final class ShareManager {

    private let dbServer: DBServer

    init(dbServer: DBServer = .shared) {
        self.dbServer = dbServer
    }

    // MARK: - Export entire DB

    /// Exports the full lime.db to a temp file and returns its URL for sharing.
    func exportDB() throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("lime_backup_\(Int(Date().timeIntervalSince1970)).db")
        try dbServer.exportDB(to: dest.path)
        return dest
    }

    /// Exports a single mapping table to a temp .limedb file for sharing.
    func exportTable(tableName: String) throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(tableName)_export_\(Int(Date().timeIntervalSince1970)).limedb")
        try dbServer.exportDB(to: dest.path)
        return dest
    }

    /// Exports the related table to a temp file for sharing.
    func exportRelated() throws -> URL {
        return try exportTable(tableName: "related")
    }
}
