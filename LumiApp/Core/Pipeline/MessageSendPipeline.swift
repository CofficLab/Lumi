import Foundation

/// `MessageSendEvent` 的中间件协议。
///
/// 语义：
/// - 可以修改 `MessageSendMiddlewareContext`
/// - 可以通过不调用 `next` 来短路（例如过滤/拦截某些发送事件）
@MainActor
protocol MessageSendMiddleware {
    var id: String { get }
    var order: Int { get }

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async
}

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnyMessageSendMiddleware {
    let id: String
    let order: Int
    private let _handle: @MainActor (MessageSendEvent, MessageSendMiddlewareContext, @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void) async -> Void

    init<M: MessageSendMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { event, ctx, next in
            await middleware.handle(event: event, ctx: ctx, next: next)
        }
    }

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        await _handle(event, ctx, next)
    }
}

/// 消息发送管线中的「下一环」。
typealias MessageSendPipelineNext = @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void

/// 管线闭包形态的发送中间件。
typealias MessageSendPipelineMiddleware = @MainActor (
    _ event: MessageSendEvent,
    _ ctx: MessageSendMiddlewareContext,
    _ next: @escaping MessageSendPipelineNext
) async -> Void

/// `MessageSendEvent` 中间件管线。
///
/// - 中间件可修改共享的 `MessageSendMiddlewareContext`，也可通过不调用 `next` 短路。
/// - `terminal` 为链尾默认逻辑（无短路时执行）。
@MainActor
final class MessageSendPipeline {
    private let middlewares: [MessageSendPipelineMiddleware]

    init(middlewares: [MessageSendPipelineMiddleware]) {
        self.middlewares = middlewares
    }

    func run(_ event: MessageSendEvent, ctx: MessageSendMiddlewareContext, terminal: @escaping MessageSendPipelineNext) async {
        func makeNext(_ index: Int) -> MessageSendPipelineNext {
            { @MainActor event, ctx in
                if index < self.middlewares.count {
                    await self.middlewares[index](event, ctx, makeNext(index + 1))
                } else {
                    await terminal(event, ctx)
                }
            }
        }

        await makeNext(0)(event, ctx)
    }
}
