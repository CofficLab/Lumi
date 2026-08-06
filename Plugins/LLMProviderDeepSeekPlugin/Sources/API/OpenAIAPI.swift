import Foundation
import LumiKernel

/// DeepSeek (OpenAI-compatible flavor) transport, request encoding, SSE parsing, and usage parsing.
///
/// This implementation targets the OpenAI-compatible chat completions protocol
/// that DeepSeek exposes. Additional protocol flavors (e.g. Anthropic-compatible)
/// will live in sibling types named `DeepSeek<Flavor>Service` so they can coexist
/// under the same `DeepSeekOpenAIProvider`.
/// This intentionally does not depend on the generic OpenAI-compatible LLMKit layer.
final class DeepSeekOpenAIService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.deepseek.com/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    func send(
        request: URLRequest,
        body: [String: Any],
        onChunk: @Sendable @escaping (DeepSeekEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw DeepSeekTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: max(request.timeoutInterval, 300)
        )
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for event in DeepSeekEventParser.parse(data) {
                    if !(await onChunk(event)) { return false }
                }
                return true
            }
        )
    }

    func sendOnce(request: URLRequest, body: [String: Any]) async throws -> Data {
        guard let network else {
            throw DeepSeekTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let response = try await network.request(HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: request.timeoutInterval
        ))
        guard response.isSuccess else {
            throw DeepSeekTransportError.httpStatus(response.statusCode, response.bodyString ?? "")
        }
        return response.body
    }
}
