import Combine
import Foundation
import ProviderConversation
import ProviderMessage

/// 会话存储设置页唯一的数据来源与交互入口。
///
/// 会话、消息、分页、统计、选中态与迁移状态全部收敛到这里；外部会话事件由
/// `ConversationStoreObserver` 写入，View 只读取状态并触发用户意图。
@MainActor
final class ConversationStoreSettingsViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var totalConversationCount: Int?
    @Published private(set) var isLoadingConversations = true
    @Published private(set) var isLoadingMoreConversations = false
    @Published private(set) var hasMoreConversations = true
    @Published private(set) var dailyCountSeries = ConversationDailyCountSeries(points: [])
    @Published private(set) var messageCounts: [UUID: Int] = [:]
    @Published private(set) var messagesForSelected: [Message] = []
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var isMigrationActive = false

    private let capability: any ConversationStoreCapability
    private var didSeedSelection = false
    private var isReloading = false
    private var pendingReload = false
    private var messageRefreshTask: Task<Void, Never>?

    let conversationPageSize = 40
    let messageDisplayLimit = 40

    init(capability: any ConversationStoreCapability) {
        self.capability = capability
    }

    var selectedConversation: ConversationSummary? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    var conversationIDs: [UUID] {
        conversations.map(\.id)
    }

    /// 右上角总数按钮的标题：无数据时退回占位符，避免出现空标题。
    var conversationCountDisplay: String {
        totalConversationCount.map(String.init) ?? "—"
    }

    // MARK: - Observer 入口

    /// 由 Observer 转发的外部会话事件。
    func handleConversationEvent(_ event: ConversationEvent) {
        switch event {
        case .listChanged, .created, .deleted, .updated:
            scheduleReload()
        case .selected, .markedActive:
            break
        case .providerChanged(let id):
            refreshSummary(id)
        case .verbosityChanged(let id), .reasoningChanged(let id),
             .automationChanged(let id), .languageChanged(let id):
            // 全局偏好（id 为 nil）不会改变每条会话展示的显式取值，无需刷新。
            if let id { refreshSummary(id) }
        }
    }

    /// 由 Observer 转发的迁移进度变化。
    func updateMigration(isActive: Bool) {
        isMigrationActive = isActive
    }

    // MARK: - 用户意图

    func selectConversation(id: UUID) {
        selectedConversationID = id
        didSeedSelection = true
    }

    // MARK: - 数据加载

    /// 首次进入页面时加载第一页会话、总数与统计。
    ///
    /// 再次进入时已有快照可能落后于 Manager（例如设置页长期持有 ViewModel），
    /// 就地刷新已加载的摘要；不整页重载，避免丢掉用户翻过的分页。
    func loadInitialIfNeeded() async {
        guard isLoadingConversations else {
            await refreshLoadedSummaries()
            return
        }
        guard conversations.isEmpty else { return }
        await performReload(initial: true)
    }

    /// 外部事件驱动的列表刷新（保留旧列表，避免闪烁）。
    func reloadConversations() async {
        scheduleReload()
        // scheduleReload 内部通过 isReloading/pendingReload 去重。
    }

    func loadMoreIfNeeded() async {
        guard !isReloading,
              !isLoadingConversations,
              !isLoadingMoreConversations,
              hasMoreConversations,
              let last = conversations.last else { return }

        isLoadingMoreConversations = true
        defer { isLoadingMoreConversations = false }

        let expectedCount = conversations.count
        let page = await capability.fetchConversationPage(
            limit: conversationPageSize,
            beforeUpdatedAt: last.lastMessageAt,
            beforeID: last.id,
            includingChildConversations: true
        )

        // 翻页期间列表被刷新或替换，旧页不能追加到新列表上。
        guard conversations.count == expectedCount, conversations.last?.id == last.id else { return }

        conversations.append(contentsOf: page)
        hasMoreConversations = page.count == conversationPageSize
        syncSelectionAfterConversationChange()
        await loadMessageCounts(for: page)
    }

    /// 由 Observer 转发的消息变化。
    ///
    /// 新消息不会改变 `ConversationSummary` 的身份，也只可能微调 `lastMessageAt`，
    /// 因此会话事件这条路收不到通知；不订阅消息变化，计数与当前会话预览就一直
    /// 停在打开页面时的快照（#995）。
    func handleMessageChange(_ change: MessageChange) {
        let conversationID: UUID
        switch change {
        case .inserted(_, let id), .persisted(_, let id):
            conversationID = id
        case .updated(let id), .cleared(let id):
            conversationID = id
        case .deleted(_, let id):
            conversationID = id
        }

        messageCounts[conversationID] = capability.messageCount(for: conversationID)

        guard conversationID == selectedConversationID else { return }
        // 流式回复会连续产生变化事件，合并成一次快照读取。
        messageRefreshTask?.cancel()
        messageRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await self?.loadMessages()
        }
    }

    /// 加载当前选中会话的最近一页消息。
    func loadMessages() async {
        guard let id = selectedConversationID else {
            messagesForSelected = []
            return
        }
        let all = await capability.messagesSnapshot(in: id)
        let loaded = Array(all.suffix(messageDisplayLimit))
        guard selectedConversationID == id else { return }
        messagesForSelected = loaded
    }

    // MARK: - Selection

    func seedSelectionIfNeeded() {
        guard !didSeedSelection else { return }
        didSeedSelection = true

        if let initialSelected = capability.selectedConversationID,
           conversations.contains(where: { $0.id == initialSelected }) {
            selectedConversationID = initialSelected
        } else {
            selectedConversationID = conversations.first?.id
        }
    }

    func syncSelectionAfterConversationChange() {
        if !didSeedSelection {
            seedSelectionIfNeeded()
            return
        }

        guard let selectedConversationID else {
            self.selectedConversationID = conversations.first?.id
            return
        }

        guard conversations.contains(where: { $0.id == selectedConversationID }) else {
            self.selectedConversationID = conversations.first?.id
            return
        }
    }

    // MARK: - Private

    /// 偏好变更后按 ID 就地更新对应摘要，不重载整页（保留已加载的分页）。
    private func refreshSummary(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let fresh = await self.capability.fetchConversationSummary(id: id) else { return }
            guard let index = self.conversations.firstIndex(where: { $0.id == id }) else { return }
            self.conversations[index] = fresh
        }
    }

    private func refreshLoadedSummaries() async {
        for id in conversations.map(\.id) {
            guard let fresh = await capability.fetchConversationSummary(id: id) else { continue }
            guard let index = conversations.firstIndex(where: { $0.id == id }) else { continue }
            conversations[index] = fresh
        }
    }

    private func scheduleReload() {
        if isReloading {
            pendingReload = true
        } else {
            Task { await performReload(initial: false) }
        }
    }

    private func performReload(initial: Bool) async {
        guard !isReloading else {
            pendingReload = true
            return
        }
        isReloading = true
        defer {
            isReloading = false
            if pendingReload {
                pendingReload = false
                Task { await performReload(initial: false) }
            }
        }

        if initial {
            isLoadingConversations = true
        }

        let page = await capability.fetchConversationPage(
            limit: conversationPageSize,
            beforeUpdatedAt: nil,
            beforeID: nil,
            includingChildConversations: true
        )
        let total = await capability.conversationCount(
            projectPath: nil,
            includingChildConversations: true
        )
        let dailySeries = await capability.fetchDailyCountSeries()

        conversations = page
        totalConversationCount = total
        dailyCountSeries = dailySeries
        hasMoreConversations = page.count == conversationPageSize
        isLoadingConversations = false
        syncSelectionAfterConversationChange()
        await loadMessageCounts(for: page)
    }

    private func loadMessageCounts(for conversations: [ConversationSummary]) async {
        for conversation in conversations where messageCounts[conversation.id] == nil {
            let count = capability.messageCount(for: conversation.id)
            messageCounts[conversation.id] = count
        }
    }
}
