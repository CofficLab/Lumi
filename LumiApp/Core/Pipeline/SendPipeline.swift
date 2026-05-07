import Foundation

/// 消息发送管线中的「下一环」。
typealias SendPipelineNext = @MainActor (SendMessageContext) async -> Void

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnySuperSendMiddleware: SuperSendMiddleware {
    let id: String
    let order: Int
    
    private let _handle: @MainActor (SendMessageContext, @escaping @MainActor (SendMessageContext) async -> Void) async -> Void
    private let _handlePost: @MainActor (RequestMetadata, ChatMessage?) async -> Void

    init<M: SuperSendMiddleware>(_ middleware: M) {
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
    private let middlewares: [SuperSendMiddleware]

    init(middlewares: [SuperSendMiddleware]) {
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
