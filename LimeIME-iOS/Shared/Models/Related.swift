import Foundation

/// A related phrase pair: previous word → likely next word.
/// Mirrors Android's Related.java.
struct Related {
    var id: Int64
    var parentWord: String   // pword column
    var childWord: String    // cword column
    var score: Int
    var baseScore: Int

    // Convenience accessors matching Android getter style used in tests
    func getPword() -> String { parentWord }
    func getCword() -> String { childWord }
    func getUserscore() -> Int { score }
    func getBasescore() -> Int { baseScore }
    func getIdAsInt() -> Int { Int(id) }
}
