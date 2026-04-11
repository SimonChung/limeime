// ViewProtocols.swift
// LimeIME-iOS
//
// Swift translations of Android View interface protocols (§3.4).
// All callbacks are delivered on the main actor.

import Foundation

// MARK: - ViewUpdateListener

/// Base protocol for all view callbacks. Mirrors Android ViewUpdateListener.
@MainActor
protocol ViewUpdateListener: AnyObject {
    func onError(_ message: String)
    func onProgress(_ percentage: Int, status: String)
}

// MARK: - SetupImView

/// Callbacks for the Setup / IM-install flow. Mirrors Android SetupImView.
@MainActor
protocol SetupImView: ViewUpdateListener {
    func updateButtonStates(_ states: [String: Bool])
    func refreshImList()
}

// MARK: - ManageImView

/// Callbacks for record CRUD operations. Mirrors Android ManageImView.
@MainActor
protocol ManageImView: ViewUpdateListener {
    func displayRecords(_ records: [LimeRecord])
    func updateRecordCount(_ count: Int)
    func refreshRecordList()
}

// MARK: - ManageRelatedView

/// Callbacks for related-phrase CRUD. Mirrors Android ManageRelatedView.
@MainActor
protocol ManageRelatedView: ViewUpdateListener {
    func displayRelatedPhrases(_ phrases: [Related])
    func refreshPhraseList()
}

// MARK: - MainActivityView

/// Root coordinator callbacks. Mirrors Android MainActivityView.
@MainActor
protocol MainActivityView: ViewUpdateListener {
    func onIMListChanged()
    func onTabSelected(_ tab: Int)
}

// MARK: - NavigationDrawerView

/// IM navigation menu callbacks. Mirrors Android NavigationDrawerView.
@MainActor
protocol NavigationDrawerView: ViewUpdateListener {
    func updateIMMenu(_ imList: [ImConfig])
}
