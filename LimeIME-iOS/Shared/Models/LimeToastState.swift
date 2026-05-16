import Foundation

struct LimeToastState {
    private(set) var message: String?

    var isShowing: Bool { message != nil }

    @discardableResult
    mutating func show(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        self.message = trimmed
        return true
    }

    mutating func hide() {
        message = nil
    }
}
