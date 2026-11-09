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
    /// 当前作用域内的对话总数（顶层对话，不含子 Agent 会话）。
    ///
    /// 用于标题栏右侧的条数徽标：与列表内容口径一致——
    /// 「所有项目」统计全库顶层对话，「当前项目」统计该项目的顶层对话。
    @Published private(set) var conversationCount = 0
    /// 最近一次分页读取是否失败。
    ///
    /// 与「列表为空」区分开：读取失败时列表保留上一份成功快照（或保持空），
    /// 由该标记驱动错误/重试界面，避免把瞬态存储故障显示成空库。
    @Published private(set) var hasLoadError = false

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
            case let .conversationAutomationChanged(id):
                self?.updateAutomationLevel(for: id)
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

    // MARK: - 统计面板

    /// 统计面板需要的最小会话能力（每日计数 + 按时间批量清理）。
    var statsCapability: any ConversationStatsCapability {
        context.statsCapability
    }

    /// 统计面板的作用域：全库为 `nil`，当前项目为该项目的路径。
    var statsProjectPath: String? {
        effectiveProjectPath
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
        // 失败后允许视图重新出现时再次尝试；成功加载出的空库不再重复查询。
        if conversations.isEmpty, isLoading || hasLoadError {
            await reload()
        }
    }

    func loadNextPage() async {
        guard !isLoadingMore, hasMore, !isReloading else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let path = effectiveProjectPath
        let expectedCount = conversations.count
        do {
            let page = try await fetchPage(
                path: path,
                beforeUpdatedAt: paginationCursor?.lastMessageAt,
                beforeID: paginationCursor?.id
            )

            // 翻页期间切了项目或列表被刷新，旧页不能追加到新列表上。
            guard effectiveProjectPath == path, conversations.count == expectedCount else { return }

            hasLoadError = false
            conversations.append(contentsOf: page)
            if let last = page.last {
                paginationCursor = ConversationPageCursor(
                    lastMessageAt: last.lastMessageAt,
                    id: last.id
                )
            }
            hasMore = page.count == Self.pageSize
        } catch {
            // 失败不改游标与 hasMore：再次滚动到列表底部时会重试，而不是永久失去分页能力。
            guard effectiveProjectPath == path, conversations.count == expectedCount else { return }
            hasLoadError = true
        }
    }

    func reload() async {
        if isReloading {
            reloadPending = true
            return
        }

        isReloading = true
        defer {
            isReloading = false
            isLoading = false
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
        var reachedEnd = false

        // 目标条数在每轮读取前重新计算：刷新期间 `loadNextPage()` 可能已追加新页，
        // 用启动时的旧目标发布快照会把刚加载的行删掉。
        do {
            while snapshot.count < max(targetCount, conversations.count) {
                let page = try await fetchPage(
                    path: path,
                    beforeUpdatedAt: cursor?.lastMessageAt,
                    beforeID: cursor?.id
                )
                guard !page.isEmpty else {
                    reachedEnd = true
                    break
                }

                snapshot.append(contentsOf: page)
                guard page.count == Self.pageSize else {
                    reachedEnd = true
                    break
                }
                guard let last = page.last else { break }
                cursor = ConversationPageCursor(lastMessageAt: last.lastMessageAt, id: last.id)
            }
        } catch {
            // 加载期间切了项目：旧项目的失败同样不能写到新项目上。
            guard effectiveProjectPath == path else { return }
            // 保留已有列表、游标与 hasMore，只暴露错误状态；瞬态读取失败
            // 不能把已知良好的会话显示成空库。
            hasLoadError = true
            return
        }

        // 加载期间切了项目：整份快照都属于旧项目，直接丢弃。
        guard effectiveProjectPath == path else { return }
        hasLoadError = false

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
            hasMore = !reachedEnd
        }

        await refreshProjectVisibilityIfNeeded(path: path)
        await refreshConversationCount(path: path)
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

    private func updateAutomationLevel(for conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var updated = conversations[index]
        updated.automationLevel = context.conversations.automationLevel(for: conversationID)
        conversations[index] = updated
    }

    private func fetchPage(
        path: String?,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async throws -> [ConversationSummary] {
        if let path {
            return try await context.conversations.loadConversationPage(
                limit: Self.pageSize,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: false,
                projectPath: path
            )
        }
        return try await context.conversations.loadConversationPage(
            limit: Self.pageSize,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: false
        )
    }

    /// 仅「所有项目」列表需要判断是否展示跨项目提示标题。
    private func refreshProjectVisibilityIfNeeded(path: String?) async {
        guard case .all = scope else { return }
        let projectCount = await context.conversations.conversationProjectCount()
        guard effectiveProjectPath == path else { return }
        hasMultipleProjects = projectCount > 1
    }

    /// 刷新标题栏徽标用的对话条数。
    ///
    /// 统计口径与列表内容保持一致（顶层对话，不含子 Agent 会话）：
    /// - `.all`：全库顶层对话数；
    /// - `.currentProject`：当前项目下的顶层对话数。
    ///
    /// 项目切换期间查询结果可能已经过期，用 `path` 做一次失效检查，
    /// 避免把上一个项目的条数写到当前项目的标题栏上。
    private func refreshConversationCount(path: String?) async {
        let count = await context.conversations.conversationCount(projectPath: path)
        guard effectiveProjectPath == path else { return }
        conversationCount = count
    }
}
