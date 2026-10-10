import Foundation
import KitAgentTool

public struct BrowserStatusTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_status"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        "Get the current URL and title of the browser page in this conversation. Lightweight — does not read page content."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看当前网页地址"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(toolName: name, reason: "Browser tools require conversation execution context.")
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let content = await sessions.status(conversationID: context.conversationID) else {
            throw BrowserSession.SessionError.noPage
        }
        return ToolCallResult(content: content)
    }
}
