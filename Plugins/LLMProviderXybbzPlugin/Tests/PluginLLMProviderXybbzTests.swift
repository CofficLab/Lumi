import Testing
@testable import LLMProviderXybbzPlugin

@MainActor
struct PluginLLMProviderXybbzTests {
    @Test func pluginMetadata() {
        #expect(XybbzPlugin().id.isEmpty == false)
        #expect(XybbzPlugin.name.isEmpty == false)
        #expect(XybbzPlugin().category == .llmProvider)
        #expect(XybbzPlugin.shared.llmProviderType() == XybbzProvider.self)
    }

    @Test func providerMetadata() {
        #expect(XybbzProvider.id.isEmpty == false)
        #expect(XybbzProvider.name.isEmpty == false)
        #expect(XybbzProvider.defaultModel.isEmpty == false)
    }
}
