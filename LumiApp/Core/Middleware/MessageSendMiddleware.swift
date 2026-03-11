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

@MainActor
final class MessageSendMiddlewareContext {
    let runtimeStore: ConversationRuntimeStore
    let traceId: UUID
    let startedAt: Date

    init(runtimeStore: ConversationRuntimeStore, traceId: UUID = UUID(), startedAt: Date = Date()) {
        self.runtimeStore = runtimeStore
        self.traceId = traceId
        self.startedAt = startedAt
    }
}

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

