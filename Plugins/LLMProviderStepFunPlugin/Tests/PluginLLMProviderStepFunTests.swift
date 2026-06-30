import Testing
@testable import LLMProviderStepFunPlugin

struct PluginLLMProviderStepFunTests {
    @Test func pluginMetadata() {
        #expect(StepFunPlugin.id.isEmpty == false)
        #expect(StepFunPlugin.displayName.isEmpty == false)
        #expect(StepFunPlugin.description.isEmpty == false)
        #expect(StepFunPlugin.iconName.isEmpty == false)
        #expect(StepFunPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(StepFunProvider.id.isEmpty == false)
        #expect(StepFunProvider.displayName.isEmpty == false)
        #expect(StepFunProvider.defaultModel.isEmpty == false)
    }
}
