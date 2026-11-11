import Foundation
import Testing
@testable import KitLLM

/// OpenAI Chat Completions 必须保留响应 ID 与结束原因。
///
/// ## 为什么要有这条测试
///
/// 共享的 OpenAI Chat Completions 解析器没有建模顶层 `id`，也没有建模
/// `choices[].finish_reason`：
///
/// - 非流式：`responseID` 与 `stopReason` 都是 nil，截断的回答（`length`）
///   丢失了「为什么没说完」的信息；
/// - 流式：`finish_reason` 通过 `stopReason` 保留了，但顶层 `id` 被丢弃，
///   最终 `LLMResponse.responseID` 是 nil。
///
/// 供应商的关联 ID 与截断原因都无法在下游恢复。
@Suite("OpenAI Chat Completions 的响应元数据")
struct OpenAIChatCompletionsResponseMetadataTests {

    private func adapter() -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/chat/completions"
            )
        )
    }

    private func sse(_ payload: String) -> Data {
        Data("data: \(payload)\n\n".utf8)
    }

    // MARK: - 非流式

    @Test("非流式响应保留顶层 id")
    func nonStreamingKeepsResponseID() throws {
        let payload = Data("""
        {"id":"chatcmpl-meta","choices":[{"index":0,"message":{"role":"assistant","content":"partial"},\
        "finish_reason":"length"}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(
            parsed.responseID == "chatcmpl-meta",
            "响应 ID 被丢弃，实际 \(String(describing: parsed.responseID))"
        )
    }

    @Test("非流式响应保留 finish_reason")
    func nonStreamingKeepsStopReason() throws {
        let payload = Data("""
        {"id":"chatcmpl-meta","choices":[{"index":0,"message":{"role":"assistant","content":"partial"},\
        "finish_reason":"length"}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(
            parsed.stopReason == "length",
            "结束原因被丢弃，实际 \(String(describing: parsed.stopReason))"
        )
    }

    @Test("没有 id 与 finish_reason 时保持 nil")
    func missingMetadataStaysNil() throws {
        let payload = Data(#"{"choices":[{"message":{"role":"assistant","content":"ok"}}]}"#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.responseID == nil)
        #expect(parsed.stopReason == nil)
    }

    // MARK: - 流式

    @Test("流式响应保留顶层 id")
    func streamingKeepsResponseID() throws {
        let chunks = try adapter().parseStreamChunks(
            data: sse(#"{"id":"chatcmpl-stream","choices":[{"index":0,"delta":{"content":"ok"}}]}"#)
        )

        let chunk = try #require(chunks.first, "应解析出 chunk")
        #expect(
            chunk.responseID == "chatcmpl-stream",
            "响应 ID 被丢弃，实际 \(String(describing: chunk.responseID))"
        )
    }

    @Test("流式响应保留 finish_reason")
    func streamingKeepsStopReason() throws {
        let chunks = try adapter().parseStreamChunks(
            data: sse(#"{"id":"chatcmpl-stream","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#)
        )

        let chunk = try #require(chunks.first, "应解析出 chunk")
        #expect(
            chunk.stopReason == "stop",
            "结束原因被丢弃，实际 \(String(describing: chunk.stopReason))"
        )
    }
}
