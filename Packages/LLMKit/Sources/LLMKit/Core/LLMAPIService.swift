import Foundation
import HttpKit

/// LLM API 服务
///
/// 保留 LLM 模块内的调用入口，底层 HTTP 传输能力由 `HttpKit` 提供。
/// 此类不包含重试逻辑，重试策略由上层统一管理。
public class LLMAPIService: @unchecked Sendable {
    private let client: HTTPClient

    public init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    /// 发送聊天完成请求（单次，不含重试）。
    public func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        try await client.sendJSONRequest(request: request, body: body)
    }

    /// 发送流式聊天请求，使用 SSE 空行分隔事件。
    public func sendStreamingRequest(
        request: URLRequest,
        body: [String: Any],
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in },
        onResponseReceived: @Sendable @escaping (HTTPURLResponse) async -> Void = { _ in },
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        try await client.sendStreamingJSONRequest(
            request: request,
            body: body,
            onRequestStart: onRequestStart,
            onResponseReceived: onResponseReceived,
            onEvent: onChunk
        )
    }
}
