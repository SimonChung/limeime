// BaseController.swift
// LimeIME-iOS
//
// Base class for all controllers.
// Mirrors Android BaseController — provides @MainActor dispatch helpers
// for error and progress callbacks to the view layer.

import Foundation

// MARK: - BaseController

@MainActor
class BaseController: ObservableObject {

    // MARK: - Dependencies

    let dbServer: DBServer
    let prefs: LIMEPreferenceManager

    // MARK: - Init

    init(dbServer: DBServer = .shared, prefs: LIMEPreferenceManager = .shared) {
        self.dbServer = dbServer
        self.prefs = prefs
    }

    // MARK: - Error dispatch

    /// Deliver an error message to the view on the main actor.
    func onError(_ message: String, to view: ViewUpdateListener?) {
        view?.onError(message)
    }

    /// Deliver a progress update to the view on the main actor.
    func onProgress(_ percentage: Int, status: String, to view: ViewUpdateListener?) {
        view?.onProgress(percentage, status: status)
    }

    // MARK: - Background task helpers

    /// Run a throwing closure on a background task; deliver errors to the view on main actor.
    nonisolated func runBackground(
        view: (any ViewUpdateListener)?,
        operation: @escaping @Sendable () throws -> Void
    ) {
        Task.detached(priority: .userInitiated) {
            do {
                try operation()
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    view?.onError(message)
                }
            }
        }
    }
}
