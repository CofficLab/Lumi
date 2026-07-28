import Testing
@testable import LLMProviderHappyCodePlugin

@MainActor
struct PluginLLMProviderHappyCodeTests {
    @Test func pluginMetadata() {
        #expect(HappyCodePlugin().id.isEmpty == false)
        #expect(HappyCodePlugin.name.isEmpty == false)
        #expect(HappyCodePlugin().category == .llmProvider)
        #expect(HappyCodePlugin.shared.llmProviderType() == HappyCodeProvider.self)
    }

    @Test func providerMetadata() {
        #expect(HappyCodeProvider.id.isEmpty == false)
        #expect(HappyCodeProvider.name.isEmpty == false)
        #expect(HappyCodeProvider.defaultModel.isEmpty == false)
    }
}
