import Testing
@testable import LLMProviderOpenAIPlugin

struct PluginLLMProviderOpenAITests {
    @Test func pluginMetadata() {
        #expect(OpenAIPlugin.info.id.isEmpty == false)
        #expect(OpenAIPlugin.info.displayName.isEmpty == false)
        #expect(OpenAIPlugin.info.description.isEmpty == false)
        #expect(OpenAIPlugin.iconName.isEmpty == false)
        #expect(OpenAIPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(OpenAIProvider.info.id.isEmpty == false)
        #expect(OpenAIProvider.info.displayName.isEmpty == false)
        #expect(OpenAIProvider.info.defaultModel.isEmpty == false)
    }
}
