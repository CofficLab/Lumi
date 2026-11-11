import Foundation
import Testing
@testable import KitLLM

/// Responses 协议的 `failed` 状态必须被识别为供应商失败。
///
/// ## 为什么要有这条测试
///
/// 共享的 Responses 解析器从不检查响应的标准 `status` 与 `error` 字段。
/// 一个协议合法但 `status: "failed"` 的响应于是走到正常成功解析器，被当作
/// 一次「成功但内容为空」的响应。
///
/// 结果是：
/// - 没有 output 时，AgentLoop 报通用的、不可恢复的 `emptyResponse`，
///   供应商给的 `server_error` / `model failed` 全部丢失；
/// - 有部分文本时，失败的响应甚至会被当成成功的助手消息落库。
@MainActor
@Suite("Responses 协议的失败状态")
struct ResponsesFailedStatusTests {

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

    @Test("failed 状态抛出供应商错误而不是返回空响应")
    func failedStatusThrowsProviderError() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_failed",
          "object": "response",
          "status": "failed",
          "error": {"code": "server_error", "message": "model failed"},
          "output": []
        }
        """)

        var thrownError: (any Error)?
        do {
            _ = try await provider.complete(
                LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
            )
        } catch {
            thrownError = error
        }

        let error = try #require(thrownError, "failed 状态必须抛错，不能当成成功的空响应")
        let message = String(describing: error)
        #expect(
            message.contains("model failed"),
            "供应商的错误信息应被带出，实际 \(message)"
        )
    }

    @Test("failed 状态带部分文本时也不得当成成功")
    func failedStatusWithPartialTextIsNotSuccess() async throws {
        let provider = makeProvider(payload: """
        {
          "id": "resp_failed",
          "object": "response",
          "status": "failed",
          "error": {"code": "server_error", "message": "model failed"},
          "output": [{
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": "partial", "annotations": []}]
          }]
        }
        """)

        await #expect(throws: (any Error).self) {
            _ = try await provider.complete(
                LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "test-model")
            )
        }
    }

    @Test("completed 状态正常返回")
    func completedStatusReturnsNormally() async throws {
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
