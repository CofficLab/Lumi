import Testing
@testable import LLMProviderFlyMuxPlugin

@MainActor
struct PluginLLMProviderFlyMuxTests {
    @Test func pluginMetadata() {
        #expect(FlyMuxPlugin().id.isEmpty == false)
        #expect(FlyMuxPlugin.name.isEmpty == false)
        #expect(FlyMuxPlugin().category == .llmProvider)
        #expect(FlyMuxPlugin.shared.llmProviderType() == FlyMuxProvider.self)
    }

    @Test func providerMetadata() {
        #expect(FlyMuxProvider.id.isEmpty == false)
        #expect(FlyMuxProvider.name.isEmpty == false)
        #expect(FlyMuxProvider.defaultModel.isEmpty == false)
    }
}
