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

    /// 初始化传输服务。
    ///
    /// - Parameters:
    ///   - client: KitHttp 客户端（当 `networkProvider` 为 nil 时使用）
    ///   - networkProvider: 可选的网络提供者，优先使用以支持 HTTP 交换记录
    public init(client: HTTPClient = HTTPClient(), networkProvider: (any NetworkProviding)? = nil) {
        self.client = client
        self.networkProvider = networkProvider
    }

    /// 发送聊天完成请求（单次，不含重试）。
    public func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        if let networkProvider {
            return try await sendViaNetworkProvider(networkProvider, request: request, body: body)
        }
        return try await client.sendJSONRequest(request: request, body: body)
    }

    /// 发送任意 JSON 请求（Responses 协议等）。
    public func sendJSON(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        if let networkProvider {
            return try await sendViaNetworkProvider(networkProvider, request: request, body: body)
        }
        return try await client.sendJSONRequest(request: request, body: body)
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
        if let networkProvider {
            try await streamViaNetworkProvider(networkProvider, request: request, body: body, onEvent: onEvent)
            return
        }
        try await client.sendStreamingJSONRequest(
            request: request,
            body: body,
            onEvent: onEvent
        )
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

        try await provider.stream(
            httpRequest,
            onResponse: { _ in },
            onChunk: { chunk in
                await onEvent(chunk)
            }
        )
    }
}
