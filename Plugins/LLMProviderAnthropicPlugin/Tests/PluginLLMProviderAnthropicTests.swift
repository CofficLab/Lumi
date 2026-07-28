import Testing
@testable import LLMProviderAnthropicPlugin

@MainActor
struct PluginLLMProviderAnthropicTests {
    @Test func pluginMetadata() {
        #expect(AnthropicPlugin().id.isEmpty == false)
        #expect(AnthropicPlugin.name.isEmpty == false)
        #expect(AnthropicPlugin().category == .llmProvider)
        #expect(AnthropicPlugin.shared.llmProviderType() == AnthropicProvider.self)
    }

    @Test func providerMetadata() {
        #expect(AnthropicProvider.id.isEmpty == false)
        #expect(AnthropicProvider.name.isEmpty == false)
        #expect(AnthropicProvider.defaultModel.isEmpty == false)
    }
}
