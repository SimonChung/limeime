import Foundation

// Standard Chinese punctuation list — spec §11.
// NOTE: The canonical implementation lives in KeyboardViewController.chinesePunctuationMappings()
// (inlined to avoid project-file dependency on this file before xcodegen regeneration).
// This file provides the same list for use outside the keyboard extension.

enum ChineseSymbol {

    static let standardSet: [String] = [
        "，", "。", "、", "；", "：", "？", "！",
        "「", "」", "『", "』", "【", "】", "〔", "〕",
        "（", "）", "《", "》", "〈", "〉",
        "…", "——", "～", "·", "※",
        "\u{201C}", "\u{201D}",
        "\u{2018}", "\u{2019}",
    ]
}
