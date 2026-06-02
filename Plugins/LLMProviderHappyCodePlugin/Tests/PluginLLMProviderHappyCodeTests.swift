import Testing
@testable import LLMProviderHappyCodePlugin

struct PluginLLMProviderHappyCodeTests {
    @Test func pluginMetadata() {
        #expect(HappyCodePlugin.id.isEmpty == false)
        #expect(HappyCodePlugin.displayName.isEmpty == false)
        #expect(HappyCodePlugin.description.isEmpty == false)
        #expect(HappyCodePlugin.iconName.isEmpty == false)
        #expect(HappyCodePlugin.category == .llmProvider)
        #expect(HappyCodePlugin.shared.llmProviderType() == HappyCodeProvider.self)
    }

    @Test func providerMetadata() {
        #expect(HappyCodeProvider.id.isEmpty == false)
        #expect(HappyCodeProvider.displayName.isEmpty == false)
        #expect(HappyCodeProvider.defaultModel.isEmpty == false)
    }
}
