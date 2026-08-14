import Testing
@testable import LLMProviderOpenCodeGoPlugin

@Test func exposesDocumentedOpenCodeGoModels() {
    #expect(OpenCodeGoProvider.info.id == "opencode-go")
    #expect(OpenCodeGoProvider.info.availableModels.count == 20)
    #expect(OpenCodeGoProvider.info.modelIDs.contains("kimi-k3"))
}
