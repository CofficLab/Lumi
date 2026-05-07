import Foundation

/// 消息发送中间件协议
///
/// 中间件可以在两个阶段介入：
/// 1. **发送前** (`handle`): 修改或增强发送给 LLM 的消息
/// 2. **发送后** (`handlePost`): 记录日志、审计、分析响应
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
///     // 发送后：记录日志
///     func handlePost(metadata: RequestMetadata, response: ChatMessage?) async {
///         print("HTTP 请求完成：\(metadata.method) \(metadata.url)")
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

    /// 发送后处理（可选实现）
    ///
    /// 在 LLM 响应后调用，可用于：
    /// - 记录请求日志
    /// - 审计和分析
    /// - Token 使用统计
    /// - 错误追踪
    ///
    /// - Parameters:
    ///   - metadata: 请求元数据，包含完整的请求和响应信息
    ///   - response: LLM 响应消息（如果请求失败则为 nil）
    func handlePost(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async
}

/// 默认实现：发送后处理为空操作
extension SuperSendMiddleware {
    func handlePost(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async {
        // 默认不执行任何操作，子类可重写
    }
}
