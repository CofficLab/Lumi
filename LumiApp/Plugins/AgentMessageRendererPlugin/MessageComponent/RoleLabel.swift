import SwiftUI

// MARK: - Role Labels

/// 角色标签枚举
/// 提供助手和工具输出的标签视图
@MainActor
enum RoleLabel {
    /// 助手标签视图
    static var assistant: some View {
        AppRoleBadge(String(localized: "Dev Assistant", table: "AgentMessages"))
    }

    /// 工具输出标签视图
    static var tool: some View {
        AppRoleBadge(String(localized: "Tool Output", table: "AgentMessages"))
    }
}
