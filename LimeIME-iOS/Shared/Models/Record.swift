import Foundation

/// A single mapping table record.
/// Mirrors Android's Record.java data class.
/// Named LimeRecord to avoid conflict with GRDB.Record.
struct LimeRecord {
    var id: String = ""
    var code: String = ""
    var word: String = ""
    var score: Int = 0
    var baseScore: Int = 0
    var code3r: String = ""

    // MARK: - Convenience accessors (match Android getter style used in tests)
    func getWord() -> String { word }
    func getCode() -> String { code }
    func getScore() -> Int { score }
    func getBasescore() -> Int { baseScore }
    func getCode3r() -> String { code3r }
}

