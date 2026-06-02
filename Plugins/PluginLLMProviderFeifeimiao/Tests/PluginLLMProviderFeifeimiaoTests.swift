import Testing
@testable import PluginLLMProviderFeifeimiao

struct PluginLLMProviderFeifeimiaoTests {
    @Test func pluginMetadata() {
        #expect(FeifeimiaoPlugin.id.isEmpty == false)
        #expect(FeifeimiaoPlugin.displayName.isEmpty == false)
        #expect(FeifeimiaoPlugin.description.isEmpty == false)
        #expect(FeifeimiaoPlugin.iconName.isEmpty == false)
        #expect(FeifeimiaoPlugin.category == .llmProvider)
        #expect(FeifeimiaoPlugin.shared.llmProviderType() == FeifeimiaoProvider.self)
    }

    @Test func providerMetadata() {
        #expect(FeifeimiaoProvider.id.isEmpty == false)
        #expect(FeifeimiaoProvider.displayName.isEmpty == false)
        #expect(FeifeimiaoProvider.defaultModel.isEmpty == false)
    }
}
