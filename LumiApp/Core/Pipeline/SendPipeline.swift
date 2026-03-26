import Foundation

/// 消息发送中间件协议
///
/// 中间件可以在两个阶段介入：
/// 1. **发送前** (`handle`): 修改或增强发送给 LLM 的消息
/// 2. **发送后** (`handlePost`): 记录日志、审计、分析响应
///
/// ## 示例
/// ```swift
/// struct MyMiddleware: SendMiddleware {
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
///         print("LLM 请求完成：\(metadata.messages?.count ?? 0) 条消息")
///     }
/// }
/// ```
@MainActor
protocol SendMiddleware {
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
extension SendMiddleware {
    func handlePost(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async {
        // 默认不执行任何操作，子类可重写
    }
}

/// 消息发送管线中的「下一环」。
typealias SendPipelineNext = @MainActor (SendMessageContext) async -> Void

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnySendMiddleware: SendMiddleware {
    let id: String
    let order: Int
    
    private let _handle: @MainActor (SendMessageContext, @escaping @MainActor (SendMessageContext) async -> Void) async -> Void
    private let _handlePost: @MainActor (RequestMetadata, ChatMessage?) async -> Void

    init<M: SendMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { ctx, next in
            await middleware.handle(ctx: ctx, next: next)
        }
        self._handlePost = { metadata, response in
            await middleware.handlePost(metadata: metadata, response: response)
        }
    }

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await _handle(ctx, next)
    }
    
    func handlePost(
        metadata: RequestMetadata,
        response: ChatMessage?
    ) async {
        await _handlePost(metadata, response)
    }
}

/// 消息发送管线
///
/// 管理中间件的执行，分为两个阶段：
/// 1. **发送前管线**: 通过 `run()` 执行，修改请求
/// 2. **发送后管线**: 通过 `runPost()` 执行，处理响应
@MainActor
final class SendPipeline {
    private let middlewares: [SendMiddleware]

    init(middlewares: [SendMiddleware]) {
        self.middlewares = middlewares.sorted { $0.order < $1.order }
    }

    /// 运行发送前管线
    ///
    /// - Parameters:
    ///   - ctx: 发送上下文
    ///   - terminal: 管线结束时的回调
    func run(ctx: SendMessageContext, terminal: @escaping SendPipelineNext) async {
        func makeNext(_ index: Int) -> SendPipelineNext {
            { @MainActor ctx in
                if index < self.middlewares.count {
                    await self.middlewares[index].handle(
                        ctx: ctx,
                        next: makeNext(index + 1)
                    )
                } else {
                    await terminal(ctx)
                }
            }
        }

        await makeNext(0)(ctx)
    }
    
    /// 运行发送后管线
    ///
    /// 在 LLM 响应后调用，按 order 顺序执行所有中间件的 `handlePost` 方法。
    ///
    /// - Parameters:
    ///   - metadata: 请求元数据
    ///   - response: LLM 响应消息（如果失败则为 nil）
    func runPost(metadata: RequestMetadata, response: ChatMessage?) async {
        for middleware in middlewares {
            await middleware.handlePost(metadata: metadata, response: response)
        }
    }
}