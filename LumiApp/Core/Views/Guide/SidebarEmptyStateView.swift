import SwiftUI

/// 侧边栏空状态视图
struct SidebarEmptyStateView: View {
    let message: String
    let subtitle: String

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(message)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(subtitle)
                .font(AppUI.Typography.caption1)
                .foregroundColor(theme.workspaceTertiaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
