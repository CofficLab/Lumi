import Foundation
import LumiKernel

// MARK: - Create New Conversation

struct CreateNewConversationLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "create_new_conversation",
        displayName: LumiPluginLocalization.string("Create New Conversation", bundle: .module),
        description: """
        Create a new conversation session.

        Parameters (all optional):
        - title: Conversation title (optional, uses default if empty)

        The new conversation will automatically:
        - Be selected and become the active conversation
        - Associate with the current project (if one is selected and ConversationManaging supports it)
        """
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Conversation title (optional, uses default if empty)")
                ])
            ]),
            "required": .array([])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        LumiPluginLocalization.string("创建新对话", bundle: .module)
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let customTitle = arguments["title"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let conversationID = await MainActor.run { () -> UUID? in
            guard let svc = ConversationListToolRuntimeBridge.conversations else { return nil }
            do {
                // ConversationManaging.createConversation 仅支持 title; projectPath 后续扩展。
                return try svc.createConversation(title: customTitle)
            } catch {
                return nil
            }
        }

        guard let conversationID else {
            return """
            ## New Conversation ❌

            **Status**: Conversation service unavailable.
            """
        }

        let summary = await MainActor.run { () -> LumiConversationSummary? in
            ConversationListToolRuntimeBridge.conversations?.conversations
                .first(where: { $0.id == conversationID })
        }

        let idShort = String(conversationID.uuidString.prefix(8))
        var result = """
        ## New Conversation Created ✅

        **Conversation ID**: `\(conversationID.uuidString)`
        **ID (short)**: `\(idShort)`
        """

        if let projectPath = summary?.projectPath {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            result += "\n**Project**: \(projectName)"
        }

        if let customTitle, !customTitle.isEmpty {
            result += "\n**Title**: \(customTitle)"
        }

        result += """

        ---
        The new conversation is now active and ready to use.
        """
        return result
    }
}

// MARK: - Delete Conversation

struct DeleteConversationLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "delete_conversation",
        displayName: LumiPluginLocalization.string("Delete Conversation", bundle: .module),
        description: """
        Delete a specified conversation session. This action is irreversible and will permanently remove the conversation and all its messages.

        Parameters:
        - conversationId: The conversation ID to delete (UUID string)

        Notes:
        - If the deleted conversation is currently selected, the selection will be cleared
        - This action is irreversible, use with caution
        """
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "conversationId": .object([
                    "type": .string("string"),
                    "description": .string("The conversation ID to delete (UUID string)")
                ])
            ]),
            "required": .array([.string("conversationId")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let id = arguments["conversationId"]?.stringValue else {
            return LumiPluginLocalization.string("删除对话", bundle: .module)
        }
        let shortId = String(id.prefix(8))
        return LumiPluginLocalization.string("删除对话 \(shortId)", bundle: .module)
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let idString = arguments["conversationId"]?.stringValue else {
            throw NSError(
                domain: "DeleteConversationLumiTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'conversationId' argument"]
            )
        }

        guard let conversationID = UUID(uuidString: idString) else {
            return """
            ## Delete Conversation ❌

            **Status**: Invalid conversation ID

            The provided ID `\(idString)` is not a valid UUID format.

            Please check the ID and try again.
            """
        }

        return await MainActor.run {
            guard let svc = ConversationListToolRuntimeBridge.conversations else {
                return """
                ## Delete Conversation ❌

                **Status**: Conversation service unavailable.
                """
            }

            guard let conversation = svc.conversations.first(where: { $0.id == conversationID }) else {
                return """
                ## Delete Conversation ❌

                **Status**: Conversation not found

                No conversation exists with ID `\(idString)`.

                Use `get_recent_conversations` to list available conversations.
                """
            }

            let title = conversation.title
            let wasSelected = svc.selectedConversationID == conversationID

            svc.deleteConversation(id: conversationID)

            var output = "## Conversation Deleted ✅\n\n"
            output += "**Title**: \(title.isEmpty ? "(untitled)" : title)\n"
            output += "**Conversation ID**: `\(idString)`\n"

            if wasSelected {
                output += "**Note**: This was the active conversation, selection has been cleared.\n"
            }

            return output
        }
    }
}

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

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
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
                    let isCurrent = projectPath == context.currentProjectPath ? " (current)" : ""
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

// MARK: - Get Conversation Count

struct GetConversationCountLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "get_conversation_count",
        displayName: LumiPluginLocalization.string("Get Conversation Count", bundle: .module),
        description: LumiPluginLocalization.string("Get the total number of conversation histories. Returns the total count of conversations.", bundle: .module)
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        LumiPluginLocalization.string("获取对话总数", bundle: .module)
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let projectPath = context.currentProjectPath

        let (totalCount, projectCount, projectName) = await MainActor.run { () -> (Int, Int, String?) in
            guard let svc = ConversationListToolRuntimeBridge.conversations else {
                return (0, 0, nil)
            }
            let all = svc.conversations
            let total = all.count

            if let projectPath {
                let projectConversations = all.filter { $0.projectPath == projectPath }
                let count = projectConversations.count
                let name = URL(fileURLWithPath: projectPath).lastPathComponent
                return (total, count, name)
            } else {
                return (total, 0, nil)
            }
        }

        if let projectName {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)
            **Conversations for Current Project** (\(projectName)): \(projectCount)
            """
        } else {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)

            _No project currently selected._
            """
        }
    }
}

// MARK: - Helpers

private extension LumiJSONValue {
    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        default:
            nil
        }
    }
}

private extension String {
    func escapedForTable() -> String {
        replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

// MARK: - Set Conversation Project (not yet supported)
//
// SetConversationProjectLumiTool 未启用,因为 `ConversationManaging` 协议
// 当前未提供 `setConversationProjectPath(_:for:)` 方法。等协议扩展后再补。
