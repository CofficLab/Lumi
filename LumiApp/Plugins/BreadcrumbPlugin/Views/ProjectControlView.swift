import MagicKit
import SwiftUI

/// 项目控制视图
/// 默认显示当前项目名，点击后弹出最近项目 Popover
struct ProjectControlView: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var isPopoverPresented = false

    var body: some View {
        let theme = themeManager.activeAppTheme

        HStack(spacing: 6) {
            Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                .font(AppUI.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(theme.workspaceTextColor())

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.workspaceTertiaryTextColor())
                .rotationEffect(.degrees(isPopoverPresented ? 180 : 0))
                .animation(.easeInOut(duration: DesignTokens.Duration.micro), value: isPopoverPresented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onTapGesture {
            isPopoverPresented = true
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            RecentProjectsSidebarView()
                .frame(width: 300, height: 400)
        }
    }
}

// MARK: - Preview

#Preview("Project Control View") {
    ProjectControlView()
        .inRootView()
}
