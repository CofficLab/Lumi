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
    /// 获取当前用于生成标题的 LLM 配置。
    let getCurrentConfig: () -> LLMConfig
    /// 仅生成标题文本，不做触发判定与持久化更新。
    let generateConversationTitle: @Sendable (String, LLMConfig) async -> String
    /// 仅当当前标题仍等于 expectedTitle 时更新为 newTitle，返回是否更新成功。
    let updateConversationTitleIfUnchanged: @Sendable (UUID, String, String) async -> Bool

    /// 当前是否已选择项目。
    let isProjectSelected: () -> Bool
    /// 获取当前项目名称与路径。
    let getProjectInfo: () -> (name: String, path: String)

    /// 当前是否已选择文件（文件预览/树选中）。
    let isFileSelected: () -> Bool
    /// 获取当前选中文件路径与内容（若有）。
    let getSelectedFileInfo: () -> (path: String, content: String)

    /// 获取系统级"当前选中文本"（若启用文本选择能力）。
    let getSelectedText: () -> String?

    /// 获取指定对话的消息数量。
    let getMessageCount: (UUID) -> Int
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

