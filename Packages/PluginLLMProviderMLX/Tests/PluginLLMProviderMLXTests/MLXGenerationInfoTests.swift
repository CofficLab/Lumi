import Foundation
import KitLLM
import MLXLMCommon
import Testing
@testable import PluginLLMProviderMLX

/// MLX 生成事件里的 `.info` 终态必须被消费，映射成 `LLMResponse` 的
/// token 用量与停止原因。
///
/// ## 为什么要有这条测试
///
/// `mlx-swift-lm` 的生成流在 `continuation.finish()` 之前会 yield 一次
/// `.info(GenerateCompletionInfo)`，它带着 `promptTokenCount`、
/// `generationTokenCount` 与 `stopReason`。
///
/// Lumi 此前只消费 `.chunk` 与 `.toolCall`，把 `.info` 整条丢掉，于是：
/// - 本地模型的输入/输出 token 永远是 nil，消息统计一片空白；
/// - `AgentLoopProvider.reportInputUsage` 的门槛 `if let inputTokenCount`
///   永远不成立，`LLMContextProvider` 的 `calibrationFactors` 永远学不到
///   本地模型的真实 tokenizer 比率；
/// - `stopReason` 永远不落库。
///
/// 云端供应商都有这三项，本地模型缺失会让同一套 UI 在两种模型下表现不一致。
@Suite("MLX 生成事件的信息消费")
@MainActor
struct MLXGenerationInfoTests {

    /// 构造一份 `.info` 终态事件。
    private func infoEvent(
        promptTokens: Int,
        generationTokens: Int,
        stopReason: GenerateStopReason
    ) -> Generation {
        .info(
            GenerateCompletionInfo(
                promptTokenCount: promptTokens,
                generationTokenCount: generationTokens,
                promptTime: 0.1,
                generationTime: 0.2,
                stopReason: stopReason
            )
        )
    }

    @Test("info 事件的 token 用量进入响应")
    func infoEventProvidesTokenUsage() async {
        var consumer = MLXGenerationConsumer()

        await consumer.consume(.chunk("你好"), onChunk: { _ in })
        await consumer.consume(
            infoEvent(promptTokens: 128, generationTokens: 42, stopReason: .stop),
            onChunk: { _ in }
        )

        let response = consumer.response(model: "qwen3-4b")

        #expect(
            response.inputTokenCount == 128,
            "输入 token 应为 128，实际 \(String(describing: response.inputTokenCount))"
        )
        #expect(
            response.outputTokenCount == 42,
            "输出 token 应为 42，实际 \(String(describing: response.outputTokenCount))"
        )
    }

    @Test("info 事件的停止原因进入响应")
    func infoEventProvidesStopReason() async {
        var consumer = MLXGenerationConsumer()

        await consumer.consume(
            infoEvent(promptTokens: 10, generationTokens: 5, stopReason: .length),
            onChunk: { _ in }
        )

        let response = consumer.response(model: "qwen3-4b")

        #expect(
            response.stopReason == "length",
            "停止原因应为 length，实际 \(String(describing: response.stopReason))"
        )
    }

    @Test("info 事件不影响正文与工具调用")
    func infoEventDoesNotDisturbContent() async {
        var consumer = MLXGenerationConsumer()

        await consumer.consume(.chunk("前半"), onChunk: { _ in })
        await consumer.consume(
            infoEvent(promptTokens: 1, generationTokens: 1, stopReason: .stop),
            onChunk: { _ in }
        )
        await consumer.consume(.chunk("后半"), onChunk: { _ in })

        let response = consumer.response(model: "qwen3-4b")

        #expect(response.content == "前半后半", "正文不应被 info 事件打断")
    }

    @Test("没有 info 事件时用量保持为空")
    func missingInfoEventKeepsUsageNil() async {
        var consumer = MLXGenerationConsumer()

        await consumer.consume(.chunk("只有正文"), onChunk: { _ in })

        let response = consumer.response(model: "qwen3-4b")

        #expect(response.inputTokenCount == nil, "无 info 事件时输入 token 应为 nil")
        #expect(response.outputTokenCount == nil, "无 info 事件时输出 token 应为 nil")
        #expect(response.stopReason == nil, "无 info 事件时停止原因应为 nil")
    }

    @Test("非流式响应保留用量与停止原因")
    func nonStreamingResponseKeepsUsage() async {
        // `complete()` 走的是「流式生成 + 汇总」这条路径。若汇总时只带正文
        // 与工具调用，辅助调用（如上下文摘要）就拿不到用量。
        var consumer = MLXGenerationConsumer()
        await consumer.consume(.chunk("正文"), onChunk: { _ in })
        await consumer.consume(
            infoEvent(promptTokens: 64, generationTokens: 16, stopReason: .stop),
            onChunk: { _ in }
        )
        let streamed = consumer.response(model: "qwen3-4b")

        let nonStreaming = MLXProviderBase.nonStreamingResponse(from: streamed)

        #expect(nonStreaming.inputTokenCount == 64, "非流式响应应保留输入 token")
        #expect(nonStreaming.outputTokenCount == 16, "非流式响应应保留输出 token")
        #expect(nonStreaming.stopReason == "stop", "非流式响应应保留停止原因")
        #expect(nonStreaming.content == "正文", "非流式响应应保留正文")
    }
}
