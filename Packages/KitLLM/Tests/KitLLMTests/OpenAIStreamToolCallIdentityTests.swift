import Foundation
import Testing
@testable import KitLLM

/// OpenAI 流式工具调用的身份字段被拆到不同 delta 时，必须能合并。
///
/// ## 为什么要有这条测试
///
/// OpenAI 兼容的流式协议可能把同一次调用的 `id` 与 `function.name` 分到
/// 不同 delta 里。适配器此前只在 `id` 和 `name` **同时**到达时才产出
/// `ToolCall`，否则只保留 arguments 作为 `partialJson`——已经收到的 ID 和
/// 后到的 name 都被丢弃。
///
/// 结果是累积器只拿到 arguments，造出 `ToolCall(id: "", name: "",
/// arguments: "{}")`：工具名无法解析，调用无法分发。一次合法的工具调用
/// 变成无名调用。
@Suite("OpenAI 流式工具调用的身份合并")
struct OpenAIStreamToolCallIdentityTests {

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

    /// 把一段 SSE 流喂给累积器，返回最终的工具调用。
    private func accumulatedToolCalls(_ events: [String]) async throws -> [ToolCall] {
        let accumulator = StreamingAccumulator()
        for event in events {
            let chunks = try adapter().parseStreamChunks(data: sse(event))
            for chunk in chunks {
                _ = await accumulator.consume(chunk) { _ in }
            }
        }
        _ = await accumulator.consume(StreamChunk(isDone: true)) { _ in }
        let response = try await accumulator.finish(model: "gpt-4o")
        return response.toolCalls?.map {
            ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
        } ?? []
    }

    @Test("id 与 name 分到不同 delta 时能合并成完整的调用")
    func identitySplitAcrossDeltasIsMerged() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{}}]}}]}"#,
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"name":"lookup","arguments":"{}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        let call = try #require(calls.first, "应合并出一次工具调用")
        #expect(call.id == "call_1", "ID 被丢弃，实际 \(call.id)")
        #expect(call.name == "lookup", "工具名被丢弃，实际 \(call.name)")
        #expect(call.arguments == "{}", "参数错误，实际 \(call.arguments)")
    }

    @Test("name 先到、arguments 后到时也能合并")
    func nameFirstThenArgumentsIsMerged() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_2","type":"function","function":{"name":"search"}}]}}]}"#,
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"q\":\"x\"}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        let call = try #require(calls.first, "应合并出一次工具调用")
        #expect(call.id == "call_2")
        #expect(call.name == "search")
        #expect(call.arguments == "{\"q\":\"x\"}", "参数错误，实际 \(call.arguments)")
    }

    @Test("id 与 name 在同一个 delta 时行为不变")
    func identityInSameDeltaStillWorks() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_3","type":"function","function":{"name":"lookup","arguments":"{}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        let call = try #require(calls.first, "应产出一次工具调用")
        #expect(call.id == "call_3")
        #expect(call.name == "lookup")
    }

    @Test("没有工具调用时不产出调用")
    func noToolCallsProducesNothing() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"content":"hello"}}]}"#,
        ])

        #expect(calls.isEmpty)
    }
}
