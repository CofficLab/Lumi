import Foundation
import KitAgentTool

/// 导航：后退、前进、刷新、跳转。
public struct BrowserNavigateTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_navigate"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.navigateDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": BrowserNavigationAction.allCases.map(\.rawValue),
                    "description": BrowserToolText.navigationActionProperty(language),
                ],
                "url": [
                    "type": "string",
                    "description": BrowserToolText.urlProperty(language),
                ],
            ],
            "required": ["action"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let rawAction = arguments["action"]?.value as? String ?? ""
        guard let action = BrowserNavigationAction(rawValue: rawAction) else {
            return "网页导航：\(rawAction)"
        }
        if action == .goto, let url = arguments["url"]?.value as? String {
            return pluginLocalization.string("跳转网页：\(url)", for: .current)
        }
        return pluginLocalization.string("网页\(action.displayName)", for: .current)
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard arguments["action"]?.value as? String == BrowserNavigationAction.goto.rawValue,
              let url = arguments["url"]?.value as? String else {
            return .low
        }
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
        guard let rawAction = arguments["action"]?.value as? String,
              let action = BrowserNavigationAction(rawValue: rawAction) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Provide a navigation action: "
                    + BrowserNavigationAction.allCases.map(\.rawValue).joined(separator: ", ")
                    + "."
            )
        }
        let url = arguments["url"]?.value as? String
        if action == .goto && (url?.isEmpty ?? true) {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "The goto action needs a url.")
        }
        let content = try await sessions.navigate(
            action: action,
            url: url,
            conversationID: context.conversationID
        )
        return ToolCallResult(content: content)
    }
}
