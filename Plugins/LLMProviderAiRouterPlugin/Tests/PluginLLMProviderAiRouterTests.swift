import Testing
@testable import LLMProviderAiRouterPlugin

@MainActor
struct PluginLLMProviderAiRouterTests {
    @Test func pluginMetadata() {
        #expect(AiRouterPlugin().id.isEmpty == false)
        #expect(AiRouterPlugin.name.isEmpty == false)
        #expect(AiRouterPlugin().category == .llmProvider)
        #expect(AiRouterPlugin.shared.llmProviderType() == AiRouterProvider.self)
    }

    @Test func providerMetadata() {
        #expect(AiRouterProvider.id.isEmpty == false)
        #expect(AiRouterProvider.name.isEmpty == false)
        #expect(AiRouterProvider.defaultModel.isEmpty == false)
    }
}
