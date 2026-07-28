import Testing
@testable import LLMProviderLPgptPlugin

@MainActor
struct PluginLLMProviderLPgptTests {
    @Test func pluginMetadata() {
        #expect(LPgptPlugin().id.isEmpty == false)
        #expect(LPgptPlugin.name.isEmpty == false)
        #expect(LPgptPlugin().category == .llmProvider)
        #expect(LPgptPlugin.shared.llmProviderType() == LPgptProvider.self)
    }

    @Test func providerMetadata() {
        #expect(LPgptProvider.id.isEmpty == false)
        #expect(LPgptProvider.name.isEmpty == false)
        #expect(LPgptProvider.defaultModel.isEmpty == false)
    }
}
