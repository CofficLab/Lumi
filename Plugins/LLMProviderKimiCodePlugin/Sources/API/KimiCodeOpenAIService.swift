import Foundation
import KernelLumi

/// Kimi Code (OpenAI-compatible flavor) transport, request encoding, SSE parsing.
final class KimiCodeOpenAIService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.kimi.com/coding/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    func send(
        request: URLRequest,
        body: [String: Any],
        onChunk: @Sendable @escaping (KimiCodeEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw KimiCodeTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: max(request.timeoutInterval, 300)
        )
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in KimiCodeEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in KimiCodeEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    func sendOnce(request: URLRequest, body: [String: Any]) async throws -> Data {
        guard let network else {
            throw KimiCodeTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let response = try await network.request(HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: request.timeoutInterval
        ))
        guard response.isSuccess else {
            throw KimiCodeTransportError.httpStatus(response.statusCode, response.bodyString ?? "")
        }
        return response.body
    }
}
