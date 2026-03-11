import Foundation
import MagicKit

/// Agent Send Guard 插件
///
/// 用中间件承载“发送前”的边界逻辑（规范化、去重、防抖等），减轻核心发送链路代码负担。
actor AgentSendGuardPlugin: SuperPlugin {
    static let id: String = "AgentSendGuard"
    static let displayName: String = "Agent Send Guard"
    static let description: String = "发送前规范化、去重、防抖（通过中间件解耦）。"
    static let iconName: String = "shield"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 510 }

    static let shared = AgentSendGuardPlugin()

    @MainActor
    func messageSendMiddlewares() -> [AnyMessageSendMiddleware] {
        [AnyMessageSendMiddleware(SendGuardMiddleware())]
    }
}

