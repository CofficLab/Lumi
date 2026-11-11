import Foundation
import Testing
@testable import KitLLM

/// Anthropic 的整段 JSON 流式回退必须带上响应元数据。
///
/// ## 为什么要有这条测试
///
/// 部分网关（如 FreeModel）在 `stream=true` 时仍返回**一整段 JSON**而不是
/// SSE。适配器为此提供了一条回退路径，但它只调用了「只解析正文与工具
/// 调用」的 `parseResponse`，构造出的 done chunk 上没有任何元数据字段。
///
/// 结果是：同一个网关从 SSE 换成整段 JSON，token 用量、缓存用量、响应
/// ID、停止原因全部丢失——累积器只保留 chunk 上已有的元数据，于是最终
/// `LLMResponse` 这些字段都是 nil。
@Suite("Anthropic 整段 JSON 流式回退")
struct AnthropicWholeJSONFallbackMetadataTests {

    private func adapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/messages"
            )
        )
    }

    /// 一段完整的 Anthropic 响应 JSON。
    private let wholeJSON = """
    {
      "id": "msg_123",
      "type": "message",
      "role": "assistant",
      "content": [{"type": "text", "text": "Hello"}],
      "stop_reason": "end_turn",
      "usage": {
        "input_tokens": 12,
        "output_tokens": 3,
        "cache_creation_input_tokens": 4,
        "cache_read_input_tokens": 5
      }
    }
    """

    @Test("整段 JSON 回退带上 token 用量")
    func fallbackCarriesTokenUsage() throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(wholeJSON.utf8)),
            "应解析出 chunk"
        )

        #expect(chunk.inputTokens == 12, "输入 token 数丢失")
        #expect(chunk.outputTokens == 3, "输出 token 数丢失")
    }

    @Test("整段 JSON 回退带上缓存用量")
    func fallbackCarriesCacheUsage() throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(wholeJSON.utf8)),
            "应解析出 chunk"
        )

        #expect(chunk.cacheWriteInputTokens == 4, "缓存写入 token 数丢失")
        #expect(chunk.cachedInputTokens == 5, "缓存命中 token 数丢失")
        #expect(chunk.cacheTotalInputTokens == 12, "总输入 token 数丢失")
    }

    @Test("整段 JSON 回退带上响应 ID 与停止原因")
    func fallbackCarriesResponseIDAndStopReason() throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(wholeJSON.utf8)),
            "应解析出 chunk"
        )

        #expect(chunk.responseID == "msg_123", "响应 ID 丢失")
        #expect(chunk.stopReason == "end_turn", "停止原因丢失")
    }

    @Test("整段 JSON 回退仍保留正文与结束标记")
    func fallbackStillCarriesContent() throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(wholeJSON.utf8)),
            "应解析出 chunk"
        )

        #expect(chunk.content == "Hello")
        #expect(chunk.isDone)
    }

    @Test("SSE 事件与整段 JSON 回退的元数据一致")
    func sseAndFallbackAgreeOnMetadata() throws {
        // message_start + message_delta 走 SSE 路径。
        let startChunk = try #require(
            try adapter().parseStreamChunk(data: Data("""
            event: message_start
            data: {"type":"message_start","message":{"id":"msg_123","usage":{"input_tokens":12}}}
            """.utf8)),
            "应解析出 message_start"
        )
        let deltaChunk = try #require(
            try adapter().parseStreamChunk(data: Data("""
            event: message_delta
            data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}
            """.utf8)),
            "应解析出 message_delta"
        )

        let fallbackChunk = try #require(
            try adapter().parseStreamChunk(data: Data(wholeJSON.utf8)),
            "应解析出 chunk"
        )

        #expect(fallbackChunk.inputTokens == startChunk.inputTokens)
        #expect(fallbackChunk.outputTokens == deltaChunk.outputTokens)
        #expect(fallbackChunk.responseID == startChunk.responseID)
        #expect(fallbackChunk.stopReason == deltaChunk.stopReason)
    }
}
