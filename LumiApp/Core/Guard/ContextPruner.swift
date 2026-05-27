import Foundation
import LLMKit

/// 上下文裁剪策略
///
/// 当对话历史消息过多时，通过滑动窗口 + 摘要占位的方式控制发送给 LLM 的消息数量，
/// 防止超出模型的上下文窗口限制。
///
/// ## 策略
///
/// 1. 消息总数未超过 `maxMessages` → 原样返回，不裁剪
/// 2. 消息总数超过 `maxMessages` →
///    - 保留最近 `maxMessages` 条消息
///    - 在头部插入一条 system 消息作为「早期对话摘要」占位
///
/// ## 设计原则
///
/// - **纯函数**：无副作用，不修改原始数组
/// - **自适应**：支持根据上次请求的 `inputTokens` 动态调整窗口大小
/// - **保留结构**：确保裁剪后的消息序列仍然符合 LLM API 要求（tool 消息紧跟 assistant）
struct ContextPruner: SuperLog {
    nonisolated static let emoji = "✂️"

    // MARK: - 配置

    /// 裁剪配置
    struct Configuration {
        /// 保留的最大消息条数（滑动窗口大小）
        let maxMessages: Int

        /// token 使用率阈值（0.0 ~ 1.0）
        /// 当上次请求的 inputTokens / contextWindow 超过此值时，自动收紧窗口
        let tokenUsageThreshold: Double

        /// token 超限时的收紧系数（乘以 maxMessages）
        let tighteningFactor: Double

        /// 早期对话摘要占位文本
        let summaryPlaceholder: String

        static let `default` = Configuration(
            maxMessages: 80,
            tokenUsageThreshold: 0.8,
            tighteningFactor: 0.6,
            summaryPlaceholder: "The following is a summary of earlier conversation in this session. Earlier messages have been pruned to save context space."
        )
    }

    // MARK: - 裁剪结果

    struct PruneResult {
        /// 裁剪后的消息列表
        let messages: [ChatMessage]
        /// 被裁剪掉的消息数量
        let prunedCount: Int
        /// 裁剪原因
        let reason: PruneReason?
    }

    enum PruneReason {
        /// 消息数量超过限制
        case messageLimitExceeded(original: Int, kept: Int)
        /// token 使用率过高，自动收紧
        case tokenBudgetTight(original: Int, kept: Int, usageRatio: Double)
    }

    // MARK: - 公开接口

    /// 裁剪消息列表
    ///
    /// - Parameters:
    ///   - messages: 展开后的 LLM 消息列表
    ///   - config: 裁剪配置
    ///   - lastInputTokens: 上次 LLM 请求的 inputTokens（可选，用于自适应调整）
    ///   - contextWindowSize: 当前模型的上下文窗口大小（可选）
    /// - Returns: 裁剪结果
    static func prune(
        _ messages: [ChatMessage],
        config: Configuration = .default,
        lastInputTokens: Int? = nil,
        contextWindowSize: Int? = nil
    ) -> PruneResult {
        // 1. 不需要裁剪
        guard messages.count > config.maxMessages else {
            return PruneResult(messages: messages, prunedCount: 0, reason: nil)
        }

        // 2. 计算实际保留条数（可能因 token 使用率收紧）
        var effectiveMax = config.maxMessages

        if let lastTokens = lastInputTokens, let windowSize = contextWindowSize, windowSize > 0 {
            let usageRatio = Double(lastTokens) / Double(windowSize)
            if usageRatio > config.tokenUsageThreshold {
                let tightenedMax = Int(Double(config.maxMessages) * config.tighteningFactor)
                effectiveMax = max(tightenedMax, 20) // 最低保留 20 条
                let kept = min(effectiveMax, messages.count)
                AppLogger.core.info("\(t)Token 使用率 \(String(format: "%.0f%%", usageRatio * 100)) 超过阈值，收紧窗口：\(config.maxMessages) → \(effectiveMax)")
                return makePrunedResult(
                    messages: messages,
                    maxKeep: effectiveMax,
                    reason: .tokenBudgetTight(original: messages.count, kept: kept, usageRatio: usageRatio),
                    config: config
                )
            }
        }

        // 3. 标准裁剪
        return makePrunedResult(
            messages: messages,
            maxKeep: effectiveMax,
            reason: .messageLimitExceeded(original: messages.count, kept: effectiveMax),
            config: config
        )
    }

    // MARK: - 私有方法

    /// 执行裁剪并构建结果
    private static func makePrunedResult(
        messages: [ChatMessage],
        maxKeep: Int,
        reason: PruneReason,
        config: Configuration
    ) -> PruneResult {
        // 从尾部取最近的消息
        let kept = Array(messages.suffix(maxKeep))

        // 确保裁剪后的消息序列结构完整：
        // - 如果开头是孤立的 tool 消息（没有对应的 assistant 消息），需要跳过
        let trimmed = trimLeadingOrphanedToolMessages(kept)

        // 在头部插入摘要占位
        let summaryMessage = ChatMessage(
            role: .system,
            conversationId: messages.first?.conversationId ?? UUID(),
            content: config.summaryPlaceholder
        )

        let result = [summaryMessage] + trimmed
        let prunedCount = messages.count - trimmed.count

        if let convId = messages.first?.conversationId {
            AppLogger.core.info("\(t)[\(convId)] 裁剪完成：\(messages.count) → \(result.count) 条消息（保留 \(trimmed.count) + 1 摘要占位）")
        }

        return PruneResult(messages: result, prunedCount: prunedCount, reason: reason)
    }

    /// 跳过开头的孤立 tool 消息
    ///
    /// 裁剪后如果开头是 tool 消息但没有对应的 assistant 消息，
    /// LLM API 会报错。需要跳过这些孤立消息，直到找到第一条非 tool 消息。
    private static func trimLeadingOrphanedToolMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var startIndex = 0
        for (index, message) in messages.enumerated() {
            if message.role == .tool {
                startIndex = index + 1
            } else {
                break
            }
        }
        return startIndex > 0 ? Array(messages.dropFirst(startIndex)) : messages
    }
}
