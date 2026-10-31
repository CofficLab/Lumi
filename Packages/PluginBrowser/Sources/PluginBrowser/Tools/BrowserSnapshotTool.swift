import Foundation
import KitAgentTool

/// 读取页面的可访问性树。
///
/// 这是 LLM 理解页面结构的主入口：输出带角色、名称、状态和 ref 的层级树，
/// 而不是一坨文本。LLM 可以据此判断「哪个是主表单」「哪个是主按钮」。
public struct BrowserSnapshotTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_snapshot"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.snapshotDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "interactive_only": [
                    "type": "boolean",
                    "description": BrowserToolText.interactiveOnlyProperty(language),
                ],
                "role": [
                    "type": "string",
                    "description": BrowserToolText.roleProperty(language),
                ],
                "name": [
                    "type": "string",
                    "description": BrowserToolText.nameProperty(language),
                ],
                "text": [
                    "type": "string",
                    "description": BrowserToolText.textFilterProperty(language),
                ],
                "limit": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 50,
                    "description": BrowserToolText.limitProperty(language),
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let hasFilter = arguments["role"]?.value != nil
            || arguments["name"]?.value != nil
            || arguments["text"]?.value != nil
        return hasFilter ? BrowserToolText.displayFind(.current) : BrowserToolText.displaySnapshot(.current)
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
        let role = arguments["role"]?.value as? String
        let name = arguments["name"]?.value as? String
        let text = arguments["text"]?.value as? String
        let limit = min(max((arguments["limit"]?.value as? Int) ?? 20, 1), 50)
        let interactiveOnly = (arguments["interactive_only"]?.value as? Bool) ?? false

        let hasFilter = role?.isEmpty == false || name?.isEmpty == false || text?.isEmpty == false

        let content: String
        if hasFilter {
            let matches = try await sessions.findElements(
                role: role?.isEmpty == true ? nil : role,
                name: name?.isEmpty == true ? nil : name,
                text: text?.isEmpty == true ? nil : text,
                limit: limit,
                conversationID: context.conversationID
            )
            content = matches.isEmpty
                ? "No element matched. Take a browser_snapshot without filters to see what is on the page."
                : matches.map { node in
                    var line = "@\(node.ref) \(node.role) \"\(node.displayName)\""
                    let flags = node.state.flags
                    if !flags.isEmpty { line += " [\(flags.joined(separator: " "))]" }
                    if let value = node.value { line += " value=\"\(value)\"" }
                    if let href = node.href { line += " → \(href)" }
                    return line
                }.joined(separator: "\n")
        } else {
            let snapshot = try await sessions.snapshot(
                interactiveOnly: interactiveOnly,
                conversationID: context.conversationID
            )
            var lines = ["# \(snapshot.pageTitle)", "URL: \(snapshot.pageURL)", ""]
            lines.append(snapshot.render(interactiveOnly: interactiveOnly))
            content = lines.joined(separator: "\n")
        }

        return ToolCallResult(content: BrowserContentBoundary.wrap(content))
    }
}
