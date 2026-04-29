import MagicKit
import os

/// 在用户首条消息发送时，根据内容自动生成会话标题（发送管线中间件）。
actor AutoConversationTitlePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-conversation-title")

    static let id = "AutoConversationTitlePlugin"
    static let displayName: String = String(localized: "Auto Conversation Title", table: "AutoConversationTitlePlugin")
    static let description: String = String(localized: "After the first user message is sent, generate a short title by calling the model according to the default title rule.", table: "AutoConversationTitlePlugin")
    static let iconName: String = "textformat.size"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 8 }

    static let shared = AutoConversationTitlePlugin()

    private init() {}

    // MARK: - Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        [AnySendMiddleware(AutoConversationTitleSendMiddleware())]
    }
}
