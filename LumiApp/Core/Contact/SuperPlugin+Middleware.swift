import Foundation

// MARK: - Middleware Hooks

extension SuperPlugin {
    /// 提供对话轮次事件中间件。
    ///
    /// 插件可返回一组中间件，用于拦截/过滤 `ConversationTurnEvent`。
    @MainActor func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware]

    /// 提供消息发送事件中间件。
    ///
    /// 插件可返回一组中间件，用于拦截/过滤 `MessageSendEvent`。
    @MainActor func messageSendMiddlewares() -> [AnyMessageSendMiddleware]
}

// MARK: - Middleware Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供对话轮次事件中间件。
    ///
    /// 插件可返回一组 `ConversationTurnMiddleware` 用于拦截/过滤 `ConversationTurnEvent`。
    @MainActor func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] { [] }

    /// 默认实现：不提供消息发送事件中间件。
    ///
    /// 插件可返回一组 `MessageSendMiddleware` 用于拦截/过滤 `MessageSendEvent`。
    @MainActor func messageSendMiddlewares() -> [AnyMessageSendMiddleware] { [] }
}
