import Combine
import Foundation
import ProviderConversation
import ProviderConversationState
import SwiftUI

/// 对话列表 + 标题栏唯一的数据来源与交互入口。
///
/// 列表分页、加载态、选中态、注意力标记、标题与项目可见性全部收敛到这里。
/// 外部会话/注意力事件由本 VM 内部订阅（等价于插件层 Observer 的职责），
/// View 只读取状态并触发用户意图，不再创建或持有任何外部 Observer。
@MainActor
final class ConversationListViewModel: ObservableObject {
    enum Scope {
        /// 全部项目的对话。
        case all
        /// 当前项目下的对话。
        case currentProject
    }

    private static let pageSize = 40

    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var immediateSelectionID: UUID?
    /// 当前项目路径解析结果（用于 `.task(id:)` 感知项目切换）。
    @Published private(set) var resolvedProjectPath: String?
    @Published private(set) var hasMultipleProjects = false

    let scope: Scope

    private let context: ConversationListContext
    private let attentionStore: ConversationAttentionStore
    private let sortStabilizer: ConversationSortStabilizer
    private var paginationCursor: ConversationPageCursor?
    private var isReloading = false
    private var reloadPending = false
    private var contextObserverHandle: (any ConversationListContext.ObserverHandle)?
    private var attentionObserverHandle: (any ConversationAttentionStore.ObserverHandle)?

    init(
        context: ConversationListContext,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer,
        scope: Scope
    ) {
        self.context = context
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
        self.scope = scope
        self.selectedConversationID = context.selectedConversationID
        self.immediateSelectionID = context.selectedConversationID
        self.resolvedProjectPath = effectiveProjectPath

        contextObserverHandle = context.addObserver { [weak self] event in
            switch event {
            case let .selectedConversationChanged(id):
                self?.selectedConversationID = id
                self?.immediateSelectionID = id
            case .conversationsChanged:
                self?.scheduleReload()
            }
        }
        attentionObserverHandle = attentionStore.addObserver { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// 插件卸载时调用，释放外部观察订阅。
    func cancel() {
        contextObserverHandle?.cancel()
        contextObserverHandle = nil
        attentionObserverHandle?.cancel()
        attentionObserverHandle = nil
    }

    // MARK: - Derived

    var headerVisible: Bool {
        switch scope {
        case .currentProject:
            return true
        case .all:
            return hasMultipleProjects
        }
    }

    var headerTitle: String {
        switch scope {
        case .currentProject:
            let projectName = context.currentProjectName ?? "—"
            return String(format: "项目对话 (%@)", projectName)
        case .all:
            return "所有项目的对话"
        }
    }

    /// The project path to filter by, or nil if showing all conversations.
    private var effectiveProjectPath: String? {
        switch scope {
        case .all:
            return nil
        case .currentProject:
            return context.currentProjectPath
        }
    }

    func needsAttention(for conversationID: UUID) -> Bool {
        attentionStore.needsAttention(for: conversationID)
    }

    /// 单行渲染所需的会话运行状态快照（纯 UI 输入，非外部 Observer）。
    func conversationState(for conversationID: UUID) -> ConversationStateSnapshot? {
        context.conversationState?.state(for: conversationID)
    }

    // MARK: - 用户意图

    func selectConversation(id: UUID) {
        // 先同步写入乐观选中，立刻高亮，不等管理器链路。
        immediateSelectionID = id
        selectedConversationID = id
        Task { @MainActor in
            context.conversations.selectConversation(id: id)
            attentionStore.markRead(conversationID: id)
        }
    }

    func deleteConversation(id: UUID) {
        context.conversations.deleteConversation(id: id)
    }

    // MARK: - 数据加载

    func loadInitialIfNeeded() async {
        if conversations.isEmpty, isLoading {
            await reload()
        }
    }

    func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        let page = await fetchPage(
            beforeUpdatedAt: paginationCursor?.lastMessageAt,
            beforeID: paginationCursor?.id
        )

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

    func reload() async {
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

        // 项目切换时重新解析项目路径。
        let path = effectiveProjectPath
        resolvedProjectPath = path

        var snapshot: [ConversationSummary] = []
        var cursor: ConversationPageCursor?

        // 获取至少当前已经展示的数量，避免刷新后丢掉用户已经加载的分页。
        while snapshot.count < targetCount {
            let page = await fetchPage(
                beforeUpdatedAt: cursor?.lastMessageAt,
                beforeID: cursor?.id
            )
            guard !page.isEmpty else { break }

            snapshot.append(contentsOf: page)
            guard page.count == Self.pageSize else { break }
            guard let last = page.last else { break }
            cursor = ConversationPageCursor(lastMessageAt: last.lastMessageAt, id: last.id)
        }

        // 没有实际变化时不触发 SwiftUI 列表替换。
        if snapshot != conversations {
            // 粘性排序：用 stabilizer 重新计算排序时间，防止高频消息导致列表跳动。
            let stabilized = snapshot
                .map { conv -> (ConversationSummary, Date) in
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

        await refreshProjectVisibilityIfNeeded(path: path)
        isLoading = false
    }

    // MARK: - Private

    private func scheduleReload() {
        if isReloading {
            reloadPending = true
        } else {
            Task { @MainActor in
                await reload()
            }
        }
    }

    private func fetchPage(
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async -> [ConversationSummary] {
        let path = effectiveProjectPath
        if let path {
            return await context.conversations.fetchConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: false,
                projectPath: path
            )
        }
        return await context.conversations.fetchConversationPage(
            limit: Self.pageSize,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID
        )
    }

    /// 仅「所有项目」列表需要判断是否展示跨项目提示标题。
    private func refreshProjectVisibilityIfNeeded(path: String?) async {
        guard case .all = scope else { return }
        let projectCount = await context.conversations.conversationProjectCount()
        guard effectiveProjectPath == path else { return }
        hasMultipleProjects = projectCount > 1
    }
}
