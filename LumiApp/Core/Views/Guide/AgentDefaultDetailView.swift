import SwiftUI

/// Agent 模式下默认详情视图（当右侧栏无内容时显示）
struct AgentDefaultDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        VStack(spacing: 20) {
            Spacer()
            Text("欢迎使用 Lumi")
                .font(AppUI.Typography.title3)
                .foregroundColor(theme.workspaceTextColor())
            Text("请从侧边栏选择一个导航入口")
                .font(AppUI.Typography.body)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
