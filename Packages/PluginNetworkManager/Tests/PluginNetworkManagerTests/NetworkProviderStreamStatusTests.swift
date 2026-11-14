import Foundation
import KitLLM
import ProviderNetwork
import Testing
@testable import PluginNetworkManager

/// 回归 #163：流式 `NetworkProvider.stream` 此前先把 HTTP 错误正文回调给
/// `onChunk`，再到方法末尾才按状态码抛错。错误正文一旦回调，上层
/// `VendorAPIService` 的 `EventReceipt.hasReceived` 置真，「首个事件前断线
/// 才安全重试」的保护拒绝重放，529/5xx 的瞬态重试被永久禁止。
///
/// 与 `LLMNetworkProviderAdapterRetryTests` 里直接抛 `HTTPNetworkError`、
/// 不投递任何 chunk 的桩不同，这里用 URLProtocol 桩驱动**真实**
/// `NetworkProvider.stream`：返回 529 **且带 SSE 错误正文**，锁定正文绝不被
/// 当作模型事件转发，并端到端验证确实触发重试。
@Suite(.serialized)
struct NetworkProviderStreamStatusTests {

    /// 线程安全计数器（实例 + NSLock，避免 Swift 6 全局可变状态告警）。
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
        func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
        func reset() { lock.lock(); defer { lock.unlock() }; count = 0 }
    }

    /// 跨 `@Sendable` 闭包边界承载响应头状态码的线程安全盒子。
    private final class StatusBox: @unchecked Sendable {
        private let lock = NSLock()
        private var status: Int?
        func store(_ value: Int) { lock.lock(); defer { lock.unlock() }; status = value }
        var value: Int? { lock.lock(); defer { lock.unlock() }; return status }
    }

    /// 返回 HTTP 529 + SSE 错误正文并计数的桩，驱动真实 URLSession →
    /// NetworkProvider.stream。错误正文形如 `data: {...}\n\n`，若被当作
    /// 正常 SSE 事件转发，就会标记 EventReceipt、禁止重试。
    private final class OverloadedSSEProtocol: URLProtocol {
        static let requestCounter = Counter()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.requestCounter.increment()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 529,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("data: {\"error\":\"overloaded\"}\n\n".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func makeProvider() -> NetworkProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OverloadedSSEProtocol.self]
        return NetworkProvider(session: URLSession(configuration: configuration))
    }

    // MARK: - 根因层：错误正文绝不被当作模型事件转发

    @Test("流式 529 带错误正文时，onChunk 一次都不调用且按状态码抛错")
    func streamRejects529BodyWithoutForwardingEvents() async throws {
        let provider = makeProvider()
        let chunkCounter = Counter()
        let statusBox = StatusBox()

        do {
            try await provider.stream(
                HTTPRequest(url: URL(string: "https://overloaded.invalid/v1/chat/completions")!),
                onResponse: { metadata in statusBox.store(metadata.statusCode) },
                onChunk: { _ in chunkCounter.increment(); return true }
            )
            Issue.record("529 应抛错")
        } catch let error as HTTPNetworkError {
            #expect(
                error.statusCode == 529,
                "必须按状态码拒绝，实际 \(String(describing: error.statusCode))"
            )
        }

        #expect(statusBox.value == 529, "响应头状态码应透出给上层")
        #expect(
            chunkCounter.value == 0,
            "错误正文绝不能被当作模型事件转发，实际 \(chunkCounter.value) 次"
        )
    }

    // MARK: - 端到端：真实 stream 路径的 529 确实触发重试

    @Test("流式 529 经真实 stream 路径触发重试至上限且不转发事件")
    func streaming529RetriesThroughRealStreamPath() async throws {
        OverloadedSSEProtocol.requestCounter.reset()
        let provider = makeProvider()
        let service = VendorAPIService(
            networkProvider: LLMNetworkProviderAdapter(provider),
            sleeper: { _ in }
        )
        let eventCounter = Counter()

        var request = URLRequest(url: URL(string: "https://overloaded.invalid/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")

        await #expect(throws: (any Error).self) {
            try await service.sendStreamingChatRequest(
                request: request,
                body: ["model": "test", "stream": true],
                onEvent: { _ in eventCounter.increment(); return true }
            )
        }

        #expect(
            OverloadedSSEProtocol.requestCounter.value == 3,
            "529 应触发 maxAttempts=3 次重试，实际 \(OverloadedSSEProtocol.requestCounter.value) 次"
        )
        #expect(
            eventCounter.value == 0,
            "错误正文不应作为模型事件回调，实际 \(eventCounter.value) 次"
        )
    }
}