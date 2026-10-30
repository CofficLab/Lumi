import Foundation
import KitLLM
import ProviderAgentLoop
import ProviderNetwork
import Testing
@testable import PluginNetworkManager

/// 防回归测试：「供应商返回 529 时应自动重试」。
///
/// ## 历史 bug
///
/// MiniMax 返回 `HTTP 529`（服务集群负载较高）时，用户回合直接失败，
/// 既不触发传输层重试，也不触发 AgentLoop 整回合重试。
///
/// ## 根因
///
/// 529 落在 `ProviderRetryPolicy` 的可重试区间（`500...599`）内，本应重试。
/// 但两层重试提取状态码的方式都是 `error as? LLMHTTPErrorProviding` /
/// `VendorAPIError`，而 `ProviderNetwork.HTTPNetworkError` 二者都不满足
/// —— 它只有同名的 `statusCode` 存储属性，而 Swift 的 `as?` 按协议遵循分派、
/// 不做鸭子类型匹配。
///
/// 状态码提取失败 → 退化为 `decision(forNetworkError:)` → 该错误不在
/// `NSURLErrorDomain` 的可重试码列表中 → `shouldRetry = false`。
///
/// 修复：`LLMNetworkProviderAdapter` 作为传输层错误边界，把 `HTTPNetworkError`
/// 归一化为 `VendorAPIError.httpStatus(code, summary)`，两层重试随即恢复。
@MainActor
struct LLMNetworkProviderAdapterRetryTests {

    // MARK: - 桩

    /// 始终返回 529 的 `NetworkProviding` 桩，形状与真实
    /// `PluginNetworkManager.NetworkProvider` 的错误抛出一致：
    /// 非 2xx 时抛 `HTTPNetworkError(statusCode:headers:body:)`。
    ///
    /// `retryAfter` 非空时按真实供应商的行为附加 `Retry-After` 响应头。
    private final class OverloadedNetwork: NetworkProviding, @unchecked Sendable {
        private(set) var requestCount = 0
        private let retryAfter: String?

        init(retryAfter: String? = nil) {
            self.retryAfter = retryAfter
        }

        private var headers: [String: String] {
            guard let retryAfter else { return [:] }
            return ["Retry-After": retryAfter]
        }

        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            requestCount += 1
            throw HTTPNetworkError(
                url: request.url,
                statusCode: 529,
                headers: headers,
                body: Data(#"{"error":{"message":"当前服务集群负载较高，请稍后重试"}}"#.utf8)
            )
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            requestCount += 1
            await onResponse(HTTPResponseMetadata(
                statusCode: 529,
                headers: headers,
                url: request.url
            ))
            throw HTTPNetworkError(
                url: request.url,
                statusCode: 529,
                headers: headers,
                body: Data(#"{"error":{"message":"当前服务集群负载较高，请稍后重试"}}"#.utf8)
            )
        }
    }

