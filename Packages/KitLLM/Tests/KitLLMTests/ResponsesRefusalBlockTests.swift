import Foundation
import Testing
@testable import KitLLM

/// Responses 协议的拒答块必须被保留。
///
/// ## 为什么要有这条测试
///
/// 共享的 Responses 文本提取器只读 `output[].content[].text`。而标准的
/// Responses 消息在拒答时用的是 `refusal` 内容块：
///
/// ```json
/// {"type": "refusal", "refusal": "I'm sorry, but I can't help with that."}
/// ```
///
/// 拒答文本因此被丢弃，AgentLoop 把一次**合法完成的拒答**归类成通用的、
/// 不可恢复的 `emptyResponse`——用户永远看不到模型给出的拒绝说明。
@MainActor
@Suite("Responses 协议的拒答块")
struct ResponsesRefusalBlockTests {

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

    @Test("拒答块的文本被保留")
    func refusalTextIsPreserved() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_refusal",
          "object": "response",
          "status": "completed",
          "output": [{
            "type": "message",
            "role": "assistant",
            "content": [{
              "type": "refusal",
              "refusal": "I'm sorry, but I can't help with that."
            }]
          }]
        }
        """)

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
        )

        #expect(
            response.content == "I'm sorry, but I can't help with that.",
            "拒答文本被丢弃，实际 \(response.content)"
        )
    }

    @Test("拒答块与正文块并存时都被保留")
    func refusalAndTextCoexist() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_mixed",
          "object": "response",
          "status": "completed",
          "output": [{
            "type": "message",
            "role": "assistant",
            "content": [
              {"type": "output_text", "text": "answer", "annotations": []},
              {"type": "refusal", "refusal": "but I cannot do that"}
            ]
          }]
        }
        """)

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
        )

        #expect(
            response.content.contains("answer"),
            "正文应保留，实际 \(response.content)"
        )
        #expect(
            response.content.contains("but I cannot do that"),
            "拒答应保留，实际 \(response.content)"
        )
    }

    @Test("普通文本响应不受影响")
    func regularTextUnaffected() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_ok",
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
    }
}
