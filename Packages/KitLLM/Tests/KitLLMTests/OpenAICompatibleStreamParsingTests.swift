import Foundation
import Testing
@testable import KitLLM

/// OpenAI 兼容 SSE 解析的行为约束。
///
/// 重点覆盖 interleaved thinking 模型（MiniMax M3 / M3.1 等思考默认开启）
/// 的「同一 delta 内同时携带 reasoning_content / content / tool_calls」形态。
struct OpenAICompatibleStreamParsingTests {

    private func adapter(
        returnsEmptyChunkWhenNoDelta: Bool = false
    ) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/chat/completions",
                returnsEmptyChunkWhenNoDelta: returnsEmptyChunkWhenNoDelta
            )
        )
    }

    private func sse(_ payload: String) -> Data {
        Data("data: \(payload)\n\n".utf8)
    }

    /// 回归用例：同一 delta 同时带 reasoning_content 与 tool_calls 时，
    /// 两者都必须保留。曾经 `if chunks.isEmpty` 守卫会把整包丢弃，
    /// 导致工具调用被吞、content 恒为空，最终被判为「模型返回空响应」。
    @Test("同一 delta 内 reasoning_content 与 tool_calls 并存时两者都保留")
    func reasoningAndToolCallsCoexist() throws {
        let payload = """
        {"choices":[{"delta":{"reasoning_content":"thinking...","tool_calls":\
        [{"index":0,"id":"call_1","function":{"name":"run_command","arguments":"{\\"command\\":\\"ls\\"}"}}]},\
        "finish_reason":"tool_calls"}],"usage":{"prompt_tokens":10,"completion_tokens":20}}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(chunks.contains { $0.eventType == .thinkingDelta && $0.content == "thinking..." })

        let toolChunk = try #require(chunks.first { $0.toolCalls?.isEmpty == false })
        #expect(toolChunk.toolCalls?.first?.name == "run_command")
        #expect(toolChunk.toolCalls?.first?.arguments == "{\"command\":\"ls\"}")
    }

    /// 工具调用与正文并存时，正文不得被丢弃（早期只保留思考、静默丢正文）。
    @Test("同一 delta 内 content 与 tool_calls 并存时两者都保留")
    func contentAndToolCallsCoexist() throws {
        let payload = """
        {"choices":[{"delta":{"content":"running now","tool_calls":\
        [{"index":0,"id":"call_1","function":{"name":"run_command","arguments":"{}"}}]}}]}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        #expect(chunks.contains { $0.eventType == .textDelta && $0.content == "running now" })
        #expect(chunks.contains { $0.toolCalls?.first?.name == "run_command" })
    }

    /// 工具调用帧上的 usage 必须透传，否则以工具调用收尾的轮次
    /// 会丢失 token 统计（速度 / 缓存命中率无法落库）。
    @Test("带 tool_calls 的末帧仍透传 usage 与 stop_reason")
    func usageSurvivesToolCallFrame() throws {
        let payload = """
        {"choices":[{"delta":{"tool_calls":\
        [{"index":0,"id":"call_1","function":{"name":"run_command","arguments":"{}"}}]},\
        "finish_reason":"tool_calls"}],"usage":{"prompt_tokens":111,"completion_tokens":222}}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        let toolChunk = try #require(chunks.first { $0.toolCalls?.isEmpty == false })
        #expect(toolChunk.inputTokens == 111)
        #expect(toolChunk.outputTokens == 222)
        #expect(toolChunk.stopReason == "tool_calls")
    }

    /// 纯 stop_reason 帧（无 tool_calls）仍要产出 usage-only chunk。
    @Test("纯 finish_reason 帧仍产出 usage chunk")
    func pureStopReasonFrame() throws {
        let payload = """
        {"choices":[{"delta":{},"finish_reason":"stop"}],\
        "usage":{"prompt_tokens":5,"completion_tokens":7}}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        let stopChunk = try #require(chunks.first)
        #expect(stopChunk.stopReason == "stop")
        #expect(stopChunk.inputTokens == 5)
        #expect(stopChunk.outputTokens == 7)
    }

    /// usage-only 帧（DeepSeek 形态：无 choices）行为不变。
    @Test("usage-only 帧仍产出 usage chunk")
    func usageOnlyFrame() throws {
        let payload = """
        {"choices":[],"usage":{"prompt_tokens":33,"completion_tokens":44}}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        let usageChunk = try #require(chunks.first)
        #expect(usageChunk.inputTokens == 33)
        #expect(usageChunk.outputTokens == 44)
    }

    @Test("[DONE] 事件标记流结束")
    func doneEvent() throws {
        let chunks = try adapter().parseStreamChunks(data: sse("[DONE]"))
        #expect(chunks.count == 1)
        #expect(chunks[0].isDone)
    }
}
