import Combine
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
    @State private var reloadPending = false
    @State private var hasMore = true
    @State private var paginationCursor: ConversationPageCursor?
    @ObservedObject private var kernel: LumiKernel
    @ObservedObject private var attentionStore: ConversationAttentionStore
    @ObservedObject private var sortStabilizer: ConversationSortStabilizer
    private let conversationManager: ConversationManaging

    /// The project path to filter by, or nil if showing all conversations.
    private let projectPath: String?

    public init(
        kernel: LumiKernel,
        conversationManager: ConversationManaging,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer,
        projectPath: String? = nil
    ) {
        self._kernel = ObservedObject(wrappedValue: kernel)
        self._attentionStore = ObservedObject(wrappedValue: attentionStore)
        self._sortStabilizer = ObservedObject(wrappedValue: sortStabilizer)
        self.conversationManager = conversationManager
        self.projectPath = projectPath
    }

    /// The project path to filter by, or nil if showing all conversations.
    private var effectiveProjectPath: String? {
        projectPath
    }

    public var body: some View {
        VStack(spacing: 0) {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await reload()
        }
        .task(id: effectiveProjectPath) {
            await reload()
        }
        .onLumiConversationsDidChange {
            Task { @MainActor in
                await reload()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
                            isSelected: conversationManager.selectedConversationID == conversation.id,
                            isActive: kernel.agentTurnManager?.isRunning(for: conversation.id) == true,
                            needsAttention: attentionStore.needsAttention(for: conversation.id),
                            onSelect: {
                                Task { @MainActor in
                                    conversationManager.selectConversation(id: conversation.id)
                                    attentionStore.markRead(conversationID: conversation.id)
                                    sortStabilizer.markViewed(conversationID: conversation.id)
                                }
                            },
                            onDelete: {
                                conversationManager.deleteConversation(id: conversation.id)
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

    private func reload() async {
        if isReloading {
            reloadPending = true
            return
        }

        isReloading = true
        defer {
            isReloading = false
            if reloadPending {
                reloadPending = false
                Task { @MainActor in
                    await reload()
                }
            }
        }

        // 首次加载时显示 loading；已有内容时保持旧列表可见。
        let targetCount = max(conversations.count, Self.pageSize)
        if conversations.isEmpty {
            isLoading = true
        }

        var snapshot: [LumiConversationSummary] = []
        var cursor: ConversationPageCursor?

        // 获取至少当前已经展示的数量，避免刷新后丢掉用户已经加载的分页。
        while snapshot.count < targetCount {
            let page: [LumiConversationSummary]
            if let projectPath = effectiveProjectPath {
                page = await conversationManager.fetchConversationPage(
                    limit: Self.pageSize,
                    beforeUpdatedAt: cursor?.updatedAt,
                    beforeID: cursor?.id,
                    includingChildConversations: false,
                    projectPath: projectPath
                )
            } else {
                page = await conversationManager.fetchConversationPage(
                    limit: Self.pageSize,
                    beforeUpdatedAt: cursor?.updatedAt,
                    beforeID: cursor?.id
                )
            }
            guard !page.isEmpty else { break }

            snapshot.append(contentsOf: page)
            guard page.count == Self.pageSize else { break }
            guard let last = page.last else { break }
            cursor = ConversationPageCursor(updatedAt: last.updatedAt, id: last.id)
        }

        // 没有实际变化时不触发 SwiftUI 列表替换。
        if snapshot != conversations {
            // 粘性排序：用 stabilizer 重新计算排序时间，防止高频消息导致列表跳动
            let stabilized = snapshot
                .map { conv -> (LumiConversationSummary, Date) in
                    (conv, sortStabilizer.effectiveSortTime(for: conv.id, updatedAt: conv.updatedAt))
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
            conversations = stabilized
            sortStabilizer.cleanup()
            paginationCursor = snapshot.last.map {
                ConversationPageCursor(updatedAt: $0.updatedAt, id: $0.id)
            }
            hasMore = snapshot.count >= targetCount && snapshot.count > 0
                ? snapshot.count == targetCount
                : snapshot.count == Self.pageSize
        }

        isLoading = false
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        let page: [LumiConversationSummary]
        if let projectPath = effectiveProjectPath {
            page = await conversationManager.fetchConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: paginationCursor?.updatedAt,
                beforeID: paginationCursor?.id,
                includingChildConversations: false,
                projectPath: projectPath
            )
        } else {
            page = await conversationManager.fetchConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: paginationCursor?.updatedAt,
                beforeID: paginationCursor?.id
            )
        }

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
