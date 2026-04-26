import Foundation

/// Keyboard configuration record from the `keyboard` table in lime.db.
/// Mirrors Android's Keyboard.java data class.
struct KeyboardConfig {
    let id: Int64
    let code: String           // Internal code (e.g., "phonetic", "dayi")
    let name: String           // Display name (Chinese)
    let desc: String           // Description
    let type: String           // Layout type (e.g., "phone")
    let image: String          // Preview image resource name
    let imkb: String           // Portrait IM keyboard layout id
    let imshiftkb: String      // Portrait IM shift keyboard layout id
    let engkb: String          // English keyboard layout id
    let engshiftkb: String     // English shift keyboard layout id
    let symbolkb: String       // Symbol keyboard layout id (e.g. lime_dayi_sym)
    let symbolshiftkb: String  // Symbol shift keyboard layout id
    let isDisabled: Bool       // Whether this keyboard entry is hidden
}
