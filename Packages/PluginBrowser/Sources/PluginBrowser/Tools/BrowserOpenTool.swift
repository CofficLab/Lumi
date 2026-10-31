import Foundation
import KitAgentTool

public struct BrowserOpenTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_open"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.openDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": BrowserToolText.urlArgumentProperty(language),
                ],
            ],
            "required": ["url"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        BrowserToolText.displayOpen(.current)
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
        // 审批发生在工具执行**之前**：本地地址的风险等级是 .high，
        // 用户批准后才会走到这里。因此此刻 `requiresLocalAccessApproval`
        // 为真就意味着「用户已经批准了访问这个本地地址」。
        let approvedForLocalAccess = BrowserSessionManager.requiresLocalAccessApproval(url)
        return ToolCallResult(content: try await sessions.open(
            url,
            conversationID: context.conversationID,
            localAccessApproved: approvedForLocalAccess
        ))
    }
}
