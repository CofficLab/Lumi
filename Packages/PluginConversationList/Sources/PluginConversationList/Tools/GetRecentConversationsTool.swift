import AgentToolKit
import Foundation
import ProviderConversation
import ProviderProject

/// 获取最近对话列表的 Agent 工具（复刻旧版 ConversationListPlugin.GetRecentConversationsTool）。
///
/// 新版实现基于 `SuperAgentTool` 协议，对话 / 项目能力在构造时注入，
/// 不再依赖 KernelLumi 的 kernel 参数。
struct GetRecentConversationsTool: SuperAgentTool, @unchecked Sendable {
    let name = "get_recent_conversations"

    private let conversations: (any ConversationManaging)?
    private let project: (any ProjectProviding)?

    init(conversations: (any ConversationManaging)?, project: (any ProjectProviding)?) {
        self.conversations = conversations
        self.project = project
    }

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取最近的对话列表，返回每个对话的 ID、标题、创建时间和所属项目。参数：limit - 返回的对话数量（默认 5，最大 20）。"
        case .english:
            return """
            Get the IDs and titles of the most recent conversations.

            Parameters:
            - limit: Number of conversations to return (default 5, max 20)

            Returns each conversation's ID, title, creation time, and associated project.
            """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let limitDescription: String
        switch language {
        case .chinese:
            limitDescription = "返回的对话数量（默认 5，最大 20）"
        case .english:
            limitDescription = "Number of conversations to return (default 5, max 20)"
        }
        return [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": limitDescription,
                    "minimum": 1,
                    "maximum": 20,
                ],
            ],
            "required": [],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "获取最近的对话列表"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 只读查询，不修改任何数据。
        .safe
    }

    private struct ConversationInfo: Sendable {
        let id: String
        let title: String
        let project: String
        let created: String
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = min(max((arguments["limit"]?.value as? Int) ?? 5, 1), 20)

        // 对话 / 项目能力均约束在 MainActor，跨任务边界访问需包一层 MainActor 任务。
        let (recent, allCount, currentProjectPath): ([LumiConversationSummary], Int, String?) =
            await Task { @MainActor in
                let recent = await conversations?.fetchConversationPage(
                    limit: limit,
                    beforeUpdatedAt: nil,
                    beforeID: nil
                ) ?? []
                let allCount = await conversations?.conversationCount(projectPath: nil) ?? 0
                return (recent, allCount, project?.currentProject?.path)
            }.value

        let recentConversations: [ConversationInfo] = await Task { @MainActor in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

            return recent.map { conversation in
                let projectName: String
                if let projectPath = conversation.projectPath {
                    let name = URL(fileURLWithPath: projectPath).lastPathComponent
                    let isCurrent = projectPath == currentProjectPath ? " (current)" : ""
                    projectName = name + isCurrent
                } else {
                    projectName = "-"
                }
                let created = dateFormatter.string(from: conversation.createdAt)
                return ConversationInfo(
                    id: conversation.id.uuidString,
                    title: conversation.displayTitle,
                    project: projectName,
                    created: created
                )
            }
        }.value

        if recentConversations.isEmpty {
            return """
            ## Recent Conversations

            **Status**: No conversations found

            Start a new conversation to see it listed here.
            """
        }

        var result = "## Recent Conversations (showing \(recentConversations.count) of \(allCount) total)\n\n"
        result += "| # | Conversation ID | Title | Project | Created |\n"
        result += "|---|----------------|-------|---------|---------|\n"

        for (index, info) in recentConversations.enumerated() {
            result += "| \(index + 1) | `\(info.id)` | \(info.title.escapedForTable()) | \(info.project) | \(info.created) |\n"
        }

        return result
    }
}

private extension String {
    /// 转义 Markdown 表格中的管道符与换行，防止破坏表格结构。
    func escapedForTable() -> String {
        replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
