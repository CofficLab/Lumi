import Foundation
import KernelLumi

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
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: max(request.timeoutInterval, 300)
        )
        // 网络层按 ~16KB 回调原始字节,不保证 SSE 帧完整;必须跨 chunk 累积成
        // 完整帧再解析,否则大 delta 会丢失,内容不完整、历史回传前缀失配、
        // 缓存命中率崩盘(与 Anthropic flavor 同一问题,见 SSESequenceAccumulator)。
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in DeepSeekEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in DeepSeekEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    func sendOnce(request: URLRequest, body: [String: Any]) async throws -> Data {
        guard let network else {
            throw DeepSeekTransportError.networkUnavailable
        }
        // 与 send() 一致:sortedKeys 保证 JSON 字节序列稳定,缓存可命中
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
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
