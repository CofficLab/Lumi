import Foundation
import KitAgentTool

public struct BrowserInteractTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_interact"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        "Interact with a visible page element listed by browser_read. Supports click and text entry. This action requires user approval."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "action": ["type": "string", "enum": ["click", "type"]],
                "element_ref": ["type": "string", "description": "A current @lumi-N element reference from browser_read"],
                "text": ["type": "string", "description": "Text to enter when action is type"],
            ],
            "required": ["action", "element_ref"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let action = arguments["action"]?.value as? String ?? "操作"
        let element = arguments["element_ref"]?.value as? String ?? "网页元素"
        return "网页\(action)：\(element)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .high }
    public var executionCapability: ToolExecutionCapability { .interactive }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(toolName: name, reason: "Browser tools require conversation execution context.")
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.value as? String,
              let elementRef = arguments["element_ref"]?.value as? String,
              ["click", "type"].contains(action) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Provide a supported action and an element_ref from browser_read.")
        }
        let text = arguments["text"]?.value as? String
        return ToolCallResult(content: try await sessions.interact(
            action: action,
            elementRef: elementRef,
            text: text,
            conversationID: context.conversationID
        ))
    }
}
