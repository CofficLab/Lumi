import AppKit
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

    var conversationCountLabel: String {
        if let totalConversationCount {
            return String(format: L("%lld conversations"), totalConversationCount)
        }
        return L("Loading conversations…")
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    // MARK: - Observer 入口

    /// 由 Observer 转发的外部会话事件。
    func handleConversationEvent(_ event: ConversationEvent) {
        switch event {
        case .listChanged, .created, .deleted, .updated:
            scheduleReload()
        case .selected, .markedActive, .providerChanged, .verbosityChanged,
             .reasoningChanged, .automationChanged, .languageChanged:
            break
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

    func openDataDirectory() {
        let url = capability.dataDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }

    // MARK: - 数据加载

    /// 首次进入页面时加载第一页会话、总数与统计。
    func loadInitialIfNeeded() async {
        guard conversations.isEmpty, isLoadingConversations else { return }
        await performReload(initial: true)
    }

    /// 外部事件驱动的列表刷新（保留旧列表，避免闪烁）。
    func reloadConversations() async {
        scheduleReload()
        // scheduleReload 内部通过 isReloading/pendingReload 去重。
    }

    func loadMoreIfNeeded() async {
        guard !isLoadingConversations,
              !isLoadingMoreConversations,
              hasMoreConversations,
              let last = conversations.last else { return }

        isLoadingMoreConversations = true
        let page = await capability.fetchConversationPage(
            limit: conversationPageSize,
            beforeUpdatedAt: last.lastMessageAt,
            beforeID: last.id,
            includingChildConversations: true
        )
        conversations.append(contentsOf: page)
        hasMoreConversations = page.count == conversationPageSize
        isLoadingMoreConversations = false
        syncSelectionAfterConversationChange()
        await loadMessageCounts(for: page)
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
