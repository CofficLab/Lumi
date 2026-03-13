import Foundation
import MagicKit
import OSLog

/// Manager 专用工具：创建 Worker 并分配任务
struct CreateAndAssignTaskTool: AgentTool, SuperLog {
    nonisolated static let verbose = true

    /// 工具名称静态常量
    nonisolated static let toolName = "create_and_assign_task"

    let name = Self.toolName
    let description = """
    Create a specialized worker agent and assign a concrete task.
    Use this when the task benefits from a specialist:
    - code_expert: code analysis/refactor/optimization
    - document_expert: documentation and explanations
    - test_expert: tests and quality checks
    - architect: system design and architecture review
    """

    private let workerAgentManager: WorkerAgentManager
    private let toolService: ToolService

    init(workerAgentManager: WorkerAgentManager, toolService: ToolService) {
        self.workerAgentManager = workerAgentManager
        self.toolService = toolService
    }

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "workerType": [
                    "type": "string",
                    "description": "Specialist type id to use (provided by plugins)"
                ],
                "taskDescription": [
                    "type": "string",
                    "description": "Detailed task that the worker should execute"
                ],
                "context": [
                    "type": "string",
                    "description": "Optional extra context (paths, constraints, references)"
                ],
                "providerId": [
                    "type": "string",
                    "description": "Optional LLM provider id override"
                ],
                "model": [
                    "type": "string",
                    "description": "Optional model override"
                ],
            ],
            "required": ["workerType", "taskDescription"],
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let workerTypeRaw = arguments["workerType"]?.value as? String,
              let taskDescription = arguments["taskDescription"]?.value as? String else {
            throw NSError(
                domain: "CreateAndAssignTaskTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing required arguments: workerType/taskDescription"]
            )
        }

        let context = arguments["context"]?.value as? String
        let managerProviderId = arguments["providerId"]?.value as? String
        let preferredModel = arguments["model"]?.value as? String

        let fullTask: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullTask = "\(taskDescription)\n\nContext:\n\(context)"
        } else {
            fullTask = taskDescription
        }

        guard let config = WorkerLLMConfigResolver.resolve(
            managerProviderId: managerProviderId,
            preferredModel: preferredModel
        ) else {
            throw NSError(
                domain: "CreateAndAssignTaskTool",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No available LLM API key for manager provider"]
            )
        }

        if Self.verbose {
            os_log("\(Self.t)🛠️ 创建 Worker 任务：type=\(workerTypeRaw)")
        }

        let result = try await workerAgentManager.executeTask(
            typeId: workerTypeRaw,
            task: fullTask,
            config: config,
            toolService: toolService
        )

        return """
        [worker_result]
        workerType: \(workerTypeRaw)
        taskDescription: \(taskDescription)
        model: \(config.providerId)/\(config.model)
        result:
        \(result)
        [/worker_result]
        """
    }
}

private enum WorkerLLMConfigResolver {
    static func resolve(
        managerProviderId: String?,
        preferredModel: String?
    ) -> LLMConfig? {
        guard let managerProviderId, !managerProviderId.isEmpty else {
            return nil
        }

        let registry = ProviderRegistry()
        guard let providerType = registry.providerType(forId: managerProviderId) else {
            return nil
        }

        let apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
        if apiKey.isEmpty {
            return nil
        }

        let storedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey)
        let model = firstNonEmpty([preferredModel, storedModel, providerType.defaultModel]) ?? providerType.defaultModel

        return LLMConfig(
            apiKey: apiKey,
            model: model,
            providerId: managerProviderId
        )
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let v = value, !v.isEmpty {
                return v
            }
        }
        return nil
    }
}

