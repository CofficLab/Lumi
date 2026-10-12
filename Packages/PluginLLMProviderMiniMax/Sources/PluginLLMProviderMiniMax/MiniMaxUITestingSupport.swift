import Foundation
import KitLLM

/// UI 测试支持（仅 DEBUG）。
///
/// 当 App 以启动参数 `--lumi-ui-testing` 启动时，MiniMax 的「刷新模型列表」
/// 改走固定桩响应，不依赖真实网络与用户 API Key，保证 UI 测试确定性。
/// 范式参照 Cisum 的 `--cisum-ui-testing` 夹具注入（见 PluginAudioDBData）。
///
/// 桩响应包含 9 个模型：静态清单 6 个 + 远程新增 3 个
/// （MiniMax-M2.1 / MiniMax-M2.1-highspeed / MiniMax-M2），
/// 与用户报告的「磁盘 models.json 有 9 个」一致。
#if DEBUG
enum MiniMaxUITestingSupport {

    /// 启用 MiniMax UI 测试夹具的启动参数。
    static let launchArgument = "--lumi-ui-testing"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 用桩网络装配真实 MiniMax 供应商，并清空历史 models.json，
    /// 保证每次 UI 测试启动时模型列表回到静态清单（6 个）的初始状态。
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

    /// 固定返回 9 模型 `/v1/models` 响应的网络桩。
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

        static let payload = """
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
    }
}
#endif
