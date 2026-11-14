import Foundation
import KitLLM
import ProviderNetwork
import Testing
@testable import PluginNetworkManager

/// 回归 #310：非流式 `NetworkProvider.request` 此前捕获 URLError 后只保留
/// description、丢弃 underlyingCode，导致 `LLMNetworkProviderAdapter` 无法还原
/// NSURLErrorDomain 错误，超时/断网/连接丢失退化为 `requestFailed`，
/// `ProviderRetryPolicy` 的可重试白名单永不命中，默认多次尝试只执行第一次。
///
/// 与 `LLMNetworkProviderAdapterRetryTests` 里直接抛 `HTTPNetworkError` 的桩不同，
/// 这里用 URLProtocol 桩驱动**真实** `NetworkProvider.request` 的 URLError 转换路径，
/// 锁定底层码被保留，并端到端验证确实触发重试。
@Suite(.serialized)
struct NetworkProviderURLErrorCodeTests {

    /// 按请求路径返回对应 URLError 的桩，驱动真实 URLSession → NetworkProvider.request。
    private final class URLErrorFailingProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let code: URLError.Code
            switch request.url?.path {
            case "/timed-out": code = .timedOut
            case "/offline": code = .notConnectedToInternet
            case "/connection-lost": code = .networkConnectionLost
            default: code = .cannotConnectToHost
            }
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }

        override func stopLoading() {}
    }

    private func makeProvider() -> NetworkProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLErrorFailingProtocol.self]
        return NetworkProvider(session: URLSession(configuration: configuration))
    }

    @Test("request 保留 URLError 的底层码", arguments: [
        ("/timed-out", NSURLErrorTimedOut),
        ("/offline", NSURLErrorNotConnectedToInternet),
        ("/connection-lost", NSURLErrorNetworkConnectionLost),
    ])
    func requestPreservesURLErrorCode(path: String, expectedCode: Int) async throws {
        let provider = makeProvider()
        do {
            _ = try await provider.request(
                HTTPRequest(url: URL(string: "https://offline.invalid\(path)")!)
            )
            Issue.record("传输失败应抛错")
        } catch let error as HTTPNetworkError {
            #expect(
                error.underlyingCode == expectedCode,
                "底层码必须保留，否则上层无法归一化为可重试网络错误"
            )
        }
    }

    // MARK: - 端到端：真实 request 路径的传输错误确实触发重试

    /// 线程安全请求计数器（实例 + NSLock，避免 Swift 6 全局可变状态告警）。
    private final class RequestCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
        func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
        func reset() { lock.lock(); defer { lock.unlock() }; count = 0 }
    }

    /// 始终超时并计数的桩，用于端到端重试验证。
    private final class CountingTimeoutProtocol: URLProtocol {
        static let counter = RequestCounter()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.counter.increment()
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
        }

        override func stopLoading() {}
    }

    @Test("非流式超时经真实 request 路径触发重试至上限")
    func nonStreamingTimeoutRetriesThroughRealRequestPath() async throws {
        CountingTimeoutProtocol.counter.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CountingTimeoutProtocol.self]
        let provider = NetworkProvider(session: URLSession(configuration: configuration))
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(provider))

        var request = URLRequest(url: URL(string: "https://offline.invalid/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")

        await #expect(throws: (any Error).self) {
            _ = try await service.send(request: request)
        }
        #expect(
            CountingTimeoutProtocol.counter.value == 3,
            "超时应触发 maxAttempts=3 次重试，实际 \(CountingTimeoutProtocol.counter.value) 次"
        )
    }
}