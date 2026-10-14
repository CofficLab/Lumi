import Foundation
import KitLLM
import ProviderStorage
import Testing
@testable import PluginLLMProviderMiniMax

/// MiniMaxLocalStore 磁盘落盘语义。
@MainActor
struct MiniMaxLocalStoreTests {

    @Test("写入后落盘到指定目录的 models.json")
    func writesSnapshotToPluginDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        store.store(models: [LLMModelInfo(id: "MiniMax-M4", displayName: "M4", contextWindowSize: 1000)])

        let fileURL = directory.appendingPathComponent("models.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // 新实例（模拟跨启动）能读回
        let reloaded = MiniMaxLocalStore(directory: directory)
        let snapshot = try #require(reloaded.cachedSnapshot())
        #expect(snapshot.models.map(\.id) == ["MiniMax-M4"])
        #expect(snapshot.models[0].contextWindowSize == 1000)
    }

    @Test("configure 绑定到内核分配的插件目录")
    func configureUsesPluginDataDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let store = MiniMaxLocalStore()
        store.configure(storage: storage)
        store.store(models: [LLMModelInfo(id: "MiniMax-M3")])

        // 目录名必须是插件 ID，而非 provider ID
        let expected = root.appendingPathComponent("com.coffic.lumi.plugin.llm-provider.minimax")
        #expect(FileManager.default.fileExists(atPath: expected.appendingPathComponent("models.json").path))
    }

    @Test("store 空列表被忽略，不覆盖已有缓存")
    func storeEmptyIgnored() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        store.store(models: [LLMModelInfo(id: "MiniMax-M3")])
        store.store(models: [])

        #expect(store.cachedSnapshot()?.models.map(\.id) == ["MiniMax-M3"])
    }

    @Test("过期快照仍可读，仅标记 isStale")
    func staleSnapshotStillReadable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        let old = Date().addingTimeInterval(-(MiniMaxLocalStore.ttl + 60))
        store.store(models: [LLMModelInfo(id: "MiniMax-M3")], syncedAt: old)

        let snapshot = try #require(store.cachedSnapshot())
        #expect(snapshot.isStale == true)
        #expect(snapshot.models.map(\.id) == ["MiniMax-M3"])
    }

    @Test("磁盘内容损坏时返回 nil 并回退静态清单")
    func corruptedDiskFallsBack() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("not json".utf8)
            .write(to: directory.appendingPathComponent("models.json"))

        let store = MiniMaxLocalStore(directory: directory)
        #expect(store.cachedSnapshot() == nil)
    }

    @Test("clear 清空内存与磁盘文件")
    func clearRemovesSnapshot() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        store.store(models: [LLMModelInfo(id: "MiniMax-M3")])
        store.clear()

        #expect(store.cachedSnapshot() == nil)
        #expect(MiniMaxLocalStore(directory: directory).cachedSnapshot() == nil)
    }

    @Test("未绑定目录时降级为纯内存，不产生任何文件")
    func inMemoryFallbackWritesNothing() throws {
        let store = MiniMaxLocalStore()
        store.store(models: [LLMModelInfo(id: "MiniMax-M3")])

        let snapshot = try #require(store.cachedSnapshot())
        #expect(snapshot.models.map(\.id) == ["MiniMax-M3"])
        // 未绑定目录：clear 不应崩溃
        store.clear()
        #expect(store.cachedSnapshot() == nil)
    }

    @Test("provider 在 store 未注入时仍回退静态清单")
    func providerFallsBackToStaticCatalogWithoutStore() {
        let provider = MiniMaxOpenAIProvider()

        #expect(provider.usesRemoteModelList == true)
        #expect(provider.lastModelSyncDate == nil)
        #expect(provider.availableModels.contains { $0.id == provider.providerInfo.defaultModel })
    }

    @Test("provider 从注入的 store 读到缓存模型并合入模型池")
    func providerReadsInjectedStore() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        store.store(models: [LLMModelInfo(id: "MiniMax-M9-Preview")])

        let provider = MiniMaxOpenAIProvider(apiService: VendorAPIService(), modelListCache: store)

        // 远程新增模型追加在静态清单之后
        let merged = provider.availableModels
        #expect(merged.contains { $0.id == "MiniMax-M9-Preview" })
        #expect(merged.count == MiniMaxVendorModels.all.count + 1)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minimax-store-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}