// SetupTabView.swift
// LimeIME-iOS
//
// App Setup tab — keyboard activation guide, DB seeding, about.
// Spec §4.

import SwiftUI

// MARK: - SetupTabView

struct SetupTabView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var setupController: SetupImController

    @State private var keyboardEnabled = false
    @State private var fullAccessEnabled = false
    @State private var seedStatus: String = ""
    @State private var isSeeding = false

    var body: some View {
        NavigationView {
            List {
                // MARK: Status banner
                Section(header: Text("啟用狀態")) {
                    statusBanner
                }

                // MARK: Step 1
                Section(header: Text("步驟 1 — 啟用鍵盤")) {
                    Text("前往「設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤」，選擇 LimeIME。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("前往系統設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                // MARK: Step 2
                Section(header: Text("步驟 2 — 允許完整取用")) {
                    Text("在剛才的鍵盤設定頁面，點選 LimeIME 並開啟「允許完整取用」。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("完整取用是讀取偏好設定 App Group 所必需。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: Initial DB seeding
                Section(header: Text("初始資料庫")) {
                    Button {
                        seedDefaultIMs()
                    } label: {
                        Label("預載預設輸入法", systemImage: "arrow.down.circle")
                    }
                    .disabled(isSeeding)

                    if !seedStatus.isEmpty {
                        Text(seedStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: About
                Section(header: Text("關於")) {
                    LabeledContent("版本", value: appVersion())
                    LabeledContent("授權", value: "GPL-3.0")
                    Link("原始碼 (GitHub)",
                         destination: URL(string: "https://github.com/lime-ime/limeime")!)
                }
            }
            .navigationTitle("LimeIME 設定")
            .onAppear { checkStatus() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { checkStatus() }
            }
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        Group {
            if keyboardEnabled && fullAccessEnabled {
                Label("LimeIME 鍵盤已啟用", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if keyboardEnabled {
                Label("鍵盤已啟用，但尚未允許完整取用", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else {
                Label("尚未啟用 LimeIME 鍵盤", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func checkStatus() {
        keyboardEnabled = UITextInputMode.activeInputModes.contains { mode in
            guard let lang = mode.primaryLanguage else { return false }
            return lang.hasPrefix("zh-Hant") || lang.hasPrefix("zh-TW")
        }
        let suite = UserDefaults(suiteName: "group.net.toload.limeime")
        fullAccessEnabled = suite != nil
    }

    private func seedDefaultIMs() {
        isSeeding = true
        seedStatus = "初始化中…"
        Task {
            let result = await setupController.seedDefaultIMs()
            switch result {
            case .success(let msg):
                seedStatus = msg
            case .failure:
                seedStatus = "輸入法已存在，略過"
            }
            isSeeding = false
        }
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
