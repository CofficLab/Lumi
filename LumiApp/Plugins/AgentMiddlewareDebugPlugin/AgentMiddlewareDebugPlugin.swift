import Foundation
import MagicKit
import OSLog

/// Agent Middleware Debug 插件
///
/// 提供一个最简单的日志中间件，用于验证中间件链路是否生效。
actor AgentMiddlewareDebugPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🧪"
    nonisolated static let verbose = false

    static let id: String = "AgentMiddlewareDebug"
    static let displayName: String = "Agent Middleware Debug"
    static let description: String = "提供日志中间件，用于验证中间件系统是否正常工作。"
    static let iconName: String = "waveform.path.ecg"
    // 用于验证中间件链路：默认始终启用，避免被用户设置关闭导致“看不到日志”误判。
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 900 }

    static let shared = AgentMiddlewareDebugPlugin()

    init() {
        os_log("\(Self.t)✅ AgentMiddlewareDebugPlugin 初始化完成")
    }

    @MainActor
    func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] {
        [AnyConversationTurnMiddleware(ConversationTurnLoggingMiddleware())]
    }
}
