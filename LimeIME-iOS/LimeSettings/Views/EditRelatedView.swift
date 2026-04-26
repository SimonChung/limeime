// EditRelatedView.swift
// LimeIME-iOS
//
// Sheet for editing or deleting a related phrase.
// Spec §6.2.2.

import SwiftUI

// MARK: - EditRelatedView

struct EditRelatedView: View {

    let phrase: Related

    @EnvironmentObject private var manageRelatedController: ManageRelatedController
    @Environment(\.presentationMode) private var presentationMode
    @State private var parentWord: String
    @State private var childWord: String
    @State private var errorMessage: String = ""
    @State private var showDeleteConfirm = false

    init(phrase: Related) {
        self.phrase = phrase
        _parentWord = State(initialValue: phrase.parentWord)
        _childWord = State(initialValue: phrase.childWord)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("編輯關聯字")) {
                    TextField("詞彙", text: $parentWord)
                        .disableAutocorrection(true)
                    TextField("關聯詞", text: $childWord)
                        .disableAutocorrection(true)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button("儲存") {
                        savePhrase()
                    }
                    .disabled(parentWord.isEmpty || childWord.isEmpty)
                }

                Section {
                    Button("刪除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("編輯關聯字")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("確認刪除", isPresented: $showDeleteConfirm) {
                Button("刪除", role: .destructive) { deletePhrase() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("確定要刪除「\(phrase.parentWord) → \(phrase.childWord)」？")
            }
        }
    }

    private func savePhrase() {
        Task {
            let result = await manageRelatedController.updateRelated(
                id: phrase.id, parentWord: parentWord, childWord: childWord)
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deletePhrase() {
        Task {
            _ = await manageRelatedController.deleteRelated(id: phrase.id)
            presentationMode.wrappedValue.dismiss()
        }
    }
}
