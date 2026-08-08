import Testing
import Foundation
import LumiKernel
@testable import ModelSelectorPlugin

@Suite("Provider scope")
struct ProviderScopeTests {
    @Test("Cloud and local scopes use provider metadata")
    func filtersUsingIsLocal() {
        let cloudProvider = makeProvider(id: "cloud", isLocal: false)
        let localProvider = makeProvider(id: "local", isLocal: true)

        #expect(ProviderScope.cloud.includes(cloudProvider))
        #expect(!ProviderScope.cloud.includes(localProvider))
        #expect(ProviderScope.local.includes(localProvider))
        #expect(!ProviderScope.local.includes(cloudProvider))
    }

    private func makeProvider(id: String, isLocal: Bool) -> LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: "model",
            availableModels: [],
            isLocal: isLocal,
            websiteURL: URL(string: "https://example.com")!
        )
    }
}
