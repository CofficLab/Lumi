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
        - Associate with the current project (if one is selected)
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

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let customTitle = arguments["title"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let conversationID = await MainActor.run { () -> UUID? in
            guard let svc = kernel.conversations else { return nil }
            do {
                return try svc.createConversation(title: customTitle, projectPath: nil, providerID: nil, modelName: nil)
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
            kernel.conversations?.conversations.first(where: { $0.id == conversationID })
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