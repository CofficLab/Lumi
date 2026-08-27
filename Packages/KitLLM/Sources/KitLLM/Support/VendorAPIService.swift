import Foundation

/// 供应商统一的 API 传输服务。
///
/// 提供两条发送路径：
/// - `sendChatRequest` / `sendJSON`：非流式 JSON
/// - `sendStreamingChatRequest`：SSE 流式，逐事件回调原始 `Data`
///
/// 优先使用 `LLMNetworkProviding`（由宿主注入，支持 HTTP 交换记录等），
/// 未注入时回退到 URLSession。
public final class VendorAPIService: @unchecked Sendable {
    private let session: URLSession
    private let networkProvider: (any LLMNetworkProviding)?
    private let maxAttempts: Int
    private let baseRetryDelay: Double

    public init(
        session: URLSession = .shared,
        networkProvider: (any LLMNetworkProviding)? = nil,
        maxAttempts: Int = 3,
        baseRetryDelay: Double = 1.0
    ) {
        self.session = session
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
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            if let networkProvider {
                let (data, response) = try await networkProvider.send(request: request, body: bodyData)
                try validateResponse(response, data: data)
                return data
            }
            var mutableRequest = request
            mutableRequest.httpBody = bodyData
            let (data, response) = try await session.data(for: mutableRequest)
            try validateResponse(response, data: data)
            return data
        }
    }

    /// 发送任意 JSON 请求（Responses 协议等）。
    public func sendJSON(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        try await sendChatRequest(request: request, body: body)
    }

    /// 发送流式聊天完成请求（SSE）。
    ///
    /// - Parameters:
    ///   - request: 已配置 URL / Header 的请求（body 由本方法写入）。
    ///   - body: JSON 请求体（`stream: true` 由调用方在 body 中设置）。
    ///   - onEvent: 每个 SSE 事件块的原始 `Data`；返回 `false` 可提前终止读取。
    public func sendStreamingChatRequest(
        request: URLRequest,
        body: [String: Any],
        onEvent: @escaping @Sendable (Data) async -> Bool
    ) async throws {
        let receipt = EventReceipt()
        try await withRetry {
            receipt.reset()
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            let forward: @Sendable (Data) async -> Bool = { event in
                receipt.markReceived()
                return await onEvent(event)
            }
            if let networkProvider {
                try await networkProvider.stream(request: request, body: bodyData, onEvent: forward)
                return
            }

            var mutableRequest = request
            mutableRequest.httpBody = bodyData
            let (bytes, response) = try await session.bytes(for: mutableRequest)
            try validateResponse(response, data: nil)
            var lineBuffer = ""
            var eventBuffer = ""
            for try await char in bytes.characters {
                if char == "\n" {
                    if lineBuffer.isEmpty {
                        if !eventBuffer.isEmpty {
                            let eventData = Data(eventBuffer.utf8)
                            eventBuffer = ""
                            receipt.markReceived()
                            if !(await onEvent(eventData)) { return }
                        }
                    } else {
                        if !eventBuffer.isEmpty { eventBuffer += "\n" }
                        eventBuffer += lineBuffer
                    }
                    lineBuffer = ""
                } else if char != "\r" {
                    lineBuffer.append(char)
                }
            }
            if !eventBuffer.isEmpty {
                receipt.markReceived()
                _ = await onEvent(Data(eventBuffer.utf8))
            }
        } shouldRetry: { error, attempt in
            // 重放部分 SSE 会重复 token；只有首个事件前断线才安全重试。
            !receipt.hasReceived && self.retryDecision(for: error, attempt: attempt).shouldRetry
        }
    }

    // MARK: - Private

    private func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let summary = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let trimmed = summary.prefix(200)
            throw VendorAPIError.httpStatus(httpResponse.statusCode, String(trimmed))
        }
    }

    private func retryDecision(for error: Error, attempt: Int) -> ProviderRetryDecision {
        if case let .httpStatus(statusCode, _) = error as? VendorAPIError {
            return ProviderRetryPolicy.decision(statusCode: statusCode, retryAfter: nil, attempt: attempt, maxAttempts: maxAttempts)
        }
        if let httpError = error as? LLMHTTPErrorProviding, let statusCode = httpError.httpStatusCode {
            return ProviderRetryPolicy.decision(statusCode: statusCode, retryAfter: nil, attempt: attempt, maxAttempts: maxAttempts)
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
