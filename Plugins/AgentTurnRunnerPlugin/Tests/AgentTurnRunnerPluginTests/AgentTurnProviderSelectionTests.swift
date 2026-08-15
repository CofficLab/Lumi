import Testing
@testable import AgentTurnRunnerPlugin

@Suite("Agent turn provider/model isolation")
struct AgentTurnProviderSelectionTests {
    @Test("Conversation binding wins over another conversation's global selection")
    func conversationBindingWins() {
        let selection = AgentTurnProviderSelection.resolve(
            conversationProviderID: "opencode-go",
            conversationModel: "kimi-k3",
            selectedProviderID: "opencode-go",
            selectedModel: "grok-4.5",
            availableProviderIDs: ["opencode-go"],
            fallbackProviderID: "fallback"
        )

        #expect(selection.providerID == "opencode-go")
        #expect(selection.model == "kimi-k3")
    }

    @Test("Global selection is only used when conversation provider is unavailable")
    func globalSelectionIsFallback() {
        let selection = AgentTurnProviderSelection.resolve(
            conversationProviderID: "removed-provider",
            conversationModel: "removed-model",
            selectedProviderID: "available-provider",
            selectedModel: "available-model",
            availableProviderIDs: ["available-provider"],
            fallbackProviderID: "fallback"
        )

        #expect(selection.providerID == "available-provider")
        #expect(selection.model == "available-model")
    }

    @Test("First registered provider is the final fallback")
    func firstProviderFallback() {
        let selection = AgentTurnProviderSelection.resolve(
            conversationProviderID: nil,
            conversationModel: nil,
            selectedProviderID: nil,
            selectedModel: nil,
            availableProviderIDs: ["fallback"],
            fallbackProviderID: "fallback"
        )

        #expect(selection == AgentTurnProviderSelection(providerID: "fallback", model: nil))
    }
}
