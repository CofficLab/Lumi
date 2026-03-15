import Foundation
import MagicKit

/// Agent Error Policy 插件
///
/// 将“错误分类/去噪/展示策略”从核心对话轮次处理里解耦出来，避免主流程不断累积分支逻辑。
actor AgentErrorPolicyPlugin: SuperPlugin {
    static let id: String = "AgentErrorPolicy"
    static let displayName: String = "Agent Error Policy"
    static let description: String = "对回合错误进行分类、去噪与用户提示策略（通过中间件解耦）。"
    static let iconName: String = "exclamationmark.triangle"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 525 }

    static let shared = AgentErrorPolicyPlugin()

    @MainActor
    func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] {
        [AnyConversationTurnMiddleware(ErrorPolicyMiddleware())]
    }
}

