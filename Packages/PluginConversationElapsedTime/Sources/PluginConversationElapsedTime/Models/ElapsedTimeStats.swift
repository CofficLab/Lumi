import Foundation
import ProviderMessage

/// 当前对话的「模型实际工作时间」统计。
///
/// ## 口径
///
/// 每次 LLM 请求都自带一段计时：从请求发出到完整响应返回（`latencyMs`）。
/// 计时窗口只包住那一次推理，用户思考、等待输入的空闲期不产生任何 assistant
/// 消息，也就完全不计入。因此把会话里所有 assistant 消息的 `latencyMs` 相加，
/// 得到的就是「模型真正在干活的时长之和」。
///
/// 工具执行时间不在其中：它在工具调用记录里，不属于模型推理。
struct ElapsedTimeStats: Equatable {
    /// 全部请求的端到端耗时之和（毫秒）。
    var totalLatencyMs: Double = 0
    /// 等首个 token 的耗时之和（毫秒）。
    var firstTokenWaitMs: Double = 0
    /// 首个 token 之后的生成耗时之和（毫秒）。
    var generationMs: Double = 0
    /// 计入统计的请求数。
    var requestCount: Int = 0

    /// 总时长（秒）。
    var totalSeconds: TimeInterval { totalLatencyMs / 1_000 }

    /// 会话里还没有任何计时数据。
    var isEmpty: Bool { requestCount == 0 }

    static let empty = ElapsedTimeStats()

    /// 从会话消息聚合模型工作时间。
    ///
    /// 只统计 assistant 消息：只有它们对应一次真实的模型请求。
    static func compute(messages: [Message]) -> ElapsedTimeStats {
        var stats = ElapsedTimeStats()

        for message in messages where message.role == .assistant {
            // 没有计时数据的老消息、失败后重试产生的空响应都不参与统计：
            // 宁可少算，也不要用 0 冒充一次请求。
            guard let latency = message.latencyMs, latency > 0 else { continue }

            stats.totalLatencyMs += latency
            stats.requestCount += 1
            stats.firstTokenWaitMs += message.timeToFirstTokenMs ?? 0
            stats.generationMs += message.streamingDurationMs ?? 0
        }

        return stats
    }
}
