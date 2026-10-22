import Foundation
import KitLLM

/// UI 测试支持（仅 DEBUG）。
///
/// 当 App 以启动参数 `--lumi-ui-testing` 启动时，MiniMax 的「刷新模型列表」
/// 改走固定桩响应，不依赖真实网络与用户 API Key，保证 UI 测试确定性。
/// 范式参照 Cisum 的 `--cisum-ui-testing` 夹具注入（见 PluginAudioDBData）。
///
/// 桩响应 = 上游实测的 9 个模型 + 一个上游独有、静态清单没有的 `MiniMax-M2.8`。
///
/// `MiniMax-M2.8` 是 UI 测试判定「刷新已生效」的信号：它只可能来自远程响应，
/// 因此它出现在模型列表里，就证明 `.modelsRefreshed` 已广播、UI 快照已刷新。
///
/// - Important: 前 9 个 id 必须与上游真实返回 **逐字一致**。历史夹具用了
///   不存在的 `MiniMax-M3.1-Flash-Preview`，会让 UI 测试断言一个调不通的模型名。
#if DEBUG
enum MiniMaxUITestingSupport {

    /// 启用 MiniMax UI 测试夹具的启动参数。
    static let launchArgument = "--lumi-ui-testing"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 用桩网络装配真实 MiniMax 供应商，并清空历史 models.json，
    /// 保证每次 UI 测试启动时模型列表回到静态清单的初始状态。
    @MainActor
    static func makeProvider(modelListCache: MiniMaxLocalStore) -> MiniMaxOpenAIProvider {
        modelListCache.clear()
        let provider = MiniMaxOpenAIProvider(
            apiService: VendorAPIService(networkProvider: StubNetwork()),
            modelListCache: modelListCache
        )
        provider.apiKeyOverride = "ui-test-key"
        return provider
    }

    /// 固定返回 `/v1/models` 响应的网络桩。
    private final class StubNetwork: NSObject, LLMNetworkProviding, @unchecked Sendable {

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.minimaxi.com/v1/models")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(Self.payload.utf8), response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {}

        /// 前 9 个逐字取自上游真实响应（`created` 为 Unix 秒级时间戳），
        /// 末尾追加上游独有的 `MiniMax-M2.8` 作为刷新生效信号。
        static let payload = """
        {"object":"list","data":[
          {"id":"MiniMax-M3.1-Flash","object":"model","created":1789556118,"owned_by":"minimax"},
          {"id":"MiniMax-M3","object":"model","created":1780272000,"owned_by":"minimax"},
          {"id":"MiniMax-M2.7","object":"model","created":1773799200,"owned_by":"minimax"},
          {"id":"MiniMax-M2.7-highspeed","object":"model","created":1773799200,"owned_by":"minimax"},
          {"id":"MiniMax-M2.5","object":"model","created":1770948000,"owned_by":"minimax"},
          {"id":"MiniMax-M2.5-highspeed","object":"model","created":1770948000,"owned_by":"minimax"},
          {"id":"MiniMax-M2.1","object":"model","created":1766455200,"owned_by":"minimax"},
          {"id":"MiniMax-M2.1-highspeed","object":"model","created":1766455200,"owned_by":"minimax"},
          {"id":"MiniMax-M2","object":"model","created":1761530400,"owned_by":"minimax"},
          {"id":"MiniMax-M2.8","object":"model","created":1760000000,"owned_by":"minimax"}
        ]}
        """
    }
}
#endif
