// LimeSettingsView.swift
// LimeIME-iOS
//
// Root 5-tab TabView. Hosted via UIHostingController from MainViewController.
// Replaces the old 4-tab version per spec §2.

import SwiftUI

// MARK: - Shared UserDefaults for @AppStorage

let sharedDefaults = UserDefaults(suiteName: "group.net.toload.limeime")!

// MARK: - LimeSettingsView (5-tab root)

struct LimeSettingsView: View {

    @StateObject private var navManager: NavigationManager
    @StateObject private var progressManager: ProgressManager
    @StateObject private var setupController: SetupImController
    @StateObject private var manageImController: ManageImController
    @StateObject private var manageRelatedController: ManageRelatedController

    init() {
        let pm = ProgressManager()
        let nav = NavigationManager()
        _progressManager = StateObject(wrappedValue: pm)
        _navManager = StateObject(wrappedValue: nav)
        _setupController = StateObject(wrappedValue: SetupImController(progress: pm))
        _manageImController = StateObject(wrappedValue: ManageImController())
        _manageRelatedController = StateObject(wrappedValue: ManageRelatedController())
    }

    var body: some View {
        TabView(selection: $navManager.selectedTab) {
            SetupTabView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(0)

            IMListView()
                .tabItem { Label("輸入法", systemImage: "list.bullet") }
                .tag(1)

            RelatedListView()
                .tabItem { Label("關聯字", systemImage: "textformat.alt") }
                .tag(2)

            PreferencesTabView()
                .tabItem { Label("偏好設定", systemImage: "slider.horizontal.3") }
                .tag(3)

            DBManagerView()
                .tabItem { Label("資料", systemImage: "archivebox") }
                .tag(4)
        }
        .environmentObject(navManager)
        .environmentObject(progressManager)
        .environmentObject(setupController)
        .environmentObject(manageImController)
        .environmentObject(manageRelatedController)
        .onAppear { seedDatabase() }
    }

    private func seedDatabase() {
        Task {
            _ = await setupController.seedDefaultIMs()
            await setupController.seedRelatedIfNeeded()
            // Refresh views in case they loaded before seeding completed
            manageImController.invalidate()
            manageRelatedController.invalidate()
        }
    }
}
