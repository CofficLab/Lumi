import Testing
@testable import LLMProviderLPgptPlugin

struct PluginLLMProviderLPgptTests {
    @Test func pluginMetadata() {
        #expect(LPgptPlugin.id.isEmpty == false)
        #expect(LPgptPlugin.displayName.isEmpty == false)
        #expect(LPgptPlugin.description.isEmpty == false)
        #expect(LPgptPlugin.iconName.isEmpty == false)
        #expect(LPgptPlugin.category == .llmProvider)
        #expect(LPgptPlugin.shared.llmProviderType() == LPgptProvider.self)
    }

    @Test func providerMetadata() {
        #expect(LPgptProvider.id.isEmpty == false)
        #expect(LPgptProvider.displayName.isEmpty == false)
        #expect(LPgptProvider.defaultModel.isEmpty == false)
    }
}
