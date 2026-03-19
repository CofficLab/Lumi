import Foundation
import MagicKit
import os

/// Agent Auto Title 插件
///
/// 将“何时触发自动生成标题”的策略放到插件里，通过 `MessageSendEvent` 中间件实现解耦。
actor AgentAutoTitlePlugin: SuperPlugin {
    /// 插件专用 Logger（subsystem=应用ID, category=插件标识），符合 Apple Unified Logging 规范
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-title")

    static let id: String = "AgentAutoTitle"
    static let displayName: String = "Agent Auto Title"
    static let description: String = "通过中间件在合适时机自动生成会话标题。"
    static let iconName: String = "text.book.closed"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 520 }

    static let shared = AgentAutoTitlePlugin()

    @MainActor
    func messageSendMiddlewares() -> [AnyMessageSendMiddleware] {
        [AnyMessageSendMiddleware(AutoTitleGenerationMiddleware())]
    }
}

