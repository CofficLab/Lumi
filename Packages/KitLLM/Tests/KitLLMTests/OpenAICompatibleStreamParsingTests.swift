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

    // MARK: - 缓存 token 总量口径

    /// 锁定 `cacheTotalInputTokens == prompt_tokens`，防止未来被「优化」成求和。
    ///
    /// ## 这里曾经被误判为 bug
    ///
    /// 看到 DeepSeek 同时返回 `prompt_cache_hit_tokens` 与 `prompt_tokens`，
    /// 很容易以为「`prompt_tokens` 只是未命中部分，总量应该相加」。
    /// 实测并非如此——DeepSeek 官方 API 示例（api-docs.deepseek.com）
    /// 明确给出恒等式：
    ///
    /// ```
    /// prompt_cache_hit_tokens + prompt_cache_miss_tokens == prompt_tokens
    /// ```
    ///
    /// 例：`prompt_tokens=17`、`hit=0`、`miss=17`；本用例取
    /// `prompt_tokens=123`、`hit=100`、`miss=23`，三者自洽。
    ///
    /// 因此 `prompt_tokens` **就是总输入**，缓存命中率的分母直接用它即可。
    ///
    /// - Important: 若改成 `input + hit`，分母会被重复放大
    ///   （123 + 100 = 223），缓存命中率被系统性低估。
    ///   下游 `CacheHitRateRequestMetrics` 以该值为分母，算错会整体失真。
    /// - Note: Anthropic 适配器**需要**相加，因为 Anthropic 的
    ///   `input_tokens` 不含 `cache_read` / `cache_creation`——两者口径本就不同，
    ///   不能互相套用。
    @Test("DeepSeek 形态的总输入就是 prompt_tokens，不叠加缓存字段")
    func deepSeekCacheTotalIsPromptTokens() throws {
        let payload = """
        {"choices":[{"delta":{},"finish_reason":"stop"}],\
        "usage":{"prompt_tokens":123,"completion_tokens":17,\
        "prompt_cache_hit_tokens":100,"prompt_cache_miss_tokens":23}}
        """
        let chunk = try #require(
            try adapter().parseStreamChunks(data: sse(payload)).first
        )
        #expect(chunk.inputTokens == 123)
        #expect(chunk.cachedInputTokens == 100)
        // hit(100) + miss(23) == prompt_tokens(123)，总量就是 123 而非 223。
        #expect(chunk.cacheTotalInputTokens == 123)
    }

    /// OpenAI 形态同理：`prompt_tokens` 已含 `cached_tokens`，不得叠加。
    @Test("OpenAI 形态的总量不叠加缓存字段")
    func openAICacheTotalIsPromptTokens() throws {
        let payload = """
        {"choices":[{"delta":{},"finish_reason":"stop"}],\
        "usage":{"prompt_tokens":500,"completion_tokens":20,\
        "prompt_tokens_details":{"cached_tokens":400}}}
        """
        let chunk = try #require(
            try adapter().parseStreamChunks(data: sse(payload)).first
        )
        #expect(chunk.inputTokens == 500)
        #expect(chunk.cachedInputTokens == 400)
        // 500 已含 400，不得变成 900
        #expect(chunk.cacheTotalInputTokens == 500)
    }

    /// 思考增量与正文增量两条产出路径都必须携带同一份总量。
    ///
    /// 这两条路径各自构造 `StreamChunk`，容易在改动其中一条时漏掉 usage 字段。
    @Test("思考增量与正文增量携带相同的总输入口径")
    func thinkingAndTextChunksShareCacheTotal() throws {
        let payload = """
        {"choices":[{"delta":{"reasoning_content":"thinking","content":"text"},\
        "finish_reason":"stop"}],\
        "usage":{"prompt_tokens":123,"prompt_cache_hit_tokens":100}}
        """
        let chunks = try adapter().parseStreamChunks(data: sse(payload))
        // 用 contains 而非断言总数：解析器可自由增补 usage / 结束帧，
        // 关键约束是「两条产出路径都带同一份 usage」，而非帧数恰好为 2。
        let thinking = try #require(chunks.first { $0.eventType == .thinkingDelta })
        let text = try #require(chunks.first { $0.eventType == .textDelta })
        for chunk in [thinking, text] {
            #expect(chunk.inputTokens == 123)
            #expect(chunk.cachedInputTokens == 100)
            #expect(chunk.cacheTotalInputTokens == 123)
        }
    }
}
