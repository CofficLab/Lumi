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
            timeout: request.timeoutInterval
        )

        let httpResponse = try await networkProvider.request(httpRequest)

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

        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: body,
            timeout: request.timeoutInterval
        )

        try await networkProvider.stream(
            httpRequest,
            onResponse: { _ in },
            onChunk: { chunk in
                await onEvent(chunk)
            }
        )
    }
}
