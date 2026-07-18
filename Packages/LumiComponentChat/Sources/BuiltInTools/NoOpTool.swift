import Foundation
import LumiComponentMessage
import LumiComponentAgentTool

/// A no-operation tool that returns a simple message without any side effects.
///
/// Useful when the agent needs to acknowledge a request without performing
/// external actions, or as a fallback for debugging.
struct NoOpTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "noop",
        displayName: "No Operation",
        description: "A no-operation tool that returns a simple confirmation without any side effects. Use it to acknowledge a simple request or for debugging."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "message": .object([
                    "type": .string("string"),
                    "description": .string("Optional message to echo back (default: \"No-op completed successfully.\")"),
                ]),
            ]),
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let message: String
        if case .string(let value) = arguments["message"] {
            message = value
        } else {
            message = "No-op completed successfully."
        }
        return "✅ \(message)"
    }
}
