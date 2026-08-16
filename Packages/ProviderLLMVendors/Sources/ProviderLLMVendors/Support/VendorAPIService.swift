import Foundation
import HttpKit

/// 新版供应商统一的 API 传输服务（精简自旧版 `LLMAPIService`）。
///
/// 提供 KernelCore 生态需要的两条发送路径：
/// - `sendChatRequest` / `sendJSON`：非流式 JSON，`.sortedKeys` 保证字节稳定（前缀缓存匹配）；
/// - `sendStreamingChatRequest`：SSE 流式，逐事件回调原始 `Data`（含 `data:` 前缀），
///   由调用方（adapter 的 `parseStreamChunk`）自行解析；
/// - 底层传输由 `HttpKit` 的 `HTTPClient` 提供，不依赖 KernelLumi 网络层。
public final class VendorAPIService: @unchecked Sendable {
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

    /// 发送任意 JSON 请求（Responses 协议等）。
    public func sendJSON(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        try await client.sendJSONRequest(request: request, body: body)
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
        try await client.sendStreamingJSONRequest(
            request: request,
            body: body,
            onEvent: onEvent
        )
    }
}
