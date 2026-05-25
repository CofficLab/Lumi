import Foundation
import AgentToolKit
import LLMKit
import LumiCoreKit

actor SubAgentScheduler: SuperLog {
    nonisolated static let emoji = "🧩"
    static let shared = SubAgentScheduler()

    private var definitions: [String: any SubAgentDefinitionProtocol] = [:]
    private var activeTasks: [String: KernelSubAgentTask] = [:]
    private let maxConcurrency = 5

    private init() {}

    func registerDefinitions(_ definitions: [any SubAgentDefinitionProtocol]) {
        var next: [String: any SubAgentDefinitionProtocol] = [:]
        for definition in definitions {
            next[definition.id] = definition
        }
        self.definitions = next
    }

    func listDefinitions() -> [any SubAgentDefinitionProtocol] {
        definitions.values.sorted { $0.id < $1.id }
    }

    func spawn(
        type: String,
        instruction: String?,
        config: LLMConfig,
        llmService: LLMService,
        toolService: ToolService
    ) throws -> KernelSubAgentTask {
        let runningCount = activeTasks.values.filter { $0.status == .running }.count
        guard runningCount < maxConcurrency else {
            throw KernelSubAgentError.concurrentLimit(maxConcurrency)
        }

        guard let definition = definitions[type] else {
            throw KernelSubAgentError.definitionNotFound(type)
        }

        let task = KernelSubAgentTask(
            id: UUID().uuidString,
            type: type,
            name: definition.name
        )
        activeTasks[task.id] = task

        task.handle = Task { [weak self] in
            guard let self else { return }
            let result = await self.runLoop(
                taskId: task.id,
                definition: definition,
                instruction: instruction,
                config: config,
                llmService: llmService,
                toolService: toolService
            )
            await self.finish(taskId: task.id, result: result)
        }

        return task
    }

    func collect(taskIds: [String], timeout: TimeInterval = 120) async -> [KernelSubAgentResult] {
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            let allDone = taskIds.allSatisfy { id in
                guard let task = activeTasks[id] else { return true }
                return task.status != .running
            }
            if allDone { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        var results: [KernelSubAgentResult] = []

        for taskId in taskIds {
            guard let task = activeTasks[taskId] else {
                results.append(KernelSubAgentResult(
                    taskId: taskId,
                    type: "",
                    name: "Unknown Sub-Agent",
                    status: .failed,
                    fields: [:],
                    rawOutput: "",
                    error: "Sub-agent task not found: \(taskId)",
                    duration: 0
                ))
                continue
            }

            if let result = task.result {
                results.append(result)
            } else if task.status == .running {
                task.handle?.cancel()
                task.status = .cancelled
                let duration = Date().timeIntervalSince(task.createdAt)
                let result = KernelSubAgentResult(
                    taskId: task.id,
                    type: task.type,
                    name: task.name,
                    status: .cancelled,
                    fields: [:],
                    rawOutput: "",
                    error: "Sub-agent timed out after \(Int(timeout))s",
                    duration: duration
                )
                task.result = result
                results.append(result)
            }
        }

        for taskId in taskIds {
            activeTasks.removeValue(forKey: taskId)
        }

        return results
    }

    private func finish(taskId: String, result: KernelSubAgentResult) {
        guard let task = activeTasks[taskId] else { return }
        task.status = result.status
        task.result = result
    }

    private func runLoop(
        taskId: String,
        definition: any SubAgentDefinitionProtocol,
        instruction: String?,
        config: LLMConfig,
        llmService: LLMService,
        toolService: ToolService
    ) async -> KernelSubAgentResult {
        let startedAt = Date()
        let conversationId = UUID()
        let allowedToolNames = Set(definition.allowedToolNames)
        let availableTools = toolService.tools.filter { allowedToolNames.contains($0.name) }
        let toolsArg: [SuperAgentTool]? = availableTools.isEmpty ? nil : availableTools

        var messages: [ChatMessage] = [
            ChatMessage(
                role: .system,
                conversationId: conversationId,
                content: Self.systemPrompt(for: definition)
            ),
            ChatMessage(
                role: .user,
                conversationId: conversationId,
                content: instruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? instruction!
                    : definition.description
            ),
        ]

        var lastOutput = ""

        for _ in 0 ..< max(1, definition.maxTurns) {
            if Task.isCancelled {
                return makeResult(
                    taskId: taskId,
                    definition: definition,
                    status: .cancelled,
                    fields: [:],
                    rawOutput: lastOutput,
                    error: "Sub-agent was cancelled",
                    duration: Date().timeIntervalSince(startedAt)
                )
            }

            let response: ChatMessage
            do {
                response = try await llmService.sendMessage(
                    messages: messages,
                    config: config,
                    tools: toolsArg
                )
            } catch {
                return makeResult(
                    taskId: taskId,
                    definition: definition,
                    status: .failed,
                    fields: [:],
                    rawOutput: lastOutput,
                    error: error.localizedDescription,
                    duration: Date().timeIntervalSince(startedAt)
                )
            }

            messages.append(response)
            lastOutput = response.content

            guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
                return makeFinalResult(
                    taskId: taskId,
                    definition: definition,
                    output: response.content,
                    duration: Date().timeIntervalSince(startedAt)
                )
            }

            for toolCall in toolCalls {
                if !allowedToolNames.contains(toolCall.name) {
                    let toolResult = "Tool not allowed for sub-agent type \(definition.id): \(toolCall.name)"
                    messages.append(ChatMessage(
                        role: .tool,
                        conversationId: conversationId,
                        content: toolResult,
                        toolCallID: toolCall.id
                    ))
                    continue
                }

                let toolContext = ToolExecutionContext(
                    conversationId: conversationId,
                    toolCallId: toolCall.id,
                    toolName: toolCall.name
                )

                let toolResult: String
                do {
                    try toolContext.checkCancellation()
                    toolResult = try await toolService.executeTool(
                        named: toolCall.name,
                        argumentsJSON: toolCall.arguments,
                        context: toolContext
                    )
                } catch {
                    toolResult = "Tool error: \(error.localizedDescription)"
                }

                messages.append(ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: toolResult,
                    toolCallID: toolCall.id
                ))
            }
        }

        return makeResult(
            taskId: taskId,
            definition: definition,
            status: .failed,
            fields: [:],
            rawOutput: lastOutput,
            error: "Sub-agent reached maximum turns (\(definition.maxTurns))",
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    private static func systemPrompt(for definition: any SubAgentDefinitionProtocol) -> String {
        """
        \(definition.systemPrompt)

        When the task is finished, respond with only one JSON object and no markdown.
        The JSON object must include a string field named "status" with value "success" or "failure".
        Include these fields when available: \(definition.resultTemplate.fields.map(\.rawValue).joined(separator: ", ")).
        Use null or an empty string for fields that do not apply.
        """
    }

    private func makeFinalResult(
        taskId: String,
        definition: any SubAgentDefinitionProtocol,
        output: String,
        duration: Double
    ) -> KernelSubAgentResult {
        let fields = Self.parseJSONFields(from: output)
        let declaredStatus = fields["status"]?.lowercased()
        let error = fields["error"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failed = declaredStatus == "failure" || declaredStatus == "failed" || error?.isEmpty == false

        return makeResult(
            taskId: taskId,
            definition: definition,
            status: failed ? .failed : .completed,
            fields: fields,
            rawOutput: output,
            error: failed ? (error?.isEmpty == false ? error : "Sub-agent reported failure") : nil,
            duration: duration
        )
    }

    private func makeResult(
        taskId: String,
        definition: any SubAgentDefinitionProtocol,
        status: KernelSubAgentStatus,
        fields: [String: String],
        rawOutput: String,
        error: String?,
        duration: Double
    ) -> KernelSubAgentResult {
        var nextFields = fields
        nextFields["duration"] = String(format: "%.1f", duration)
        if let error, nextFields["error"] == nil {
            nextFields["error"] = error
        }

        return KernelSubAgentResult(
            taskId: taskId,
            type: definition.id,
            name: definition.name,
            status: status,
            fields: nextFields,
            rawOutput: rawOutput,
            error: error,
            duration: duration
        )
    }

    private static func parseJSONFields(from output: String) -> [String: String] {
        let candidate = extractJSONObjectString(from: output)
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["output": output]
        }

        return object.reduce(into: [String: String]()) { result, pair in
            switch pair.value {
            case is NSNull:
                result[pair.key] = ""
            case let value as String:
                result[pair.key] = value
            case let value as CustomStringConvertible:
                result[pair.key] = value.description
            default:
                result[pair.key] = "\(pair.value)"
            }
        }
    }

    private static func extractJSONObjectString(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start <= end {
            return String(trimmed[start ... end])
        }

        return trimmed
    }
}

enum KernelSubAgentError: Error, LocalizedError {
    case concurrentLimit(Int)
    case definitionNotFound(String)
    case missingArgument(String)
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .concurrentLimit(let max):
            return "Maximum concurrent sub-agents reached (\(max))."
        case .definitionNotFound(let type):
            return "Sub-agent type not found: \(type)"
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .modelUnavailable:
            return "No valid LLM provider/model is configured for sub-agents."
        }
    }
}
