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
                .font(.appLargeTitle)
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(message)
                .font(.appBodyEmphasized)
                .foregroundColor(theme.workspaceSecondaryTextColor())

            Text(subtitle)
                .font(.appCaption)
                .foregroundColor(theme.workspaceTertiaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
