import Testing
@testable import LLMProviderXiaomiPlugin

struct PluginLLMProviderXiaomiTests {
    @Test func pluginMetadata() {
        #expect(XiaomiPlugin.info.id.isEmpty == false)
        #expect(XiaomiPlugin.info.displayName.isEmpty == false)
        #expect(XiaomiPlugin.info.description.isEmpty == false)
        #expect(XiaomiPlugin.iconName.isEmpty == false)
        #expect(XiaomiPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(XiaomiProvider.info.id == "xiaomi")
        #expect(XiaomiProvider.info.displayName.isEmpty == false)
        #expect(XiaomiProvider.info.defaultModel.isEmpty == false)
    }

    @Test func apiProviderMetadata() {
        #expect(XiaomiAPIProvider.info.id == "xiaomi-api")
        #expect(XiaomiAPIProvider.info.displayName.isEmpty == false)
        #expect(XiaomiAPIProvider.info.defaultModel.isEmpty == false)
    }

    @Test func providersUseDistinctAPIKeyStorage() {
        // TokenPlan 与小米 API 是独立服务，API Key 必须分开存储
        #expect(XiaomiProvider.apiKeyStorageKey != XiaomiAPIProvider.apiKeyStorageKey)
    }
}
