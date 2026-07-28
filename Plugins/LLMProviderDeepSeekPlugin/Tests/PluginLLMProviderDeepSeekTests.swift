import Testing
@testable import LLMProviderDeepSeekPlugin

@MainActor
struct PluginLLMProviderDeepSeekTests {
    @Test func pluginMetadata() {
        #expect(DeepSeekPlugin().id.isEmpty == false)
        #expect(DeepSeekPlugin.name.isEmpty == false)
        #expect(DeepSeekPlugin().category == .llmProvider)
        #expect(DeepSeekPlugin.shared.llmProviderType() == DeepSeekProvider.self)
    }

    @Test func providerMetadata() {
        #expect(DeepSeekProvider.id.isEmpty == false)
        #expect(DeepSeekProvider.name.isEmpty == false)
        #expect(DeepSeekProvider.defaultModel.isEmpty == false)
    }
}
