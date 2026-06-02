import Testing
@testable import PluginLLMProviderZhipu

struct PluginLLMProviderZhipuTests {
    @Test func pluginMetadata() {
        #expect(ZhipuPlugin.id.isEmpty == false)
        #expect(ZhipuPlugin.displayName.isEmpty == false)
        #expect(ZhipuPlugin.description.isEmpty == false)
        #expect(ZhipuPlugin.iconName.isEmpty == false)
        #expect(ZhipuPlugin.category == .llmProvider)
        #expect(ZhipuPlugin.shared.llmProviderType() == ZhipuProvider.self)
    }

    @Test func providerMetadata() {
        #expect(ZhipuProvider.id.isEmpty == false)
        #expect(ZhipuProvider.displayName.isEmpty == false)
        #expect(ZhipuProvider.defaultModel.isEmpty == false)
    }
}
