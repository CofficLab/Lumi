import Foundation
import ProviderConversation
import ProviderProject

/// Agent 工具「最近对话列表」需要的最小会话与项目能力边界。
///
/// 工具只关心「分页取最近对话」「会话总数」「当前项目路径」，
/// 不直接持有 `ConversationManaging` / `ProjectProviding` 宽接口。
@MainActor
protocol ConversationListQueryCapability: AnyObject {
    /// 按更新时间倒序取最近一页对话。
    func fetchRecentConversations(limit: Int) async -> [ConversationSummary]

    /// 会话总数；`projectPath` 为 `nil` 时统计全部项目。
    func conversationCount(projectPath: String?) async -> Int

    /// 当前打开的项目路径，无项目时为 `nil`。
    var currentProjectPath: String? { get }
}

/// 将内核的 `ConversationManaging` 与 `ProjectProviding` 收窄为工具所需的查询能力。
@MainActor
final class ConversationListQueryCapabilityAdapter: ConversationListQueryCapability {
    private let conversations: (any ConversationManaging)?
    private let project: (any ProjectProviding)?

    init(conversations: (any ConversationManaging)?, project: (any ProjectProviding)?) {
        self.conversations = conversations
        self.project = project
    }

    func fetchRecentConversations(limit: Int) async -> [ConversationSummary] {
        await conversations?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: nil,
            beforeID: nil
        ) ?? []
    }

    func conversationCount(projectPath: String?) async -> Int {
        await conversations?.conversationCount(projectPath: projectPath) ?? 0
    }

    var currentProjectPath: String? { project?.currentProject?.path }
}
