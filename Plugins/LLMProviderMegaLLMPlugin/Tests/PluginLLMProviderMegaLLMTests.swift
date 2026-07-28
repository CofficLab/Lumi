import Testing
@testable import LLMProviderMegaLLMPlugin

@MainActor
struct PluginLLMProviderMegaLLMTests {
    @Test func pluginMetadata() {
        #expect(MegaLLMPlugin().id.isEmpty == false)
        #expect(MegaLLMPlugin.name.isEmpty == false)
        #expect(MegaLLMPlugin().category == .llmProvider)
        #expect(MegaLLMPlugin.shared.llmProviderType() == MegaLLMProvider.self)
    }

    @Test func providerMetadata() {
        #expect(MegaLLMProvider.id.isEmpty == false)
        #expect(MegaLLMProvider.name.isEmpty == false)
        #expect(MegaLLMProvider.defaultModel.isEmpty == false)
    }
}
