import Foundation
import ProviderConversation

extension ConversationManager {
    /// Load a bounded conversation page for settings/history UIs.
    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil
    ) async -> [ConversationSummary] {
        await fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: false
        )
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool
    ) async -> [ConversationSummary] {
        await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        ) ?? []
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [ConversationSummary] {
        await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations,
            projectPath: projectPath
        ) ?? []
    }

    public func fetchConversation(id: UUID) async -> ConversationSummary? {
        if let cached = conversations.first(where: { $0.id == id }) {
            return cached
        }

        guard let summary = await store?.fetchConversation(id: id) else {
            return nil
        }

        await MainActor.run {
            self.cache(summary)
        }
        return summary
    }

    /// Count conversations without loading their summaries.
    public func conversationCount(projectPath: String? = nil) async -> Int {
        await store?.conversationCount(projectPath: projectPath, includingChildConversations: false) ?? 0
    }

    public func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
        await store?.conversationCount(
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        ) ?? 0
    }

    /// 不同项目路径的数量（仅统计 projectPath 非空、顶层对话）。
    public func conversationProjectCount() async -> Int {
        await store?.conversationProjectCount() ?? 0
    }

    /// Fetch daily conversation counts without loading conversation summaries.
    func fetchDailyCountSeries() async -> ConversationDailyCountSeries {
        await store?.fetchDailyCountSeries() ?? ConversationDailyCountSeries(points: [])
    }
}
