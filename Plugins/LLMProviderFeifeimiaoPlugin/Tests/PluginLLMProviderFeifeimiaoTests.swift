import Testing
@testable import LLMProviderFeifeimiaoPlugin

@MainActor
struct PluginLLMProviderFeifeimiaoTests {
    @Test func pluginMetadata() {
        #expect(FeifeimiaoPlugin().id.isEmpty == false)
        #expect(FeifeimiaoPlugin.name.isEmpty == false)
        #expect(FeifeimiaoPlugin().category == .llmProvider)
        #expect(FeifeimiaoPlugin.shared.llmProviderType() == FeifeimiaoProvider.self)
    }

    @Test func providerMetadata() {
        #expect(FeifeimiaoProvider.id.isEmpty == false)
        #expect(FeifeimiaoProvider.name.isEmpty == false)
        #expect(FeifeimiaoProvider.defaultModel.isEmpty == false)
    }
}
