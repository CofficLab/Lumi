import Foundation
import KitLLM
import ProviderMessageStreaming
import Testing
@testable import KitLLM
@testable import ProviderAgentLoop

/// 收集 chunk 的线程安全盒子。
private final class StreamChunkCollector: @unchecked Sendable {
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

/// 端到端回归：思考增量不得把流式阶段从 `.thinking` 翻成 `.generating`。
///
/// 复刻真实链路：
///   KitLLM.StreamingAccumulator（thinkingDelta → chunk）
///     → AgentLoop 的分派（appendThinking(reasoning) + appendContent(content)）
///       → DefaultMessageStreamingProviding（stage）
///
/// 修复前，累积器对思考增量产出 `LLMStreamChunk(content: piece,
/// reasoningContent: piece)`，于是同一个 chunk 走两趟分派，第二趟把阶段翻成
/// `.generating`。思考模型（MiniMax M3 等）的每个思考 token 都触发一次
/// 「正在思考…」→「正在生成回复…」的来回翻转，V1 底部状态卡因此逐 token 抖动。
@MainActor
@Test("端到端：思考增量不会让流式阶段翻成 generating")
func thinkingDeltaDoesNotFlipStreamingStageEndToEnd() async throws {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()

    // 复刻 AgentLoop 的流式分派（DefaultAgentLoopProvider.requestOneLLM）
    func dispatch(chunk: LLMStreamChunk) async {
        if let reasoning = chunk.reasoningContent, !reasoning.isEmpty {
            streaming.appendThinking(reasoning, conversationID: conversationID)
        }
        if let content = chunk.content, !content.isEmpty {
            streaming.appendContent(content, conversationID: conversationID)
        }
    }

    streaming.start(conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .sending)

    // KitLLM 累积器处理一个思考增量
    let accumulator = StreamingAccumulator()
    let collector = StreamChunkCollector()
    _ = await accumulator.consume(
        StreamChunk(content: "思考片段", eventType: .thinkingDelta)
    ) { chunk in
        collector.append(chunk)
    }

    for chunk in collector.all {
        await dispatch(chunk: chunk)
    }

    #expect(
        streaming.stage(for: conversationID) == .thinking,
        "思考增量不应把阶段翻成 generating"
    )
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == "思考片段")
    #expect(
        streaming.streamingMessage(for: conversationID)?.content.isEmpty ?? true,
        "思考文本不应被当作正文写进可见内容"
    )

    // 真正的正文增量仍然要切到 generating。
    _ = await accumulator.consume(
        StreamChunk(content: "正文片段", eventType: .textDelta)
    ) { chunk in
        collector.append(chunk)
    }
    let textChunks = collector.all.filter { $0.reasoningContent == nil }
    for chunk in textChunks {
        await dispatch(chunk: chunk)
    }
    #expect(streaming.stage(for: conversationID) == .generating)
}
