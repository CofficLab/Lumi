import Foundation

// MARK: - Middleware Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供对话轮次事件中间件。
    @MainActor func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] { [] }

    /// 默认实现：不提供消息发送事件中间件。
    @MainActor func messageSendMiddlewares() -> [AnyMessageSendMiddleware] { [] }
}
