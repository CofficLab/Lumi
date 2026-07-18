import Foundation
import LumiComponentMessage
import LumiComponentAgentTool

/// Allows the agent to read current conversation configuration.
///
/// The agent can use this tool to check its own settings (language, verbosity,
/// automation level, model, project path) before responding, so it can adapt
/// its behavior accordingly.
struct ConversationInfoTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "conversation_info",
        displayName: "Conversation Info",
        description: "Read the current conversation's configuration including language, verbosity, automation level, model, and project path. Use this to understand your own operating context."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "conversationID": .object([
                    "type": .string("string"),
                    "description": .string("Conversation UUID to query. Leave empty to query the current conversation."),
                ]),
            ]),
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let conversationID: UUID
        if case .string(let value) = arguments["conversationID"], let uuid = UUID(uuidString: value) {
            conversationID = uuid
        } else {
            conversationID = context.conversationID
        }

        return await MainActor.run {
            guard let service = ChatService.shared else {
                return "Error: ChatService not available."
            }
            guard let summary = service.conversationSummary(for: conversationID) else {
                return "Error: conversation \(conversationID.uuidString.prefix(8)) not found."
            }

            var lines: [String] = [
                "**Conversation Info**",
                "- ID: `\(conversationID.uuidString.prefix(8))`",
                "- Title: \(summary.title)",
                "- Language: \(summary.language?.rawValue ?? "chinese")",
                "- Verbosity: \(summary.verbosity?.rawValue ?? "detailed")",
                "- Automation Level: \(summary.automationLevel?.rawValue ?? "autonomous")",
                "- Project Path: \(summary.projectPath ?? "(not set)")",
            ]

            if let providerID = summary.providerID {
                lines.append("- Provider: \(providerID)")
            }
            if let modelName = summary.modelName {
                lines.append("- Model: \(modelName)")
            }

            return lines.joined(separator: "\n")
        }
    }
}
