import Foundation
import Testing
@testable import KitLLM

// MARK: - 测试替身

/// 可编程的网络替身：按顺序返回不同响应，并记录请求次数。
private final class SequenceNetworkProvider: LLMNetworkProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedResponses: [(data: Data, statusCode: Int)] = []
    private var storedStreamEvents: [[Data]] = []
    private var storedStreamError: Error?
    private var storedError: Error?
    private var storedRequestCount = 0

    func setResponses(_ responses: [(data: Data, statusCode: Int)]) {
        lock.withLock { storedResponses = responses }
    }

    func setStreamEvents(_ events: [[Data]]) {
        lock.withLock { storedStreamEvents = events }
    }

    func setStreamError(_ error: Error?) {
        lock.withLock { storedStreamError = error }
    }

    func setError(_ error: Error?) {
        lock.withLock { storedError = error }
    }

    var requestCount: Int { lock.withLock { storedRequestCount } }

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        let (picked, error) = lock.withLock { () -> ((data: Data, statusCode: Int)?, Error?) in
            storedRequestCount += 1
            if storedResponses.isEmpty { return (nil, storedError) }
            if storedResponses.count == 1 { return (storedResponses[0], storedError) }
            return (storedResponses.removeFirst(), storedError)
        }
        if let error { throw error }
        let url = request.url ?? URL(string: "https://example.invalid")!
        guard let picked else {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (Data(), response)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: picked.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (picked.data, response)
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let (eventGroups, streamError, error) = lock.withLock { () -> ([[Data]], Error?, Error?) in
            storedRequestCount += 1
            return (storedStreamEvents, storedStreamError, storedError)
        }
        if let error { throw error }
        let group = eventGroups.first ?? []
        for event in group {
            if !(await onEvent(event)) { return }
        }
        if let streamError { throw streamError }
    }
}

/// 记录退避等待时长的替身。
private final class RecordingSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [TimeInterval] = []

    func sleep(_ seconds: TimeInterval) async throws {
        lock.withLock { stored.append(seconds) }
    }

    var delays: [TimeInterval] { lock.withLock { stored } }
}

// MARK: - 重试

@Suite("VendorAPIService 重试")
struct VendorAPIServiceRetryTests {

    @Test("5xx 会重试并在成功后返回数据")
    func retriesOnServerError() async throws {
        let network = SequenceNetworkProvider()
        network.setResponses([
            (Data("busy".utf8), 503),
            (Data(#"{"ok":true}"#.utf8), 200),
        ])
        let sleeper = RecordingSleeper()
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 3,
            baseRetryDelay: 0.5,
            sleeper: { try await sleeper.sleep($0) }
        )
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)

        let data = try await service.sendChatRequest(request: request, body: [:])

        #expect(String(decoding: data, as: UTF8.self) == #"{"ok":true}"#)
        #expect(network.requestCount == 2)
        #expect(sleeper.delays.count == 1)
        #expect(sleeper.delays[0] > 0)
    }

    @Test("达到最大尝试次数后抛出状态码错误")
    func givesUpAfterMaxAttempts() async {
        let network = SequenceNetworkProvider()
        network.setResponses([(Data("busy".utf8), 503)])
        let sleeper = RecordingSleeper()
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 2,
            baseRetryDelay: 0,
            sleeper: { try await sleeper.sleep($0) }
        )
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)

        do {
            _ = try await service.sendChatRequest(request: request, body: [:])
            Issue.record("应当抛出 httpStatus 错误")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(statusCode, summary, _) = error else {
                Issue.record("错误类型不符: \(error)")
                return
            }
            #expect(statusCode == 503)
            #expect(summary == "busy")
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
        #expect(network.requestCount == 2)
    }

    @Test("4xx 不触发重试")
    func doesNotRetryOnClientError() async {
        let network = SequenceNetworkProvider()
        network.setResponses([(Data(#"{"error":"bad"}"#.utf8), 400)])
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 3,
            baseRetryDelay: 0,
            sleeper: { _ in }
        )
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)

        await #expect(throws: VendorAPIError.self) {
            try await service.sendChatRequest(request: request, body: [:])
        }
        #expect(network.requestCount == 1)
    }

    @Test("网络超时属于瞬态错误会被重试")
    func retriesOnTimeout() async throws {
        let network = SequenceNetworkProvider()
        let sleeper = RecordingSleeper()
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 2,
            baseRetryDelay: 0.5,
            sleeper: { try await sleeper.sleep($0) }
        )
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)

        // 网络替身被设为抛出超时错误，第一次调用直接失败。
        network.setError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
        await #expect(throws: NSError.self) {
            try await service.sendChatRequest(request: request, body: [:])
        }
        #expect(network.requestCount == 2)
        #expect(sleeper.delays.count == 1)
    }

    @Test("无 body 的 GET 请求同样走网络替身")
    func sendsRequestWithoutBody() async throws {
        let network = SequenceNetworkProvider()
        network.setResponses([(Data(#"{"models":[]}"#.utf8), 200)])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/models")!)

        let data = try await service.send(request: request)

        #expect(String(decoding: data, as: UTF8.self) == #"{"models":[]}"#)
    }

    @Test("JSON 请求体按键排序序列化")
    func sendsJSONBody() async throws {
        let network = SequenceNetworkProvider()
        network.setResponses([(Data("ok".utf8), 200)])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)

        _ = try await service.sendJSON(request: request, body: ["b": 2, "a": 1])

        #expect(network.requestCount == 1)
    }
}

// MARK: - 流式

@Suite("VendorAPIService 流式")
struct VendorAPIServiceStreamingTests {

    @Test("SSE 事件被逐个转发给回调")
    func forwardsStreamEvents() async throws {
        let network = SequenceNetworkProvider()
        network.setStreamEvents([[Data("one".utf8), Data("two".utf8)]])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)
        let collector = EventCollector()

        try await service.sendStreamingChatRequest(request: request, body: [:]) { event in
            collector.append(event)
            return true
        }

        #expect(collector.values == ["one", "two"])
    }

    @Test("回调返回 false 时提前终止读取")
    func stopsWhenCallbackReturnsFalse() async throws {
        let network = SequenceNetworkProvider()
        network.setStreamEvents([[Data("one".utf8), Data("two".utf8)]])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)
        let collector = EventCollector()

        try await service.sendStreamingChatRequest(request: request, body: [:]) { event in
            collector.append(event)
            return false
        }

        #expect(collector.values == ["one"])
    }

    @Test("已经收到事件后失败不重试，避免重复投递 token")
    func doesNotRetryAfterPartialStream() async throws {
        let network = SequenceNetworkProvider()
        network.setStreamEvents([[Data("one".utf8)]])
        network.setStreamError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost))
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 3,
            baseRetryDelay: 0,
            sleeper: { _ in }
        )
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)
        let collector = EventCollector()

        await #expect(throws: NSError.self) {
            try await service.sendStreamingChatRequest(request: request, body: [:]) { event in
                collector.append(event)
                return true
            }
        }

        #expect(collector.values == ["one"])
        #expect(network.requestCount == 1)
    }
}

/// 线程安全的事件收集器。
private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    func append(_ event: Data) {
        lock.withLock { stored.append(String(decoding: event, as: UTF8.self)) }
    }

    var values: [String] { lock.withLock { stored } }
}
