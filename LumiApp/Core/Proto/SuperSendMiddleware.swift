import Foundation
import LumiCoreKit
import HttpKit

/// 消息发送中间件协议
///
/// 中间件可以在三个阶段介入：
/// 1. **发送前** (`handle`): 修改或增强发送给 LLM 的消息
/// 2. **每次请求后** (`handlePost`): 记录日志、审计、分析单次 LLM 响应
/// 3. **Turn 结束后** (`handleTurnFinished`): 在整个 Agent 回合结束后执行收尾逻辑
///
/// ## 示例
/// ```swift
/// struct MyMiddleware: SuperSendMiddleware {
///     let id = "my-middleware"
///     let order = 100
///
///     // 发送前：添加系统提示词
///     func handle(ctx: SendMessageContext, next: SendPipelineNext) async {
///         ctx.transientSystemPrompts.append("你是一个助手")
///         await next(ctx)
///     }
///
///     // 每次请求后：记录日志
///     func handlePost(metadata: HTTPRequestMetadata, response: ChatMessage?) async {
///         print("HTTP 请求完成：\(metadata.method) \(metadata.url)")
///     }
///
///     // Turn 结束后：提取记忆
///     func handleTurnFinished(ctx: TurnFinishedContext) async {
///         guard ctx.endReason == .completed else { return }
///         // 在对话正常结束后执行收尾逻辑
///     }
/// }
/// ```
@MainActor
protocol SuperSendMiddleware {
    /// 中间件唯一标识
    var id: String { get }
    /// 执行顺序（数字越小越先执行）
    var order: Int { get }

    /// 发送前处理
    ///
    /// - Parameters:
    ///   - ctx: 发送上下文，包含消息和状态
    ///   - next: 调用下一个中间件的回调
    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async

    /// 每次请求后处理（可选实现）
    ///
    /// 在单次 LLM HTTP 请求完成后调用，可用于：
    /// - 记录请求日志
    /// - 审计和分析
    /// - Token 使用统计
    /// - 错误追踪
    ///
    /// - Parameters:
    ///   - metadata: 请求元数据，包含完整的请求和响应信息
    ///   - response: LLM 响应消息（如果请求失败则为 nil）
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
    func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        // 默认不执行任何操作，子类可重写
    }

    func handleTurnFinished(
        ctx: TurnFinishedContext
    ) async {
        // 默认不执行任何操作，子类可重写
    }
}
