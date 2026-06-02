import Foundation
import SuperLogKit
import AgentToolKit

/// 获取最近对话列表工具
///
/// 返回最近的 N 个对话的 ID 和标题。
public struct GetRecentConversationsTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose: Bool = true
    public let name = "get_recent_conversations"

    /// 通过构造器注入的依赖
    private let conversationVM: WindowConversationVM
    private let currentProjectPath: String?

    public init(conversationVM: WindowConversationVM, currentProjectPath: String?) {
        self.conversationVM = conversationVM
        self.currentProjectPath = currentProjectPath
    }
    
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            获取最近的几个对话的 ID 和标题。

            参数：
            - limit: 要返回的对话数量（默认 5，最大 20）

            返回每个对话的 ID、标题、创建时间和关联项目。
            """
        case .english:
            return """
            Get the IDs and titles of the most recent conversations.

            Parameters:
            - limit: Number of conversations to return (default 5, max 20)

            Returns each conversation's ID, title, creation time, and associated project.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let limitDescription: String
        switch language {
        case .chinese:
            limitDescription = "要返回的对话数量（默认 5，最大 20）"
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
                    "maximum": 20
                ]
            ],
            "required": [] as [String]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        String(localized: "获取最近的对话列表", table: "ConversationList")
    }
    
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    struct ConversationInfo: Sendable {
        let id: String
        let title: String
        let project: String
        let created: String
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 解析 limit 参数
        let limit = arguments["limit"]?.value as? Int ?? 5
        let clampedLimit = min(max(limit, 1), 20)

        // 获取所有对话（在主线程上执行，提取 Sendable 信息）
        let (allCount, recentConversations) = await MainActor.run {
            let allConversations = conversationVM.fetchAllConversations()
            let recentConversations = Array(allConversations.prefix(clampedLimit))

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

            let infos = recentConversations.map { conversation -> ConversationInfo in
                let projectName: String
                if let projectId = conversation.projectId {
                    let name = URL(fileURLWithPath: projectId).lastPathComponent
                    let isCurrent = projectId == currentProjectPath ? " (current)" : ""
                    projectName = name + isCurrent
                } else {
                    projectName = "-"
                }
                let created = dateFormatter.string(from: conversation.createdAt)
                return ConversationInfo(
                    id: conversation.id.uuidString,
                    title: conversation.title,
                    project: projectName,
                    created: created
                )
            }
            return (allConversations.count, infos)
        }

        if recentConversations.isEmpty {
            return """
            ## Recent Conversations

            **Status**: No conversations found

            Start a new conversation to see it listed here.
            """
        }

        // 格式化输出
        var result = "## Recent Conversations (showing \(recentConversations.count) of \(allCount) total)\n\n"
        result += "| # | Conversation ID | Title | Project | Created |\n"
        result += "|---|----------------|-------|---------|---------|\n"

        for (index, info) in recentConversations.enumerated() {
            result += "| \(index + 1) | `\(info.id)` | \(info.title.escapedForTable()) | \(info.project) | \(info.created) |\n"
        }

        return result
    }
}

// MARK: - Helper

extension String {
    /// 转义 Markdown 表格中的特殊字符
    public func escapedForTable() -> String {
        self.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
