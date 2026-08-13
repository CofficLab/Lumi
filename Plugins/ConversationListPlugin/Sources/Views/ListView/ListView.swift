import Combine
import KernelLumi
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
    /// 点击时立刻写入的乐观选中 ID：不等 selectConversation 的同步持久化/通知
    /// 链路，让选中高亮即时跟上点击；随后由 onChange 与管理器真实状态对齐。
    @State private var immediateSelectionID: UUID?
    /// conversationManager 是协议存在类型，无法直接 @ObservedObject；
    /// 通过 onReceive(objectWillChange) 递增它来强制 body 重新求值。
    @State private var managerRevision = 0
    @ObservedObject private var kernel: KernelLumi
    @ObservedObject private var attentionStore: ConversationAttentionStore
    @ObservedObject private var sortStabilizer: ConversationSortStabilizer
    private let conversationManager: ConversationManaging

    /// The project path to filter by, or nil if showing all conversations.
    private let projectPath: String?

    public init(
        kernel: KernelLumi,
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
        // 外部选中变化（删除自动选中、启动恢复、其他入口切换）时对齐乐观状态
        .onChange(of: conversationManager.selectedConversationID) { _, newID in
            immediateSelectionID = newID
        }
        // 管理器是协议存在类型，无法 @ObservedObject；用 Combine 订阅
        // objectWillChange 并递增 revision，强制 body 重新求值读取最新选中。
        .onReceive(conversationManager.objectWillChange) { _ in
            managerRevision += 1
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
                            isSelected: (immediateSelectionID ?? conversationManager.selectedConversationID) == conversation.id,
                            isActive: kernel.agentTurnManager?.isRunning(for: conversation.id) == true,
                            needsAttention: attentionStore.needsAttention(for: conversation.id),
                            onSelect: {
                                // 先同步写入乐观选中，立刻高亮，不等管理器链路
                                immediateSelectionID = conversation.id
                                Task { @MainActor in
                                    conversationManager.selectConversation(id: conversation.id)
                                    attentionStore.markRead(conversationID: conversation.id)
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
                    beforeUpdatedAt: cursor?.lastMessageAt,
                    beforeID: cursor?.id,
                    includingChildConversations: false,
                    projectPath: projectPath
                )
            } else {
                page = await conversationManager.fetchConversationPage(
                    limit: Self.pageSize,
                    beforeUpdatedAt: cursor?.lastMessageAt,
                    beforeID: cursor?.id
                )
            }
            guard !page.isEmpty else { break }

            snapshot.append(contentsOf: page)
            guard page.count == Self.pageSize else { break }
            guard let last = page.last else { break }
            cursor = ConversationPageCursor(lastMessageAt: last.lastMessageAt, id: last.id)
        }

        // 没有实际变化时不触发 SwiftUI 列表替换。
        if snapshot != conversations {
            // 粘性排序：用 stabilizer 重新计算排序时间，防止高频消息导致列表跳动
            let stabilized = snapshot
                .map { conv -> (LumiConversationSummary, Date) in
                    (conv, sortStabilizer.effectiveSortTime(for: conv.id, lastMessageAt: conv.lastMessageAt))
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
            conversations = stabilized
            sortStabilizer.cleanup()
            paginationCursor = snapshot.last.map {
                ConversationPageCursor(lastMessageAt: $0.lastMessageAt, id: $0.id)
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
                beforeUpdatedAt: paginationCursor?.lastMessageAt,
                beforeID: paginationCursor?.id,
                includingChildConversations: false,
                projectPath: projectPath
            )
        } else {
            page = await conversationManager.fetchConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: paginationCursor?.lastMessageAt,
                beforeID: paginationCursor?.id
            )
        }

        conversations.append(contentsOf: page)
        if let last = page.last {
            paginationCursor = ConversationPageCursor(
                lastMessageAt: last.lastMessageAt,
                id: last.id
            )
        }
        hasMore = page.count == Self.pageSize
        isLoadingMore = false
    }
}
