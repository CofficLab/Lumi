import Testing
import LumiKernel
@testable import LLMProviderStepFunPlugin

@MainActor
struct PluginLLMProviderStepFunTests {
    @Test func pluginMetadata() {
        let plugin = StepFunPlugin()
        #expect(plugin.id.isEmpty == false)
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        let info = StepFunProvider.info
        #expect(info.id.isEmpty == false)
        #expect(info.displayName.isEmpty == false)
        #expect(info.defaultModel.isEmpty == false)
    }
}
