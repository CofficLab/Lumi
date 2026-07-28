import Testing
@testable import LLMProviderOpenAIPlugin

@MainActor
struct PluginLLMProviderOpenAITests {
    @Test func pluginMetadata() {
        #expect(OpenAIPlugin().id.isEmpty == false)
        #expect(OpenAIPlugin().name.isEmpty == false)
        #expect(OpenAIPlugin().category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(OpenAIProvider.info.id.isEmpty == false)
        #expect(OpenAIProvider.info.name.isEmpty == false)
        #expect(OpenAIProvider.info.defaultModel.isEmpty == false)
    }
}
