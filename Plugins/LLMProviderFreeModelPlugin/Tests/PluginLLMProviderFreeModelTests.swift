import Testing
@testable import LLMProviderFreeModelPlugin

struct PluginLLMProviderFreeModelTests {
    @Test func pluginMetadata() {
        #expect(FreeModelPlugin.id.isEmpty == false)
        #expect(FreeModelPlugin.displayName.isEmpty == false)
        #expect(FreeModelPlugin.description.isEmpty == false)
        #expect(FreeModelPlugin.iconName.isEmpty == false)
        #expect(FreeModelPlugin.category == .llmProvider)
        #expect(FreeModelPlugin.shared.llmProviderType() == FreeModelProvider.self)
    }

    @Test func providerMetadata() {
        #expect(FreeModelProvider.id.isEmpty == false)
        #expect(FreeModelProvider.displayName.isEmpty == false)
        #expect(FreeModelProvider.defaultModel.isEmpty == false)
    }
}
