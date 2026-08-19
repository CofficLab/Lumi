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

    public init(session: URLSession = .shared, networkProvider: (any LLMNetworkProviding)? = nil) {
        self.session = session
        self.networkProvider = networkProvider
    }

    /// 发送聊天完成请求（单次，不含重试）。
    public func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
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
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        if let networkProvider {
            try await networkProvider.stream(request: request, body: bodyData, onEvent: onEvent)
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
                    // 空行 = SSE 事件分隔符
                    if !eventBuffer.isEmpty {
                        let eventData = Data(eventBuffer.utf8)
                        eventBuffer = ""
                        let shouldContinue = await onEvent(eventData)
                        if !shouldContinue { return }
                    }
                } else {
                    // 累积到事件缓冲
                    if !eventBuffer.isEmpty { eventBuffer += "\n" }
                    eventBuffer += lineBuffer
                }
                lineBuffer = ""
            } else if char != "\r" {
                lineBuffer.append(char)
            }
        }

        // 处理最后一个事件（无尾部空行）
        if !eventBuffer.isEmpty {
            _ = await onEvent(Data(eventBuffer.utf8))
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
}
