import Foundation
import MagicKit
import os

/// Agent Message Count Logger 插件
///
/// 通过 `MessageSendEvent` 中间件，在发送消息时输出当前对话的消息数量日志。
actor AgentMessageCountLoggerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-count-logger")

    static let id: String = "AgentMessageCountLogger"
    static let displayName: String = "Agent Message Count Logger"
    static let description: String = "在发送消息时输出当前对话的消息数量日志。"
    static let iconName: String = "number.circle"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 515 }

    /// 日志标识符
    nonisolated static let emoji = "📊"

    /// 详细日志级别
    nonisolated static let verbose = true

    static let shared = AgentMessageCountLoggerPlugin()

    @MainActor
    func messageSendMiddlewares() -> [AnyMessageSendMiddleware] {
        [AnyMessageSendMiddleware(AgentMessageCountLoggerMiddleware())]
    }
}
