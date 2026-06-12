import Testing
@testable import LLMProviderAiRouterPlugin

struct PluginLLMProviderAiRouterTests {
    @Test func pluginMetadata() {
        #expect(AiRouterPlugin.id.isEmpty == false)
        #expect(AiRouterPlugin.displayName.isEmpty == false)
        #expect(AiRouterPlugin.description.isEmpty == false)
        #expect(AiRouterPlugin.iconName.isEmpty == false)
        #expect(AiRouterPlugin.category == .llmProvider)
        #expect(AiRouterPlugin.shared.llmProviderType() == AiRouterProvider.self)
    }

    @Test func providerMetadata() {
        #expect(AiRouterProvider.id.isEmpty == false)
        #expect(AiRouterProvider.displayName.isEmpty == false)
        #expect(AiRouterProvider.defaultModel.isEmpty == false)
    }
}
