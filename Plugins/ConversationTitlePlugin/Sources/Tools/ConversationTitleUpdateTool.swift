import Foundation
import KernelLumi

public struct ConversationTitleUpdateTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "update_conversation_title",
        displayName: "Update Conversation Title",
        description: "Update the current conversation title."
    )

    private let conversations: (any ConversationManaging)?

    public init(conversations: (any ConversationManaging)? = nil) {
        self.conversations = conversations
    }

    public var tags: Set<LumiToolTag> { [.sideEffect] }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A concise, descriptive title for the current conversation")
                ])
            ]),
            "required": .array([.string("title")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let title = arguments["title"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return "Update conversation title"
        }
        return "Update conversation title to \"\(title)\""
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let title = arguments["title"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            throw NSError(
                domain: "ConversationTitleUpdateTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'title' argument"]
            )
        }

        guard let conversations else {
            return """
            ## Update Conversation Title ❌

            **Status**: Conversation service unavailable.
            """
        }

        let updated = await MainActor.run {
            conversations.updateConversationTitle(title, for: kernel.conversationID)
        }

        guard updated else {
            return """
            ## Update Conversation Title ❌

            **Status**: Conversation not found or title update failed.
            """
        }

        return """
        ## Conversation Title Updated ✅

        **Conversation ID**: `\(kernel.conversationID.uuidString)`
        **Title**: \(title)
        """
    }
}
