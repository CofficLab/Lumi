import Testing
@testable import LLMProviderFlyMuxPlugin

struct PluginLLMProviderFlyMuxTests {
    @Test func pluginMetadata() {
        #expect(FlyMuxPlugin.id.isEmpty == false)
        #expect(FlyMuxPlugin.displayName.isEmpty == false)
        #expect(FlyMuxPlugin.description.isEmpty == false)
        #expect(FlyMuxPlugin.iconName.isEmpty == false)
        #expect(FlyMuxPlugin.category == .llmProvider)
        #expect(FlyMuxPlugin.shared.llmProviderType() == FlyMuxProvider.self)
    }

    @Test func providerMetadata() {
        #expect(FlyMuxProvider.id.isEmpty == false)
        #expect(FlyMuxProvider.displayName.isEmpty == false)
        #expect(FlyMuxProvider.defaultModel.isEmpty == false)
    }
}