    /// 连接类失败（无 HTTP 状态码，带底层 NSURLError 码）。
    private final class OfflineNetwork: NetworkProviding, @unchecked Sendable {
        private(set) var requestCount = 0

        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            requestCount += 1
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: "连接超时",
                underlyingCode: NSURLErrorTimedOut
            )
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            requestCount += 1
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: "连接超时",
                underlyingCode: NSURLErrorTimedOut
            )
        }
    }

    private func chatRequest() throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.minimaxi.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - 根因层：状态码被正确提取

    @Test("修复后：529 被归一化为 VendorAPIError.httpStatus，重试策略可识别")
    func errorIsNormalizedToRetryableHTTPStatus() async throws {
        let network = OverloadedNetwork()
        let adapter = LLMNetworkProviderAdapter(network)

        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
            Issue.record("529 应抛错")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(code, summary, _) = error else {
                Issue.record("应归一为 httpStatus，实际为 \(error)")
                return
            }
            #expect(code == 529)
            // 摘要从 JSON 信封提取，供错误卡片展示
            #expect(summary.contains("服务集群负载较高"))
        }
    }

    @Test("修复后：归一化错误命中可重试判定（500...599）")
    func normalizedErrorIsClassifiedRetryable() async throws {
        let network = OverloadedNetwork()
        let adapter = LLMNetworkProviderAdapter(network)

        var thrown: Error?
        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
        } catch {
            thrown = error
        }

        let decision = OpenAICompatibleProviderAdapter.retryDecision(
            for: try #require(thrown),
            statusCode: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(decision.shouldRetry == true, "529 归一化后应被判定为可重试")
    }

    @Test("修复后：AgentLoopFailure 归类为 .server 且可整回合重试")
    func agentLoopFailureIsRetryable() async throws {
        let network = OverloadedNetwork()
        let adapter = LLMNetworkProviderAdapter(network)

        var thrown: Error?
        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
        } catch {
            thrown = error
        }

        let failure = AgentLoopFailure.from(
            error: try #require(thrown),
            providerID: "minimax-tokenplan",
            modelName: "MiniMax-M3"
        )
        #expect(failure.kind == .server)
        #expect(failure.isRetryable, "AgentLoop 层也应触发整回合重试")
        #expect(failure.httpStatusCode == 529)
    }

    // MARK: - 表现层：端到端确实重试

    @Test("修复后：529 触发传输层重试至 maxAttempts 上限")
    func vendorAPIServiceRetriesOn529() async throws {
        let network = OverloadedNetwork()
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(network))

        do {
            _ = try await service.send(request: try chatRequest())
            Issue.record("529 应抛错")
        } catch {
            #expect((error as? VendorAPIError) != nil)
        }

        #expect(
            network.requestCount == 3,
            "529 应触发 maxAttempts=3 次重试，实际 \(network.requestCount) 次"
        )
    }

    @Test("修复后：流式路径 529 同样触发重试")
    func streamingPathRetriesOn529() async throws {
        let network = OverloadedNetwork()
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(network))

        do {
            try await service.sendStreamingChatRequest(
                request: try chatRequest(),
                body: ["model": "MiniMax-M3", "stream": true],
                onEvent: { _ in true }
            )
            Issue.record("529 应抛错")
        } catch {
            #expect((error as? VendorAPIError) != nil)
        }

        #expect(
            network.requestCount == 3,
            "流式路径也应重试至上限，实际 \(network.requestCount) 次"
        )
    }

    @Test("修复后：流式响应头 529 在转发任何 SSE 事件前抛出，保护重放安全")
    func streamingRejectsNon2xxBeforeForwardingEvents() async throws {
        // 桩在响应头阶段报 529 且不投递任何 chunk：
        // 若适配层先转发事件再报错，VendorAPIService 的 EventReceipt 会置真，
        // 后续错误将因「重放会重复 token」而拒绝重试。
        let network = OverloadedNetwork()
        let adapter = LLMNetworkProviderAdapter(network)
        let counter = Counter()

        do {
            try await adapter.stream(
                request: try chatRequest(),
                body: Data(),
                onEvent: { _ in counter.increment(); return true }
            )
            Issue.record("529 应抛错")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(code, _, _) = error else {
                Issue.record("应归一为 httpStatus")
                return
            }
            #expect(code == 529)
        }

        #expect(counter.value == 0, "响应头即 529 时不应转发任何 SSE 事件")
    }

    // MARK: - Retry-After：服务端给出的退避建议必须一路带到重试策略

    @Test("529 携带 Retry-After 时，归一化错误保留服务端建议的等待时间")
    func normalizedErrorCarriesRetryAfter() async throws {
        let network = OverloadedNetwork(retryAfter: "30")
        let adapter = LLMNetworkProviderAdapter(network)

        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
            Issue.record("529 应抛错")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(code, _, retryAfterSeconds) = error else {
                Issue.record("应归一为 httpStatus，实际为 \(error)")
                return
            }
            #expect(code == 529)
            #expect(retryAfterSeconds == 30, "服务端建议的 30s 必须被保留")
        }
    }

    @Test("Retry-After 进入重试决策，成为实际等待时长")
    func retryAfterBecomesRetryDelay() async throws {
        let network = OverloadedNetwork(retryAfter: "30")
        let adapter = LLMNetworkProviderAdapter(network)

        var thrown: Error?
        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
        } catch {
            thrown = error
        }

        let decision = OpenAICompatibleProviderAdapter.retryDecision(
            for: try #require(thrown),
            statusCode: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(decision.shouldRetry)
        #expect(decision.delaySeconds == 30, "应采用服务端建议的 30s 作为等待时长")
    }

    @Test("流式路径同样保留 Retry-After")
    func streamingPathCarriesRetryAfter() async throws {
        let network = OverloadedNetwork(retryAfter: "15")
        let adapter = LLMNetworkProviderAdapter(network)

        do {
            try await adapter.stream(
                request: try chatRequest(),
                body: Data(),
                onEvent: { _ in true }
            )
            Issue.record("529 应抛错")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(_, _, retryAfterSeconds) = error else {
                Issue.record("应归一为 httpStatus")
                return
            }
            #expect(retryAfterSeconds == 15)
        }
    }

    @Test("没有 Retry-After 头时退避建议为空，交由本地抖动退避决定")
    func missingRetryAfterYieldsNoAdvice() async throws {
        let network = OverloadedNetwork(retryAfter: nil)
        let adapter = LLMNetworkProviderAdapter(network)

        var thrown: Error?
        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
        } catch {
            thrown = error
        }

        guard case let .httpStatus(_, _, retryAfterSeconds) = try #require(thrown) as? VendorAPIError else {
            Issue.record("应归一为 httpStatus")
            return
        }
        #expect(retryAfterSeconds == nil)
    }

    @Test("AgentLoopFailure 保留服务端退避建议，供整回合重试遵守")
    func agentLoopFailureCarriesRetryAfter() async throws {
        let network = OverloadedNetwork(retryAfter: "30")
        let adapter = LLMNetworkProviderAdapter(network)

        var thrown: Error?
        do {
            _ = try await adapter.send(request: try chatRequest(), body: Data())
        } catch {
            thrown = error
        }

        let failure = AgentLoopFailure.from(error: try #require(thrown))
        #expect(failure.kind == .server)
        #expect(failure.isRetryable)
        #expect(failure.httpStatusCode == 529)
        #expect(failure.retryAfterSeconds == 30)
    }

    // MARK: - 不回归：取消与非重试错误

    @Test("取消错误原样透出，不触发重试")
    func cancellationPassesThroughWithoutRetry() async throws {
        let network = CancelledNetwork()
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(network))

        await #expect(throws: CancellationError.self) {
            _ = try await service.send(request: try chatRequest())
        }
        #expect(network.requestCount == 1, "用户取消不应重试")
    }

    @Test("4xx 客户端错误仍不重试（避免放大无效请求）")
    func clientErrorStillDoesNotRetry() async throws {
        let network = BadRequestNetwork()
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(network))

        do {
            _ = try await service.send(request: try chatRequest())
            Issue.record("400 应抛错")
        } catch {
            #expect((error as? VendorAPIError) != nil)
        }
        #expect(network.requestCount == 1, "400 不应重试")
    }

    @Test("连接类失败（NSURLError 码）行为不变：可重试")
    func transportFailureStillRetries() async throws {
        let network = OfflineNetwork()
        let service = VendorAPIService(networkProvider: LLMNetworkProviderAdapter(network))

        await #expect(throws: (any Error).self) {
            _ = try await service.send(request: try chatRequest())
        }
        #expect(
            network.requestCount == 3,
            "超时属可重试网络错误，应重试至上限，实际 \(network.requestCount) 次"
        )
    }
}

// MARK: - Helpers

/// 跨 `@Sendable` 闭包边界的线程安全计数器。
///
/// `onEvent` 以 `@Sendable` 闭包并发执行，直接捕获并修改局部变量会触发
/// Swift 6 并发检查（`mutation of captured var in concurrently-executing code`）。
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }
}

/// 始终抛取消错误的网络桩。
private final class CancelledNetwork: NetworkProviding, @unchecked Sendable {
    private(set) var requestCount = 0

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestCount += 1
        throw CancellationError()
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        requestCount += 1
        throw CancellationError()
    }
}

/// 始终返回 400 的网络桩。
private final class BadRequestNetwork: NetworkProviding, @unchecked Sendable {
    private(set) var requestCount = 0

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestCount += 1
        throw HTTPNetworkError(
            url: request.url,
            statusCode: 400,
            headers: [:],
            body: Data(#"{"error":{"message":"invalid api key"}}"#.utf8)
        )
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        requestCount += 1
        throw HTTPNetworkError(
            url: request.url,
            statusCode: 400,
            headers: [:],
            body: Data(#"{"error":{"message":"invalid api key"}}"#.utf8)
        )
    }
}
