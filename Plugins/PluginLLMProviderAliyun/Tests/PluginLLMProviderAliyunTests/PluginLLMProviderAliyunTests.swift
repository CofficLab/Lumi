import Testing
@testable import PluginLLMProviderAliyun

struct PluginLLMProviderAliyunTests {
    @Test func pluginMetadata() {
        #expect(AliyunPlugin.id.isEmpty == false)
        #expect(AliyunPlugin.displayName.isEmpty == false)
        #expect(AliyunPlugin.description.isEmpty == false)
        #expect(AliyunPlugin.iconName.isEmpty == false)
        #expect(AliyunPlugin.category == .llmProvider)
        #expect(AliyunPlugin.shared.llmProviderType() == AliyunProvider.self)
    }

    @Test func providerMetadata() {
        #expect(AliyunProvider.id.isEmpty == false)
        #expect(AliyunProvider.displayName.isEmpty == false)
        #expect(AliyunProvider.defaultModel.isEmpty == false)
    }
}
