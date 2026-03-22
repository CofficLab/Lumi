import Foundation

// MARK: - Middleware Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供对话轮次事件中间件。
    @MainActor func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] { [] }
}
