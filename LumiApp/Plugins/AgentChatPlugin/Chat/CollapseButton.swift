import SwiftUI
import MagicKit

// MARK: - Collapse Button

/// 折叠按钮组件
/// 用于在助手消息 Header 中显示折叠/展开操作
struct CollapseButton: View {
    /// 点击回调
    let action: () -> Void

    var body: some View {
        AppIconButton(
            systemImage: "chevron.up",
            label: String(localized: "Collapse", table: "AgentInput"),
            tint: AppUI.Color.semantic.textSecondary.opacity(0.8),
            size: .compact,
            action: action
        )
        .help(String(localized: "Collapse Message", table: "AgentInput"))
    }
}
