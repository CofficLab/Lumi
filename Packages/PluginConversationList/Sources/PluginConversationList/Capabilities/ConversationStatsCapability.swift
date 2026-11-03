import Foundation
import ProviderConversation

/// 对话统计面板需要的最小会话能力边界。
///
/// 面板只关心三件事：
/// - 「最近一段时间每天有多少对话」（折线图）；
/// - 「删除 N 天前的对话」（批量清理）；
/// - 当前作用域是全库还是某个项目。
///
/// 它不直接持有 `ConversationManaging` 宽接口——由
/// `ConversationStatsCapabilityAdapter` 负责收窄。
@MainActor
protocol ConversationStatsCapability: AnyObject {
    /// 每日对话计数序列（按创建日聚合）。
    ///
    /// - Parameters:
    ///   - days: 序列长度（向前回溯的天数）。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func fetchDailyCountSeries(
        days: Int,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> ConversationDailyCountSeries

    /// 删除「创建于 `cutoff` 之前」的对话，返回被删除的会话 ID。
    @discardableResult
    func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID]

    /// 统计「创建于 `cutoff` 之前」的对话数量。
    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int
}

/// 将内核的 `ConversationManaging` 收窄为统计面板所需的查询与清理能力。
@MainActor
final class ConversationStatsCapabilityAdapter: ConversationStatsCapability {
    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    func fetchDailyCountSeries(
        days: Int,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> ConversationDailyCountSeries {
        await conversations.fetchDailyCountSeries(
            days: days,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
    }

    func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID] {
        await conversations.deleteConversations(
            createdBefore: cutoff,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
    }

    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int {
        await conversations.conversationCount(
            createdBefore: cutoff,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
    }
}
