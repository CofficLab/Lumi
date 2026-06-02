import Testing
@testable import LLMProviderHyperAPIPlugin

struct PluginLLMProviderHyperAPITests {
    @Test func pluginMetadata() {
        #expect(HyperAPIPlugin.id.isEmpty == false)
        #expect(HyperAPIPlugin.displayName.isEmpty == false)
        #expect(HyperAPIPlugin.description.isEmpty == false)
        #expect(HyperAPIPlugin.iconName.isEmpty == false)
        #expect(HyperAPIPlugin.category == .llmProvider)
        #expect(HyperAPIPlugin.shared.llmProviderType() == HyperAPIProvider.self)
    }

    @Test func providerMetadata() {
        #expect(HyperAPIProvider.id.isEmpty == false)
        #expect(HyperAPIProvider.displayName.isEmpty == false)
        #expect(HyperAPIProvider.defaultModel.isEmpty == false)
    }
}
