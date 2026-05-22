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
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hSize == .regular {
                        Text("資料庫管理")
                            .font(.largeTitle).bold()
                            .padding(.top, 120)
                            .padding(.bottom, 8)
                    }
                    formSection(
                        header: "備份",
                        footer: "備份包含所有字根、關聯字及喜好設定。"
                    ) {
                        Button { performBackup() } label: {
                            Label("備份資料庫", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isWorking)
                        .padding(.vertical, 11)
                    }

                    formSection(
                        header: "還原",
                        footer: "還原後鍵盤將重新載入資料庫。"
                    ) {
                        Button { showRestoreConfirm = true } label: {
                            Label("還原資料庫", systemImage: "arrow.down.circle")
                        }
                        .disabled(isWorking)
                        .foregroundColor(.red)
                        .padding(.vertical, 11)
                    }

                    formSection(header: "初始資料庫") {
                        Button { showInitConfirm = true } label: {
                            Label("還原預設資料庫", systemImage: "arrow.counterclockwise.circle")
                        }
                        .disabled(isWorking)
                        .foregroundColor(.red)
                        .padding(.vertical, 11)
                    }

                    if !statusMessage.isEmpty {
                        formSection(header: "狀態") {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 11)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle(hSize == .regular ? "" : "資料庫管理")
            .navigationBarTitleDisplayMode(hSize == .regular ? .inline : .large)
            .toolbarBackground(hSize == .regular ? .hidden : .automatic, for: .navigationBar)
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
                if isWorking {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            if preparingShare {
                                ProgressView("準備備份中…")
                            } else if backupProgress > 0 {
                                Text("備份中… \(Int(backupProgress * 100))%")
                                ProgressView(value: backupProgress)
                                    .frame(width: 180)
                            } else {
                                ProgressView("處理中…")
                            }
                        }
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 8))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(
        header: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .padding(.top, 20)
            GroupBox { content() }
                .groupBoxStyle(FormSectionGroupBoxStyle())
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Backup

    private func performBackup() {
        isWorking = true
        backupProgress = 0
        preparingShare = false
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
                // Switch the overlay into "準備備份中…" mode and keep isWorking=true.
                // UIActivityViewController initialization can block the main
                // thread for several seconds while it inspects a large zip
                // (file-type sniffing, preview generation, activity discovery);
                // letting isWorking flip to false here would cause a noticeable
                // freeze with no feedback between the 100% bar and the share
                // sheet finally appearing. The sheet's onDismiss handler clears
                // isWorking/preparingShare.
                await MainActor.run {
                    self.backupProgress = 0
                    self.preparingShare = true
                    self.backupURL = dest
                    self.statusMessage = "備份已準備完成"
                    self.showShareSheet = true
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

    private func cleanupBackup() {
        if let url = backupURL {
            try? FileManager.default.removeItem(at: url)
            backupURL = nil
        }
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

// MARK: - UIKit Share Sheet bridge

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
