import Foundation
import Testing
@testable import KitLLM

/// OpenAI 流式同一 delta 内的并行工具调用必须按各自 `tool_calls[].index` 累积。
///
/// ## 为什么要有这条测试（回归 #162）
///
/// 一个 `delta.tool_calls` 数组可能同时携带多个并行调用（index 0、1…）。
/// 适配器此前只用一个 `toolCallIndex` 变量，循环结束后只保留最后一个 index，
/// 并把整个数组连同这个共享 index 交给累积器。累积器对数组里每个调用都用
/// 同一个 index 归位，于是所有调用被写进同一槽：ID/name 取第一个、arguments
/// 被拼接成 `{"a":1}{"b":2}` 这样的非法 JSON，其余调用直接丢失。
@Suite("OpenAI 流式并行工具调用按 index 累积")
struct OpenAIStreamParallelToolCallTests {

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

    @Test("同一 delta 内的两个并行调用累积成两个独立调用")
    func parallelToolCallsInOneDeltaAreAccumulatedSeparately() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_A","type":"function","function":{"name":"a","arguments":"{\"a\":1}"}},{"index":1,"id":"call_B","type":"function","function":{"name":"b","arguments":"{\"b\":2}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        #expect(calls.count == 2, "并行调用被合并，实际 \(calls.count) 个")
        let first = try #require(calls.first)
        #expect(first.id == "call_A")
        #expect(first.name == "a")
        #expect(first.arguments == "{\"a\":1}", "参数被拼接，实际 \(first.arguments)")
        let second = try #require(calls.dropFirst().first)
        #expect(second.id == "call_B")
        #expect(second.name == "b")
        #expect(second.arguments == "{\"b\":2}", "参数被拼接，实际 \(second.arguments)")
    }

    @Test("并行调用的 arguments 分片跨 delta 按 index 各自拼接")
    func parallelToolCallArgumentsStreamByIndexAcrossDeltas() async throws {
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_A","type":"function","function":{"name":"a"}},{"index":1,"id":"call_B","type":"function","function":{"name":"b"}}]}}]}"#,
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"a\":"}},{"index":1,"function":{"arguments":"{\"b\":"}}]}}]}"#,
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"1}"}},{"index":1,"function":{"arguments":"2}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        #expect(calls.count == 2, "并行调用被合并，实际 \(calls.count) 个")
        let first = try #require(calls.first)
        #expect(first.id == "call_A")
        #expect(first.name == "a")
        #expect(first.arguments == "{\"a\":1}", "index 0 参数错误，实际 \(first.arguments)")
        let second = try #require(calls.dropFirst().first)
        #expect(second.id == "call_B")
        #expect(second.name == "b")
        #expect(second.arguments == "{\"b\":2}", "index 1 参数错误，实际 \(second.arguments)")
    }

    @Test("不带 index 的网关跨 delta 仍逐个分配独立槽位")
    func gatewayWithoutIndexStillAssignsDistinctSlotsAcrossDeltas() async throws {
        // 无 index 时沿用累积器的 nextIndex 逐调用分配；修复不能把每个 delta
        // 的首个调用都塞进 index 0，否则跨 delta 的两次调用会被错误合并。
        let calls = try await accumulatedToolCalls([
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_A","type":"function","function":{"name":"a","arguments":"{\"a\":1}"}}]}}]}"#,
            #"{"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_B","type":"function","function":{"name":"b","arguments":"{\"b\":2}"}}]},"finish_reason":"tool_calls"}]}"#,
        ])

        #expect(calls.count == 2, "无 index 的跨 delta 调用被合并，实际 \(calls.count) 个")
        #expect(calls.first?.id == "call_A")
        #expect(calls.first?.arguments == "{\"a\":1}")
        #expect(calls.dropFirst().first?.id == "call_B")
        #expect(calls.dropFirst().first?.arguments == "{\"b\":2}")
    }
}
