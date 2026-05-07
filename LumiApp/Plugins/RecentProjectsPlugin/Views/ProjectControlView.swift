import MagicKit
import LibGit2Swift
import SwiftUI

/// 项目控制视图
/// 默认显示当前项目名 + Git 分支 badge，点击后弹出最近项目 Popover
struct ProjectControlView: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM

    @State private var isPopoverPresented = false
    @State private var branch: String?

    var body: some View {
        let theme = themeVM.activeAppTheme
        let projectName = projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName

        HStack(spacing: 6) {
            Text(projectName)
                .fontWeight(.medium)
                .lineLimit(1)
                .layoutPriority(1)

            if let branch, !branch.isEmpty {
                gitBranchBadge(branch)
            }

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
        .onAppear {
            refreshBranch()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refreshBranch()
        }
        .onApplicationDidBecomeActive {
            refreshBranch()
        }
    }

    // MARK: - Git Branch Badge

    /// 紧凑的分支药丸标签，与 RecentProjectsSidebarView 中的风格一致
    private func gitBranchBadge(_ branch: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 7, weight: .semibold))

            Text(branch)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(AppUI.Color.semantic.primary)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(AppUI.Color.semantic.primary.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(AppUI.Color.semantic.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Branch Refresh

    private func refreshBranch() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            branch = nil
            return
        }

        Task.detached { [path] in
            let result = (try? LibGit2.getCurrentBranch(at: path)) ?? nil
            await MainActor.run {
                self.branch = result
            }
        }
    }
}

// MARK: - Preview

#Preview("Project Control View") {
    ProjectControlView()
        .inRootView()
}
