import LumiKernel
import Testing
@testable import ToolManagerPlugin

@Suite("Sub-agent registry")
@MainActor
struct SubAgentRegistryTests {
    @Test("ToolManagerService retains sub-agent definitions in registration order")
    func retainsDefinitions() {
        let service = ToolManagerService()
        let first = makeDefinition(id: "first")
        let second = makeDefinition(id: "second")

        service.addSubAgent(first)
        service.addSubAgent(second)
        service.addSubAgent(first)

        #expect(service.allSubAgents().map(\.id) == ["first", "second"])
        service.removeAllSubAgents()
        #expect(service.allSubAgents().isEmpty)
    }

    @Test("ToolManagerService allows provider-local sub-agent ids")
    func retainsProviderLocalDefinitions() {
        let service = ToolManagerService()
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
            executionToolService: ToolManagerService()
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
            executionToolService: ToolManagerService()
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
