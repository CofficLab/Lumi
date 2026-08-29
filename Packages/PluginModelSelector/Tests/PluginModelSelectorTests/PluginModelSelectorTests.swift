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
        #expect(ProviderScope.frequent.includes(cloudProvider, usageCount: 1))
        #expect(!ProviderScope.frequent.includes(localProvider))
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

@Suite("Provider usage store")
@MainActor
struct ProviderUsageStoreTests {
    @Test("Persists approximate provider usage and ranks by count")
    func persistsAndRanksUsage() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelSelectorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = Date(timeIntervalSince1970: 2_000)
        let store = ProviderUsageStore(directory: directory)
        store.recordUse(providerID: "openai", at: firstDate)
        store.recordUse(providerID: "deepseek", at: secondDate)
        store.recordUse(providerID: "openai", at: secondDate)

        #expect(store.usageCount(for: "openai") == 2)
        #expect(store.lastUsedAt(for: "openai") == secondDate)
        #expect(store.isMoreFrequentlyUsed("openai", than: "deepseek"))

        let reloadedStore = ProviderUsageStore(directory: directory)
        #expect(reloadedStore.usageCount(for: "openai") == 2)
        #expect(reloadedStore.lastUsedAt(for: "deepseek") == secondDate)
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
        #expect(plugin.metadata.category == .core)
    }
}
