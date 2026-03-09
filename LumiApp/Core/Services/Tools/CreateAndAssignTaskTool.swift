import Foundation
import MagicKit
import OSLog

/// Manager 专用工具：创建 Worker 并分配任务
struct CreateAndAssignTaskTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let verbose = true

    let name = "create_and_assign_task"
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
                    "enum": ["code_expert", "document_expert", "test_expert", "architect"],
                    "description": "Specialist type to use"
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
              let workerType = WorkerAgentType(rawValue: workerTypeRaw),
              let taskDescription = arguments["taskDescription"]?.value as? String else {
            throw NSError(
                domain: "CreateAndAssignTaskTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing required arguments: workerType/taskDescription"]
            )
        }

        let context = arguments["context"]?.value as? String
        let preferredProviderId = arguments["providerId"]?.value as? String
        let preferredModel = arguments["model"]?.value as? String

        let fullTask: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullTask = "\(taskDescription)\n\nContext:\n\(context)"
        } else {
            fullTask = taskDescription
        }

        guard let config = WorkerLLMConfigResolver.resolve(
            preferredProviderId: preferredProviderId,
            preferredModel: preferredModel
        ) else {
            throw NSError(
                domain: "CreateAndAssignTaskTool",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No available LLM API key for worker execution"]
            )
        }

        if Self.verbose {
            os_log("\(Self.t)🛠️ 创建 Worker 任务：type=\(workerType.rawValue)")
        }

        let result = try await workerAgentManager.executeTask(
            type: workerType,
            task: fullTask,
            config: config,
            toolService: toolService
        )

        return """
        [worker_result]
        workerType: \(workerType.rawValue)
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
        preferredProviderId: String?,
        preferredModel: String?
    ) -> LLMConfig? {
        let registry = ProviderRegistry()
        let providers = registry.allProviders()

        var candidateProviderIDs: [String] = []
        if let preferredProviderId, !preferredProviderId.isEmpty {
            candidateProviderIDs.append(preferredProviderId)
        }
        candidateProviderIDs.append(contentsOf: providers.map(\.id))

        var seen = Set<String>()
        for providerId in candidateProviderIDs where !seen.contains(providerId) {
            seen.insert(providerId)
            guard let providerType = registry.providerType(forId: providerId) else { continue }

            let apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
            if apiKey.isEmpty { continue }

            let storedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey)
            let model = firstNonEmpty([preferredModel, storedModel, providerType.defaultModel]) ?? providerType.defaultModel

            return LLMConfig(
                apiKey: apiKey,
                model: model,
                providerId: providerId,
                temperature: nil,
                maxTokens: nil
            )
        }

        return nil
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
