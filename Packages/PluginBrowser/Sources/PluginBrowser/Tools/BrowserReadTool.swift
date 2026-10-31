import Foundation
import KitAgentTool

public struct BrowserReadTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_read"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.readDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "max_characters": [
                    "type": "integer",
                    "minimum": 500,
                    "maximum": 20000,
                    "description": BrowserToolText.maxCharactersProperty(language),
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        BrowserToolText.displayRead(.current)
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
        let requested = (arguments["max_characters"]?.value as? Int) ?? 12_000
        let content = try await sessions.read(
            conversationID: context.conversationID,
            maxCharacters: min(max(requested, 500), 20_000)
        )
        return ToolCallResult(content: BrowserContentBoundary.wrap(content))
    }
}
