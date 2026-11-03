import Foundation
import KitAgentTool

/// 等待页面满足某个条件。
///
/// 存在的意义是消除 LLM 的「盲猜 sleep」。异步渲染的页面用固定等待去猜，
/// 要么白等一段时间，要么等得不够然后读到半成品页面。
public struct BrowserWaitTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_wait"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.waitDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "condition": [
                    "type": "string",
                    "enum": BrowserWaitCondition.allCases.map(\.rawValue),
                    "description": BrowserToolText.conditionProperty(language),
                ],
                "value": [
                    "type": "string",
                    "description": BrowserToolText.waitValueProperty(language),
                ],
                "timeout": [
                    "type": "number",
                    "minimum": 0.5,
                    "maximum": 60,
                    "description": BrowserToolText.timeoutProperty(language),
                ],
            ],
            "required": ["condition"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let condition = arguments["condition"]?.value as? String ?? "condition"
        let value = arguments["value"]?.value as? String
        if let value, !value.isEmpty {
            return pluginLocalization.string("等待网页\(condition)：\(value)", for: .current)
        }
        return pluginLocalization.string("等待网页\(condition)", for: .current)
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
        guard let rawCondition = arguments["condition"]?.value as? String,
              let condition = BrowserWaitCondition(rawValue: rawCondition) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Provide a condition: "
                    + BrowserWaitCondition.allCases.map(\.rawValue).joined(separator: ", ")
                    + "."
            )
        }
        let value = arguments["value"]?.value as? String
        if (condition == .selector || condition == .text) && (value?.isEmpty ?? true) {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "The \(condition.rawValue) condition needs a value (a CSS selector or the text to wait for)."
            )
        }
        let timeout = (arguments["timeout"]?.value as? Double) ?? 10

        let detail = try await sessions.wait(
            condition: condition,
            value: value,
            timeout: timeout,
            conversationID: context.conversationID
        )
        return ToolCallResult(content: "Condition met: \(detail). Take a browser_snapshot to see the current state.")
    }
}
