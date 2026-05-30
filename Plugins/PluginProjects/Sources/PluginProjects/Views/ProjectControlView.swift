import GitBranchMonitorKit
import LibGit2Swift
import SwiftUI
import LumiCoreKit
import LumiUI

/// 项目控制视图
/// 默认显示当前项目名 + Git 分支 badge，点击后弹出最近项目 Popover
public struct ProjectControlView: View {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var isPopoverPresented = false
    @State private var branch: String?
    @StateObject private var branchMonitor = GitBranchMonitor(verbose: true)

    public var body: some View {
        if !projectVM.isProjectSelected {
            EmptyView()
        } else {
            projectControlContent
        }
    }

    private var projectControlContent: some View {
        let theme = themeVM.activeChromeTheme
        let projectName = projectVM.currentProjectName

        return HStack(spacing: 6) {
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
                .animation(.easeInOut(duration: 0.15), value: isPopoverPresented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onTapGesture {
            isPopoverPresented = true
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ProjectsSidebarView()
                .frame(width: 300, height: 400)
        }
        .onAppear {
            setupBranchMonitor()
            refreshBranch()
        }
        .onChange(of: projectVM.currentProjectPath) { _, newPath in
            updateBranchMonitor(for: newPath)
            refreshBranch()
        }
        .onApplicationDidBecomeActive {
            refreshBranch()
        }
    }

    // MARK: - Git Branch Badge

    /// 紧凑的分支药丸标签，与 ProjectsSidebarView 中的风格一致
    private func gitBranchBadge(_ branch: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 7, weight: .semibold))

            Text(branch)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(Color(hex: "7C6FFF"))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(Color(hex: "7C6FFF").opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(hex: "7C6FFF").opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Branch Monitor Setup
    
    private func setupBranchMonitor() {
        // 清空调回调，避免重复添加
        branchMonitor.stopAll()
        
        // 设置分支变化回调
        let currentPath = projectVM.currentProjectPath
        branchMonitor.onBranchChange { projectPath, newBranch in
            Task { @MainActor in
                // Note: Cannot use [weak self] with struct, capture path instead
                // Only update if the change is for the current project
                if projectPath == currentPath {
                    // This callback will be called from background thread
                    // The actual state update happens in the view
                }
            }
        }
        
        // 开始监听当前项目路径
        if !currentPath.isEmpty {
            branchMonitor.startMonitoring(projectPath: currentPath)
        }
    }
    
    private func updateBranchMonitor(for newPath: String) {
        // 停止监听旧路径（如果有）
        // 注意：branchMonitor 内部会处理重复监听的情况
        
        // 开始监听新路径
        if newPath.isEmpty {
            // 如果新路径为空，停止所有监听
            branchMonitor.stopAll()
        } else {
            branchMonitor.startMonitoring(projectPath: newPath)
        }
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
