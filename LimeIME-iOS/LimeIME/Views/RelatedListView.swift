// RelatedListView.swift
// LimeIME-iOS
//
// Related-phrase CRUD — the 關聯字 tab.
// Spec §6.2.

import SwiftUI

// MARK: - RelatedListView

struct RelatedListView: View {

    @EnvironmentObject private var manageRelatedController: ManageRelatedController

    @State private var phrases: [Related] = []
    @State private var totalCount: Int = 0
    @State private var page: Int = 0
    @State private var query: String = ""

    @State private var loadTask: Task<Void, Never>?
    @State private var showAdd = false
    @State private var editingPhrase: IdentifiableRelated?
    @State private var deleteCandidate: IdentifiableRelated?
    @State private var showDeleteConfirm = false

    struct IdentifiableRelated: Identifiable {
        var id: Int64 { phrase.id }
        let phrase: Related
    }

    private let pageSize = 100

    private var totalPages: Int { max(1, (totalCount + pageSize - 1) / pageSize) }
    private var isLastPage: Bool { page >= totalPages - 1 }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    ForEach(phrases, id: \.id) { phrase in
                        HStack {
                            Text(phrase.parentWord).bold()
                            Spacer()
                            Text(phrase.childWord).foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteCandidate = IdentifiableRelated(phrase: phrase)
                                showDeleteConfirm = true
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }

                            Button {
                                editingPhrase = IdentifiableRelated(phrase: phrase)
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)

                // Pagination bar
                HStack {
                    Button("< 上頁") { changePage(page - 1) }
                        .disabled(page == 0)
                    Spacer()
                    Text("第 \(page + 1) / \(totalPages) 頁")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("下頁 >") { changePage(page + 1) }
                        .disabled(isLastPage)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            }
            .searchable(text: $query, prompt: "搜尋詞彙")
            .onChange(of: query) { _ in resetAndLoad() }
            .navigationTitle("關聯字管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadPhrases() }
            .onChange(of: manageRelatedController.refreshToken) { _ in resetAndLoad() }
            .sheet(isPresented: $showAdd, onDismiss: { loadPhrases() }) {
                AddRelatedView()
            }
            .sheet(item: $editingPhrase, onDismiss: { loadPhrases() }) { wrapper in
                EditRelatedView(phrase: wrapper.phrase)
            }
            .alert("確認刪除", isPresented: $showDeleteConfirm, presenting: deleteCandidate) { wrapper in
                Button("刪除", role: .destructive) { deletePhrase(wrapper.phrase) }
                Button("取消", role: .cancel) {}
            } message: { wrapper in
                Text("確定要刪除「\(wrapper.phrase.parentWord) → \(wrapper.phrase.childWord)」？")
            }
        }
    }

    // MARK: - Data

    private func loadPhrases() {
        loadTask?.cancel()
        loadTask = Task {
            let result = await manageRelatedController.loadRelated(
                query: query.isEmpty ? nil : query, page: page)
            guard !Task.isCancelled else { return }
            phrases = result.phrases
            totalCount = result.total
        }
    }

    private func resetAndLoad() {
        page = 0
        loadPhrases()
    }

    private func changePage(_ newPage: Int) {
        guard newPage >= 0, newPage < totalPages else { return }
        page = newPage
        loadPhrases()
    }

    private func deletePhrase(_ phrase: Related) {
        Task {
            _ = await manageRelatedController.deleteRelated(id: phrase.id)
            loadPhrases()
        }
    }
}
