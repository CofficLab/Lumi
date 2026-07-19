import Foundation
import LumiKernel

struct UpdateConversationTitleLumiTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "update_conversation_title",
        displayName: LumiPluginLocalization.string("Update Conversation Title", bundle: .module),
        description: """
        Update the title of a specified conversation. Provide conversationId (UUID) and title.
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
                "title": .object([
                    "type": .string("string"),
                    "description": .string("New title (required)")
                ])
            ]),
            "required": .array([.string("conversationId"), .string("title")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let title = arguments["title"]?.stringValue.map { String($0.prefix(15)) } ?? "unknown"
        return "更新对话标题: \(title)"
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let conversationIDString = arguments["conversationId"]?.stringValue,
              let conversationID = UUID(uuidString: conversationIDString)
        else {
            return """
            ## Update Conversation Title ❌

            **Error**: Invalid or missing `conversationId` parameter.
            """
        }

        guard let newTitle = arguments["title"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !newTitle.isEmpty
        else {
            return """
            ## Update Conversation Title ❌

            **Error**: Missing or empty `title` parameter.
            """
        }

        let oldTitle = await MainActor.run {
            chatService.conversations.first(where: { $0.id == conversationID })?.title
        }

        let updated = await MainActor.run {
            chatService.updateConversationTitle(newTitle, for: conversationID)
        }

        guard updated else {
            return """
            ## Update Conversation Title ❌

            **Error**: Conversation not found

            **Conversation ID**: `\(conversationIDString)`
            """
        }

        var response = "## Update Conversation Title ✅\n\n"
        response += "**Conversation ID**: `\(conversationIDString)`\n"
        if let oldTitle {
            response += "**Previous Title**: \(oldTitle)\n"
        }
        response += "**New Title**: \(newTitle)"
        return response
    }
}
