import Foundation
import MagicKit

/// 在用户首条消息发送时，根据内容自动生成会话标题（发送管线中间件）。
actor AutoConversationTitlePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose = false

    static let displayName: String = "自动会话标题"
    static let description: String = "首条用户消息发送后，按默认标题规则调用模型生成简短标题。"
    static let iconName: String = "textformat.size"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 8 }

    static let shared = AutoConversationTitlePlugin()

    private init() {}

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        [AnySendMiddleware(AutoConversationTitleSendMiddleware())]
    }
}