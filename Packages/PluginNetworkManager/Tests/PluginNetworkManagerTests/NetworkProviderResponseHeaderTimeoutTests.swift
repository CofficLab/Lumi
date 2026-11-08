import Foundation
import KitLLM
import ProviderNetwork
import Testing
@testable import PluginNetworkManager

/// 防回归测试：「等待响应头兜底超时后，流式请求仍可按默认策略重试」。
///
/// ## 历史 bug
///
/// `NetworkProvider.withResponseHeaderTimeout` 合成的超时错误只设置了
/// `underlyingDescription`，没有 `underlyingCode`。经 `LLMNetworkProviderAdapter`
/// 归一化后退化为 `VendorAPIError.requestFailed`，不命中
/// `ProviderRetryDecision` 的 `NSURLErrorTimedOut` 白名单，即使尚未收到任何
/// SSE 事件、重放安全，`VendorAPIService` 默认的三次尝试也只执行第一次。
struct NetworkProviderResponseHeaderTimeoutTests {

    /// 一个永远不返回响应头的 `URLProtocol` 桩：`startLoading` 什么都不做，
    /// 请求会一直挂起，直到兜底计时器取消它。
    private final class StalledURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {}
        override func stopLoading() {}
    }

    /// 把挂起请求收到的合成超时错误回放给适配器，模拟生产链路。
    private final class TimeoutThrowingNetwork: NetworkProviding, @unchecked Sendable {
        private let error: Error

        init(error: Error) {
            self.error = error
        }

        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            throw error
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            throw error
        }
    }

    private func stalledSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StalledURLProtocol.self]
        configuration.timeoutIntervalForRequest = 300
        return URLSession(configuration: configuration)
    }

    @Test
    func stalledResponseHeaderTimeoutSurvivesRetryClassification() async throws {
        let url = URL(string: "https://stall.invalid/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // 真实走一次兜底竞速：响应头永远不来，只有 0.2s 计时器能结束等待。
        var syntheticTimeout: Error?
        do {
            _ = try await NetworkProvider.withResponseHeaderTimeout(
                session: stalledSession(),
                urlRequest: urlRequest,
                url: url,
                timeout: 0.2
            )
            Issue.record("挂起的响应头应触发兜底超时")
        } catch {
            syntheticTimeout = error
        }

        // 根因层：合成错误必须带可重试的超时码。
        let networkError = try #require(syntheticTimeout as? HTTPNetworkError)
        #expect(networkError.underlyingCode == NSURLErrorTimedOut)

        // 生产链：适配器归一化后必须仍是 NSURLError 超时，而不是 requestFailed。
        let adapter = LLMNetworkProviderAdapter(TimeoutThrowingNetwork(error: networkError))
        var normalizedError: Error?
        do {
            try await adapter.stream(
                request: URLRequest(url: url),
                body: Data(),
                onEvent: { _ in true }
            )
        } catch {
            normalizedError = error
        }
        let nsError = try #require(normalizedError as NSError?)
        #expect(nsError.domain == NSURLErrorDomain)
        #expect(nsError.code == NSURLErrorTimedOut)

        // 最终判定：默认三次尝试下，首次超时必须被判定为可重试。
        let decision = OpenAICompatibleProviderAdapter.retryDecision(
            for: nsError,
            statusCode: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(decision.shouldRetry == true)
    }
}
