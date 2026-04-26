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

    var body: some View {
        NavigationView {
            List {
                // MARK: Backup
                Section(
                    header: Text("備份"),
                    footer: Text("備份包含所有字根、關聯字及偏好設定。")
                        .font(.footnote)
                ) {
                    Button {
                        performBackup()
                    } label: {
                        Label("備份資料庫", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking)
                }

                // MARK: Restore
                Section(
                    header: Text("還原"),
                    footer: Text("還原後鍵盤將重新載入資料庫。")
                        .font(.footnote)
                ) {
                    Button {
                        showRestoreConfirm = true
                    } label: {
                        Label("還原資料庫", systemImage: "arrow.down.circle")
                    }
                    .disabled(isWorking)
                    .foregroundColor(.red)
                }

                // MARK: Init DB
                Section(header: Text("初始資料庫")) {
                    Button {
                        showInitConfirm = true
                    } label: {
                        Label("還原預設資料庫", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(isWorking)
                    .foregroundColor(.red)
                }

                // MARK: Status
                if !statusMessage.isEmpty {
                    Section(header: Text("狀態")) {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("資料庫管理")
            .alert("確認還原", isPresented: $showInitConfirm) {
                Button("還原", role: .destructive) { restoreBundledDatabase() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("還原後目前所有資料將被取代，確定繼續？")
            }
            .alert("確認還原", isPresented: $showRestoreConfirm) {
                Button("還原", role: .destructive) {
                    showFilePicker = true
                }
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
            .sheet(isPresented: $showShareSheet, onDismiss: cleanupBackup) {
                if let url = backupURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .overlay {
                if isWorking {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("處理中…")
                            .padding(24)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Backup

    private func performBackup() {
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let url = try await MainActor.run { try self.setupController.backupDB() }
                await MainActor.run {
                    self.isWorking = false
                    self.backupURL = url
                    self.showShareSheet = true
                    self.statusMessage = "備份已準備完成"
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
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
