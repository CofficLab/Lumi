import Foundation
import MagicKit

/// 请求日志插件
///
/// 记录每次聊天请求的发送数据，包括请求消息、配置、响应等信息。
/// 用于调试和审计。
actor RequestLogPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    static let id = "RequestLog"
    static let displayName: String = String(localized: "PluginName", table: "RequestLog")
    static let description: String = String(localized: "PluginDescription", table: "RequestLog")
    static let iconName: String = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 100 }

    static let shared = RequestLogPlugin()

    private init() {}

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        [AnySendMiddleware(RequestLogSendMiddleware())]
    }
}