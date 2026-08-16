import Foundation
import HttpKit

/// 新版供应商统一的 API 传输服务（精简自旧版 `LLMAPIService`）。
///
/// 只保留 KernelCore 生态需要的非流式 JSON 发送路径：
/// - `sendChatRequest`：POST JSON，`.sortedKeys` 保证字节稳定（前缀缓存匹配）；
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
}
