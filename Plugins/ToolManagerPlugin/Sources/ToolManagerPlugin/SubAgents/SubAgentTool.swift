import Foundation
import LumiKernel

/// Runs one of ToolManagerPlugin's built-in specialist agents in an
/// independent conversation managed by Kernel's AgentTurnManaging service.
@preconcurrency
public struct SubAgentTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "run_subagent",
        displayName: "Run Sub-Agent",
        description: "Run a focused task with a built-in specialist agent"
    )

    private let definitions: [LumiSubAgentDefinition]

    public init() {
        self.definitions = BuiltInSubAgents.definitions
    }

    public init(definitions: [LumiSubAgentDefinition]) {
        self.definitions = definitions
    }

    public var name: String { Self.info.id }

    public var toolDescription: String {
        let agents = definitions.map {
            "- \($0.id) (\($0.displayName)): \($0.description)"
        }.joined(separator: "\n")

        return """
        Run a focused task with the best built-in specialist agent. The specialist runs in an independent conversation and returns a concise result.

        Available specialists:
        \(agents)

        Provide a complete task. You may optionally provide intent or agent_id to guide selection.
        """
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("The complete task for the specialist agent.")
                ]),
                "intent": .object([
                    "type": .string("string"),
                    "description": .string("Optional hint such as explore, review, fix, or test.")
                ]),
                "agent_id": .object([
                    "type": .string("string"),
                    "description": .string("Optional exact specialist id.")
                ])
            ]),
            "required": .array([.string("task")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        try await executeResult(arguments: arguments, kernel: kernel).content
    }

    public func executeResult(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> LumiToolExecutionResult {
        try kernel.checkCancellation()
        guard let task = arguments["task"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !task.isEmpty else {
            throw SubAgentToolError.missingTask
        }

        guard let definition = selectDefinition(
            task: task,
            intent: arguments["intent"]?.stringValue,
            requestedID: arguments["agent_id"]?.stringValue
        ) else {
            throw SubAgentToolError.noMatchingAgent
        }
        let request = AgentTurnCreationRequest(
            parentConversationID: kernel.conversationID,
            title: definition.displayName,
            task: task,
            providerID: definition.inheritsSelectedProvider ? nil : definition.providerID,
            modelID: definition.inheritsSelectedProvider ? nil : definition.modelID,
            systemPrompt: definition.systemPrompt,
            excludedToolNames: [Self.info.id],
            parentTurnID: kernel.turnID
        )
        let result = try await runTurn(request: request, kernel: kernel)

        return LumiToolExecutionResult(
            content: "Selected specialist: \(definition.displayName)\n\n\(result)"
        )
    }

    @MainActor
    private func runTurn(
        request: AgentTurnCreationRequest,
        kernel: LumiKernel
    ) async throws -> String {
        guard let manager = kernel.agentTurnManager else {
            throw LumiKernelError.serviceNotAvailable(service: "AgentTurn")
        }
        let handle = try await manager.createTurn(request)
        let messages = kernel.messageManager?.messages(for: handle.conversationID) ?? []
        return messages.last(where: { $0.role == .assistant })?.content
            ?? messages.last(where: { $0.role == .error })?.content
            ?? "Sub-agent completed without a final response."
    }

    private func selectDefinition(
        task: String,
        intent: String?,
        requestedID: String?
    ) -> LumiSubAgentDefinition? {
        if let requestedID {
            let normalized = requestedID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let exact = definitions.first(where: { $0.id.lowercased() == normalized }) {
                return exact
            }
        }

        let query = ([intent, task].compactMap { $0 }.joined(separator: " ")).lowercased()
        return definitions.enumerated().max { lhs, rhs in
            score(definition: lhs.element, query: query) < score(definition: rhs.element, query: query)
        }?.element
    }

    private func score(definition: LumiSubAgentDefinition, query: String) -> Int {
        let searchable = "\(definition.id) \(definition.displayName) \(definition.description)".lowercased()
        var score = query.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .reduce(0) { partial, token in
                partial + (searchable.contains(token) ? 2 : 0)
            }

        let keywords: [(terms: [String], ids: [String])] = [
            (["explore", "find", "locate", "read", "trace", "architecture"], ["builtin-explore"]),
            (["review", "audit", "quality", "regression"], ["builtin-code-review"]),
            (["fix", "bug", "debug", "error", "crash"], ["builtin-bugfixer"]),
            (["test", "coverage", "unit", "integration"], ["builtin-test-writer"]),
        ]
        for group in keywords where group.terms.contains(where: query.contains) {
            if group.ids.contains(definition.id) { score += 10 }
        }
        return score
    }
}

private enum SubAgentToolError: Error, LocalizedError, Sendable {
    case missingTask
    case noMatchingAgent

    var errorDescription: String? {
        switch self {
        case .missingTask:
            "A non-empty task is required."
        case .noMatchingAgent:
            "No built-in specialist agent is available."
        }
    }
}
