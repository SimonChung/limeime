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

            PreferencesTabView()
                .tabItem { Label("喜好設定", systemImage: "slider.horizontal.3") }
                .tag(3)

            DBManagerView()
                .tabItem { Label("資料庫", systemImage: "archivebox") }
                .tag(4)
        }
        .environmentObject(navManager)
        .environmentObject(progressManager)
        .environmentObject(setupController)
        .environmentObject(manageImController)
        .environmentObject(manageRelatedController)
        .onAppear {
            Task {
                await setupController.seedRelatedIfNeeded()
                manageRelatedController.invalidate()
            }
            // Cold-launch deep link (URL arrived before view appeared).
            if let url = pendingLimeDeepLinkURL {
                pendingLimeDeepLinkURL = nil
                handleDeepLink(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .limeDeepLink)) { note in
            // Warm-launch deep link (app already running).
            if let url = note.object as? URL { handleDeepLink(url) }
        }
        .overlay {
            if progressManager.isVisible {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        if !progressManager.status.isEmpty {
                            Text(progressManager.status)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Deep link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "limeime" else { return }
        switch url.host {
        case "settings":
            navManager.selectTab(3)   // 喜好設定
        default:
            break
        }
    }

}
