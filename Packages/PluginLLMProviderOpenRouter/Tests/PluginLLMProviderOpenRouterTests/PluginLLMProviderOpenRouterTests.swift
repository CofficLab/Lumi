import Testing
@testable import PluginLLMProviderOpenRouter

struct PluginLLMProviderOpenRouterTests {
    @Test func pluginMetadata() {
        #expect(OpenRouterPlugin.id.isEmpty == false)
        #expect(OpenRouterPlugin.displayName.isEmpty == false)
        #expect(OpenRouterPlugin.description.isEmpty == false)
        #expect(OpenRouterPlugin.iconName.isEmpty == false)
        #expect(OpenRouterPlugin.category == .llmProvider)
        #expect(OpenRouterPlugin.shared.llmProviderType() == OpenRouterProvider.self)
    }

    @Test func providerMetadata() {
        #expect(OpenRouterProvider.id.isEmpty == false)
        #expect(OpenRouterProvider.displayName.isEmpty == false)
        #expect(OpenRouterProvider.defaultModel.isEmpty == false)
    }
}
