import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

/// 复现用户报告：MiniMax 供应商默认显示 6 个模型；
/// 点击刷新后磁盘 models.json 写入 9 个模型，但 UI 读取的模型池仍为 6 个。
///
/// 本测试用真实 `MiniMaxOpenAIProvider` + 网络桩（模拟国内站 `/v1/models`
/// 返回 9 个模型）走完整刷新链路：refreshModels → 磁盘落盘 → notifyModelsRefreshed
/// → manager 模型池。UI（box/viewModel）读取的正是 manager 模型池。
@MainActor
struct MiniMaxRefreshReproductionTests {

    /// 模拟国内站 `/v1/models` 返回 9 个模型：6 个与静态清单重叠 + 3 个新增。
    private static let remotePayload = """
    {"object":"list","data":[
      {"id":"MiniMax-M3.1-Flash-Preview","object":"model","created":1780272000,"owned_by":"minimax"},
      {"id":"MiniMax-M3","object":"model","created":1780272000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.7","object":"model","created":1773799200,"owned_by":"minimax"},
      {"id":"MiniMax-M2.7-highspeed","object":"model","created":1773799200,"owned_by":"minimax"},
      {"id":"MiniMax-M2.5","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.5-highspeed","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.1","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2.1-highspeed","object":"model","created":1770948000,"owned_by":"minimax"},
      {"id":"MiniMax-M2","object":"model","created":1770948000,"owned_by":"minimax"}
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

    /// 用户场景的完整复现：刷新前 6 个 → 刷新后应变为 9 个。
    @Test("刷新后模型池应从 6 变为 9（manager 即 UI 读取路径）")
    func refreshShouldExpandModelPoolFrom6To9() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minimax-repro-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MiniMaxLocalStore(directory: directory)
        let network = StubNetwork(Data(Self.remotePayload.utf8))
        let apiService = VendorAPIService(networkProvider: network)
        let provider = MiniMaxOpenAIProvider(apiService: apiService, modelListCache: store)

        // 保存/恢复真实 API Key，避免测试污染用户的 Keychain。
        let storageKey = provider.providerInfo.apiKeyStorageKey
        let previousKey = VendorAPIKeyTools.get(storageKey: storageKey)
        VendorAPIKeyTools.set("test-key", storageKey: storageKey)
        defer {
            if previousKey.isEmpty {
                VendorAPIKeyTools.remove(storageKey: storageKey)
            } else {
                VendorAPIKeyTools.set(previousKey, storageKey: storageKey)
            }
        }

        let manager = DefaultLLMManager()
        try manager.register(provider)

        // ── 刷新前：UI 显示静态清单 6 个 ──
        #expect(MiniMaxVendorModels.all.count == 6)
        #expect(provider.availableModels.count == 6, "刷新前应显示静态清单 6 个")
        #expect(manager.models(for: provider.providerID).count == 6, "刷新前 manager 模型池应为 6 个")

        // ── 点击刷新（等价 ModelSelectorViewModel.refreshModels 的调用序列）──
        try await provider.refreshModels()
        manager.notifyModelsRefreshed(providerID: provider.providerID)

        // 磁盘 models.json 已写入 9 个
        let fileURL = directory.appendingPathComponent("models.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path), "刷新后磁盘应出现 models.json")
        let diskObject = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        let diskModels = (diskObject?["models"] as? [[String: Any]]) ?? []
        #expect(diskModels.count == 9, "磁盘 models.json 应包含 9 个模型")

        // ── 用户报告的缺陷点：UI 读取的模型池仍为 6 个 ──
        #expect(provider.availableModels.count == 9, "刷新后 provider 模型池应变为 9 个")
        #expect(manager.models(for: provider.providerID).count == 9, "刷新后 manager 模型池应变为 9 个")
    }

    /// 换一个角度：远程返回与静态清单完全不同的 9 个 id（合并后应为 15 个）。
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

        let storageKey = provider.providerInfo.apiKeyStorageKey
        let previousKey = VendorAPIKeyTools.get(storageKey: storageKey)
        VendorAPIKeyTools.set("test-key", storageKey: storageKey)
        defer {
            if previousKey.isEmpty {
                VendorAPIKeyTools.remove(storageKey: storageKey)
            } else {
                VendorAPIKeyTools.set(previousKey, storageKey: storageKey)
            }
        }

        try await provider.refreshModels()
        #expect(provider.availableModels.count == MiniMaxVendorModels.all.count + 9,
                "远程新增 9 个应追加到静态 6 个之后")
    }
}
