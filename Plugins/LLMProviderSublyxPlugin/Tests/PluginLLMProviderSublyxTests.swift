import Testing
@testable import LLMProviderSublyxPlugin

struct PluginLLMProviderSublyxTests {
    @Test func pluginMetadata() {
        #expect(SublyxPlugin.info.id.isEmpty == false)
        #expect(SublyxPlugin.info.displayName.isEmpty == false)
        #expect(SublyxPlugin.info.description.isEmpty == false)
        #expect(SublyxPlugin.iconName.isEmpty == false)
        #expect(SublyxPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(SublyxProvider.info.id == "sublyx")
        #expect(SublyxProvider.info.displayName == "Sublyx")
        #expect(SublyxProvider.info.defaultModel == "gpt-5.5")
        #expect(SublyxProvider.info.availableModels.contains("gpt-5.5"))
        #expect(SublyxProvider.info.availableModels.contains("gpt-4o"))
    }
}
