import Testing
@testable import LLMProviderStepFunPlugin

@MainActor
struct PluginLLMProviderStepFunTests {
    @Test func pluginMetadata() {
        #expect(StepFunPlugin().id.isEmpty == false)
        #expect(StepFunPlugin.name.isEmpty == false)
        #expect(StepFunPlugin().category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(StepFunProvider.id.isEmpty == false)
        #expect(StepFunProvider.name.isEmpty == false)
        #expect(StepFunProvider.defaultModel.isEmpty == false)
    }
}
