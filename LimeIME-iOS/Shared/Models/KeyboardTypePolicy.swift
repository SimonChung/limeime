import UIKit

enum KeyboardTypePolicy {
    static func isForcedEnglishKeyboardType(_ keyboardType: UIKeyboardType) -> Bool {
        switch keyboardType {
        case .numberPad, .decimalPad, .asciiCapableNumberPad, .phonePad, .emailAddress:
            return true
        default:
            return false
        }
    }
}
