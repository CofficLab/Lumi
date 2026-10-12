import Foundation
import KitLLM
import ProviderNetwork

/// 把 `NetworkProviding`（ProviderNetwork）桥接为 `LLMNetworkProviding`（KitLLM）。
///
/// 使 LLM 供应商的网络请求经过 kernel 的 `NetworkProviding`，
/// 从而获得 HTTP 交换记录等能力。
public final class LLMNetworkProviderAdapter: LLMNetworkProviding {
    private let networkProvider: any NetworkProviding

    public init(_ networkProvider: any NetworkProviding) {
        self.networkProvider = networkProvider
    }

    // MARK: - LLMNetworkProviding

    public func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: body,
            timeout: Self.llmTimeout(request)
        )

        let httpResponse: HTTPResponse
        do {
            httpResponse = try await networkProvider.request(httpRequest)
        } catch let error as HTTPNetworkError where error.statusCode == nil && error.underlyingCode != nil {
            throw NSError(
                domain: NSURLErrorDomain,
                code: error.underlyingCode!,
                userInfo: [NSLocalizedDescriptionKey: error.underlyingDescription ?? error.localizedDescription]
            )
        }

        // 构造一个 HTTPURLResponse 用于 VendorAPIService 的 validateResponse
        let urlResponse = HTTPURLResponse(
            url: httpRequest.url,
            statusCode: httpResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: httpResponse.headers
        )!

        return (httpResponse.body, urlResponse)
    }

    public func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        // SSE must remain byte-transparent. URLSession may advertise Brotli
        // in the response headers even after transparently decoding the body,
        // which makes the shared stream layer unable to distinguish compressed
        // bytes from plain SSE. Disable content encoding for LLM streams.
        headers["Accept-Encoding"] = "identity"

        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: body,
            timeout: Self.llmTimeout(request)
        )

        do {
            try await networkProvider.stream(
                httpRequest,
                onResponse: { _ in },
                onChunk: { chunk in
                    await onEvent(chunk)
                }
            )
        } catch let error as HTTPNetworkError where error.statusCode == nil && error.underlyingCode != nil {
            throw NSError(
                domain: NSURLErrorDomain,
                code: error.underlyingCode!,
                userInfo: [NSLocalizedDescriptionKey: error.underlyingDescription ?? error.localizedDescription]
            )
        }
    }

    /// LLM 请求的空闲超时。
    ///
    /// `URLRequest.timeoutInterval` 默认 60s，且一旦显式写入会覆盖 session 级
    /// 配置。流式 LLM（思考模式）在首个 SSE 事件前可能长时间无字节，60s 会把
    /// 尚未开始的流掐断，导致 `VendorAPIError.incompleteStream`
    /// （「流式响应在收到结束信号前中断」）。这里保证 LLM 请求至少 300s，
    /// 若调用方显式配置了更大的超时则尊重调用方。
    private static func llmTimeout(_ request: URLRequest) -> TimeInterval {
        max(request.timeoutInterval, 300)
    }
}
