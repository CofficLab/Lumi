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
    let env: ConversationTurnCoordinator.Environment
    let actions: ConversationTurnCoordinator.MessageActions
    let ui: ConversationTurnCoordinator.UIActions

    let traceId: UUID
    let startedAt: Date

    init(
        runtimeStore: ConversationRuntimeStore,
        env: ConversationTurnCoordinator.Environment,
        actions: ConversationTurnCoordinator.MessageActions,
        ui: ConversationTurnCoordinator.UIActions,
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

