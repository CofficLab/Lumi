import Foundation
import Testing
@testable import KitLLM

/// Anthropic 整段 JSON 流式回退必须保留 `redacted_thinking` 不透明块（#1167）。
///
/// 部分网关在 `stream=true` 时返回整段 JSON，回退路径调用 `parseResponse`。
/// 旧解析器只返回正文与工具调用，`ContentBlock` 也没有 `data` 字段，合法的
/// opaque thinking 块在进入累积器之前就被丢弃。正常 SSE 分支已支持该字段，
/// 两种受支持响应形式的行为必须一致。
@Suite("Anthropic 整段 JSON 回退 redacted thinking")
struct AnthropicWholeJSONFallbackRedactedThinkingTests {

    private func adapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/messages"
            )
        )
    }

    /// 把若干 chunk 喂进累积器，返回最终响应。
    private func accumulate(_ chunks: [StreamChunk]) async throws -> LLMResponse {
        let accumulator = StreamingAccumulator()
        for chunk in chunks {
            _ = await accumulator.consume(chunk) { _ in }
        }
        return try await accumulator.finish(model: "claude-test")
    }

    private func redactedJSON(data: String) -> String {
        """
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [
            { "type": "redacted_thinking", "data": "\(data)" },
            { "type": "tool_use", "id": "toolu_1", "name": "read_file", "input": {} }
          ],
          "stop_reason": "tool_use"
        }
        """
    }

    @Test("整段 JSON 回退保留单个 redacted_thinking 块")
    func fallbackPreservesSingleRedactedBlock() throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(redactedJSON(data: "opaque-data").utf8))
        )
        #expect(chunk.redactedThinkingBlocks == ["opaque-data"])
        #expect(chunk.toolCalls?.first?.id == "toolu_1")
    }

    @Test("整段 JSON 回退保留多个 redacted_thinking 块")
    func fallbackPreservesMultipleRedactedBlocks() throws {
        let json = """
        {
          "id": "msg_multi",
          "type": "message",
          "role": "assistant",
          "content": [
            { "type": "redacted_thinking", "data": "first" },
            { "type": "redacted_thinking", "data": "second" },
            { "type": "text", "text": "hi" }
          ],
          "stop_reason": "end_turn"
        }
        """
        let chunk = try #require(try adapter().parseStreamChunk(data: Data(json.utf8)))
        #expect(chunk.redactedThinkingBlocks == ["first", "second"])
    }

    @Test("整段 JSON 回退经累积器后最终响应含 redactedThinking")
    func fallbackProducesRedactedThinkingInFinalResponse() async throws {
        let chunk = try #require(
            try adapter().parseStreamChunk(data: Data(redactedJSON(data: "opaque-data").utf8))
        )
        let response = try await accumulate([chunk])
        #expect(response.redactedThinking == [LLMRedactedThinkingBlock(data: "opaque-data")])
    }

    @Test("整段 JSON 与等价 SSE 的最终 redactedThinking 一致")
    func fallbackAndSSEAgreeOnRedactedThinking() async throws {
        let sseChunk = try #require(
            try adapter().parseStreamChunk(data: Data("""
            event: content_block_start
            data: {"type":"content_block_start","index":0,"content_block":{"type":"redacted_thinking","data":"opaque-data"}}
            """.utf8))
        )
        let sseDone = StreamChunk(isDone: true, eventType: .messageStop)
        let sseResponse = try await accumulate([sseChunk, sseDone])

        let fallbackChunk = try #require(
            try adapter().parseStreamChunk(data: Data(redactedJSON(data: "opaque-data").utf8))
        )
        let fallbackResponse = try await accumulate([fallbackChunk])

        #expect(sseResponse.redactedThinking == fallbackResponse.redactedThinking)
        #expect(fallbackResponse.redactedThinking == [LLMRedactedThinkingBlock(data: "opaque-data")])
    }

    @Test("仅含 redacted_thinking 的整段 JSON 仍产生 chunk")
    func redactedOnlyResponseStillProducesChunk() throws {
        let json = """
        {
          "id": "msg_only",
          "type": "message",
          "role": "assistant",
          "content": [{ "type": "redacted_thinking", "data": "opaque" }],
          "stop_reason": "end_turn"
        }
        """
        let chunk = try #require(try adapter().parseStreamChunk(data: Data(json.utf8)))
        #expect(chunk.redactedThinkingBlocks == ["opaque"])
        #expect(chunk.isDone)
    }

    @Test("非流式 parseResponse 同样返回 redactedThinking")
    func parseResponseReturnsRedactedThinking() throws {
        let parsed = try adapter().parseResponse(data: Data(redactedJSON(data: "opaque-data").utf8))
        #expect(parsed.redactedThinking == [LLMRedactedThinkingBlock(data: "opaque-data")])
    }

    @Test("无 redacted_thinking 时字段为空，不引入额外块")
    func noRedactedBlocksWhenAbsent() async throws {
        let json = """
        {
          "id": "msg_plain",
          "type": "message",
          "role": "assistant",
          "content": [{ "type": "text", "text": "Hello" }],
          "stop_reason": "end_turn"
        }
        """
        let chunk = try #require(try adapter().parseStreamChunk(data: Data(json.utf8)))
        #expect(chunk.redactedThinkingBlocks == nil)
        let response = try await accumulate([chunk])
        #expect(response.redactedThinking == nil)
    }
}