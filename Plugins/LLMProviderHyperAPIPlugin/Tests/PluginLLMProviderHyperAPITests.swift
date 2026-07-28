import Testing
@testable import LLMProviderHyperAPIPlugin

@MainActor
struct PluginLLMProviderHyperAPITests {
    @Test func pluginMetadata() {
        #expect(HyperAPIPlugin().id.isEmpty == false)
        #expect(HyperAPIPlugin.name.isEmpty == false)
        #expect(HyperAPIPlugin().category == .llmProvider)
        #expect(HyperAPIPlugin.shared.llmProviderType() == HyperAPIProvider.self)
    }

    @Test func providerMetadata() {
        #expect(HyperAPIProvider.id.isEmpty == false)
        #expect(HyperAPIProvider.name.isEmpty == false)
        #expect(HyperAPIProvider.defaultModel.isEmpty == false)
    }
}
