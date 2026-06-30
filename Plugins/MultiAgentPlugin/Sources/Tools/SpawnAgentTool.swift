import Foundation
import LumiCoreKit
import SuperLogKit

/// 创建子智能体工具。
public struct SpawnAgentTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🚀"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "spawn_agent",
        displayName: LumiPluginLocalization.string("Spawn Agent", bundle: .module),
        description: LumiPluginLocalization.string("Spawn a new sub-agent that runs in the background. Returns an agent_id to collect results later.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("The task description for the sub-agent to perform")
                ]),
                "provider_id": .object([
                    "type": .string("string"),
                    "description": .string("LLM provider ID (e.g., openai, anthropic, deepseek, zhipu, aliyun)")
                ]),
                "model_id": .object([
                    "type": .string("string"),
                    "description": .string("Model ID (e.g., gpt-4o, claude-sonnet-4-20250514, deepseek-chat)")
                ]),
                "description": .object([
                    "type": .string("string"),
                    "description": .string("A short 3-5 word description of what this agent will do")
                ])
            ]),
            "required": .array([.string("task"), .string("provider_id"), .string("model_id"), .string("description")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "启动子智能体" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let task = arguments["task"]?.stringValue, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }

        guard let providerId = arguments["provider_id"]?.stringValue, !providerId.isEmpty else {
            throw SubAgentError.missingArgument("provider_id")
        }

        guard let modelId = arguments["model_id"]?.stringValue, !modelId.isEmpty else {
            throw SubAgentError.missingArgument("model_id")
        }

        guard let description = arguments["description"]?.stringValue, !description.isEmpty else {
            throw SubAgentError.missingArgument("description")
        }

        let runner = SubAgentRunner.shared
        let agentId: String
        do {
            agentId = try await runner.spawn(
                task: task,
                description: description,
                providerId: providerId,
                modelId: modelId
            )
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        if Self.verbose {
            MultiAgentPlugin.logger.info("\(self.t)子智能体已启动：\(agentId.prefix(8)) (\(providerId)/\(modelId))")
        }

        return """
            Agent spawned successfully.

            - agent_id: \(agentId)
            - provider: \(providerId)
            - model: \(modelId)
            - description: \(description)

            The agent is now running in the background. Use `collect_agents` with this agent_id to get the result when it finishes. You can spawn more agents and then collect them all at once.
            """
    }
}
