import Foundation

@MainActor
protocol SendMiddleware {
    var id: String { get }
    var order: Int { get }

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async
}

/// 消息发送管线中的「下一环」。
typealias SendPipelineNext = @MainActor (SendMessageContext) async -> Void

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnySendMiddleware: SendMiddleware {
    let id: String
    let order: Int
    private let _handle: @MainActor (SendMessageContext, @escaping @MainActor (SendMessageContext) async -> Void) async -> Void

    init<M: SendMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { ctx, next in
            await middleware.handle(ctx: ctx, next: next)
        }
    }

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await _handle(ctx, next)
    }
}

@MainActor
final class SendPipeline {
    private let middlewares: [SendMiddleware]

    init(middlewares: [SendMiddleware]) {
        self.middlewares = middlewares
    }

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
}
