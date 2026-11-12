import Foundation
import ProviderMessage

/// 当前对话的 token 用量统计。
///
/// 口径与「上下文用量」保持一致：缓存型端点（如 Anthropic 兼容协议）的
/// `inputTokenCount` 可能只表示**未命中缓存**的部分，实际总输入由
/// `cacheTotalInputTokenCount` 给出，因此取 `cacheTotalInputTokenCount`
/// 优先、缺失时才退回 `inputTokenCount`。
struct TokenUsageStats: Equatable {
    /// 全部响应累计的输入 token 数。
    var inputTokens: Int = 0
    /// 全部响应累计的输出 token 数。
    var outputTokens: Int = 0
    /// 上报了用量的响应数量。
    var requestCount: Int = 0

    /// 输入 + 输出。
    var totalTokens: Int { inputTokens + outputTokens }

    /// 会话里还没有任何用量数据。
    var isEmpty: Bool { requestCount == 0 }

    static let empty = TokenUsageStats()

    /// 从会话消息聚合 token 用量。
    ///
    /// 只统计 assistant 消息：user / tool 消息没有服务端上报的用量，
    /// 把它们算进来会重复计入同一批 prompt。
    static func compute(messages: [Message]) -> TokenUsageStats {
        var stats = TokenUsageStats()

        for message in messages where message.role == .assistant {
            let input = message.cacheTotalInputTokenCount
                ?? message.inputTokenCount
                ?? 0
            let output = message.outputTokenCount ?? 0

            // 一条既没有输入也没有输出的 assistant 消息（供应商未上报 usage）
            // 不算一次请求，否则「请求数」会与供应商实际调用次数不一致。
            guard input > 0 || output > 0 else { continue }

            stats.inputTokens += input
            stats.outputTokens += output
            stats.requestCount += 1
        }

        return stats
    }
}
