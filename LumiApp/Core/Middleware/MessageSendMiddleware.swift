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
    let services: MessageSendMiddlewareServices
    let traceId: UUID
    let startedAt: Date

    init(
        runtimeStore: ConversationRuntimeStore,
        services: MessageSendMiddlewareServices,
        traceId: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.runtimeStore = runtimeStore
        self.services = services
        self.traceId = traceId
        self.startedAt = startedAt
    }
}

/// `MessageSendEvent` 中间件上下文的依赖集合（通过闭包注入，避免插件直接依赖核心对象）。
@MainActor
struct MessageSendMiddlewareServices {
    /// 获取对话标题（用于判断是否仍是默认标题）。
    let getConversationTitle: (UUID) -> String?
    /// 是否已为该对话生成过标题（用于防止重复生成）。
    let hasGeneratedTitle: (UUID) -> Bool
    /// 标记“已生成标题”状态。
    let setTitleGenerated: (Bool, UUID) -> Void
    /// 获取当前用于生成标题的 LLM 配置。
    let getCurrentConfig: () -> LLMConfig
    /// 执行“如有需要则生成标题”的核心逻辑。
    let autoGenerateConversationTitleIfNeeded: @Sendable (UUID, String, LLMConfig) async -> Void
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

