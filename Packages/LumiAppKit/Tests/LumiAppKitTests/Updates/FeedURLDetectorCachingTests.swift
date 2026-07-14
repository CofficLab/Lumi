import Foundation
import Testing
@testable import LumiAppKit

/// `FeedURLDetector` 缓存窗口与强制刷新行为测试
struct FeedURLDetectorCachingTests {

    @Test
    func firstDetectSwitchesToPrimary() async {
        let detector = FeedURLDetector(
            initialURL: URL(string: "https://initial.example/appcast.xml")!,
            reachabilityChecker: AlwaysReachableChecker(),
            cacheWindow: 60,
            clock: { Date(timeIntervalSinceReferenceDate: 1_000) }
        )

        await detector.detectIfNeeded()
        let resolved = await detector.resolvedFeedURL
        // 默认实现下 resolvePrimaryFeedURL 永远返回 UpdateFeedURLProvider.primary。
        #expect(resolved == UpdateFeedURLProvider.primary)
    }

    @Test
    func secondDetectWithinCacheWindowIsNoOp() async {
        let callCount = CallCountingChecker()
        let detector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary,
            reachabilityChecker: callCount,
            cacheWindow: 3600,
            // clock 永远返回相同时间，确保两次都在窗口内
            clock: { Date(timeIntervalSinceReferenceDate: 1_000_000) }
        )

        // 首次探测
        await detector.detectIfNeeded()
        // 二次探测（同一时间点 → 必定命中缓存）
        await detector.detectIfNeeded()

        #expect(callCount.count == 1)
    }

    @Test
    func secondDetectAfterCacheWindowRechecks() async {
        let now = MockClock()
        let callCount = CallCountingChecker()
        let detector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary,
            reachabilityChecker: callCount,
            cacheWindow: 60,
            clock: { now.currentDate }
        )

        await detector.detectIfNeeded()
        now.advance(by: 120) // 超出 60s 窗口
        await detector.detectIfNeeded()

        #expect(callCount.count == 2)
    }

    @Test
    func forceRedetectBypassesCacheWindow() async {
        let callCount = CallCountingChecker()
        let detector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary,
            reachabilityChecker: callCount,
            cacheWindow: 3600, // 大窗口
            clock: { Date(timeIntervalSinceReferenceDate: 0) }
        )

        await detector.detectIfNeeded()
        await detector.forceRedetect()

        #expect(callCount.count == 2)
    }
}

/// `URLSessionReachabilityChecker` 的协议契约测试
///
/// 该测试用自定义 URLProtocol 拦截请求，避免依赖真实网络。
/// 由于 `MockURLProtocol.handler` 是进程级共享状态，必须串行执行。
@Suite(.serialized)
struct URLSessionReachabilityCheckerTests {

    @Test
    func returnsTrueForHTTP200() async {
        let session = makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }
        let checker = URLSessionReachabilityChecker(timeout: 5, session: session)

        let reachable = await checker.isReachable(URL(string: "https://example.com/appcast.xml")!)
        #expect(reachable == true)
    }

    @Test
    func returnsFalseForNon200() async {
        let session = makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }
        let checker = URLSessionReachabilityChecker(timeout: 5, session: session)

        let reachable = await checker.isReachable(URL(string: "https://example.com/appcast.xml")!)
        #expect(reachable == false)
    }

    @Test
    func returnsFalseOnNetworkError() async {
        let session = makeMockedSession { _ in
            throw URLError(.notConnectedToInternet)
        }
        let checker = URLSessionReachabilityChecker(timeout: 5, session: session)

        let reachable = await checker.isReachable(URL(string: "https://example.com/appcast.xml")!)
        #expect(reachable == false)
    }

    // MARK: - Mocked session helper

    private func makeMockedSession(
        handler: @escaping (URLRequest) async throws -> (URLResponse, Data)
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        // 配置 stub 行为（每次配置都会被读取）
        MockURLProtocol.handler = handler
        return session
    }
}

// MARK: - 测试辅助类型

/// 总是可达的 stub。
private struct AlwaysReachableChecker: FeedURLReachabilityChecker {
    func isReachable(_ url: URL) async -> Bool { true }
}

/// 计数被调用次数的 stub。
private final class CallCountingChecker: FeedURLReachabilityChecker, @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }

    func isReachable(_ url: URL) async -> Bool {
        lock.lock(); _count += 1; lock.unlock()
        return true
    }
}

/// 可手动推进的虚拟时钟。
private final class MockClock: @unchecked Sendable {
    private var now: Date
    init() {
        self.now = Date(timeIntervalSinceReferenceDate: 0)
    }

    var currentDate: Date {
        lock.lock(); defer { lock.unlock() }
        return now
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        now = now.addingTimeInterval(seconds)
    }

    private let lock = NSLock()
}

/// 自定义 URLProtocol：用闭包返回响应/数据/错误。
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler:
        ((URLRequest) async throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            guard let handler = Self.handler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            do {
                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}