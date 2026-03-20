import Foundation

/// `ConversationTurnEvent` 的中间件协议。
///
/// 语义：
/// - 可以修改 `ConversationTurnMiddlewareContext`
/// - 可以通过不调用 `next` 来短路（例如过滤高频事件）
@MainActor
protocol ConversationTurnMiddleware {
    var id: String { get }
    var order: Int { get }

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async
}

@MainActor
final class ConversationTurnMiddlewareContext {
    let runtimeStore: ConversationRuntimeStore
    let env: ConversationTurnPipelineHandler.Environment
    let actions: ConversationTurnPipelineHandler.MessageActions
    let ui: ConversationTurnPipelineHandler.UIActions

    let traceId: UUID
    let startedAt: Date

    init(
        runtimeStore: ConversationRuntimeStore,
        env: ConversationTurnPipelineHandler.Environment,
        actions: ConversationTurnPipelineHandler.MessageActions,
        ui: ConversationTurnPipelineHandler.UIActions,
        traceId: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.runtimeStore = runtimeStore
        self.env = env
        self.actions = actions
        self.ui = ui
        self.traceId = traceId
        self.startedAt = startedAt
    }
}

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnyConversationTurnMiddleware {
    let id: String
    let order: Int
    private let _handle: @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext, @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void) async -> Void

    init<M: ConversationTurnMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { event, ctx, next in
            await middleware.handle(event: event, ctx: ctx, next: next)
        }
    }

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        await _handle(event, ctx, next)
    }
}

/// 管线中的「下一环」：传入（可能已被上游修改的）事件与上下文，继续向下执行或结束。
typealias ConversationTurnPipelineNext = @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void

/// 管线闭包形态中间件
typealias ConversationTurnPipelineMiddleware = @MainActor (
    _ event: ConversationTurnEvent,
    _ ctx: ConversationTurnMiddlewareContext,
    _ next: @escaping ConversationTurnPipelineNext
) async -> Void

/// 对话轮次事件中间件管线
///
/// - 中间件可以修改共享的 `ConversationTurnMiddlewareContext`（引用类型），并决定是否调用 `next`。
/// - `terminal` 表示链尾默认处理逻辑（当没有中间件短路时执行）。
@MainActor
final class ConversationTurnPipeline {
    private let middlewares: [ConversationTurnPipelineMiddleware]

    init(middlewares: [ConversationTurnPipelineMiddleware]) {
        self.middlewares = middlewares
    }

    func run(_ event: ConversationTurnEvent, ctx: ConversationTurnMiddlewareContext, terminal: @escaping ConversationTurnPipelineNext) async {
        func makeNext(_ index: Int) -> ConversationTurnPipelineNext {
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
