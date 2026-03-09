import Foundation
import MagicKit
import OSLog

/// Worker 执行服务
///
/// 负责 Worker 的多轮 LLM 调用与工具调用处理。
actor WorkerAgentService: SuperLog {
    nonisolated static let emoji = "👷"
    nonisolated static let verbose = true

    private let llmService: any WorkerLLMServiceProtocol
    private let toolService: any WorkerToolServiceProtocol
    private let maxDepth = 10

    init(llmService: any WorkerLLMServiceProtocol, toolService: any WorkerToolServiceProtocol) {
        self.llmService = llmService
        self.toolService = toolService
    }

    func execute(worker: WorkerAgent, task: String) async throws -> String {
        var messages: [ChatMessage] = [
            ChatMessage(role: .system, content: worker.systemPrompt),
            ChatMessage(role: .user, content: task),
        ]

        var depth = 0
        while depth < maxDepth {
            let availableTools = workerTools()
            let response = try await llmService.sendMessage(
                messages: messages,
                config: worker.config,
                tools: availableTools.isEmpty ? nil : availableTools
            )

            messages.append(response)

            guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
                let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? "Task completed with no textual output." : content
            }

            for toolCall in toolCalls {
                let toolResult = try await executeToolCall(toolCall)
                messages.append(ChatMessage(
                    role: .user,
                    content: toolResult,
                    toolCallID: toolCall.id
                ))
            }
            depth += 1
        }

        throw WorkerError.maxDepthReached(maxDepth: maxDepth)
    }

    private func workerTools() -> [AgentTool] {
        toolService.tools.filter { $0.name != "create_and_assign_task" }
    }

    private func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        if toolService.requiresPermission(toolName: toolCall.name, argumentsJSON: toolCall.arguments) {
            return "Error: Tool '\(toolCall.name)' requires user approval and is not allowed in worker background execution."
        }

        return try await toolService.executeTool(
            named: toolCall.name,
            argumentsJSON: toolCall.arguments
        )
    }
}

enum WorkerError: LocalizedError {
    case maxDepthReached(maxDepth: Int)

    var errorDescription: String? {
        switch self {
        case .maxDepthReached(let maxDepth):
            return "Worker reached max tool-call depth (\(maxDepth))."
        }
    }
}
