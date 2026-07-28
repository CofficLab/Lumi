import Testing
@testable import LLMProviderOpenRouterPlugin

@MainActor
struct PluginLLMProviderOpenRouterTests {
    @Test func pluginMetadata() {
        #expect(OpenRouterPlugin().id.isEmpty == false)
        #expect(OpenRouterPlugin.name.isEmpty == false)
        #expect(OpenRouterPlugin().category == .llmProvider)
        #expect(OpenRouterPlugin.shared.llmProviderType() == OpenRouterProvider.self)
    }

    @Test func providerMetadata() {
        #expect(OpenRouterProvider.id.isEmpty == false)
        #expect(OpenRouterProvider.name.isEmpty == false)
        #expect(OpenRouterProvider.defaultModel.isEmpty == false)
    }
}
