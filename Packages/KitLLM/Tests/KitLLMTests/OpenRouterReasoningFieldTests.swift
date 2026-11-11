import Foundation
import Testing
@testable import KitLLM

/// OpenRouter 的 `reasoning` 字段必须被识别为思考内容。
///
/// ## 为什么要有这条测试
///
/// OpenRouter 的 Chat Completions 把助手的思考放在 `reasoning` 字段上
/// （`message.reasoning` 与流式 `delta.reasoning`），而共享的
/// OpenAI 兼容解析器只认 `reasoning_content`。
///
/// 结果是思考内容在两种模式下都被静默丢弃：思考更新里没有它，最终响应
/// 与持久化的助手历史里也没有它。正文照常到达，因此这个数据丢失很难被
/// 察觉——只有检查思考界面或持久化响应才会发现。
@Suite("OpenRouter 的 reasoning 字段")
struct OpenRouterReasoningFieldTests {

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

    @Test("非流式的 message.reasoning 被保留")
    func nonStreamingReasoningIsPreserved() throws {
        let payload = Data(#"""
        {"choices":[{"message":{"content":"answer","reasoning":"think first"}}]}
        """#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "answer")
        #expect(
            parsed.reasoningContent == "think first",
            "reasoning 字段被丢弃，实际 \(String(describing: parsed.reasoningContent))"
        )
    }

    @Test("reasoning_content 仍然被支持")
    func reasoningContentStillWorks() throws {
        let payload = Data(#"""
        {"choices":[{"message":{"content":"answer","reasoning_content":"think"}}]}
        """#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.reasoningContent == "think")
    }

    // MARK: - 流式

    @Test("流式的 delta.reasoning 产出思考增量")
    func streamingReasoningProducesThinkingDelta() throws {
        let payload = """
        {"choices":[{"delta":{"reasoning":"think first"}}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(
            chunks.contains { $0.eventType == .thinkingDelta && $0.content == "think first" },
            "reasoning 增量未产出思考 chunk：\(chunks)"
        )
    }

    @Test("流式的 reasoning 与 reasoning_content 都能被识别")
    func streamingReasoningContentStillWorks() throws {
        let payload = """
        {"choices":[{"delta":{"reasoning_content":"think"}}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(
            chunks.contains { $0.eventType == .thinkingDelta && $0.content == "think" },
            "reasoning_content 增量未产出思考 chunk：\(chunks)"
        )
    }

    @Test("流式的 reasoning 与正文并存时两者都保留")
    func streamingReasoningAndContentCoexist() throws {
        let payload = """
        {"choices":[{"delta":{"reasoning":"think","content":"answer"}}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(chunks.contains { $0.eventType == .thinkingDelta && $0.content == "think" })
        #expect(chunks.contains { $0.eventType == .textDelta && $0.content == "answer" })
    }
}
