import Foundation
import KitLLM
import Testing
@testable import KitLLM

/// 收集 chunk 的线程安全盒子。
private final class ChunkCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [LLMStreamChunk] = []
    func append(_ chunk: LLMStreamChunk) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }
    var all: [LLMStreamChunk] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// 回归测试：思考增量只能带 `reasoningContent`，不能同时带 `content`。
///
/// - Important: 思考增量与正文增量是两种不同的东西。历史上累积器对
///   `thinkingDelta` 产出 `LLMStreamChunk(content: piece, reasoningContent: piece)`，
///   把同一段文本同时塞进两个字段。下游（AgentLoop）的分派是
///   `appendThinking(reasoning)` 后 `appendContent(content)`，于是同一个 chunk
///   会走两趟，第二趟把流式阶段从 `.thinking` 翻成 `.generating`。
///   思考模型（MiniMax M3 等默认开启思考）的每个思考 token 都触发一次
///   「正在思考…」→「正在生成回复…」的来回翻转，V1 底部状态卡因此逐 token 抖动。
///
///   修复后思考增量只带 `reasoningContent`，与 `GoProvider` 的行为一致。
@Test("回归：思考增量只带 reasoningContent，不伪造正文")
func thinkingDeltaChunkDoesNotCarryContent() async throws {
    let accumulator = StreamingAccumulator()
    let collector = ChunkCollector()

    _ = await accumulator.consume(
        StreamChunk(content: "思考片段", eventType: .thinkingDelta)
    ) { chunk in
        collector.append(chunk)
    }

    let chunks = collector.all
    #expect(chunks.count == 1)

    let chunk = try? #require(chunks.first)
    #expect(chunk?.reasoningContent == "思考片段")
    #expect(
        chunk?.content == nil,
        "思考增量不应同时带 content，否则下游会把思考文本当作正文再写一遍"
    )

    // 最终响应里思考与正文依然各自完整。
    _ = await accumulator.consume(StreamChunk(isDone: true)) { _ in }
    let response = try await accumulator.finish(model: "test-model")
    #expect(response.reasoningContent == "思考片段")
    #expect(
        response.content.isEmpty,
        "只有思考增量时，正文应为空"
    )
}

/// 对照组：正文增量只带 `content`，不带 `reasoningContent`。
@Test("回归：正文增量只带 content")
func textDeltaChunkDoesNotCarryReasoning() async {
    let accumulator = StreamingAccumulator()
    let collector = ChunkCollector()

    _ = await accumulator.consume(
        StreamChunk(content: "正文片段", eventType: .textDelta)
    ) { chunk in
        collector.append(chunk)
    }

    let chunk = try? #require(collector.all.first)
    #expect(chunk?.content == "正文片段")
    #expect(chunk?.reasoningContent == nil)
}
