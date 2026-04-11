// NavigationManager.swift
// LimeIME-iOS
//
// Holds tab selection state.
// Mirrors Android NavigationManager / NavigationDrawerView.

import Foundation
import Combine

// MARK: - NavigationManager

@MainActor
final class NavigationManager: ObservableObject {

    @Published var selectedTab: Int = 0

    func selectTab(_ index: Int) {
        selectedTab = index
    }
}
