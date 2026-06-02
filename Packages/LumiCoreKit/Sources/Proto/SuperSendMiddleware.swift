import Foundation
import HttpKit

/// 消息发送中间件协议
///
/// 中间件可以在三个阶段介入：
/// 1. **发送前** (`handle`): 修改或增强发送给 LLM 的消息
/// 2. **每次请求后** (`handlePost`): 记录日志、审计、分析单次 LLM 响应
/// 3. **Turn 结束后** (`handleTurnFinished`): 在整个 Agent 回合结束后执行收尾逻辑
@MainActor
public protocol SuperSendMiddleware {
    /// 中间件唯一标识
    var id: String { get }
    /// 执行顺序（数字越小越先执行）
    var order: Int { get }

    /// 发送前处理
    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async

    /// 每次请求后处理（可选实现）
    func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async

    /// Turn 结束后处理（可选实现）
    ///
    /// 在一个完整的 Agent 回合结束时调用（每个 Turn 恰好一次）。
    /// 可用于：
    /// - 提取并保存记忆
    /// - 更新任务完成状态
    /// - 统计本轮 Token 用量
    /// - 发送桌面通知
    ///
    /// - Parameter ctx: Turn 结束上下文，包含结束原因和本轮所有消息
    func handleTurnFinished(
        ctx: TurnFinishedContext
    ) async
}

/// 默认实现：后置处理为空操作
extension SuperSendMiddleware {
    public func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        // 默认不执行任何操作
    }

    public func handleTurnFinished(
        ctx: TurnFinishedContext
    ) async {
        // 默认不执行任何操作
    }
}
