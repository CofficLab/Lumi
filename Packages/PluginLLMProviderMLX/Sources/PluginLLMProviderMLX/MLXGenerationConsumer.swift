import Foundation
import KitLLM
import MLXLMCommon

/// MLX 生成事件流的消费器。
///
/// `MLXRuntime.generate` 的流消费逻辑（累积正文、解析工具调用）原先内联在
/// 异步方法里，无法脱离真实模型容器做单元测试。抽成独立类型后，生成事件的
/// 消费规则可以脱离 MLX 运行时单独验证。
///
/// - Note: 该类型不是线程安全的。`MLXRuntime` 在主 actor 上顺序消费生成流，
///   同一时刻只有一个消费者，不存在并发访问。
struct MLXGenerationConsumer {

    // MARK: - 属性

    /// 已累积的正文。
    private(set) var content = ""

    /// 已解析出的工具调用。
    private(set) var toolCalls: [LLMToolCall] = []

    /// 来自 `.info` 终态事件的输入 token 数。
    private(set) var inputTokenCount: Int?

    /// 来自 `.info` 终态事件的输出 token 数。
    private(set) var outputTokenCount: Int?

    /// 来自 `.info` 终态事件的停止原因。
    private(set) var stopReason: String?

    /// 消费一个生成事件。
    ///
    /// - Parameters:
    ///   - generation: MLX 生成事件。
    ///   - onChunk: 正文与工具调用的流式回调。
    mutating func consume(
        _ generation: Generation,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async {
        if let text = generation.chunk {
            content += text
            await onChunk(LLMStreamChunk(content: text, eventTitle: "生成中"))
        }
        if let toolCall = generation.toolCall {
            let arguments = (try? JSONSerialization.data(withJSONObject: toolCall.function.arguments.mapValues { $0.anyValue }))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let call = LLMToolCall(id: UUID().uuidString, name: toolCall.function.name, arguments: arguments)
            toolCalls.append(call)
            await onChunk(LLMStreamChunk(eventTitle: "工具调用", toolCalls: [call]))
        }
        if let info = generation.info {
            inputTokenCount = info.promptTokenCount
            outputTokenCount = info.generationTokenCount
            stopReason = Self.stopReasonText(info.stopReason)
        }
    }

    /// 汇总消费结果。
    ///
    /// - Parameter model: 实际使用的模型标识。
    func response(model: String) -> LLMResponse {
        LLMResponse(
            content: content,
            model: model,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            inputTokenCount: inputTokenCount,
            outputTokenCount: outputTokenCount,
            stopReason: stopReason
        )
    }

    /// 把 MLX 的停止原因转成与云端供应商一致的文本。
    ///
    /// 云端供应商的 `stopReason` 直接沿用协议原值（OpenAI 的 `stop` /
    /// `length` / `tool_calls`，Anthropic 的 `end_turn` 等），这里沿用同一套
    /// 文本，下游按文本判断截断时才与云端模型表现一致。
    private static func stopReasonText(_ reason: GenerateStopReason) -> String {
        switch reason {
        case .stop: return "stop"
        case .length: return "length"
        case .cancelled: return "cancelled"
        }
    }
}
