import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

/// MiniMax 远程模型列表刷新链路的集成测试。
///
/// 用真实 `MiniMaxOpenAIProvider` + 网络桩（模拟国内站 `/v1/models`）走完整
/// 刷新链路：refreshModels → 磁盘落盘 → notifyModelsRefreshed → manager 模型池。
/// UI（box/viewModel）读取的正是 manager 模型池。
///
/// - Note: 桩响应对齐 2026-10 实测的真实 `/v1/models` 返回（9 个模型），
///   与静态清单 id 完全重合。历史上两者是错开的（清单 6 个 vs 上游 9 个），
///   因为清单里存在一个上游没有的 `MiniMax-M3.1-Flash-Preview`。
@MainActor
struct MiniMaxRefreshReproductionTests {

    /// 把 API Key 写入**一次性**的 Keychain service，绝不碰生产 service。
    ///
    /// - Important: 不能改用「读旧值 → 写测试值 → defer 还原」的写法。未隔离时
    ///   `VendorAPIKeyTools.get` 会读生产 service，若此刻读取失败（未授权 / 条目
    ///   不可访问）返回空串，原实现会在 defer 里执行 `remove`，**反而删掉用户
    ///   真实的 MiniMax key**。本套件曾把用户的 key 覆盖成 `test-key`。
    ///
    ///   隔离后读写都落在一次性 service 上，测试进程退出即失效，无需还原。
    ///
    /// - Important: service 必须取自 ``TestKeychain/service``，**不能**每次生成
    ///   随机 UUID。`keychainService` 是进程级全局状态，本套件若在并行执行的
    ///   其他套件中途改写它，那些套件的写入与读取就会落到不同 service 上，
    ///   表现为「单跑通过、全量失败」。
    private static func withIsolatedAPIKey(_ provider: MiniMaxOpenAIProvider) {
        TestKeychain.activate()
        VendorAPIKeyTools.set("test-key", storageKey: provider.providerInfo.apiKeyStorageKey)
    }

    /// 模拟国内站 `/v1/models` 返回，逐字对齐 2026-10 实测结果。
    private static let remotePayload = """
    {"object":"list","data":[
      {"id":"MiniMax-M3.1-Flash","object":"model","created":1789556118,"owned_by":"minimax"},
      {"id":"MiniMax-M3","object":"model","created":1780272000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.7","object":"model","created":1773799200,"owned_by":"minimax"},
      {"id":"MiniMax-M2.7-highspeed","object":"model","created":1773799200,"owned_by":"minimax"},
      {"id":"MiniMax-M2.5","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.5-highspeed","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.1","object":"model","created":1766455200,"owned_by":"minimax"},
      {"id":"MiniMax-M2.1-highspeed","object":"model","created":1766455200,"owned_by":"minimax"},
      {"id":"MiniMax-M2","object":"model","created":1761530400,"owned_by":"minimax"}
    ]}
    """

    /// 返回 200 与固定 JSON 的网络桩，不真正发请求。
    private final class StubNetwork: LLMNetworkProviding, @unchecked Sendable {
        private let payload: Data

        init(_ payload: Data) {
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (payload, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {}
    }

    /// 上游返回的 9 个模型与静态清单完全重合，刷新前后模型池都应为 9 个。
    ///
    /// 回归：历史清单里有一个上游不存在的 `MiniMax-M3.1-Flash-Preview`，
    /// 刷新后会同时出现 `-Preview`（调不通）与 `MiniMax-M3.1-Flash`（可用）
    /// 两个条目。修正 id 后两者合一，池大小稳定为 9。
    @Test("刷新后模型池保持 9 个，不因 id 错位产生重复条目（manager 即 UI 读取路径）")
    func refreshKeepsModelPoolAlignedWithRemote() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minimax-repro-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        let network = StubNetwork(Data(Self.remotePayload.utf8))
        let apiService = VendorAPIService(networkProvider: network)
        let provider = MiniMaxOpenAIProvider(apiService: apiService, modelListCache: store)

        Self.withIsolatedAPIKey(provider)

        let manager = DefaultLLMManager()
        try manager.register(provider)

        // ── 刷新前：UI 显示静态清单 ──
        #expect(MiniMaxVendorModels.all.count == 9)
        #expect(provider.availableModels.count == 9, "刷新前应显示静态清单 9 个")
        #expect(manager.models(for: provider.providerID).count == 9, "刷新前 manager 模型池应为 9 个")

        // ── 点击刷新（等价 ModelSelectorViewModel.refreshModels 的调用序列）──
        try await provider.refreshModels()
        manager.notifyModelsRefreshed(providerID: provider.providerID)

        // 磁盘 models.json 已写入 9 个
        let fileURL = directory.appendingPathComponent("models.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path), "刷新后磁盘应出现 models.json")
        let diskObject = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        let diskModels = (diskObject?["models"] as? [[String: Any]]) ?? []
        #expect(diskModels.count == 9, "磁盘 models.json 应包含 9 个模型")

        // ── 刷新后：上游 id 与清单一一对应，不新增也不重复 ──
        #expect(provider.availableModels.count == 9, "刷新后模型池应仍为 9 个")
        #expect(manager.models(for: provider.providerID).count == 9, "刷新后 manager 模型池应仍为 9 个")

        let ids = provider.availableModels.map(\.id)
        #expect(Set(ids).count == ids.count, "模型池不应出现重复 id")
        #expect(!ids.contains("MiniMax-M3.1-Flash-Preview"), "上游不存在该 id，清单不应保留")
        #expect(ids.contains("MiniMax-M3.1-Flash"), "应使用上游真实 id")

        // 远程新增模型的元数据由家族规则补全，不落 32K 兜底
        for model in provider.availableModels {
            let expected = MiniMaxModelFamily.family(for: model.id).contextWindowSize
            #expect(model.contextWindowSize == expected, "\(model.id) 上下文窗口应为 \(expected ?? 0)")
            #expect(model.contextWindowSize != nil, "\(model.id) 不应落 32K 兜底")
        }
    }

    /// 远程返回与静态清单完全不同的 9 个 id（合并后应为静态数量 + 9）。
    @Test("远程新增模型应追加到静态清单之后")
    func remoteOnlyModelsAreAppended() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minimax-repro-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        let remoteOnly = """
        {"object":"list","data":[
          {"id":"MiniMax-X1","object":"model"},
          {"id":"MiniMax-X2","object":"model"},
          {"id":"MiniMax-X3","object":"model"},
          {"id":"MiniMax-X4","object":"model"},
          {"id":"MiniMax-X5","object":"model"},
          {"id":"MiniMax-X6","object":"model"},
          {"id":"MiniMax-X7","object":"model"},
          {"id":"MiniMax-X8","object":"model"},
          {"id":"MiniMax-X9","object":"model"}
        ]}
        """
        let apiService = VendorAPIService(networkProvider: StubNetwork(Data(remoteOnly.utf8)))
        let provider = MiniMaxOpenAIProvider(apiService: apiService, modelListCache: store)

        Self.withIsolatedAPIKey(provider)

        try await provider.refreshModels()
        #expect(provider.availableModels.count == MiniMaxVendorModels.all.count + 9,
                "远程新增 9 个应追加到静态清单之后")

        // `MiniMax-X1` 这类未知命名无法推断家族，上下文窗口保持 nil 由上层兜底
        let unknown = try #require(provider.availableModels.first { $0.id == "MiniMax-X1" })
        #expect(unknown.contextWindowSize == nil, "未知家族不猜测上下文窗口")
    }
}
