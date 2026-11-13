import Foundation
import KitLLM
import MLXLMCommon
import Testing
@testable import PluginLLMProviderMLX

/// MLX 生成流里的 `.rejectedToolCall` 必须被消费并 surfaced 为带诊断的错误。
///
/// ## 为什么要有这条测试
///
/// 小模型幻觉出未声明的函数名或畸形工具调用负载时，mlx-swift-lm 发出
/// `.rejectedToolCall` 而不是 `.toolCall`，且拒绝负载不会作为 `.chunk`
/// 流式输出。此前消费器没有该分支，拒绝被整条丢弃：整轮输出为空时
/// 被判为空响应，重试插件把 `.emptyResponse` 当瞬时异常反复重启回合，
/// 用户只看到一连串通用空响应重试（#1228）。
@Suite("MLX 生成事件的拒绝消费")
@MainActor
struct MLXGenerationRejectionTests {

    private func rejection(
        reason: RejectedToolCall.Reason = .undeclaredTool,
        toolName: String? = "ghost_tool",
        detail: String? = "The function was not present in the supplied tool definitions."
    ) -> RejectedToolCall {
        RejectedToolCall(
            reason: reason,
            format: .json,
            toolName: toolName,
            callID: nil,
            rawText: "RAW-SECRET-PAYLOAD",
            detail: detail
        )
    }

    @Test("rejectedToolCall 事件必须被捕获而不是静默丢弃")
    func rejectionEventIsCaptured() async {
        var consumer = MLXGenerationConsumer()
        await consumer.consume(.rejectedToolCall(rejection()), onChunk: { _ in })

        #expect(consumer.rejection?.reason == .undeclaredTool)
        #expect(consumer.rejection?.toolName == "ghost_tool")
    }

    @Test("被拒绝的原始输出不得进入正文或流式回调")
    func rejectionNeverBecomesContent() async {
        let sink = ChunkSink()
        var consumer = MLXGenerationConsumer()
        await consumer.consume(.chunk("前导正文"), onChunk: { await sink.record($0) })
        await consumer.consume(.rejectedToolCall(rejection()), onChunk: { await sink.record($0) })

        let chunks = await sink.chunks
        #expect(consumer.content == "前导正文")
        #expect(consumer.toolCalls.isEmpty)
        #expect(chunks.count == 1)
        #expect(!consumer.content.contains("RAW-SECRET-PAYLOAD"))
        for chunk in chunks {
            #expect(!(chunk.content ?? "").contains("RAW-SECRET-PAYLOAD"))
        }
    }

    @Test("多个拒绝事件保留第一个诊断")
    func firstRejectionIsKept() async {
        var consumer = MLXGenerationConsumer()
        await consumer.consume(.rejectedToolCall(rejection(reason: .malformedSyntax)), onChunk: { _ in })
        await consumer.consume(.rejectedToolCall(rejection(reason: .undeclaredTool)), onChunk: { _ in })

        #expect(consumer.rejection?.reason == .malformedSyntax)
    }

    @Test("错误描述携带原因与工具名且不泄漏原始输出")
    func errorDescriptionCarriesSafeDiagnostics() {
        let error = MLXProviderError.rejectedToolCall(rejection())
        let description = error.errorDescription ?? ""

        #expect(description.contains("undeclared_tool"))
        #expect(description.contains("ghost_tool"))
        #expect(description.contains("The function was not present in the supplied tool definitions."))
        #expect(!description.contains("RAW-SECRET-PAYLOAD"))
    }

    @Test("没有拒绝事件时保持为空")
    func noRejectionKeepsNil() async {
        var consumer = MLXGenerationConsumer()
        await consumer.consume(.chunk("正常正文"), onChunk: { _ in })

        #expect(consumer.rejection == nil)
        #expect(consumer.response(model: "qwen3-4b").content == "正常正文")
    }
}

private actor ChunkSink {
    private(set) var chunks: [LLMStreamChunk] = []
    func record(_ chunk: LLMStreamChunk) { chunks.append(chunk) }
}