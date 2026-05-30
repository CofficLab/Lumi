import Testing
@testable import PluginLLMProviderOpenAI

struct PluginLLMProviderOpenAITests {
    @Test func pluginMetadata() {
        #expect(OpenAIPlugin.id.isEmpty == false)
        #expect(OpenAIPlugin.displayName.isEmpty == false)
        #expect(OpenAIPlugin.description.isEmpty == false)
        #expect(OpenAIPlugin.iconName.isEmpty == false)
        #expect(OpenAIPlugin.category == .llmProvider)
        #expect(OpenAIPlugin.shared.llmProviderType() == OpenAIProvider.self)
    }

    @Test func providerMetadata() {
        #expect(OpenAIProvider.id.isEmpty == false)
        #expect(OpenAIProvider.displayName.isEmpty == false)
        #expect(OpenAIProvider.defaultModel.isEmpty == false)
    }
}
