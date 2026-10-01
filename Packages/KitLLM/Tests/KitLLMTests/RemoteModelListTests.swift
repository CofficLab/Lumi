import Foundation
import Testing
@testable import KitLLM

/// 远程模型列表：loader 解析、缓存语义、VendorLLMProvider 默认行为。
struct RemoteModelListTests {

    // MARK: - RemoteModelListLoader.parse

    @Test("解析 OpenAI 标准格式（无 name/context_length）")
    func parseOpenAIStandardFormat() throws {
        let json = """
        {"data":[{"id":"gpt-4o","object":"model"},{"id":"gpt-4o-mini","object":"model"}]}
        """
        let models = try RemoteModelListLoader.parse(data: Data(json.utf8))

        #expect(models.count == 2)
        #expect(models[0].id == "gpt-4o")
        #expect(models[0].displayName == "gpt-4o") // 缺省回退 id
        #expect(models[0].contextWindowSize == nil)
        #expect(models[1].id == "gpt-4o-mini")
    }

    @Test("解析 CommandCode 变体（含 name/context_length）")
    func parseCommandCodeVariant() throws {
        let json = """
        {"data":[{"id":"claude-sonnet-5-5","name":"Claude Sonnet 5.5","context_length":1000000}]}
        """
        let models = try RemoteModelListLoader.parse(data: Data(json.utf8))

        #expect(models.count == 1)
        #expect(models[0].id == "claude-sonnet-5-5")
        #expect(models[0].displayName == "Claude Sonnet 5.5")
        #expect(models[0].contextWindowSize == 1_000_000)
    }

    @Test("空 data 或缺失 data 视为解码失败（不返回空列表）")
    func parseEmptyFails() {
        let emptyData = #"{"data":[]}"#
        #expect(throws: VendorAPIError.self) {
            try RemoteModelListLoader.parse(data: Data(emptyData.utf8))
        }

        let missingData = #"{"models":[]}"#
        #expect(throws: VendorAPIError.self) {
            try RemoteModelListLoader.parse(data: Data(missingData.utf8))
        }
    }

    @Test("跳过无 id 的条目")
    func parseSkipsMissingID() throws {
        let json = #"{"data":[{"name":"No ID","context_length":1000}]}"#
        let models = try RemoteModelListLoader.parse(data: Data(json.utf8))
        #expect(models.isEmpty)
    }

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

    @Test("RemoteModelMerger:远程空时返回基线")
    @MainActor
    func mergerEmptyRemoteReturnsBase() {
        let base = [LLMModelInfo(id: "a"), LLMModelInfo(id: "b")]
        let merged = RemoteModelMerger.merge(base: base, remote: [])
        #expect(merged.map(\.id) == ["a", "b"])
    }

    @Test("RemoteModelMerger:远程覆盖同 id 基线元数据")
    @MainActor
    func mergerRemoteOverridesBase() {
        let base = [LLMModelInfo(id: "a", displayName: "A-base", contextWindowSize: 100)]
        let remote = [LLMModelInfo(id: "a", displayName: "A-remote", contextWindowSize: 999)]
        let merged = RemoteModelMerger.merge(base: base, remote: remote)

        #expect(merged.count == 1)
        #expect(merged[0].displayName == "A-remote")
        #expect(merged[0].contextWindowSize == 999)
    }

    @Test("RemoteModelMerger:远程新增模型追加在基线之后")
    @MainActor
    func mergerRemoteAppendedAfterBase() {
        let base = [LLMModelInfo(id: "a"), LLMModelInfo(id: "b")]
        let remote = [LLMModelInfo(id: "c"), LLMModelInfo(id: "d")]
        let merged = RemoteModelMerger.merge(base: base, remote: remote)
        #expect(merged.map(\.id) == ["a", "b", "c", "d"])
    }

    @Test("RemoteModelMerger:远程与基线交叉时按基线顺序输出，新增追加在后")
    @MainActor
    func mergerMixedOrder() {
        let base = [LLMModelInfo(id: "a"), LLMModelInfo(id: "b"), LLMModelInfo(id: "c")]
        let remote = [LLMModelInfo(id: "b", displayName: "B-remote"), LLMModelInfo(id: "d")]
        let merged = RemoteModelMerger.merge(base: base, remote: remote)

        #expect(merged.map(\.id) == ["a", "b", "c", "d"])
        #expect(merged[1].displayName == "B-remote")
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