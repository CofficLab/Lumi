import Testing
@testable import PluginLLMProviderMegaLLM

struct PluginLLMProviderMegaLLMTests {
    @Test func pluginMetadata() {
        #expect(MegaLLMPlugin.id.isEmpty == false)
        #expect(MegaLLMPlugin.displayName.isEmpty == false)
        #expect(MegaLLMPlugin.description.isEmpty == false)
        #expect(MegaLLMPlugin.iconName.isEmpty == false)
        #expect(MegaLLMPlugin.category == .llmProvider)
        #expect(MegaLLMPlugin.shared.llmProviderType() == MegaLLMProvider.self)
    }

    @Test func providerMetadata() {
        #expect(MegaLLMProvider.id.isEmpty == false)
        #expect(MegaLLMProvider.displayName.isEmpty == false)
        #expect(MegaLLMProvider.defaultModel.isEmpty == false)
    }
}
