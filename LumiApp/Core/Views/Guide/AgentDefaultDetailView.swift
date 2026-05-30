import SwiftUI

/// Agent 模式下默认详情视图（当右侧栏无内容时显示）
struct AgentDefaultDetailView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        let theme = themeVM.activeChromeTheme

        VStack(spacing: 20) {
            Spacer()
            Text("欢迎使用 Lumi")
                .font(.appTitle)
                .foregroundColor(theme.workspaceTextColor())
            Text("请从侧边栏选择一个导航入口")
                .font(.appBody)
                .foregroundColor(theme.workspaceSecondaryTextColor())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
