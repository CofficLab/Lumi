import Foundation
import KernelCore
import KitLLM
import ProviderChatSection
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

// MARK: - LLMNetworkProviding 桩

/// 记录请求并按脚本返回响应的网络桩。
///
/// 配额查询与远程模型列表共用这一个桩，因此既能断言「请求打到了哪个 URL、
/// 带了什么 Header」，也能注入各类失败（HTTP 状态码、抛错）。
///
/// 记录写入走 `lock.lock()` 必须在**同步**上下文，因此 `send` 内部先把记录
/// 交给一个同步的私有方法 `record(_:)`，避免在 async 上下文直接碰 NSLock。
final class StubLLMNetwork: NSObject, LLMNetworkProviding, @unchecked Sendable {

    /// 单次请求的记录。
    struct RecordedRequest: @unchecked Sendable {
        let url: String?
        let method: String?
        let headers: [String: String]
        let body: Data

        var authorization: String? {
            headers.first { $0.key.caseInsensitiveCompare("Authorization") == .orderedSame }?.value
        }
    }

    /// 脚本化响应。
    enum Outcome: Sendable {
        /// 返回指定状态码与响应体。
        case http(statusCode: Int, body: Data)
        /// 抛出指定错误。
        case failure(any Error & Sendable)

        /// 便捷构造 200 JSON 响应。
        static func json(_ string: String) -> Outcome {
            .http(statusCode: 200, body: Data(string.utf8))
        }
    }

    private let lock = NSLock()
    private var _requests: [RecordedRequest] = []
    private let _outcome: Outcome

    init(_ outcome: Outcome) {
        self._outcome = outcome
    }

    /// 按成功状态码返回 JSON。
    convenience init(json: String) {
        self.init(.json(json))
    }

    /// 便捷构造 HTTP 失败响应。
    static func http(_ statusCode: Int, body: String = "") -> StubLLMNetwork {
        StubLLMNetwork(.http(statusCode: statusCode, body: Data(body.utf8)))
    }

    /// 便捷构造传输错误。
    static func failing(_ error: any Error & Sendable) -> StubLLMNetwork {
        StubLLMNetwork(.failure(error))
    }

    var requests: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    var requestCount: Int { requests.count }

    /// 最后一次请求（无请求时返回 nil）。
    var lastRequest: RecordedRequest? { requests.last }

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        record(RecordedRequest(
            url: request.url?.absoluteString,
            method: request.httpMethod,
            headers: request.allHTTPHeaderFields ?? [:],
            body: body
        ))

        switch _outcome {
        case let .http(statusCode, data):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.minimaxi.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        case let .failure(error):
            throw error
        }
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {}

    /// 同步方法内追加请求记录。
    private func record(_ request: RecordedRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }
}

// MARK: - 固定响应

/// 测试共用的固定响应体。
enum StubPayload {

    /// 一条合法配额的完整响应。
    static let tokenPlanSuccess = """
    {"base_resp":{"status_code":0,"status_msg":"success"},
     "model_remains":[{
       "model_name":"general",
       "current_interval_remaining_percent":81,
       "current_interval_status":1,
       "current_interval_total_count":100,
       "current_interval_usage_count":19,
       "start_time":1788000000000,
       "end_time":1788018000000,
       "remains_time":12345000,
       "current_weekly_remaining_percent":98,
       "current_weekly_status":1,
       "current_weekly_total_count":500,
       "current_weekly_usage_count":10,
       "weekly_start_time":1787500000000,
       "weekly_end_time":1788100000000,
       "weekly_remains_time":345600000
     }]}
    """

    /// 远程模型列表响应。
    static let modelList = """
    {"object":"list","data":[
      {"id":"MiniMax-M3.1-Flash-Preview"},
      {"id":"MiniMax-M3"},
      {"id":"MiniMax-M2.7"},
      {"id":"MiniMax-M2.7-highspeed"},
      {"id":"MiniMax-M2.5"},
      {"id":"MiniMax-M2.5-highspeed"},
      {"id":"MiniMax-M2.1"},
      {"id":"MiniMax-M2.1-highspeed"},
      {"id":"MiniMax-M2"}
    ]}
    """
}

// MARK: - Kernel 组装

/// 组装一个带相关 Provider 的 kernel。
@MainActor
enum KernelFixture {

    struct Harness {
        let kernel: KernelCoreContainer
        let manager: DefaultLLMManager
        let chat: DefaultChatSectionProviding
    }

    /// 默认装配：LLM 管理器 + chat 分区。
    ///
    /// 缺任何一个 Provider 都会让 `onBoot` 提前 return，因此测试显式声明
    /// 「这次 boot 需要哪些能力」，避免漏注册被静默跳过。
    static func makeHarness() throws -> Harness {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return Harness(kernel: kernel, manager: manager, chat: chat)
    }
}

// MARK: - Keychain 隔离

/// 让测试写入的 API Key 不污染用户真实 Keychain，并隔离各用例。
///
/// **为什么不能用「每个用例换一个 service」**：`VendorAPIKeyTools.keychainService`
/// 是进程级全局可变状态，而 Swift Testing 默认并行执行 suite。若 A 用例把 service
/// 换成 serviceA、B 用例换成 serviceB，A 的写入与读取会落到不同 service 上，
/// 「Key 缺失」用例还会偶发读到别的用例刚写入的值。这类失败**只在全量运行时出现，
/// 单跑必过**，极难定位（本包曾因此出现 11 个只在全量运行时失败的用例）。
///
/// **本方案**：service 只在进程内设置一次，之后所有用例共用；用例之间靠
/// **独立 storageKey** 隔离。需要覆盖固定 storageKey 的用例（如 supplier 本体）
/// 与其他 Keychain 用例串行执行，见 `MiniMaxRefreshReproductionTests`。
enum TestKeychain {

    /// 进程级唯一 service；`once` 保证并发下也只赋值一次。
    static let service: String = "com.coffic.lumi.apikey.minimax.test.\(ProcessInfo.processInfo.processIdentifier)"

    private static let once: Void = {
        VendorAPIKeyTools.keychainService = service
    }()

    /// 确保 service 已重定向；所有公开入口都会先调它。
    static func activate() {
        once
    }

    /// 生成一次性的 storageKey，供测试使用。
    static func uniqueKey(_ label: String) -> String {
        activate()
        return "\(MiniMaxSharedConstants.apiKeyStorageKey).test.\(label).\(UUID().uuidString)"
    }

    /// 在 Keychain 中写入指定 Key。
    ///
    /// 必须在 `uniqueKey(_:)` 返回的 storageKey 上调用（或调用方自行保证不与
    /// 其他并发用例共享同一个 key）；`nil` 表示删除。
    static func set(_ value: String?, forKey key: String) {
        activate()
        if let value {
            VendorAPIKeyTools.set(value, storageKey: key)
        } else {
            VendorAPIKeyTools.remove(storageKey: key)
        }
    }
}
