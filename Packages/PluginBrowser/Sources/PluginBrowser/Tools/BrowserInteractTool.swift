import Foundation
import KitAgentTool

/// 与页面元素交互。
///
/// 动作集合覆盖 LLM 在真实网页上需要做的事：点击、双击、填入、逐字输入、
/// 下拉选择、勾选、按键、悬停、滚动、聚焦。
public struct BrowserInteractTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_interact"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.interactDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": BrowserInteractionAction.allCases.map(\.rawValue),
                    "description": BrowserToolText.actionProperty(language),
                ],
                "element_ref": [
                    "type": "string",
                    "description": BrowserToolText.elementRefProperty(language),
                ],
                "text": [
                    "type": "string",
                    "description": BrowserToolText.textProperty(language),
                ],
            ],
            "required": ["action"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let rawAction = arguments["action"]?.value as? String ?? ""
        let element = arguments["element_ref"]?.value as? String
        guard let action = BrowserInteractionAction(rawValue: rawAction) else {
            return "网页操作：\(rawAction)"
        }
        switch action {
        case .scroll:
            let direction = arguments["text"]?.value as? String ?? ""
            return "滚动网页\(direction.isEmpty ? "" : "（\(direction)）")"
        case .fill, .type:
            let text = arguments["text"]?.value as? String ?? ""
            return "网页\(action.displayName)：\(element ?? "元素") → \(text)"
        case .select:
            let text = arguments["text"]?.value as? String ?? ""
            return "网页选择：\(element ?? "下拉框") → \(text)"
        case .press:
            let key = arguments["text"]?.value as? String ?? ""
            return "网页按键：\(key)"
        default:
            return "网页\(action.displayName)：\(element ?? "元素")"
        }
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
        guard let rawAction = arguments["action"]?.value as? String,
              let action = BrowserInteractionAction(rawValue: rawAction) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Provide a supported action: "
                    + BrowserInteractionAction.allCases.map(\.rawValue).joined(separator: ", ")
                    + "."
            )
        }
        let elementRef = arguments["element_ref"]?.value as? String
        if action.requiresElement && (elementRef?.isEmpty ?? true) {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "The \(action.rawValue) action needs an element_ref from browser_snapshot."
            )
        }
        let text = arguments["text"]?.value as? String
        if action.requiresText && (text?.isEmpty ?? true) {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "The \(action.rawValue) action needs a text argument."
            )
        }
        return ToolCallResult(content: try await sessions.interact(
            action: action,
            elementRef: elementRef,
            text: text,
            conversationID: context.conversationID
        ))
    }
}
