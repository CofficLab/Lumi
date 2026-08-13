import Foundation
import KernelLumi

/// StepFun API 传输层：请求编码、SSE 流式传输、事件解析。
///
/// 不依赖 LLMKit 的 OpenAICompatibleProviderAdapter，完全自实现。
final class StepFunService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.stepfun.com/step_plan/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    /// 发起流式请求。
    ///
    /// `onChunk` 在每个 SSE 事件解析后被调用；返回 `false` 即可中止消费。
    func send(
        request: URLRequest,
        body: [String: Any],
        onChunk: @Sendable @escaping (StepFunEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw StepFunTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: max(request.timeoutInterval, 300)
        )
        // 网络层按 ~16KB 回调原始字节，不保证 SSE 帧完整；必须跨 chunk 累积成
        // 完整帧再解析，否则大 delta 会丢失。
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in StepFunEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in StepFunEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    /// 非流式请求（用于 ping / availability check）。
    func sendOnce(request: URLRequest, body: [String: Any]) async throws -> Data {
        guard let network else {
            throw StepFunTransportError.networkUnavailable
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
            throw StepFunTransportError.httpStatus(response.statusCode, response.bodyString ?? "")
        }
        return response.body
    }
}