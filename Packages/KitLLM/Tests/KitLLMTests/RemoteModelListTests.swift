import Foundation
import Testing
@testable import KitLLM

/// LLMModelListCache 缓存语义 + VendorLLMProvider 静态默认行为。
struct RemoteModelListTests {

    // MARK: - LLMModelListCache

    @Test("store 后内存命中，返回复制值不污染缓存")
    func cacheMemoryHit() throws {
        let suite = "kitllm-test-cache-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = LLMModelListCache(providerID: "test", userDefaults: defaults)
        let now = Date()

        cache.store(
            models: [LLMModelInfo(id: "m1", displayName: "M1", contextWindowSize: 1000)],
            syncedAt: now
        )

        let snapshot = try #require(cache.cachedSnapshot())
        #expect(snapshot.models.count == 1)
        #expect(snapshot.models[0].id == "m1")
        #expect(snapshot.models[0].contextWindowSize == 1000)
        #expect(snapshot.syncedAt == now)
        #expect(snapshot.isStale == false)

        // 复制值：修改返回的模型不影响缓存
        var info = snapshot.models[0]
        info = LLMModelInfo(id: "m1", displayName: "Hacked", contextWindowSize: 1)
        _ = info
        #expect(cache.cachedSnapshot()?.models[0].displayName == "M1")
    }

    @Test("磁盘缓存跨实例保留（同 providerID + 同 defaults）")
    func cacheDiskPersistence() throws {
        let suite = "kitllm-test-disk-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache1 = LLMModelListCache(providerID: "p", userDefaults: defaults)
        cache1.store(models: [LLMModelInfo(id: "a"), LLMModelInfo(id: "b")], syncedAt: Date())

        // 新实例（模拟跨启动）
        let cache2 = LLMModelListCache(providerID: "p", userDefaults: defaults)
        let snapshot = try #require(cache2.cachedSnapshot())
        #expect(snapshot.models.map(\.id) == ["a", "b"])
        #expect(cache2.cachedSnapshot()?.isStale == false)
    }

    @Test("store 空列表被忽略，不覆盖已有缓存")
    func cacheStoreEmptyIgnored() throws {
        let suite = "kitllm-test-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = LLMModelListCache(providerID: "p", userDefaults: defaults)
        cache.store(models: [LLMModelInfo(id: "a")])
        cache.store(models: [])

        #expect(cache.cachedSnapshot()?.models.map(\.id) == ["a"])
    }

    @Test("clear 清空内存与磁盘")
    func cacheClear() throws {
        let suite = "kitllm-test-clear-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = LLMModelListCache(providerID: "p", userDefaults: defaults)
        cache.store(models: [LLMModelInfo(id: "a")])

        cache.clear()

        #expect(cache.cachedSnapshot() == nil)
        let reloaded = LLMModelListCache(providerID: "p", userDefaults: defaults)
        #expect(reloaded.cachedSnapshot() == nil)
    }

    // MARK: - VendorLLMProvider 默认行为

    @Test("静态供应商:usesRemoteModelList==false, availableModels==静态列表, refresh 无害")
    @MainActor
    func staticProviderBehavior() async {
        let provider = StaticTestProvider()
        #expect(provider.usesRemoteModelList == false)
        #expect(provider.availableModels.map(\.id) == ["static-a", "static-b"])
        #expect(provider.lastModelSyncDate == nil)

        // 静态供应商 refreshModels 不抛错、不改列表
        try? await provider.refreshModels()
        #expect(provider.availableModels.map(\.id) == ["static-a", "static-b"])
    }
}

/// 最小静态供应商测试替身。
@MainActor
private final class StaticTestProvider: VendorLLMProvider {
    init() {
        super.init(info: LLMProviderInfo(
            id: "static-test",
            displayName: "Static Test",
            defaultModel: "static-a",
            models: [
                LLMModelInfo(id: "static-a"),
                LLMModelInfo(id: "static-b"),
            ]
        ))
    }
}
