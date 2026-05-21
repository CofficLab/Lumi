import SwiftUI

/// 侧边栏空状态视图
struct SidebarEmptyStateView: View {
    let message: String
    let subtitle: String

    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        let theme = themeVM.activeChromeTheme

        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(theme.workspaceTertiaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
