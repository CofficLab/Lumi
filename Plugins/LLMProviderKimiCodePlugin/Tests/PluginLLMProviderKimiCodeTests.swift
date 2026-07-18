import Testing
@testable import LLMProviderKimiCodePlugin

struct PluginLLMProviderKimiCodeTests {
    @Test func pluginMetadata() {
        #expect(KimiCodePlugin.id.isEmpty == false)
        #expect(KimiCodePlugin.displayName.isEmpty == false)
        #expect(KimiCodePlugin.description.isEmpty == false)
        #expect(KimiCodePlugin.iconName.isEmpty == false)
        #expect(KimiCodePlugin.category == .llmProvider)
    }

    @Test func openAIProviderMetadata() {
        #expect(KimiCodeOpenAIProvider.id == "kimi-code-openai")
        #expect(KimiCodeOpenAIProvider.defaultModel == "k3")
        #expect(KimiCodeOpenAIProvider.availableModels.contains("kimi-for-coding"))
        #expect(KimiCodeOpenAIProvider.availableModels.contains("kimi-for-coding-highspeed"))
    }

    @Test func anthropicProviderMetadata() {
        #expect(KimiCodeAnthropicProvider.id == "kimi-code-anthropic")
        #expect(KimiCodeAnthropicProvider.defaultModel == "k3")
        #expect(KimiCodeAnthropicProvider.availableModels.contains("kimi-for-coding"))
        #expect(KimiCodeAnthropicProvider.availableModels.contains("kimi-for-coding-highspeed"))
    }

    @Test func sharedAPIKeyStorageKey() {
        // Both providers should share the same API key storage key
        #expect(KimiCodeOpenAIProvider.info._apiKeyStorageKey == "DevAssistant_ApiKey_KimiCode")
        #expect(KimiCodeAnthropicProvider.info._apiKeyStorageKey == "DevAssistant_ApiKey_KimiCode")
    }
}