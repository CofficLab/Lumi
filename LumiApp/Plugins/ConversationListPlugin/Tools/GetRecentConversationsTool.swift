import Foundation
import AgentToolKit
import os

/// 获取最近对话列表工具
///
/// 返回最近的 N 个对话的 ID 和标题。
struct GetRecentConversationsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose: Bool = true
    let name = "get_recent_conversations"
    
    func description(for language: LanguagePreference) -> String {
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

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        String(localized: "获取最近的对话列表", table: "ConversationList")
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 解析 limit 参数
        let limit = arguments["limit"]?.value as? Int ?? 5
        let clampedLimit = min(max(limit, 1), 20)

        // 从 ToolContext 获取当前窗口的 conversationVM
        guard let conversationVM = context.conversationVM else {
            return """
            ## Recent Conversations

            **Status**: No active window

            Please ensure a window is open.
            """
        }

        // 获取当前项目路径（用于标记当前项目的对话）
        let currentProjectPath = await MainActor.run {
            RootContainer.shared.windowManagerVM.activeWindowContainer?.projectVM.currentProject?.path
        }

        // 获取所有对话（已按时间倒序）
        let allConversations = await MainActor.run {
            conversationVM.fetchAllConversations()
        }

        // 取前 N 个
        let recentConversations = Array(allConversations.prefix(clampedLimit))

        if recentConversations.isEmpty {
            return """
            ## Recent Conversations

            **Status**: No conversations found

            Start a new conversation to see it listed here.
            """
        }

        // 格式化输出
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var result = "## Recent Conversations (showing \(recentConversations.count) of \(allConversations.count) total)\n\n"
        result += "| # | Conversation ID | Title | Project | Created |\n"
        result += "|---|----------------|-------|---------|---------|\n"

        for (index, conversation) in recentConversations.enumerated() {
            let projectName: String
            if let projectId = conversation.projectId {
                let name = URL(fileURLWithPath: projectId).lastPathComponent
                let isCurrent = projectId == currentProjectPath ? " (current)" : ""
                projectName = name + isCurrent
            } else {
                projectName = "-"
            }

            let created = dateFormatter.string(from: conversation.createdAt)
            let idShort = conversation.id.uuidString.prefix(8)

            result += "| \(index + 1) | `\(conversation.id.uuidString)` | \(conversation.title.escapedForTable()) | \(projectName) | \(created) |\n"
        }

        return result
    }
}

// MARK: - Helper

extension String {
    /// 转义 Markdown 表格中的特殊字符
    func escapedForTable() -> String {
        self.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
