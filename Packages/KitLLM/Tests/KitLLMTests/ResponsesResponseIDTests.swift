import Foundation
import Testing
@testable import KitLLM

/// Responses 协议必须保留标准响应 ID。
///
/// ## 为什么要有这条测试
///
/// 共享的 Responses 协议实现只提取正文与 token 用量，完全不读顶层 `id`。
///
/// 自定义 `.responses` 供应商走的就是这条路径（`streamComplete` 直接回落到
/// `complete`），因此助手消息落库时 `responseID` 是 nil——供应商明明给了
/// 有效的关联标识，下游却无法恢复。
@MainActor
@Suite("Responses 协议的响应 ID")
struct ResponsesResponseIDTests {

    /// 返回固定 JSON 的网络桩。
    private final class ResponsesNetworkStub: LLMNetworkProviding, @unchecked Sendable {
        let payload: Data

        init(payload: Data) {
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (payload, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {}
    }

    /// 只实现 Responses 端点的供应商替身。
    private final class ResponsesOnlyProvider: VendorLLMProvider {
        override var responsesEndpointURL: String { "https://example.invalid/v1/responses" }
        override func resolveAPIKey() throws -> String { "sk-test-responses" }
    }

    private func makeProvider(payload: String) -> ResponsesOnlyProvider {
        let network = ResponsesNetworkStub(payload: Data(payload.utf8))
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        return ResponsesOnlyProvider(
            info: LLMProviderInfo(
                id: "responses-only",
                displayName: "Responses Only",
                defaultModel: "test-model",
                models: [],
                isLocal: true,
                apiFormat: .responses
            ),
            apiService: service
        )
    }

    @Test("Responses 响应保留顶层 id")
    func responsesKeepsResponseID() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_123",
          "object": "response",
          "status": "completed",
          "output": [{
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": "ok", "annotations": []}]
          }]
        }
        """)

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
        )

        #expect(response.content == "ok")
        #expect(
            response.responseID == "resp_123",
            "响应 ID 被丢弃，实际 \(String(describing: response.responseID))"
        )
    }

    @Test("没有 id 时保持 nil")
    func missingResponseIDStaysNil() async throws {
        let provider = makeProvider(payload: """
        {
          "object": "response",
          "status": "completed",
          "output": [{
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": "ok", "annotations": []}]
          }]
        }
        """)

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
        )

        #expect(response.responseID == nil)
    }
}
