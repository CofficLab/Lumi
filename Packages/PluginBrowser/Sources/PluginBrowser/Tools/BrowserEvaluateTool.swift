import Foundation
import KitAgentTool

/// 在页面上下文执行 JavaScript。
///
/// 作为兜底能力存在：真实网页千变万化，任何一组固定工具都覆盖不全。
/// 给 LLM 一个 escape hatch，比让它在「工具做不到」时卡死强。
public struct BrowserEvaluateTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_evaluate"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.evaluateDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "script": [
                    "type": "string",
                    "description": BrowserToolText.scriptProperty(language),
                ],
            ],
            "required": ["script"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        BrowserToolText.displayEvaluate(.current)
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }
    public var executionCapability: ToolExecutionCapability { .serialSideEffect }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(toolName: name, reason: "Browser tools require conversation execution context.")
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let script = arguments["script"]?.value as? String,
              !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing script")
        }
        let result = try await sessions.evaluate(
            script: script,
            conversationID: context.conversationID
        )
        return ToolCallResult(content: BrowserContentBoundary.wrap(result))
    }
}
