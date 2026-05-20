import Foundation
import MagicKit
import LLMKit

/// 创建子智能体工具
///
/// 创建一个在后台运行的子智能体，使用指定的 LLM 供应商和模型。
/// 返回 agent_id 用于后续 collect_agents 收集结果。
///
/// 典型用法：主 Agent 在一次响应中并行调用多次 spawn_agent，
/// 然后调用 collect_agents 一次性收集所有结果。
struct SpawnAgentTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🚀"
    nonisolated static let verbose: Bool = false

    let name = "spawn_agent"

    // MARK: - Dependencies

    private let llmService: LLMService
    private let llmVM: AppLLMVM
    private let toolService: ToolService

    init(llmService: LLMService, llmVM: AppLLMVM, toolService: ToolService) {
        self.llmService = llmService
        self.llmVM = llmVM
        self.toolService = toolService
    }

    // MARK: - SuperAgentTool

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return String(localized: "Spawn a new sub-agent that runs in the background. Returns an agent_id to collect results later.", table: "MultiAgent")
        case .english:
            return String(localized: "Spawn a new sub-agent that runs in the background. Returns an agent_id to collect results later.", table: "MultiAgent")
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let taskDesc: String
        let providerIdDesc: String
        let modelIdDesc: String
        let descriptionDesc: String

        switch language {
        case .chinese:
            taskDesc = "子智能体需要执行的任务描述"
            providerIdDesc = "LLM 供应商 ID（如 openai、anthropic、deepseek、zhipu、aliyun）"
            modelIdDesc = "模型 ID（如 gpt-4o、claude-sonnet-4-20250514、deepseek-chat）"
            descriptionDesc = "关于此智能体任务的简短描述（3-5 个词）"
        case .english:
            taskDesc = "The task description for the sub-agent to perform"
            providerIdDesc = "LLM provider ID (e.g., openai, anthropic, deepseek, zhipu, aliyun)"
            modelIdDesc = "Model ID (e.g., gpt-4o, claude-sonnet-4-20250514, deepseek-chat)"
            descriptionDesc = "A short 3-5 word description of what this agent will do"
        }

        return [
            "type": "object",
            "properties": [
                "task": [
                    "type": "string",
                    "description": taskDesc,
                ],
                "provider_id": [
                    "type": "string",
                    "description": providerIdDesc,
                ],
                "model_id": [
                    "type": "string",
                    "description": modelIdDesc,
                ],
                "description": [
                    "type": "string",
                    "description": descriptionDesc,
                ],
            ],
            "required": ["task", "provider_id", "model_id", "description"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let task = arguments["task"]?.value as? String, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }

        guard let providerId = (arguments["provider_id"]?.value as? String), !providerId.isEmpty else {
            throw SubAgentError.missingArgument("provider_id")
        }

        guard let modelId = (arguments["model_id"]?.value as? String), !modelId.isEmpty else {
            throw SubAgentError.missingArgument("model_id")
        }

        guard let description = (arguments["description"]?.value as? String), !description.isEmpty else {
            throw SubAgentError.missingArgument("description")
        }

        // 验证供应商和模型
        let allProviders = llmVM.allProviders
        guard let provider = allProviders.first(where: { $0.id == providerId }) else {
            let registeredIds = allProviders.map(\.id).joined(separator: ", ")
            return "Error: Provider '\(providerId)' not found. Available providers: \(registeredIds)"
        }

        guard provider.availableModels.contains(modelId) else {
            return "Error: Model '\(modelId)' not found in provider '\(providerId)'. Available models: \(provider.availableModels.joined(separator: ", "))"
        }

        // 获取 API Key
        let apiKey = llmVM.getApiKey(for: providerId)
        guard !apiKey.isEmpty else {
            return "Error: API key not configured for provider '\(providerId)'. Please configure it in Settings first."
        }

        // 创建子智能体
        let runner = SubAgentRunner.shared
        let agentId: String
        do {
            agentId = try await runner.spawn(
                task: task,
                description: description,
                providerId: providerId,
                modelId: modelId,
                llmService: llmService,
                apiKey: apiKey,
                toolService: toolService
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

    @MainActor
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await execute(arguments: arguments)
    }
}
