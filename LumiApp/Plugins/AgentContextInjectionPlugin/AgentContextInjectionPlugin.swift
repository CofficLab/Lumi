import Foundation
import MagicKit

/// Agent Context Injection 插件
///
/// 通过 `MessageSendEvent` 中间件，在发送前把“项目/选中文件/选中文本”等上下文拼接进用户消息，
/// 以插件方式解耦，避免核心发送链路不断膨胀。
actor AgentContextInjectionPlugin: SuperPlugin {
    static let id: String = "AgentContextInjection"
    static let displayName: String = "Agent Context Injection"
    static let description: String = "发送前注入项目/选中文件/选中文本上下文（通过中间件解耦）。"
    static let iconName: String = "paperclip.badge.ellipsis"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 515 }

    static let shared = AgentContextInjectionPlugin()

    @MainActor
    func messageSendMiddlewares() -> [AnyMessageSendMiddleware] {
        [AnyMessageSendMiddleware(ContextInjectionMiddleware())]
    }
}

