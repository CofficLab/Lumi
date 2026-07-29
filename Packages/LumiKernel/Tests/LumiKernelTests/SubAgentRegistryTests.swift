import Testing
@testable import LumiKernel

@Suite("Sub-agent registry")
@MainActor
struct SubAgentRegistryTests {
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

    private func makeDefinition(id: String) -> LumiSubAgentDefinition {
        LumiSubAgentDefinition(
            id: id,
            displayName: id,
            description: "test",
            providerID: "test",
            modelID: "test",
            systemPrompt: "test"
        )
    }
}
