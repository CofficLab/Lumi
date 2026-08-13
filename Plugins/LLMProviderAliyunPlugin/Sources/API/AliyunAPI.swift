import Foundation
import KernelLumi

/// 阿里云 Anthropic 协议 API 服务层。
final class AliyunAnthropicService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String,
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    func makeRequest(apiKey: String, body: Data) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw AliyunTransportError.invalidURL(baseURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    func send(
        apiKey: String,
        body: Data,
        onChunk: @Sendable @escaping (AliyunAnthropicEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw AliyunTransportError.networkUnavailable
        }
        let request = try makeRequest(apiKey: apiKey, body: body)
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: max(request.timeoutInterval, 300)
        )
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in AliyunAnthropicEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in AliyunAnthropicEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    func sendOnce(apiKey: String, body: Data) async throws -> Data {
        guard let network else {
            throw AliyunTransportError.networkUnavailable
        }
        let request = try makeRequest(apiKey: apiKey, body: body)
        let response = try await network.request(HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: request.timeoutInterval
        ))
        guard response.isSuccess else {
            throw AliyunTransportError.httpStatus(response.statusCode, response.bodyString ?? "")
        }
        return response.body
    }
}
