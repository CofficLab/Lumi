import Testing
@testable import PluginLLMProviderAnthropic

struct PluginLLMProviderAnthropicTests {
    @Test func pluginMetadata() {
        #expect(AnthropicPlugin.id.isEmpty == false)
        #expect(AnthropicPlugin.displayName.isEmpty == false)
        #expect(AnthropicPlugin.description.isEmpty == false)
        #expect(AnthropicPlugin.iconName.isEmpty == false)
        #expect(AnthropicPlugin.category == .llmProvider)
        #expect(AnthropicPlugin.shared.llmProviderType() == AnthropicProvider.self)
    }

    @Test func providerMetadata() {
        #expect(AnthropicProvider.id.isEmpty == false)
        #expect(AnthropicProvider.displayName.isEmpty == false)
        #expect(AnthropicProvider.defaultModel.isEmpty == false)
    }
}
