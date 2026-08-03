import LumiKernel
import LumiUI
import SwiftUI

/// 对话列表视图
public struct ListView: View {
    private static let pageSize = 40

    @State private var conversations: [LumiConversationSummary] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isReloading = false
    @State private var hasMore = true
    @State private var paginationCursor: ConversationPageCursor?
    let svc: (any ConversationManaging)?
    @ObservedObject private var kernel: LumiKernel
    @ObservedObject private var attentionStore: ConversationAttentionStore

    public init(kernel: LumiKernel, attentionStore: ConversationAttentionStore) {
        self.svc = kernel.conversations
        self._kernel = ObservedObject(wrappedValue: kernel)
        self._attentionStore = ObservedObject(wrappedValue: attentionStore)
    }

    public var body: some View {
        Group {
            if svc == nil {
                ListErrorView()
            } else if isLoading {
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
                                    guard let svc else { return }
                                    Task { @MainActor in
                                        _ = await svc.fetchConversation(id: conversation.id)
                                        svc.selectConversation(id: conversation.id)
                                        attentionStore.markRead(conversationID: conversation.id)
                                    }
                                },
                                onDelete: {
                                    guard let svc else { return }
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
        }
        .onLumiConversationsDidChange {
            Task { @MainActor in
                await reload()
            }
        }
    }

    private func reload() async {
        guard let svc, !isReloading else { return }

        isReloading = true
        defer { isReloading = false }

        // 首次加载时显示 loading；已有内容时保持旧列表可见。
        let targetCount = max(conversations.count, Self.pageSize)
        if conversations.isEmpty {
            isLoading = true
        }

        var snapshot: [LumiConversationSummary] = []
        var cursor: ConversationPageCursor?

        // 获取至少当前已经展示的数量，避免刷新后丢掉用户已经加载的分页。
        while snapshot.count < targetCount {
            let page = await svc.fetchConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: cursor?.updatedAt,
                beforeID: cursor?.id
            )
            guard !page.isEmpty else { break }

            snapshot.append(contentsOf: page)
            guard page.count == Self.pageSize else { break }
            guard let last = page.last else { break }
            cursor = ConversationPageCursor(updatedAt: last.updatedAt, id: last.id)
        }

        // 没有实际变化时不触发 SwiftUI 列表替换。
        if snapshot != conversations {
            conversations = snapshot
            paginationCursor = snapshot.last.map {
                ConversationPageCursor(updatedAt: $0.updatedAt, id: $0.id)
            }
            hasMore = snapshot.count >= targetCount && snapshot.count > 0
                ? snapshot.count == targetCount
                : snapshot.count == Self.pageSize
        }

        isLoading = false
    }

    private var selectedConversationID: UUID? {
        svc?.selectedConversationID
    }

    private func loadNextPage() async {
        guard let svc, !isLoadingMore, hasMore else { return }

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
