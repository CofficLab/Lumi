import Foundation

/// Turn 结束原因
///
/// 描述一个 Agent 回合为何终止，中间件可据此决定不同的处理策略。
public enum TurnEndReason: Sendable, Equatable {
    /// 正常完成：LLM 返回了不含工具调用的 assistant 消息
    case completed
    /// 用户主动取消（点击停止按钮）
    case cancelled
    /// 请求失败（网络错误、API 错误等），包含错误描述
    case failed(String)
    /// 用户拒绝了工具执行权限
    case userRejection
}

/// Turn 结束上下文
///
/// 在一个完整的 Agent 回合结束时，由 `AgentTurnService` 创建并传递给
/// 每个中间件的 `handleTurnFinished(ctx:)` 方法。
///
/// ## 与 `handlePost` 的区别
///
/// | 维度 | `handlePost` | `handleTurnFinished` |
/// |------|-------------|---------------------|
/// | 粒度 | 每次 LLM HTTP 请求 | 整个 Agent Turn |
/// | 频率 | 一个 Turn 内可能多次 | 每个 Turn 恰好一次 |
/// | 时机 | 单次请求完成后立即 | 整个循环结束后 |
///
/// ## 生命周期
///
/// 在 `AgentTurnService.finishTurn()` 系列方法中创建，
/// 随管道执行完毕而销毁，不跨 Turn 复用。
///
/// ## 使用示例
///
/// ```swift
/// func handleTurnFinished(ctx: TurnFinishedContext) async {
///     guard ctx.endReason == .completed else { return }
///     // 在对话正常结束后提取记忆、更新统计等
/// }
/// ```
@MainActor
open class TurnFinishedContext {

    /// 所属会话的唯一标识
    public let conversationId: UUID

    /// Turn 结束原因
    public let endReason: TurnEndReason

    /// 本轮 Turn 中产生的所有消息（包含用户消息、助手消息、工具消息等）
    public let turnMessages: [ChatMessage]

    // MARK: - Initializer

    /// LumiCoreKit 提供的初始化器
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - endReason: Turn 结束原因
    ///   - turnMessages: 本轮产生的所有消息
    public init(
        conversationId: UUID,
        endReason: TurnEndReason,
        turnMessages: [ChatMessage]
    ) {
        self.conversationId = conversationId
        self.endReason = endReason
        self.turnMessages = turnMessages
    }
}
