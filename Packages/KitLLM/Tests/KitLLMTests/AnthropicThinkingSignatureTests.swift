import Foundation
import Testing
@testable import KitLLM

/// #287：Anthropic 扩展思考的 `signature` 必须贯穿整条链路——
/// SSE `signature_delta` → 累积器 → `LLMResponse`；非流式解析 → 同一响应；
/// 下一轮请求重建 thinking 块时原样回传。缺失签名的 thinking 块会被
/// 供应商拒绝，带工具调用的多轮对话直接 400。
@Suite("Anthropic thinking 签名（#287）")
struct AnthropicThinkingSignatureTests {

    private func makeAdapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://api.example.com/v1/messages"
            )
        )
    }

    /// 把 SSE 负载组装成 Anthropic 事件块。
    private func anthropicEvent(_ event: String, _ payload: [String: Any]) -> Data {
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        return Data("event: \(event)\ndata: \(json)\n\n".utf8)
    }

    @Test("SSE signature_delta 事件解析出签名 chunk")
    func parsesSignatureDeltaEvent() throws {
        let adapter = makeAdapter()
        let event = anthropicEvent("content_block_delta", [
            "type": "content_block_delta",
            "index": 0,
            "delta": ["type": "signature_delta", "signature": "sig-abc123"],
        ])

        let chunk = try #require(try adapter.parseStreamChunk(data: event))
        #expect(chunk.eventType == .signatureDelta)
        #expect(chunk.thinkingSignature == "sig-abc123")
    }

    @Test("累积器把签名带入最终响应")
    func accumulatorCarriesSignatureIntoFinalResponse() async throws {
        let accumulator = StreamingAccumulator()

        _ = await accumulator.consume(
            StreamChunk(content: "先分析", eventType: .thinkingDelta)
        ) { _ in }
        _ = await accumulator.consume(
            StreamChunk(eventType: .signatureDelta, thinkingSignature: "sig-abc123")
        ) { _ in }
        _ = await accumulator.consume(StreamChunk(content: "答案", eventType: .textDelta)) { _ in }
        _ = await accumulator.consume(StreamChunk(isDone: true)) { _ in }

        let response = try await accumulator.finish(model: "test-model")
        #expect(response.reasoningContent == "先分析")
        #expect(
            response.thinkingSignature == "sig-abc123",
            "签名必须随最终响应下发，落库后下一轮才能回传"
        )
    }

    @Test("非流式响应解析 thinking 文本与签名")
    func parsesThinkingAndSignatureFromNonStreamingResponse() throws {
        let adapter = makeAdapter()
        let body: [String: Any] = [
            "id": "msg_1",
            "type": "message",
            "role": "assistant",
            "stop_reason": "end_turn",
            "content": [
                ["type": "thinking", "thinking": "先分析上下文", "signature": "sig-abc123"],
                ["type": "text", "text": "答案"],
            ],
            "usage": ["input_tokens": 10, "output_tokens": 5],
        ]
        let data = try JSONSerialization.data(withJSONObject: body)

        let parsed = try adapter.parseResponse(data: data)

        #expect(parsed.reasoningContent == "先分析上下文")
        #expect(parsed.thinkingSignature == "sig-abc123")
        #expect(parsed.content == "答案")
    }

    @Test("重建请求时 thinking 块携带原始签名")
    func transformMessageEchoesSignatureInThinkingBlock() {
        let adapter = makeAdapter()
        let message = LLMMessage(
            role: .assistant,
            content: "",
            toolCalls: [LLMToolCall(id: "call-1", name: "fetch_weather", arguments: "{}")],
            reasoningContent: "先分析上下文",
            thinkingSignature: "sig-abc123"
        )

        let transformed = adapter.transformMessage(message)
        let content = try! #require(transformed["content"] as? [[String: Any]])
        let thinkingBlock = try! #require(content.first { ($0["type"] as? String) == "thinking" })
        #expect(thinkingBlock["thinking"] as? String == "先分析上下文")
        #expect(
            thinkingBlock["signature"] as? String == "sig-abc123",
            "带工具调用的历史必须回传签名，否则供应商拒绝请求"
        )
    }

    @Test("没有签名时不伪造 signature 键")
    func transformMessageOmitsSignatureWhenAbsent() {
        let adapter = makeAdapter()
        let message = LLMMessage(
            role: .assistant,
            content: "",
            toolCalls: [LLMToolCall(id: "call-1", name: "fetch_weather", arguments: "{}")],
            reasoningContent: "先分析上下文"
        )

        let transformed = adapter.transformMessage(message)
        let content = try! #require(transformed["content"] as? [[String: Any]])
        let thinkingBlock = try! #require(content.first { ($0["type"] as? String) == "thinking" })
        #expect(thinkingBlock["signature"] == nil)
    }

    @Test("整段 JSON 回退一次性携带思考全文与签名")
    func wholeJSONFallbackCarriesReasoningAndSignature() async throws {
        let adapter = makeAdapter()
        let body: [String: Any] = [
            "id": "msg_1",
            "type": "message",
            "role": "assistant",
            "stop_reason": "end_turn",
            "content": [
                ["type": "thinking", "thinking": "先分析上下文", "signature": "sig-abc123"],
                ["type": "text", "text": "答案"],
            ],
            "usage": ["input_tokens": 10, "output_tokens": 5],
        ]
        let data = try JSONSerialization.data(withJSONObject: body)

        // 无 SSE 标记的整段 JSON 触发回退路径。
        let chunk = try #require(try adapter.parseStreamChunk(data: data))
        #expect(chunk.isDone)
        #expect(chunk.thinkingSignature == "sig-abc123")
        #expect(
            chunk.reasoningContent == "先分析上下文",
            "回退 chunk 不带思考全文的话，累积器的思考文本就丢了"
        )

        let accumulator = StreamingAccumulator()
        _ = await accumulator.consume(chunk) { _ in }
        let response = try await accumulator.finish(model: "test-model")
        #expect(response.reasoningContent == "先分析上下文")
        #expect(response.thinkingSignature == "sig-abc123")
        #expect(response.content == "答案")
    }
}
