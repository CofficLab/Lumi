import Foundation
import LumiKernel

// MARK: - Get Recent Conversations

struct GetRecentConversationsLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "get_recent_conversations",
        displayName: LumiPluginLocalization.string("Get Recent Conversations", bundle: .module),
        description: """
        Get the IDs and titles of the most recent conversations.

        Parameters:
        - limit: Number of conversations to return (default 5, max 20)

        Returns each conversation's ID, title, creation time, and associated project.
        """
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Number of conversations to return (default 5, max 20)"),
                    "minimum": .int(1),
                    "maximum": .int(20)
                ])
            ]),
            "required": .array([])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        LumiPluginLocalization.string("获取最近的对话列表", bundle: .module)
    }

    private struct ConversationInfo: Sendable {
        let id: String
        let title: String
        let project: String
        let created: String
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let limit = min(max(arguments["limit"]?.intValue ?? 5, 1), 20)

        let (allCount, recentConversations) = await MainActor.run { () -> (Int, [ConversationInfo]) in
            guard let svc = ConversationListToolRuntimeBridge.conversations else {
                return (0, [])
            }
            let all = svc.conversations
            let recent = Array(all.prefix(limit))

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

            let infos = recent.map { conversation -> ConversationInfo in
                let projectName: String
                if let projectPath = conversation.projectPath {
                    let name = URL(fileURLWithPath: projectPath).lastPathComponent
                    let isCurrent = projectPath == kernel.currentProjectPath ? " (current)" : ""
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
            return (all.count, infos)
        }

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
