import Foundation
import Testing
@testable import KitLLM

/// OpenAI Chat Completions 的 `refusal` 字段必须被保留。
///
/// ## 为什么要有这条测试
///
/// OpenAI 在模型拒绝作答时返回 `message.refusal`（非流式）或
/// `delta.refusal`（流式），同时 `content` 为 `null`。此前的解析器既不读
/// 非流式的 `message.refusal`，也不读流式的 `delta.refusal`，于是：
/// - 非流式：内容被映射成空串 `""`；
/// - 流式：拒绝文本从未进入累积器，流以空内容正常结束，随后在 AgentLoop
///   层被重新归类为 `VendorAPIError.emptyResponse`。
///
/// 结果是「模型明确拒绝了」与「模型返回空响应 / 畸形响应」无法区分，
/// 用户看到的是通用失败提示而不是模型的拒绝说明。
@Suite("OpenAI 拒答（refusal）解析")
struct OpenAIRefusalParsingTests {

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

    @Test("非流式的 message.refusal 被保留为正文")
    func nonStreamingRefusalIsPreserved() throws {
        let payload = Data(#"""
        {"choices":[{"message":{"content":null,"refusal":"I'm sorry, but I can't help with that."}}]}
        """#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(
            parsed.content == "I'm sorry, but I can't help with that.",
            "拒答文本被丢弃，实际内容：\(parsed.content)"
        )
    }

    @Test("非流式同时有正文与拒答时优先保留正文")
    func nonStreamingPrefersContentOverRefusal() throws {
        let payload = Data(#"""
        {"choices":[{"message":{"content":"Here you go","refusal":"nope"}}]}
        """#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "Here you go")
    }

    @Test("非流式有正文时不受拒答字段影响")
    func nonStreamingContentUnaffected() throws {
        let payload = Data(#"""
        {"choices":[{"message":{"content":"hello"}}]}
        """#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "hello")
    }

    // MARK: - 流式

    @Test("流式的 delta.refusal 被产出为正文增量")
    func streamingRefusalProducesTextDelta() throws {
        let payload = """
        {"id":"chatcmpl-refusal","object":"chat.completion.chunk","created":0,"model":"gpt-4o",\
        "choices":[{"index":0,"delta":{"role":"assistant","refusal":"I'm sorry, but I can't help with that."},\
        "finish_reason":null}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(
            chunks.contains { $0.eventType == .textDelta && $0.content == "I'm sorry, but I can't help with that." },
            "流式拒答未产出正文增量：\(chunks)"
        )
    }

    @Test("流式拒答与正文并存时两者都保留")
    func streamingRefusalAndContentCoexist() throws {
        let payload = """
        {"choices":[{"delta":{"content":"partial","refusal":"blocked"},"finish_reason":null}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(chunks.contains { $0.eventType == .textDelta && $0.content == "partial" })
        #expect(chunks.contains { $0.eventType == .textDelta && $0.content == "blocked" })
    }

    @Test("流式拒答帧仍透传 usage 与 finish_reason")
    func streamingRefusalKeepsUsage() throws {
        let payload = """
        {"choices":[{"delta":{"refusal":"blocked"},"finish_reason":"stop"}],\
        "usage":{"prompt_tokens":11,"completion_tokens":5}}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        let refusal = try #require(chunks.first { $0.eventType == .textDelta })
        #expect(refusal.content == "blocked")
        #expect(refusal.inputTokens == 11)
        #expect(refusal.outputTokens == 5)
        #expect(refusal.stopReason == "stop")
    }
}
