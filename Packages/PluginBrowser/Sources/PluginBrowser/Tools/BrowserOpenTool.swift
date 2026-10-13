import Foundation
import KitAgentTool

public struct BrowserOpenTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_open"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        "Open an HTTP or HTTPS page in Lumi's visible browser workspace. The page is isolated to the current conversation."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": ["url": ["type": "string", "description": "The HTTP or HTTPS URL to open"]],
            "required": ["url"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "打开网页"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let url = arguments["url"]?.value as? String else { return .high }
        return BrowserSessionManager.requiresLocalAccessApproval(url) ? .high : .low
    }
    public var executionCapability: ToolExecutionCapability { .serialSideEffect }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(toolName: name, reason: "Browser tools require conversation execution context.")
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let url = arguments["url"]?.value as? String else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing url")
        }
        return ToolCallResult(content: try await sessions.open(
            url,
            conversationID: context.conversationID,
            allowLocalAccess: BrowserSessionManager.requiresLocalAccessApproval(url)
        ))
    }
}
