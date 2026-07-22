@preconcurrency import Foundation

public struct SubAgentDelegateTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "delegate_subagent",
        displayName: "Delegate Sub-Agent",
        description: "Delegate a task to a registered sub-agent"
    )

    private let definition: LumiSubAgentDefinition
    private let providerResolver: @MainActor @Sendable (String) -> (any LumiLLMProvider)?
    private let availableTools: [any LumiAgentTool]
    private let executionToolService: any LumiToolServicing

    public init(
        definition: LumiSubAgentDefinition,
        providerResolver: @escaping @MainActor @Sendable (String) -> (any LumiLLMProvider)?,
        availableTools: [any LumiAgentTool],
        executionToolService: any LumiToolServicing
    ) {
        self.definition = definition
        self.providerResolver = providerResolver
        self.availableTools = availableTools
        self.executionToolService = executionToolService
    }

    public var name: String { "delegate_\(definition.id)" }
    public var toolDescription: String { definition.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string(
                        "A natural-language description of WHAT to do and WHY. " +
                        "The sub-agent is a specialist that will autonomously plan and execute " +
                        "the task using its own toolset. Be specific about the goal and any constraints."
                    )
                ])
            ]),
            "required": .array([.string("task")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        try context.checkCancellation()
        guard let task = arguments["task"]?.stringValue, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }
        guard let provider = providerResolver(definition.providerID) else {
            return "Error: Provider '\(definition.providerID)' not available for sub-agent '\(definition.id)'."
        }
        let tools = resolveTools()
        let runner = SubAgentLoopRunner()
        let result = await runner.run(
            provider: provider,
            model: definition.modelID,
            systemPrompt: definition.systemPrompt,
            task: task,
            tools: tools,
            toolService: executionToolService,
            conversationID: context.conversationID,
            maxTurns: definition.maxTurns
        )
        return formatResult(result)
    }

    @MainActor
    private func resolveTools() -> [any LumiAgentTool] {
        let allTools = availableTools
        if definition.requiredTags.contains(.all) { return allTools }
        var filtered = allTools
        if !definition.requiredTags.isEmpty {
            filtered = filtered.filter { tool in
                tool.tags.contains(where: { definition.requiredTags.contains($0) })
            }
        }
        if !definition.excludedTags.isEmpty {
            filtered = filtered.filter { tool in
                !tool.tags.contains(where: { definition.excludedTags.contains($0) })
            }
        }
        if !definition.excludedToolNames.isEmpty {
            filtered = filtered.filter { tool in
                !definition.excludedToolNames.contains(tool.name)
            }
        }
        if !definition.additionalToolNames.isEmpty {
            let additionalSet = Set(definition.additionalToolNames)
            let existingNames = Set(filtered.map(\.name))
            let missing = allTools.filter {
                additionalSet.contains($0.name) && !existingNames.contains($0.name)
            }
            filtered.append(contentsOf: missing)
        }
        return filtered
    }

    private func formatResult(_ result: SubAgentLoopResult) -> String {
        switch result.status {
        case .completed: return result.content
        case .failed: return "Error: \(result.error ?? "Unknown error")"
        case .maxTurnsReached: return "Max turns reached. Result: \(result.content)"
        }
    }
}

public enum SubAgentError: Error, Sendable {
    case missingArgument(String)
}

public struct SubAgentLoopResult: Sendable {
    public enum Status: Sendable {
        case completed
        case failed
        case maxTurnsReached
    }
    public let content: String
    public let status: Status
    public let duration: Double
    public let error: String?

    public init(content: String, status: Status, duration: Double, error: String? = nil) {
        self.content = content
        self.status = status
        self.duration = duration
        self.error = error
    }
}

public struct SubAgentLoopRunner {
    public init() {}

    @MainActor
    public func run(
        provider: any LumiLLMProvider,
        model: String,
        systemPrompt: String,
        task: String,
        tools: [any LumiAgentTool],
        toolService: any LumiToolServicing,
        conversationID: UUID,
        maxTurns: Int = 10
    ) async -> SubAgentLoopResult {
        let start = Date()
        var messages: [LumiChatMessage] = [
            LumiChatMessage(conversationID: conversationID, role: .system, content: systemPrompt),
            LumiChatMessage(conversationID: conversationID, role: .user, content: task)
        ]

        for _ in 0..<maxTurns {
            try? Task.checkCancellation()
            let request = LumiLLMRequest(messages: messages, model: model, tools: tools)
            var assistant: LumiChatMessage
            do {
                assistant = try await provider.sendStreaming(request) { _ in }
            } catch {
                return SubAgentLoopResult(
                    content: error.localizedDescription,
                    status: .failed,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription
                )
            }

            if assistant.hasInlineToolCallInBody {
                let nudge = LumiChatMessage(
                    conversationID: conversationID,
                    role: .system,
                    content: "Note: Your previous response wrote tool calls as text in the body instead of using the structured tool-call interface.",
                    metadata: ["lumi-nudge": "inline-tool-call-retry"]
                )
                let retriedRequest = LumiLLMRequest(messages: messages + [assistant, nudge], model: model, tools: tools)
                do {
                    assistant = try await provider.sendStreaming(retriedRequest) { _ in }
                } catch {}
            }

            messages.append(assistant)

            guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
                return SubAgentLoopResult(
                    content: assistant.content,
                    status: .completed,
                    duration: Date().timeIntervalSince(start)
                )
            }

            for toolCall in toolCalls {
                try? Task.checkCancellation()
                let result = await toolService.execute(toolCall, conversationID: conversationID)
                messages.append(LumiChatMessage(
                    conversationID: conversationID,
                    role: .tool,
                    content: result.content,
                    toolCallID: toolCall.id
                ))
            }
        }

        let lastAssistant = messages.last(where: { $0.role == .assistant })
        return SubAgentLoopResult(
            content: lastAssistant?.content ?? "",
            status: .maxTurnsReached,
            duration: Date().timeIntervalSince(start)
        )
    }
}
