// SettingsTheme.swift
// LimeIME-iOS
//
// Semantic color roles for the settings app. Keep direct hardcoded colors
// here so views describe intent instead of choosing final colors inline.

import SwiftUI

enum SettingsTheme {
    static let destructive = Color(uiColor: .systemRed)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let progressAccent = Color(uiColor: .systemBlue)

    static let floatingActionForeground = Color(uiColor: .white)
    static let floatingActionBackground = Color(uiColor: .systemBlue)
    static let floatingActionShadow = Color(uiColor: .black).opacity(0.3)

    static let overlayScrim = Color(uiColor: .black).opacity(0.3)
    static let globalOverlayScrim = Color(uiColor: .black).opacity(0.35)
    static let overlayCardBackground = Color(uiColor: .systemBackground)

    static let switchTrack = Color(uiColor: .systemGreen)
    static let switchThumb = Color(uiColor: .white)
    static let switchShadow = Color(uiColor: .black).opacity(0.18)
}
