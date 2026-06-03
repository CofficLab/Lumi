import Foundation
import SuperLogKit
import AgentToolKit

/// 收集子智能体结果工具
///
/// 等待指定的子智能体完成并返回结果。支持同时等待多个智能体，
/// 超时后自动取消未完成的智能体。
public struct CollectAgentsTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = true

    public let name = "collect_agents"

    // MARK: - SuperAgentTool

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return String(localized: "Wait for spawned sub-agents to complete and collect their results.", bundle: .module)
        case .english:
            return String(localized: "Wait for spawned sub-agents to complete and collect their results.", bundle: .module)
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let agentIdsDesc: String
        let timeoutDesc: String

        switch language {
        case .chinese:
            agentIdsDesc = String(localized: "Comma-separated list of agent IDs returned by spawn_agent", bundle: .module)
            timeoutDesc = String(localized: "Maximum seconds to wait for each agent (default: 120, range: 1-3600)", bundle: .module)
        case .english:
            agentIdsDesc = String(localized: "Comma-separated list of agent IDs returned by spawn_agent", bundle: .module)
            timeoutDesc = String(localized: "Maximum seconds to wait for each agent (default: 120, range: 1-3600)", bundle: .module)
        }

        return [
            "type": "object",
            "properties": [
                "agent_ids": [
                    "type": "string",
                    "description": agentIdsDesc,
                ],
                "timeout": [
                    "type": "integer",
                    "description": timeoutDesc,
                    "minimum": 1,
                    "maximum": 3600,
                ],
            ],
            "required": ["agent_ids"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "收集子智能体结果"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let agentIdsRaw = arguments["agent_ids"]?.value as? String, !agentIdsRaw.isEmpty else {
            throw SubAgentError.missingArgument("agent_ids")
        }

        let agentIds = agentIdsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !agentIds.isEmpty else {
            return "Error: No valid agent IDs provided."
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.value)

        if Self.verbose {
            MultiAgentPlugin.logger.info("\(self.t)等待 \(agentIds.count) 个子智能体完成（超时: \(Int(timeout))s）")
        }

        let runner = SubAgentRunner.shared
        let results = await runner.collect(agentIds: agentIds, timeout: timeout)

        // 格式化输出
        var output = "# Agent Results\n\n"

        for result in results {
            let statusIcon: String
            switch result.status {
            case .completed: statusIcon = "✅"
            case .failed: statusIcon = "❌"
            case .cancelled: statusIcon = "⏹️"
            case .running: statusIcon = "⏳"
            }

            output += "## \(statusIcon) Agent `\(result.agentId.prefix(8))`\n"
            output += "- **Provider**: \(result.providerId)\n"
            output += "- **Model**: \(result.modelId)\n"
            output += "- **Status**: \(result.status.rawValue)\n"
            output += "- **Duration**: \(String(format: "%.1f", result.duration))s\n"
            output += "\n"
            output += result.result
            output += "\n\n---\n\n"
        }

        let completedCount = results.filter { $0.status == .completed }.count
        output += "**Summary**: \(completedCount)/\(results.count) agents completed successfully."

        return output
    }

    static func normalizedTimeout(_ value: Any?) -> TimeInterval {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = 120
        }

        return TimeInterval(min(max(requested, 1), 3600))
    }
}
