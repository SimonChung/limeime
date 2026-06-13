// DBManagerView.swift
// LimeIME-iOS
//
// DB backup and restore — the 資料庫 tab.
// Spec §7.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - DBManagerView

struct DBManagerView: View {

    @EnvironmentObject private var setupController: SetupImController
    @EnvironmentObject private var manageImController: ManageImController
    @EnvironmentObject private var manageRelatedController: ManageRelatedController

    @State private var statusMessage: String = ""
    @State private var isWorking = false
    @State private var showRestoreConfirm = false
    @State private var showInitConfirm = false
    @State private var showFilePicker = false
    @State private var backupURL: URL?
    @State private var showShareSheet = false
    @State private var backupProgress: Double = 0
    @State private var preparingShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("資料庫管理")
                        .font(.largeTitle).bold()
                        .padding(.top, SettingsMetrics.titleTopPadding)
                        .padding(.bottom, 20)

                    // 備份 — filled (primary) action.
                    dbAction(footer: "備份包含所有字根、關聯字及喜好設定。") {
                        Button { performBackup() } label: {
                            Label("備份資料庫", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isWorking)
                    }

                    // 還原 — bordered action.
                    dbAction(footer: "還原後鍵盤將重新載入資料庫。") {
                        Button { showRestoreConfirm = true } label: {
                            Label("還原資料庫", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(LimeTonalButtonStyle())
                        .disabled(isWorking)
                    }

                    // 初始資料庫 — bordered destructive action + red warning footer.
                    dbAction(
                        footer: "警告：將清除目前所有輸入法資料表，還原為萊姆內建的空白預設資料庫，此動作無法復原。",
                        warning: true
                    ) {
                        Button { showInitConfirm = true } label: {
                            Label("還原預設資料庫", systemImage: "arrow.counterclockwise.circle")
                        }
                        .buttonStyle(LimeTonalButtonStyle(tint: SettingsTheme.destructive))
                        .disabled(isWorking)
                    }

                    if !statusMessage.isEmpty {
                        Label(statusMessage, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .padding(.horizontal, SettingsMetrics.formHeaderLeadingPadding)
                    }
                }
                .padding(.horizontal, SettingsMetrics.pageHorizontalPadding)
                .padding(.bottom, SettingsMetrics.setupBottomPadding)
                .frame(maxWidth: SettingsMetrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            // Static inline title only (matches the other tab roots). Hide the
            // system nav bar so the title doesn't render twice on iPhone.
            .toolbar(.hidden, for: .navigationBar)
            .alert("確認還原", isPresented: $showInitConfirm) {
                Button("還原", role: .destructive) { restoreBundledDatabase() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("還原後目前所有資料將被取代，確定繼續？")
            }
            .alert("確認還原", isPresented: $showRestoreConfirm) {
                Button("還原", role: .destructive) { showFilePicker = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("還原後目前所有資料將被取代，確定繼續？")
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    performRestore(from: url)
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // Sheet dismissed by user — release the overlay we kept up
                // through UIActivityViewController init (which can block the
                // main thread for several seconds on a large backup zip).
                isWorking = false
                backupProgress = 0
                preparingShare = false
                cleanupBackup()
            }) {
                if let url = backupURL { ShareSheet(activityItems: [url]) }
            }
            .overlay {
                if shouldShowLocalWorkingOverlay {
                    ZStack {
                        SettingsTheme.overlayScrim.ignoresSafeArea()
                        VStack(spacing: SettingsMetrics.modalSpacing) {
                            if preparingShare {
                                ProgressView("準備備份中…")
                            } else if backupProgress > 0 {
                                Text("備份中… \(Int(backupProgress * 100))%")
                                ProgressView(value: backupProgress)
                                    .frame(width: SettingsMetrics.progressBarWidth)
                            } else {
                                ProgressView("處理中…")
                            }
                        }
                        .padding(SettingsMetrics.modalPadding)
                        .background(RoundedRectangle(cornerRadius: SettingsMetrics.modalCornerRadius)
                            .fill(SettingsTheme.overlayCardBackground)
                            .shadow(radius: SettingsMetrics.modalShadowRadius))
                    }
                }
            }
        }
    }

    /// A DB action: a full-width button above a supporting footer. The
    /// 還原預設資料庫 footer is a red warning carrying a leading triangle glyph.
    /// Mirrors the design kit's DBTab `Action` (button + footer, no grouped
    /// section header — the button labels are self-explanatory).
    @ViewBuilder
    private func dbAction<Content: View>(
        footer: String,
        warning: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
            HStack(alignment: .top, spacing: 6) {
                if warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                }
                Text(footer)
            }
            .font(.footnote)
            .foregroundColor(warning ? SettingsTheme.destructive : .secondary)
            .padding(.horizontal, SettingsMetrics.formHeaderLeadingPadding)
        }
        .padding(.bottom, SettingsMetrics.dbActionBottomSpacing)
    }

    // MARK: - Backup

    private func performBackup() {
        var presentationState = BackupSharePresentationState(
            isWorking: isWorking,
            backupProgress: backupProgress,
            preparingShare: preparingShare,
            showShareSheet: showShareSheet)
        presentationState.startBackup()
        apply(presentationState)
        let server = DBServer.shared
        let progress = Progress()
        // KVO observer publishes fractionCompleted updates back to SwiftUI.
        // Captured in the Task closure so it stays alive for the duration of
        // the backup; invalidated when the Task completes.
        let observer = progress.observe(\.fractionCompleted, options: [.new]) { p, _ in
            let value = p.fractionCompleted
            Task { @MainActor in backupProgress = value }
        }
        Task.detached(priority: .userInitiated) {
            // Run the zip + file-copy on a background priority so the
            // overlay actually renders. The previous version hopped back to
            // the main actor for backupDB(), which blocked SwiftUI from
            // drawing isWorking=true until the work finished.
            defer { observer.invalidate() }
            do {
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("lime_backup_\(Int(Date().timeIntervalSince1970)).zip")
                try server.backupDatabase(uri: dest, progress: progress)
                await MainActor.run {
                    var presentationState = BackupSharePresentationState(
                        isWorking: self.isWorking,
                        backupProgress: self.backupProgress,
                        preparingShare: self.preparingShare,
                        showShareSheet: self.showShareSheet)
                    presentationState.finishBackupAndPresentShare()
                    self.apply(presentationState)
                    self.backupURL = dest
                    self.statusMessage = "資料庫備份完成"
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
                    self.backupProgress = 0
                    self.preparingShare = false
                    self.statusMessage = "備份失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func apply(_ presentationState: BackupSharePresentationState) {
        isWorking = presentationState.isWorking
        backupProgress = presentationState.backupProgress
        preparingShare = presentationState.preparingShare
        showShareSheet = presentationState.showShareSheet
    }

    private func cleanupBackup() {
        if let url = backupURL {
            try? FileManager.default.removeItem(at: url)
            backupURL = nil
        }
    }

    private var shouldShowLocalWorkingOverlay: Bool {
        isWorking && (preparingShare || backupProgress > 0)
    }

    // MARK: - Init DB

    private func restoreBundledDatabase() {
        isWorking = true
        statusMessage = "還原中…"
        Task {
            let result = await setupController.restoreBundledDatabase()
            switch result {
            case .success(let msg):
                statusMessage = msg
                manageImController.invalidate()
            case .failure:
                statusMessage = "還原失敗"
            }
            isWorking = false
        }
    }

    // MARK: - Restore

    private func performRestore(from url: URL) {
        isWorking = true
        statusMessage = "還原中…"
        Task {
            let result = await setupController.restoreDB(from: url)
            switch result {
            case .success:
                statusMessage = "資料庫還原完成"
                manageImController.invalidate()
                manageRelatedController.invalidate()
            case .failure(let error):
                statusMessage = "還原失敗：\(error.localizedDescription)"
            }
            isWorking = false
        }
    }
}

struct BackupSharePresentationState {
    var isWorking = false
    var backupProgress = 0.0
    var preparingShare = false
    var showShareSheet = false

    mutating func startBackup() {
        isWorking = true
        backupProgress = 0
        preparingShare = false
        showShareSheet = false
    }

    mutating func finishBackupAndPresentShare() {
        isWorking = false
        backupProgress = 0
        preparingShare = false
        showShareSheet = true
    }
}

// MARK: - UIKit Share Sheet bridge

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
