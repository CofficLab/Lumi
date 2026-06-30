import Foundation
import LumiCoreKit
import SuperLogKit

/// 收集子智能体结果工具
///
/// 等待指定的子智能体完成并返回结果。支持同时等待多个智能体，
/// 超时后自动取消未完成的智能体。
public struct CollectAgentsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "collect_agents",
        displayName: LumiPluginLocalization.string("Collect Agents", bundle: .module),
        description: LumiPluginLocalization.string("Wait for spawned sub-agents to complete and collect their results.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "agent_ids": .object([
                    "type": .string("string"),
                    "description": .string("Comma-separated list of agent IDs returned by spawn_agent")
                ]),
                "timeout": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum seconds to wait for each agent (default: 120, range: 1-3600)"),
                    "minimum": .int(1),
                    "maximum": .int(3600)
                ])
            ]),
            "required": .array([.string("agent_ids")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "收集子智能体结果" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let agentIdsRaw = arguments["agent_ids"]?.stringValue, !agentIdsRaw.isEmpty else {
            throw SubAgentError.missingArgument("agent_ids")
        }

        let agentIds = agentIdsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !agentIds.isEmpty else {
            return "Error: No valid agent IDs provided."
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.anyValue)

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
