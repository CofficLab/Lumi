import Foundation
import Testing
@testable import KitLLM

/// `Retry-After` 解析、退避计算与重试等待时长的单元测试。
///
/// ## 覆盖的行为
///
/// - `Retry-After` 的两种合法形式（`delay-seconds` 与 `HTTP-date`）；
/// - 响应头键的大小写不敏感；
/// - 非法/过期/超长值的处理；
/// - 等抖动退避的取值区间与单调性；
/// - 服务端给出 `Retry-After` 时精确遵守、不叠加抖动。
struct RetryAfterAndBackoffTests {

    // MARK: - Retry-After 解析

    @Test("delay-seconds 形式被解析为秒数")
    func parsesDelaySeconds() {
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "30"]) == 30)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "0"]) == 0)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "  7  "]) == 7)
    }

    @Test("响应头键大小写不敏感")
    func headerLookupIsCaseInsensitive() {
        #expect(HTTPRetryAfter.seconds(from: ["retry-after": "12"]) == 12)
        #expect(HTTPRetryAfter.seconds(from: ["RETRY-AFTER": "12"]) == 12)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "12"]) == 12)
    }

    @Test("HTTP-date 形式按基准时间换算为等待秒数")
    func parsesHTTPDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let target = now.addingTimeInterval(45)
        let raw = Self.imfFixdate(target)

        let seconds = HTTPRetryAfter.seconds(from: ["Retry-After": raw], now: now)
        #expect(seconds != nil)
        #expect(abs((seconds ?? 0) - 45) < 1, "HTTP-date 应换算为距基准时间的秒数")
    }

    @Test("指向过去的 HTTP-date 视为无有效建议")
    func pastHTTPDateYieldsNoAdvice() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let raw = Self.imfFixdate(now.addingTimeInterval(-120))

        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": raw], now: now) == nil)
    }

    @Test("缺失、空白与非法值均视为无建议")
    func invalidValuesYieldNoAdvice() {
        #expect(HTTPRetryAfter.seconds(from: [:]) == nil)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": ""]) == nil)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "   "]) == nil)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "soon"]) == nil)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "-5"]) == nil)
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "1.5"]) == nil)
    }

    @Test("超过上限的等待时间被截断，避免回合被无限期阻塞")
    func capsExcessiveWait() {
        #expect(HTTPRetryAfter.seconds(from: ["Retry-After": "3600"]) == HTTPRetryAfter.maxHonoredSeconds)
        #expect(HTTPRetryAfter.maxHonoredSeconds == 60)
    }

    @Test("超出整数范围的秒数仍被识别为秒数并截断，而不是被当成非法格式")
    func capsExcessiveWaitBeyondIntegerRange() {
        let huge = "99999999999999999999"
        #expect(
            HTTPRetryAfter.seconds(from: ["Retry-After": huge]) == HTTPRetryAfter.maxHonoredSeconds,
            "超大秒数应被截断，而不是因整数溢出被忽略"
        )
    }

    // MARK: - 退避计算

    @Test("指数退避上限随失败次数翻倍")
    func exponentialCap() {
        #expect(ProviderRetryBackoff.cap(base: 1, attempt: 1) == 1)
        #expect(ProviderRetryBackoff.cap(base: 1, attempt: 2) == 2)
        #expect(ProviderRetryBackoff.cap(base: 1, attempt: 3) == 4)
        #expect(ProviderRetryBackoff.cap(base: 0, attempt: 3) == 0)
        // 非法 attempt 不得产生负指数。
        #expect(ProviderRetryBackoff.cap(base: 1, attempt: 0) == 1)
        #expect(ProviderRetryBackoff.cap(base: 1, attempt: -5) == 1)
    }

    @Test("等抖动退避落在 [cap/2, cap) 区间内")
    func equalJitterStaysInRange() {
        #expect(ProviderRetryBackoff.delay(base: 1, attempt: 1, randomUnit: 0) == 0.5)
        #expect(abs(ProviderRetryBackoff.delay(base: 1, attempt: 1, randomUnit: 1) - 1.0) < 0.0001)
        #expect(ProviderRetryBackoff.delay(base: 1, attempt: 2, randomUnit: 0) == 1)
        #expect(ProviderRetryBackoff.delay(base: 0, attempt: 3, randomUnit: 0.5) == 0)
    }

    @Test("退避带随机性：不同随机值产生不同等待，避免客户端同步重试")
    func jitterProducesDistinctDelays() {
        let first = ProviderRetryBackoff.delay(base: 1, attempt: 1, randomUnit: 0.1)
        let second = ProviderRetryBackoff.delay(base: 1, attempt: 1, randomUnit: 0.9)
        #expect(first != second)
        #expect(first > 0 && second > 0, "抖动不得退化为 0 延迟")
    }

    // MARK: - 重试策略

    @Test("策略采纳服务端给出的 Retry-After 作为等待时长")
    func policyUsesServerProvidedDelay() {
        let decision = ProviderRetryPolicy.decision(
            statusCode: 529,
            retryAfter: 30,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(decision.shouldRetry)
        #expect(decision.delaySeconds == 30)
    }

    @Test("无服务端建议时策略不给出固定等待，交由本地抖动退避决定")
    func policyLeavesDelayToLocalBackoffWhenNoAdvice() {
        let decision = ProviderRetryPolicy.decision(
            statusCode: 529,
            retryAfter: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(decision.shouldRetry)
        #expect(decision.delaySeconds == nil)
    }

    @Test("认证失败仍不可重试，且不因携带 Retry-After 而被放行")
    func unauthorizedIsNeverRetried() {
        let decision = ProviderRetryPolicy.decision(
            statusCode: 401,
            retryAfter: 30,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(!decision.shouldRetry, "Retry-After 不得扩大可重试范围")
    }

    @Test("非 429/5xx 的状态码即使带 Retry-After 也不可重试")
    func retryAfterDoesNotExpandRetryableStatusSet() {
        for status in [400, 401, 403, 404, 422] {
            let decision = ProviderRetryPolicy.decision(
                statusCode: status,
                retryAfter: 30,
                attempt: 1,
                maxAttempts: 3
            )
            #expect(
                !decision.shouldRetry,
                "HTTP \(status) 不应因 Retry-After 被判定为可重试"
            )
        }
    }

    @Test("429 与 5xx 仍是可重试的，且 Retry-After 决定等待时长")
    func retryableStatusesKeepWorking() {
        let rateLimited = ProviderRetryPolicy.decision(
            statusCode: 429,
            retryAfter: 5,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(rateLimited.shouldRetry)
        #expect(rateLimited.delaySeconds == 5)

        let overloaded = ProviderRetryPolicy.decision(
            statusCode: 529,
            retryAfter: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(overloaded.shouldRetry)
        #expect(overloaded.delaySeconds == nil)
    }

    @Test("超过 maxAttempts 后不再重试")
    func attemptsAreBounded() {
        let decision = ProviderRetryPolicy.decision(
            statusCode: 529,
            retryAfter: 30,
            attempt: 3,
            maxAttempts: 3
        )
        #expect(!decision.shouldRetry)
    }

    // MARK: - 错误载体

    @Test("VendorAPIError 携带服务端退避建议")
    func vendorErrorCarriesRetryAfter() {
        let error = VendorAPIError.httpStatus(
            statusCode: 529,
            summary: "当前服务集群负载较高，请稍后重试",
            retryAfterSeconds: 30
        )
        guard case let .httpStatus(code, summary, retryAfterSeconds) = error else {
            Issue.record("应构造为 httpStatus")
            return
        }
        #expect(code == 529)
        #expect(summary.contains("服务集群负载较高"))
        #expect(retryAfterSeconds == 30)
    }

    @Test("便捷构造的 HTTP 错误没有退避建议")
    func convenienceFactoryHasNoRetryAfter() {
        let error = VendorAPIError.httpStatus(401, "Unauthorized")
        guard case let .httpStatus(_, _, retryAfterSeconds) = error else {
            Issue.record("应构造为 httpStatus")
            return
        }
        #expect(retryAfterSeconds == nil)
        #expect(error.errorDescription?.contains("401") == true)
    }

    // MARK: - Helpers

    private static func imfFixdate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.string(from: date)
    }
}

/// `VendorAPIService` 的重试等待时长测试。
///
/// 用注入的等待器替代真实 `Task.sleep`：既避免单测耗时数十秒，又能直接
/// 断言「实际等了多久」。
struct VendorAPIServiceRetryDelayTests {

    @Test("无 Retry-After 时按带抖动的指数退避等待")
    func localBackoffIsJittered() async throws {
        let delays = DelayRecorder()
        let service = VendorAPIService(
            networkProvider: OverloadedNetwork(retryAfter: nil),
            maxAttempts: 3,
            baseRetryDelay: 1.0,
            sleeper: { seconds in await delays.record(seconds) }
        )

        await #expect(throws: (any Error).self) {
            _ = try await service.send(request: Self.request())
        }

        let recorded = await delays.values
        #expect(recorded.count == 2, "maxAttempts=3 → 最多等待两次")
        for (index, delay) in recorded.enumerated() {
            let cap = ProviderRetryBackoff.cap(base: 1, attempt: index + 1)
            #expect(delay >= cap / 2, "等待不得短于 cap/2：\(delay) < \(cap / 2)")
            #expect(delay < cap, "等待不得达到 cap：\(delay) >= \(cap)")
        }
    }

    @Test("服务端给出 Retry-After 时精确遵守，不叠加抖动")
    func honorsServerRetryAfterExactly() async throws {
        let delays = DelayRecorder()
        let service = VendorAPIService(
            networkProvider: OverloadedNetwork(retryAfter: 30),
            maxAttempts: 3,
            baseRetryDelay: 1.0,
            sleeper: { seconds in await delays.record(seconds) }
        )

        await #expect(throws: (any Error).self) {
            _ = try await service.send(request: Self.request())
        }

        let recorded = await delays.values
        #expect(recorded == [30, 30], "必须精确遵守服务端给出的 30s")
    }

    @Test("流式路径同样遵守 Retry-After")
    func streamingPathHonorsRetryAfter() async throws {
        let delays = DelayRecorder()
        let service = VendorAPIService(
            networkProvider: OverloadedNetwork(retryAfter: 12),
            maxAttempts: 2,
            baseRetryDelay: 1.0,
            sleeper: { seconds in await delays.record(seconds) }
        )

        await #expect(throws: (any Error).self) {
            try await service.sendStreamingChatRequest(
                request: Self.request(),
                body: ["model": "MiniMax-M3", "stream": true],
                onEvent: { _ in true }
            )
        }

        let recorded = await delays.values
        #expect(recorded == [12])
    }

    private static func request() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.minimaxi.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        return request
    }
}

// MARK: - Stubs

/// 始终返回 529 的网络桩，可选携带 `Retry-After` 建议。
private final class OverloadedNetwork: LLMNetworkProviding, @unchecked Sendable {
    private let retryAfter: TimeInterval?
    private(set) var requestCount = 0

    init(retryAfter: TimeInterval?) {
        self.retryAfter = retryAfter
    }

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        requestCount += 1
        throw VendorAPIError.httpStatus(
            statusCode: 529,
            summary: "当前服务集群负载较高，请稍后重试",
            retryAfterSeconds: retryAfter
        )
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        requestCount += 1
        throw VendorAPIError.httpStatus(
            statusCode: 529,
            summary: "当前服务集群负载较高，请稍后重试",
            retryAfterSeconds: retryAfter
        )
    }
}

/// 记录重试等待时长的线程安全收集器。
private actor DelayRecorder {
    private(set) var values: [TimeInterval] = []

    func record(_ seconds: TimeInterval) {
        values.append(seconds)
    }
}
