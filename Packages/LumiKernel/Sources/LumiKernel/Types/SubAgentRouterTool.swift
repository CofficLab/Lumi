@preconcurrency import Foundation

public struct SubAgentRouterTool: LumiAgentTool, @unchecked Sendable {
    public static let info = LumiAgentToolInfo(
        id: "delegate_task",
        displayName: "Delegate Task",
        description: "Delegate a task to the best registered sub-agent"
    )

    private let definitions: [LumiSubAgentDefinition]
    private let providerResolver: @MainActor @Sendable (String) -> (any LumiLLMProvider)?
    private let availableTools: [any LumiAgentTool]
    private let executionToolService: any ToolManaging

    public init(
        definitions: [LumiSubAgentDefinition],
        providerResolver: @escaping @MainActor @Sendable (String) -> (any LumiLLMProvider)?,
        availableTools: [any LumiAgentTool],
        executionToolService: any ToolManaging
    ) {
        self.definitions = definitions
        self.providerResolver = providerResolver
        self.availableTools = availableTools
        self.executionToolService = executionToolService
    }

    public var name: String { Self.info.id }

    public var toolDescription: String {
        let agentList = definitions.map { definition in
            "- \(definition.routingID) (\(definition.displayName)): \(definition.description)"
        }.joined(separator: "\n")

        return """
        Delegate a self-contained task to the best registered sub-agent. Use this before manually chaining low-level file/search/git/build tools for exploration, code review, debugging, testing, documentation, commit drafting, or build verification.

        Available sub-agents:
        \(agentList)

        Provide the task and optionally an intent or agent_id. Omit agent_id when you want Lumi to route automatically.
        """
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string(
                        "A natural-language description of the delegated task, including goal, scope, and constraints."
                    )
                ]),
                "intent": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Optional routing hint, such as explore, review, fix, test, docs, commit, build, or auto."
                    )
                ]),
                "agent_id": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Optional exact sub-agent routing id, such as provider:id. Omit this for automatic routing."
                    )
                ])
            ]),
            "required": .array([.string("task")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        try kernel.checkCancellation()
        guard let task = arguments["task"]?.stringValue, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }
        guard !definitions.isEmpty else {
            return "Error: No sub-agents are registered."
        }

        let intent = arguments["intent"]?.stringValue
        let requestedAgentID = arguments["agent_id"]?.stringValue
        let selection = selectDefinition(
            task: task,
            intent: intent,
            requestedAgentID: requestedAgentID
        )

        switch selection {
        case .selected(let definition):
            let delegate = SubAgentDelegateTool(
                definition: definition,
                providerResolver: providerResolver,
                availableTools: availableTools,
                executionToolService: executionToolService
            )
            let output = try await delegate.execute(
                arguments: ["task": .string(task)],
                kernel: kernel
            )
            return """
            Selected sub-agent: \(definition.routingID) (\(definition.displayName))

            \(output)
            """
        case .failed(let message):
            return message
        }
    }

    private enum Selection {
        case selected(LumiSubAgentDefinition)
        case failed(String)
    }

    private func selectDefinition(
        task: String,
        intent: String?,
        requestedAgentID: String?
    ) -> Selection {
        if let requestedAgentID, !requestedAgentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectRequestedDefinition(requestedAgentID)
        }

        let query = ([intent, task].compactMap { $0 }.joined(separator: " ")).lowercased()
        let scored = definitions.enumerated().map { index, definition in
            (
                index: index,
                score: score(definition: definition, query: query, intent: intent),
                definition: definition
            )
        }
        let best = scored.max { lhs, rhs in
            if lhs.score == rhs.score { return lhs.index > rhs.index }
            return lhs.score < rhs.score
        }
        guard let best else {
            return .failed("Error: No sub-agents are registered.")
        }
        return .selected(best.definition)
    }

    private func selectRequestedDefinition(_ requestedAgentID: String) -> Selection {
        let normalized = requestedAgentID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let exact = definitions.first(where: { $0.routingID.lowercased() == normalized }) {
            return .selected(exact)
        }

        let idMatches = definitions.filter { $0.id.lowercased() == normalized }
        if idMatches.count == 1, let match = idMatches.first {
            return .selected(match)
        }
        if idMatches.count > 1 {
            let candidates = idMatches.map(\.routingID).joined(separator: ", ")
            return .failed("Error: Sub-agent id '\(requestedAgentID)' is ambiguous. Use one of: \(candidates).")
        }

        if let displayName = definitions.first(where: { $0.displayName.lowercased() == normalized }) {
            return .selected(displayName)
        }

        let candidates = definitions.map(\.routingID).joined(separator: ", ")
        return .failed("Error: Sub-agent '\(requestedAgentID)' was not found. Available sub-agents: \(candidates).")
    }

    private func score(
        definition: LumiSubAgentDefinition,
        query: String,
        intent: String?
    ) -> Int {
        let searchable = [
            definition.id,
            definition.displayName,
            definition.description,
        ].joined(separator: " ").lowercased()

        var score = 0
        let tokens = tokenize(query)
        for token in tokens where searchable.contains(token) {
            score += 2
        }

        let normalizedIntent = intent?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedIntent, !normalizedIntent.isEmpty, normalizedIntent != "auto" {
            if definition.id.lowercased().contains(normalizedIntent) {
                score += 20
            }
            if definition.displayName.lowercased().contains(normalizedIntent) {
                score += 12
            }
            if definition.description.lowercased().contains(normalizedIntent) {
                score += 6
            }
        }

        score += keywordScore(definition: definition, query: query)
        return score
    }

    private func keywordScore(definition: LumiSubAgentDefinition, query: String) -> Int {
        let id = definition.id.lowercased()
        let displayName = definition.displayName.lowercased()
        let name = "\(id) \(displayName)"

        let groups: [(keywords: [String], agents: [String], weight: Int)] = [
            (["explore", "investigate", "find", "locate", "read", "trace", "understand", "architecture", "how implemented"], ["explore"], 10),
            (["review", "audit", "risk", "regression"], ["review"], 10),
            (["fix", "bug", "debug", "error", "failure", "crash"], ["fix", "bug"], 10),
            (["test", "coverage", "unit", "integration"], ["test"], 10),
            (["doc", "docs", "documentation", "readme"], ["doc", "writer"], 10),
            (["commit", "message", "changelog"], ["commit"], 10),
            (["build", "compile", "xcode", "verify", "rust", "cargo", "go", "golang", "maven", "gradle", "npm", "yarn", "pnpm", "cmake", "make", "dotnet", "elixir", "swiftpm", "swift package"], ["build", "xcode"], 10),
        ]

        var score = 0
        for group in groups {
            let queryMatches = group.keywords.contains { query.contains($0) }
            let agentMatches = group.agents.contains { name.contains($0) }
            if queryMatches && agentMatches {
                score += group.weight
            }
        }
        return score
    }

    private func tokenize(_ value: String) -> [String] {
        value
            .split { !$0.isLetter && !$0.isNumber }
            .map { String($0).lowercased() }
            .filter { $0.count >= 3 }
    }
}
