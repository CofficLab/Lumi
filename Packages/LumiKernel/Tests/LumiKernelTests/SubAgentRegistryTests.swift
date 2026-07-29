import Testing
@testable import LumiKernel

@Suite("Sub-agent registry")
@MainActor
struct SubAgentRegistryTests {
    @Test("Inline XML tool calls become structured Lumi calls")
    func parsesInlineToolCall() {
        let result = InlineToolCallParser.parse(
            "before <tool_call>{\"name\":\"Glob\",\"arguments\":{\"pattern\":\"**/*.swift\"}}</tool_call> after",
            availableToolNames: ["glob"]
        )
        #expect(result?.toolCalls.count == 1)
        #expect(result?.toolCalls.first?.name == "glob")
        #expect(result?.toolCalls.first?.arguments.contains("pattern") == true)
        #expect(result?.cleanedContent == "before  after")
    }

    @Test("Inline function-call XML parameters are decoded")
    func parsesInvokeToolCall() {
        let result = InlineToolCallParser.parse(
            "<function_calls><invoke name=\"read_file\"><parameter name=\"path\">/tmp/A.swift</parameter></invoke></function_calls>",
            availableToolNames: ["read_file"]
        )
        #expect(result?.toolCalls.first?.name == "read_file")
        #expect(result?.toolCalls.first?.arguments.contains("path") == true)
    }

    @Test("ToolService retains sub-agent definitions in registration order")
    func retainsDefinitions() {
        let service = ToolService()
        let first = makeDefinition(id: "first")
        let second = makeDefinition(id: "second")

        service.addSubAgent(first)
        service.addSubAgent(second)
        service.addSubAgent(first)

        #expect(service.allSubAgents().map(\.id) == ["first", "second"])
        service.removeAllSubAgents()
        #expect(service.allSubAgents().isEmpty)
    }

    @Test("ToolService allows provider-local sub-agent ids")
    func retainsProviderLocalDefinitions() {
        let service = ToolService()
        let stepfunExplore = makeDefinition(id: "explore", providerID: "stepfun")
        let openAIExplore = makeDefinition(id: "explore", providerID: "openai")

        service.addSubAgent(stepfunExplore)
        service.addSubAgent(openAIExplore)
        service.addSubAgent(stepfunExplore)

        #expect(service.allSubAgents().map(\.routingID) == ["stepfun:explore", "openai:explore"])
    }

    @Test("SubAgentRouterTool reports ambiguous provider-local ids")
    func routerReportsAmbiguousIDs() async throws {
        let definitions = [
            makeDefinition(id: "explore", providerID: "stepfun"),
            makeDefinition(id: "explore", providerID: "openai"),
        ]
        let router = SubAgentRouterTool(
            definitions: definitions,
            providerResolver: { _ in nil },
            availableTools: [],
            executionToolService: ToolService()
        )

        let output = try await router.execute(
            arguments: [
                "task": .string("Explore the project"),
                "agent_id": .string("explore"),
            ],
            kernel: LumiKernel()
        )

        #expect(output.contains("ambiguous"))
        #expect(output.contains("stepfun:explore"))
        #expect(output.contains("openai:explore"))
    }

    @Test("SubAgentRouterTool routes automatically by intent")
    func routerRoutesByIntent() async throws {
        let definitions = [
            makeDefinition(id: "review", providerID: "stepfun", displayName: "Code Review", description: "Review code for bugs and regressions"),
            makeDefinition(id: "explore", providerID: "stepfun", displayName: "Explore", description: "Read files and explore project implementation"),
        ]
        let router = SubAgentRouterTool(
            definitions: definitions,
            providerResolver: { _ in nil },
            availableTools: [],
            executionToolService: ToolService()
        )

        let output = try await router.execute(
            arguments: [
                "task": .string("Find the files that implement this feature"),
                "intent": .string("explore"),
            ],
            kernel: LumiKernel()
        )

        #expect(output.contains("Selected sub-agent: stepfun:explore"))
    }

    private func makeDefinition(id: String) -> LumiSubAgentDefinition {
        makeDefinition(id: id, providerID: "test")
    }

    private func makeDefinition(
        id: String,
        providerID: String,
        displayName: String? = nil,
        description: String = "test"
    ) -> LumiSubAgentDefinition {
        LumiSubAgentDefinition(
            id: id,
            displayName: displayName ?? id,
            description: description,
            providerID: providerID,
            modelID: "test",
            systemPrompt: "test"
        )
    }
}
