// ProgressManager.swift
// LimeIME-iOS
//
// Observable progress overlay state.
// Mirrors Android's ProgressDialogManager.
// All mutations must occur on MainActor.

import Foundation
import Combine

// MARK: - ProgressManager

@MainActor
final class ProgressManager: ObservableObject {

    @Published var isVisible: Bool = false
    @Published var status: String = ""
    @Published var percent: Int = 0

    // MARK: - Public API

    func show(status: String = "", percent: Int = 0) {
        self.status = status
        self.percent = percent
        self.isVisible = true
    }

    func update(status: String, percent: Int = -1) {
        self.status = status
        if percent >= 0 {
            self.percent = percent
        }
    }

    func dismiss() {
        self.isVisible = false
        self.status = ""
        self.percent = 0
    }
}
