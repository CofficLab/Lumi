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
        let page = await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        ) ?? []
        // 分页结果同样要进缓存：否则翻到第二页后，这些真实会话在
        // 删除/标题/偏好路径里会被缓存守卫当成不存在（issue #965）。
        for summary in page {
            cache(summary)
        }
        return page
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [ConversationSummary] {
        let page = await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations,
            projectPath: projectPath
        ) ?? []
        for summary in page {
            cache(summary)
        }
        return page
    }

    /// 分页读取的失败必须传给调用方：列表刷新要保留上一份成功快照，
    /// 不能把瞬态存储错误当成空库。
    public func loadConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool
    ) async throws -> [ConversationSummary] {
        guard let store else { throw ConversationPageLoadError.storageUnavailable }
        let page = try await store.loadConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        )
        for summary in page {
            cache(summary)
        }
        return page
    }

    public func loadConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool,
        projectPath: String
    ) async throws -> [ConversationSummary] {
        guard let store else { throw ConversationPageLoadError.storageUnavailable }
        let page = try await store.loadConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations,
            projectPath: projectPath
        )
        for summary in page {
            cache(summary)
        }
        return page
    }

    public func fetchConversation(id: UUID) async -> ConversationSummary? {
        if let cached = conversations.first(where: { $0.id == id }) {
            return cached
        }

        guard let summary = await store?.fetchConversation(id: id) else {
            return nil
        }

        await MainActor.run {
            self.cacheHydratedSummary(summary)
        }
        return summary
    }

    /// 返回仍然**没有标题**的对话 ID。
    ///
    /// 走存储层查询而不是内存摘要：内存里只保留最近的一部分对话，
    /// 历史遗留的无标题对话大概率不在窗口里，按内存筛会漏掉它们。
    public func untitledConversationIDs(limit: Int) async -> [UUID] {
        await store?.untitledConversationIDs(limit: limit) ?? []
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

    /// 指定项目下、仍有活动的会话 ID。
    ///
    /// 走存储层查询而不是内存摘要：摘要列表未必已全量加载，
    /// 用它筛会话会漏掉「已落库但未进入缓存」的会话。
    public func conversationIDs(projectPath: String, updatedSince: Date? = nil) async -> [String] {
        await store?.conversationIDs(projectPath: projectPath, updatedSince: updatedSince) ?? []
    }

    /// Count conversations created before a cutoff date.
    public func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int {
        await store?.conversationCount(
            createdBefore: cutoff,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        ) ?? 0
    }

    /// Fetch daily conversation counts without loading conversation summaries.
    public func fetchDailyCountSeries(
        days: Int = 14,
        projectPath: String? = nil,
        includingChildConversations: Bool = false
    ) async -> ConversationDailyCountSeries {
        await store?.fetchDailyCountSeries(
            days: days,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        ) ?? ConversationDailyCountSeries(points: [])
    }
}
