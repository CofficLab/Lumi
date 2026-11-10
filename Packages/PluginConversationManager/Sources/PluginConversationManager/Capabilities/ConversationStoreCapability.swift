import Foundation
import ProviderConversation
import ProviderMessage

/// 会话存储设置页所需的最小会话/消息能力。
@MainActor
protocol ConversationStoreCapability: AnyObject {
    /// 当前选中会话（用于初始选中态对齐）。
    var selectedConversationID: UUID? { get }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [ConversationSummary]

    func conversationCount(
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int

    func fetchDailyCountSeries() async -> ConversationDailyCountSeries

    func messagesSnapshot(in conversationID: UUID) async -> [Message]

    /// 读取一条会话的最新摘要：优先管理器内存（偏好变更会先同步到这里），回退存储层。
    func fetchConversationSummary(id: UUID) async -> ConversationSummary?

    func messageCount(for conversationID: UUID) -> Int

    @discardableResult
    func addConversationObserver(
        _ callback: @escaping (ConversationEvent) -> Void
    ) -> any ConversationObserverHandle

    @discardableResult
    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle
}

/// 将 ConversationManager 与 MessageManaging 适配为设置页能力。
@MainActor
final class ConversationStoreCapabilityAdapter: ConversationStoreCapability {
    private let manager: ConversationManager
    private let messageManager: (any MessageManaging)?

    init(manager: ConversationManager, messageManager: (any MessageManaging)?) {
        self.manager = manager
        self.messageManager = messageManager
    }

    var selectedConversationID: UUID? { manager.selectedConversationID }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [ConversationSummary] {
        await manager.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        )
    }

    func conversationCount(
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int {
        await manager.conversationCount(
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
    }

    func fetchDailyCountSeries() async -> ConversationDailyCountSeries {
        await manager.fetchDailyCountSeries()
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await messageManager?.messagesSnapshot(in: conversationID) ?? []
    }

    func fetchConversationSummary(id: UUID) async -> ConversationSummary? {
        await manager.fetchConversation(id: id)
    }

    func messageCount(for conversationID: UUID) -> Int {
        messageManager?.messageCount(for: conversationID) ?? 0
    }

    @discardableResult
    func addConversationObserver(
        _ callback: @escaping (ConversationEvent) -> Void
    ) -> any ConversationObserverHandle {
        manager.addConversationObserver(callback)
    }

    @discardableResult
    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        guard let messageManager else {
            return NoopMessageChangeObserverHandle()
        }
        return messageManager.addMessageChangeObserver(callback)
    }
}

/// 未注入消息管理器时的空令牌，避免调用方区分可选分支。
@MainActor
final class NoopMessageChangeObserverHandle: MessageChangeObserverHandle {
    func cancel() {}
}
