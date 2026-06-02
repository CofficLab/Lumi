import Testing
@testable import PluginLLMProviderDeepSeek

struct PluginLLMProviderDeepSeekTests {
    @Test func pluginMetadata() {
        #expect(DeepSeekPlugin.id.isEmpty == false)
        #expect(DeepSeekPlugin.displayName.isEmpty == false)
        #expect(DeepSeekPlugin.description.isEmpty == false)
        #expect(DeepSeekPlugin.iconName.isEmpty == false)
        #expect(DeepSeekPlugin.category == .llmProvider)
        #expect(DeepSeekPlugin.shared.llmProviderType() == DeepSeekProvider.self)
    }

    @Test func providerMetadata() {
        #expect(DeepSeekProvider.id.isEmpty == false)
        #expect(DeepSeekProvider.displayName.isEmpty == false)
        #expect(DeepSeekProvider.defaultModel.isEmpty == false)
    }
}
