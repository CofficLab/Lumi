import Testing
@testable import PluginLLMProviderXybbz

struct PluginLLMProviderXybbzTests {
    @Test func pluginMetadata() {
        #expect(XybbzPlugin.id.isEmpty == false)
        #expect(XybbzPlugin.displayName.isEmpty == false)
        #expect(XybbzPlugin.description.isEmpty == false)
        #expect(XybbzPlugin.iconName.isEmpty == false)
        #expect(XybbzPlugin.category == .llmProvider)
        #expect(XybbzPlugin.shared.llmProviderType() == XybbzProvider.self)
    }

    @Test func providerMetadata() {
        #expect(XybbzProvider.id.isEmpty == false)
        #expect(XybbzProvider.displayName.isEmpty == false)
        #expect(XybbzProvider.defaultModel.isEmpty == false)
    }
}
