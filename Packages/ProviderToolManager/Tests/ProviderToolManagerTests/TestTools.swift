import AgentToolKit
import Foundation

/// 测试用最小工具：返回固定内容，可配置风险等级与执行失败。
struct MockTool: SuperAgentTool {
    let name: String
    let risk: CommandRiskLevel
    let displayName: String
    let failWith: String?

    init(
        name: String,
        risk: CommandRiskLevel = .low,
        displayName: String? = nil,
        failWith: String? = nil
    ) {
        self.name = name
        self.risk = risk
        self.displayName = displayName ?? name
        self.failWith = failWith
    }

    func description(for language: LanguagePreference) -> String {
        "Mock tool \(name)"
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object"]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        risk
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let path = arguments["path"]?.value as? String {
            return "\(displayName) \(path)"
        }
        return displayName
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        if let failWith {
            throw ToolExecutionError.executionFailed(toolName: name, reason: failWith)
        }
        if let path = arguments["path"]?.value as? String {
            return "read \(path)"
        }
        return "ok: \(name)"
    }
}

/// 便捷构造一次 `ToolCall`。
func makeToolCall(
    name: String,
    arguments: [String: Any] = [:],
    id: String = UUID().uuidString
) -> ToolCall {
    let data = try! JSONSerialization.data(withJSONObject: arguments)
    return ToolCall(
        id: id,
        name: name,
        arguments: String(data: data, encoding: .utf8) ?? "{}"
    )
}
