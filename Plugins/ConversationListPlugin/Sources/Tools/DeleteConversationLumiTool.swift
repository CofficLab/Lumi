import Foundation
import LumiKernel

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

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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

            let title = conversation.displayTitle
            let wasSelected = svc.selectedConversationID == conversationID

            svc.deleteConversation(id: conversationID)

            var output = "## Conversation Deleted ✅\n\n"
            output += "**Title**: \(title)\n"
            output += "**Conversation ID**: `\(idString)`\n"

            if wasSelected {
                output += "**Note**: This was the active conversation, selection has been cleared.\n"
            }

            return output
        }
    }
}
