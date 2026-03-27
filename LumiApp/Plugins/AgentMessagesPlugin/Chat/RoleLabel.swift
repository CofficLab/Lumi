import SwiftUI

// MARK: - Role Labels

/// 角色标签枚举
/// 提供助手和工具输出的标签视图
enum RoleLabel {
    /// 助手标签视图
    static var assistant: some View {
        Text(String(localized: "Dev Assistant", table: "AgentMessages"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }

    /// 工具输出标签视图
    static var tool: some View {
        Text(String(localized: "Tool Output", table: "AgentMessages"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }
}