// AddRelatedView.swift
// LimeIME-iOS
//
// Sheet for adding a new related phrase.
// Spec §6.2.1.

import SwiftUI

// MARK: - AddRelatedView

struct AddRelatedView: View {

    @EnvironmentObject private var manageRelatedController: ManageRelatedController
    @Environment(\.presentationMode) private var presentationMode
    @State private var parentWord: String = ""
    @State private var childWord: String = ""
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("新增關聯字")) {
                    TextField("詞彙 (word)", text: $parentWord)
                        .disableAutocorrection(true)
                    TextField("關聯詞 (related)", text: $childWord)
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
                    Button("新增") {
                        addPhrase()
                    }
                    .disabled(parentWord.isEmpty || childWord.isEmpty)
                }
            }
            .navigationTitle("新增關聯字")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addPhrase() {
        Task {
            let result = await manageRelatedController.addRelated(
                parentWord: parentWord, childWord: childWord)
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
