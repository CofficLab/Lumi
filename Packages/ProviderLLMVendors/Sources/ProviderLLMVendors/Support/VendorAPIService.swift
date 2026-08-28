import Foundation
import KitHttp
import ProviderNetwork

/// 新版供应商统一的 API 传输服务（精简自旧版 `LLMAPIService`）。
///
/// 提供 KernelCore 生态需要的两条发送路径：
/// - `sendChatRequest` / `sendJSON`：非流式 JSON，`.sortedKeys` 保证字节稳定（前缀缓存匹配）；
/// - `sendStreamingChatRequest`：SSE 流式，逐事件回调原始 `Data`（含 `data:` 前缀），
///   由调用方（adapter 的 `parseStreamChunk`）自行解析；
/// - 优先使用 `NetworkProviding`（支持 HTTP 交换记录），回退到 `KitHttp.HTTPClient`。
public final class VendorAPIService: @unchecked Sendable {
    private let client: HTTPClient
    private let networkProvider: (any NetworkProviding)?
    private let maxAttempts: Int
    private let baseRetryDelay: Double

    /// 初始化传输服务。
    ///
    /// - Parameters:
    ///   - client: KitHttp 客户端（当 `networkProvider` 为 nil 时使用）
    ///   - networkProvider: 可选的网络提供者，优先使用以支持 HTTP 交换记录
    public init(
        client: HTTPClient = HTTPClient(),
        networkProvider: (any NetworkProviding)? = nil,
        maxAttempts: Int = 3,
        baseRetryDelay: Double = 1.0
    ) {
        self.client = client
        self.networkProvider = networkProvider
        self.maxAttempts = max(1, maxAttempts)
        self.baseRetryDelay = max(0, baseRetryDelay)
    }

    /// 发送聊天完成请求；只对瞬态网络错误和可恢复 HTTP 状态重试。
    public func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        try await withRetry {
            if let networkProvider {
                return try await sendViaNetworkProvider(networkProvider, request: request, body: body)
            }
            return try await client.sendJSONRequest(request: request, body: body)
        }
    }

    /// 发送任意 JSON 请求（Responses 协议等）。
    public func sendJSON(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        try await withRetry {
            if let networkProvider {
                return try await sendViaNetworkProvider(networkProvider, request: request, body: body)
            }
            return try await client.sendJSONRequest(request: request, body: body)
        }
    }

    /// 发送流式聊天完成请求（SSE）。
    ///
    /// - Parameters:
    ///   - request: 已配置 URL / Header 的请求（body 由本方法写入）。
    ///   - body: JSON 请求体（`stream: true` 由调用方在 body 中设置）。
    ///   - onEvent: 每个 SSE 事件块（可能含 `event:` / `data:` 行）的原始 `Data`；
    ///     返回 `false` 可提前终止读取（如收到 `[DONE]`）。
    public func sendStreamingChatRequest(
        request: URLRequest,
        body: [String: Any],
        onEvent: @escaping @Sendable (Data) async -> Bool
    ) async throws {
        let receipt = EventReceipt()
        try await withRetry {
            receipt.reset()
            let forward: @Sendable (Data) async -> Bool = { event in
                receipt.markReceived()
                return await onEvent(event)
            }
            if let networkProvider {
                try await streamViaNetworkProvider(networkProvider, request: request, body: body, onEvent: forward)
                return
            }
            try await client.sendStreamingJSONRequest(request: request, body: body, onEvent: forward)
        } shouldRetry: { error, attempt in
            !receipt.hasReceived && self.retryDecision(for: error, attempt: attempt).shouldRetry
        }
    }

    // MARK: - NetworkProviding Bridge

    /// 通过 NetworkProviding 发送非流式请求
    private func sendViaNetworkProvider(
        _ provider: any NetworkProviding,
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"

        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: bodyData,
            timeout: request.timeoutInterval
        )
        let response = try await provider.request(httpRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPNetworkError(
                url: response.url,
                statusCode: response.statusCode,
                headers: response.headers,
                body: response.body
            )
        }
        return response.body
    }

    /// 通过 NetworkProviding 发送流式请求
    private func streamViaNetworkProvider(
        _ provider: any NetworkProviding,
        request: URLRequest,
        body: [String: Any],
        onEvent: @escaping @Sendable (Data) async -> Bool
    ) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"

        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: bodyData,
            timeout: request.timeoutInterval
        )

        let responseState = StreamResponseState()
        try await provider.stream(
            httpRequest,
            onResponse: { metadata in responseState.metadata = metadata },
            onChunk: { chunk in
                guard responseState.metadata.map({ (200..<300).contains($0.statusCode) }) ?? true else { return true }
                return await onEvent(chunk)
            }
        )
        if let metadata = responseState.metadata, !(200..<300).contains(metadata.statusCode) {
            throw HTTPNetworkError(url: metadata.url, statusCode: metadata.statusCode, headers: metadata.headers)
        }
    }

    private func retryDecision(for error: Error, attempt: Int) -> ProviderRetryDecision {
        if let networkError = error as? HTTPNetworkError {
            if let statusCode = networkError.statusCode {
                return ProviderRetryPolicy.decision(statusCode: statusCode, retryAfter: nil, attempt: attempt, maxAttempts: maxAttempts)
            }
            if let underlyingCode = networkError.underlyingCode {
                return ProviderRetryPolicy.decision(
                    forNetworkError: NSError(domain: NSURLErrorDomain, code: underlyingCode),
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            }
            return ProviderRetryPolicy.decision(forNetworkError: error, attempt: attempt, maxAttempts: maxAttempts)
        }
        return ProviderRetryPolicy.decision(forNetworkError: error, attempt: attempt, maxAttempts: maxAttempts)
    }

    private func withRetry<T>(
        _ operation: () async throws -> T,
        shouldRetry: ((Error, Int) -> Bool)? = nil
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                try Task.checkCancellation()
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let decision = retryDecision(for: error, attempt: attempt)
                let allowed = shouldRetry?(error, attempt) ?? decision.shouldRetry
                guard allowed else { throw error }
                let delay = decision.delaySeconds ?? baseRetryDelay * pow(2.0, Double(attempt - 1))
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                attempt += 1
            }
        }
    }
}

private final class StreamResponseState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedMetadata: HTTPResponseMetadata?

    var metadata: HTTPResponseMetadata? {
        get {
            lock.lock(); defer { lock.unlock() }
            return storedMetadata
        }
        set {
            lock.lock(); defer { lock.unlock() }
            storedMetadata = newValue
        }
    }
}

private final class EventReceipt: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var hasReceived: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        value = false
    }

    func markReceived() {
        lock.lock(); defer { lock.unlock() }
        value = true
    }
}
