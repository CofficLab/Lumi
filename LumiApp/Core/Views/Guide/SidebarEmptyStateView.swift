import SwiftUI

/// 侧边栏空状态视图
struct SidebarEmptyStateView: View {
    let message: String
    let subtitle: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppUI.Color.adaptive.textSecondary(for: colorScheme))

            Text(message)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.adaptive.textSecondary(for: colorScheme))

            Text(subtitle)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.adaptive.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
