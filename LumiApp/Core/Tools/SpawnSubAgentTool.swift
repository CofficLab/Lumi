import Foundation
import AgentToolKit
import LLMKit

struct SpawnSubAgentTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🚀"

    let name = "spawn_subagent"

    private let llmService: LLMService
    private let llmVM: AppLLMVM
    private let toolService: ToolService

    init(llmService: LLMService, llmVM: AppLLMVM, toolService: ToolService) {
        self.llmService = llmService
        self.llmVM = llmVM
        self.toolService = toolService
    }

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "启动一个预定义类型的内核级子 Agent，在隔离上下文中执行任务。返回 task_id，稍后可用 collect_subagent 收集结果。"
        case .english:
            return "Start a predefined kernel sub-agent in an isolated context. Returns a task_id that can be collected later with collect_subagent."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let typeDesc: String
        let instructionDesc: String

        switch language {
        case .chinese:
            typeDesc = "子 Agent 类型 ID，例如 git.commit"
            instructionDesc = "给子 Agent 的补充指令，可选"
        case .english:
            typeDesc = "Sub-agent type ID, for example git.commit"
            instructionDesc = "Optional additional instruction for the sub-agent"
        }

        return [
            "type": "object",
            "properties": [
                "type": [
                    "type": "string",
                    "description": typeDesc,
                ],
                "instruction": [
                    "type": "string",
                    "description": instructionDesc,
                ],
            ],
            "required": ["type"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    @MainActor
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let type = arguments["type"]?.value as? String, !type.isEmpty else {
            throw KernelSubAgentError.missingArgument("type")
        }

        let instruction = arguments["instruction"]?.value as? String
        guard let config = llmVM.makeConfig(providerId: llmVM.selectedProviderId, model: llmVM.currentModel) else {
            throw KernelSubAgentError.modelUnavailable
        }

        let task = try await SubAgentScheduler.shared.spawn(
            type: type,
            instruction: instruction,
            config: config,
            llmService: llmService,
            toolService: toolService
        )

        return """
        Sub-agent spawned successfully.

        - task_id: \(task.id)
        - type: \(task.type)
        - name: \(task.name)

        Use `collect_subagent` with this task_id to get the result.
        """
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String? {
        guard let type = arguments["type"]?.value as? String, !type.isEmpty else {
            return nil
        }
        return "启动子 Agent \(type)"
    }
}
