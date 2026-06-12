import Testing
@testable import LLMProviderXiaomiPlugin

struct PluginLLMProviderXiaomiTests {
    @Test func pluginMetadata() {
        #expect(XiaomiPlugin.id.isEmpty == false)
        #expect(XiaomiPlugin.displayName.isEmpty == false)
        #expect(XiaomiPlugin.description.isEmpty == false)
        #expect(XiaomiPlugin.iconName.isEmpty == false)
        #expect(XiaomiPlugin.category == .llmProvider)
        #expect(XiaomiPlugin.shared.llmProviderType() == XiaomiProvider.self)
    }

    @Test func providerMetadata() {
        #expect(XiaomiProvider.id.isEmpty == false)
        #expect(XiaomiProvider.displayName.isEmpty == false)
        #expect(XiaomiProvider.defaultModel.isEmpty == false)
    }
}
