import LumiKernel
import LumiUI
import SwiftUI

/// 对话列表视图
public struct ListView: View {
    private static let pageSize = 40

    @State private var conversations: [LumiConversationSummary] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var selectedConversationID: UUID?
    @State private var paginationCursor: ConversationPageCursor?
    let svc: any ConversationManaging
    @ObservedObject private var kernel: LumiKernel
    @ObservedObject private var attentionStore: ConversationAttentionStore

    public init(kernel: LumiKernel, attentionStore: ConversationAttentionStore) {
        precondition(kernel.conversations != nil, "kernel.conversations is nil")
        self.svc = kernel.conversations!
        self._kernel = ObservedObject(wrappedValue: kernel)
        self._attentionStore = ObservedObject(wrappedValue: attentionStore)
        self._selectedConversationID = State(initialValue: kernel.conversations?.selectedConversationID)
    }

    public var body: some View {
        Group {
            if isLoading {
                ListLoadingView()
            } else if conversations.isEmpty {
                ListEmptyView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(conversations, id: \.id) { conversation in
                            ItemView(
                                conversation: conversation,
                                isSelected: selectedConversationID == conversation.id,
                                isActive: kernel.agentTurnManager?.isRunning(for: conversation.id) == true,
                                needsAttention: attentionStore.needsAttention(for: conversation.id),
                                onSelect: {
                                    selectedConversationID = conversation.id
                                    Task { @MainActor in
                                        _ = await svc.fetchConversation(id: conversation.id)
                                        svc.selectConversation(id: conversation.id)
                                        attentionStore.markRead(conversationID: conversation.id)
                                    }
                                },
                                onDelete: {
                                    svc.deleteConversation(id: conversation.id)
                                }
                            )
                        }

                        if hasMore {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .onAppear {
                                    Task { await loadNextPage() }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await reload()
            for await _ in NotificationCenter.default.notifications(named: .lumiConversationsDidChange) {
                await reload()
            }
        }
    }

    private func reload() async {
        conversations = []
        paginationCursor = nil
        hasMore = true
        selectedConversationID = svc.selectedConversationID
        isLoading = true
        await loadNextPage()
        isLoading = false
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        let page = await svc.fetchConversationPage(
            limit: Self.pageSize,
            beforeUpdatedAt: paginationCursor?.updatedAt,
            beforeID: paginationCursor?.id
        )

        conversations.append(contentsOf: page)
        if let last = page.last {
            paginationCursor = ConversationPageCursor(
                updatedAt: last.updatedAt,
                id: last.id
            )
        }
        hasMore = page.count == Self.pageSize
        isLoadingMore = false
    }
}

private struct ConversationPageCursor {
    let updatedAt: Date
    let id: UUID
}
