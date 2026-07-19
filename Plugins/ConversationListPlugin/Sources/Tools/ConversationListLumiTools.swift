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
        - Inherit model preferences from the current selection (provider/model)
        - Be selected and become the active conversation
        - Associate with the current project (if one is selected)
        """
    )

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

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

        let conversationID = await MainActor.run {
            chatService.createConversation(
                title: customTitle,
                projectPath: context.currentProjectPath,
                language: nil
            )
        }

        let summary = await MainActor.run {
            chatService.conversations.first(where: { $0.id == conversationID })
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

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

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
            guard let conversation = chatService.conversations.first(where: { $0.id == conversationID }) else {
                return """
                ## Delete Conversation ❌

                **Status**: Conversation not found

                No conversation exists with ID `\(idString)`.

                Use `get_recent_conversations` to list available conversations.
                """
            }

            let title = conversation.title
            let wasSelected = chatService.selectedConversationID == conversationID

            chatService.deleteConversation(id: conversationID)

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

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

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
            let allConversations = chatService.conversations
            let recentConversations = Array(allConversations.prefix(limit))

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

            let infos = recentConversations.map { conversation -> ConversationInfo in
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
            return (allConversations.count, infos)
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

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

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
            let allConversations = chatService.conversations
            let totalCount = allConversations.count

            if let projectPath {
                let projectConversations = allConversations.filter { $0.projectPath == projectPath }
                let projectCount = projectConversations.count
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                return (totalCount, projectCount, projectName)
            } else {
                return (totalCount, 0, nil)
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

// MARK: - Set Conversation Project

struct SetConversationProjectLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "set_conversation_project",
        displayName: LumiPluginLocalization.string("Set Conversation Project", bundle: .module),
        description: """
        Set or remove the project association for a specified conversation.

        Parameters:
        - conversationId: Conversation ID (required, full UUID string)
        - projectPath: Project path (optional, pass "" or null to remove association)

        After setting, the conversation will appear in the project's history.
        """
    )

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "conversationId": .object([
                    "type": .string("string"),
                    "description": .string("Conversation ID (required, full UUID string)")
                ]),
                "projectPath": .object([
                    "type": .string("string"),
                    "description": .string("Project path (optional, pass empty string or null to remove association)")
                ])
            ]),
            "required": .array([.string("conversationId")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let convId = arguments["conversationId"]?.stringValue.map { String($0.prefix(8)) } ?? "unknown"
        return LumiPluginLocalization.string("设置对话项目: \(convId)", bundle: .module)
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let conversationIDString = arguments["conversationId"]?.stringValue,
              let conversationID = UUID(uuidString: conversationIDString)
        else {
            return """
            ## Set Conversation Project ❌

            **Error**: Invalid or missing `conversationId` parameter.

            Please provide a valid UUID string.
            """
        }

        let projectPath: String?
        if let pathArg = arguments["projectPath"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !pathArg.isEmpty
        {
            projectPath = pathArg
        } else {
            projectPath = nil
        }

        let result = await MainActor.run { () -> (success: Bool, title: String?, oldProject: String?, newProject: String?) in
            guard let conversation = chatService.conversations.first(where: { $0.id == conversationID }) else {
                return (false, nil, nil, nil)
            }

            let oldProject = conversation.projectPath
            let updated = chatService.setConversationProjectPath(projectPath, for: conversationID)
            guard updated else {
                return (false, nil, nil, nil)
            }
            return (true, conversation.title, oldProject, projectPath)
        }

        guard result.success else {
            return """
            ## Set Conversation Project ❌

            **Error**: Conversation not found

            **Conversation ID**: `\(conversationIDString)`

            Use `get_recent_conversations` to find a valid conversation ID.
            """
        }

        var response = "## Set Conversation Project ✅\n\n"
        response += "**Conversation**: \(result.title ?? "(unknown)")\n"
        response += "**ID**: `\(conversationIDString)`\n\n"

        if let newProject = result.newProject {
            let projectName = URL(fileURLWithPath: newProject).lastPathComponent
            response += "**New Project**: \(projectName)"
        } else {
            response += "**New Project**: _None (association removed)_"
        }

        if let oldProject = result.oldProject {
            let oldProjectName = URL(fileURLWithPath: oldProject).lastPathComponent
            response += "\n**Previous Project**: \(oldProjectName)"
        } else {
            response += "\n**Previous Project**: _None_"
        }

        return response
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
