import Foundation
import MagicKit

/// Agent Permission Policy 插件
///
/// 将“权限请求的去噪/合并/展示策略”从核心对话轮次 handler 中解耦出来。
actor AgentPermissionPolicyPlugin: SuperPlugin {
    static let id: String = "AgentPermissionPolicy"
    static let displayName: String = "Agent Permission Policy"
    static let description: String = "权限请求去噪、合并与展示策略（通过中间件解耦）。"
    static let iconName: String = "hand.raised"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 530 }

    static let shared = AgentPermissionPolicyPlugin()

    @MainActor
    func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] {
        [AnyConversationTurnMiddleware(PermissionPolicyMiddleware())]
    }
}

