import Testing
import Foundation
import KernelCore
import ProviderLLMManager
import KitLLM
@testable import PluginModelSelector

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

    private func makeProvider(id: String, isLocal: Bool) -> LLMProviderInfo {
        LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: "model",
            models: [],
            isLocal: isLocal
        )
    }
}

@Suite("ModelSelectorPlugin metadata")
@MainActor
struct ModelSelectorPluginMetadataTests {
    @Test("Keeps legacy plugin id, order and policy")
    func identityAndPolicy() {
        let plugin = ModelSelectorPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.model-selector")
        #expect(plugin.order == 82)
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(plugin.metadata.category == .chat)
    }
}
